#!/usr/bin/env python3
"""QA for trailer clips and the final cut.

  qa.py clips --shots shots.json            every recorded clip in <shots dir>/clips
  qa.py final FILE.mp4 [--roblox]           the exported cut (+ Roblox upload limits with --roblox)
  qa.py sheet FILE [--cols 4 --rows 4]      contact sheet PNG with timestamps (also made by `final`)

Checks (each clip / file):
  * format: resolution, fps, codec, duration
  * dropped frames: gaps in frame timestamps > 1.5 frame intervals (screencapture drops when the Mac is busy)
  * black frames (blackdetect) and frozen stretches (freezedetect; a frozen gameplay clip = Studio hitched)
  * Studio UI chrome: flat Studio-grey or white bands along the frame edges (panel/toolbar leaked into the crop)
  * cursor: verifies the clip metadata says it was recorded without -C; the contact sheet is for eyes
Writes a JSON report next to the file and exits 1 if anything FAILs. LOOK at the contact sheet before
calling a cut done: the Studio top bar, a stray cursor or a wrong HUD state are easiest to see there.
"""
import argparse
import json
import re
import subprocess
import sys
import tempfile
from pathlib import Path

ROBLOX_MAX_SECS = 30.0
ROBLOX_MAX_BYTES = 375 * 1024 * 1024
ROBLOX_MAX_W, ROBLOX_MAX_H = 4096, 2160


def run(cmd):
    return subprocess.run(cmd, capture_output=True, text=True)


def stream_info(path):
    r = run(["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries",
             "stream=codec_name,width,height,avg_frame_rate,r_frame_rate,nb_frames:format=duration,size",
             "-of", "json", str(path)])
    j = json.loads(r.stdout or "{}")
    s = (j.get("streams") or [{}])[0]
    f = j.get("format") or {}

    def rate(v):
        try:
            a, b = v.split("/")
            return float(a) / float(b) if float(b) else 0.0
        except Exception:
            return 0.0
    return {"codec": s.get("codec_name"), "w": s.get("width"), "h": s.get("height"),
            "fps": round(rate(s.get("avg_frame_rate", "0/1")), 2), "r_fps": round(rate(s.get("r_frame_rate", "0/1")), 2),
            "duration": float(f.get("duration", 0) or 0), "bytes": int(f.get("size", 0) or 0)}


def dropped_frames(path, fps_nominal):
    r = run(["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries", "frame=pts_time",
             "-of", "csv=p=0", str(path)])
    ts = []
    for line in r.stdout.split():
        try:
            ts.append(float(line.strip().strip(",")))
        except ValueError:
            pass
    if len(ts) < 3:
        return {"frames": len(ts), "gaps": 0, "missing": 0, "worst_gap_ms": 0}
    ts.sort()
    step = 1.0 / (fps_nominal or 60)
    gaps, missing, worst = 0, 0, 0.0
    for a, b in zip(ts, ts[1:]):
        d = b - a
        worst = max(worst, d)
        if d > step * 1.5:
            gaps += 1
            missing += int(round(d / step)) - 1
    return {"frames": len(ts), "gaps": gaps, "missing": missing, "worst_gap_ms": round(worst * 1000, 1),
            "missing_pct": round(100.0 * missing / max(1, len(ts) + missing), 2)}


def detect(path, vf):
    r = run(["ffmpeg", "-v", "info", "-i", str(path), "-vf", vf, "-an", "-f", "null", "-"])
    return r.stderr


def black_frames(path):
    out = detect(path, "blackdetect=d=0.05:pix_th=0.08")
    spans = [(float(a), float(b)) for a, b in re.findall(r"black_start:([\d.]+) black_end:([\d.]+)", out)]
    return spans


def frozen(path):
    out = detect(path, "freezedetect=n=0.002:d=0.6")
    starts = [float(x) for x in re.findall(r"freeze_start: ([\d.]+)", out)]
    durs = [float(x) for x in re.findall(r"freeze_duration: ([\d.]+)", out)]
    return [(s, d) for s, d in zip(starts, durs)]


def edge_chrome(path, duration):
    """Sample frames and look for flat bands on each edge that match Studio UI colours."""
    flags = {}
    times = [duration * k / 7 for k in range(1, 7)]
    for t in times:
        raw = subprocess.run(["ffmpeg", "-v", "error", "-ss", f"{t:.2f}", "-i", str(path), "-frames:v", "1",
                              "-vf", "scale=320:180", "-f", "rawvideo", "-pix_fmt", "rgb24", "-"],
                             capture_output=True).stdout
        if len(raw) < 320 * 180 * 3:
            continue
        W, H = 320, 180

        def px(x, y):
            i = (y * W + x) * 3
            return raw[i], raw[i + 1], raw[i + 2]
        bands = {"top": [(x, y) for y in range(0, 4) for x in range(W)],
                 "bottom": [(x, y) for y in range(H - 4, H) for x in range(W)],
                 "left": [(x, y) for x in range(0, 4) for y in range(H)],
                 "right": [(x, y) for x in range(W - 4, W) for y in range(H)]}
        for edge, pts in bands.items():
            cols = [px(x, y) for x, y in pts]
            n = len(cols)
            mean = [sum(c[i] for c in cols) / n for i in range(3)]
            var = sum(sum((c[i] - mean[i]) ** 2 for i in range(3)) for c in cols) / n
            grey = max(mean) - min(mean) < 8
            studio_dark = grey and 30 <= mean[0] <= 70
            studio_light = grey and mean[0] >= 225
            if var < 60 and (studio_dark or studio_light):
                flags.setdefault(edge, 0)
                flags[edge] += 1
    # an edge flagged in most samples is a leak, not a dark sky
    return [e for e, c in flags.items() if c >= 4]


def contact_sheet(path, out_png, cols=4, rows=4):
    try:
        from PIL import Image, ImageDraw, ImageFont
    except ImportError:
        return None
    info = stream_info(path)
    n = cols * rows
    tmp = Path(tempfile.mkdtemp(prefix="sheet_"))
    tiles = []
    for k in range(n):
        t = info["duration"] * (k + 0.5) / n
        f = tmp / f"t{k:02d}.png"
        run(["ffmpeg", "-v", "error", "-y", "-ss", f"{t:.3f}", "-i", str(path), "-frames:v", "1",
             "-vf", "scale=480:-2", str(f)])
        if f.exists():
            tiles.append((t, Image.open(f).convert("RGB")))
    if not tiles:
        return None
    tw, th = tiles[0][1].size
    sheet = Image.new("RGB", (cols * tw, rows * (th + 26)), (18, 18, 22))
    d = ImageDraw.Draw(sheet)
    try:
        font = ImageFont.truetype("/System/Library/Fonts/SFNSMono.ttf", 18)
    except OSError:
        font = ImageFont.load_default()
    for k, (t, im) in enumerate(tiles):
        x, y = (k % cols) * tw, (k // cols) * (th + 26)
        sheet.paste(im, (x, y + 26))
        d.text((x + 6, y + 3), f"{t:6.2f}s", fill=(230, 230, 230), font=font)
    sheet.save(out_png)
    for f in tmp.iterdir():
        f.unlink()
    tmp.rmdir()
    return str(out_png)


def check_file(path, meta=None, roblox=False, expect_fps=60):
    info = stream_info(path)
    rep = {"file": str(path), **info, "fail": [], "warn": []}
    if (info["w"] or 0) % 2 or (info["h"] or 0) % 2:
        rep["fail"].append("odd width/height (H.264 + Roblox need even sizes)")
    drops = dropped_frames(path, expect_fps)
    rep["drops"] = drops
    if drops.get("missing_pct", 0) > 2:
        rep["fail"].append(f"{drops['missing']} dropped frames ({drops['missing_pct']}%) - re-record with fewer apps open")
    elif drops.get("missing", 0) > 0:
        rep["warn"].append(f"{drops['missing']} dropped frames, worst gap {drops['worst_gap_ms']} ms")
    blk = black_frames(path)
    rep["black"] = blk
    if blk:
        rep["warn" if all(b - a < 0.3 for a, b in blk) else "fail"].append(f"black frames at {blk}")
    frz = frozen(path)
    rep["frozen"] = frz
    if frz:
        rep["warn"].append(f"frozen stretches (start, secs) {frz} - fine for a hold, bad mid-action")
    chrome = edge_chrome(path, info["duration"])
    rep["chrome_edges"] = chrome
    if chrome:
        rep["fail"].append(f"Studio-UI-coloured band on {chrome} edge(s): recalibrate the region or close panels")
    if meta is not None:
        if meta.get("cursor") is not False:
            rep["fail"].append("clip metadata doesn't confirm a cursor-free recording")
        if meta.get("shot_in", 0) < 0.2 and not meta.get("stitched"):
            rep["warn"].append("less than 0.2 s of preroll before the shot")
    if roblox:
        if info["duration"] > ROBLOX_MAX_SECS + 0.01:
            rep["fail"].append(f"{info['duration']:.2f}s > 30 s Roblox limit")
        if info["bytes"] > ROBLOX_MAX_BYTES:
            rep["fail"].append("file > 375 MB")
        if (info["w"] or 0) > ROBLOX_MAX_W or (info["h"] or 0) > ROBLOX_MAX_H:
            rep["fail"].append("resolution above 4096x2160")
        if Path(path).suffix.lower() not in (".mp4", ".mov"):
            rep["fail"].append("must be .mp4 or .mov")
    return rep


def print_rep(rep):
    status = "FAIL" if rep["fail"] else ("WARN" if rep["warn"] else "OK")
    print(f"[{status}] {Path(rep['file']).name}: {rep['w']}x{rep['h']} {rep['fps']}fps {rep['duration']:.2f}s "
          f"{rep['bytes'] / 1e6:.1f}MB")
    for f in rep["fail"]:
        print("   FAIL", f)
    for w in rep["warn"]:
        print("   warn", w)


def cmd_clips(a):
    root = Path(a.shots).parent
    clips = root / "clips"
    ids = [s["id"] for s in json.loads(Path(a.shots).read_text()).get("shots", [])]
    reps, bad = [], False
    for sid in ids:
        mov = clips / f"{sid}.mov"
        if not mov.exists():
            print(f"[MISSING] {sid}")
            continue
        mp = clips / f"{sid}.json"
        meta = json.loads(mp.read_text()) if mp.exists() else {}
        rep = check_file(mov, meta)
        sheet = contact_sheet(mov, clips / f"{sid}_sheet.png", 4, 2)
        rep["sheet"] = sheet
        print_rep(rep)
        print("   sheet", sheet)
        bad |= bool(rep["fail"])
        reps.append(rep)
    (root / "qa_clips.json").write_text(json.dumps(reps, indent=2))
    sys.exit(1 if bad else 0)


def cmd_final(a):
    p = Path(a.file)
    rep = check_file(p, None, roblox=a.roblox)
    rep["sheet"] = contact_sheet(p, p.with_name(p.stem + "_sheet.png"), 4, 4)
    print_rep(rep)
    print("   sheet", rep["sheet"])
    p.with_name(p.stem + "_qa.json").write_text(json.dumps(rep, indent=2))
    sys.exit(1 if rep["fail"] else 0)


def cmd_sheet(a):
    p = Path(a.file)
    print(contact_sheet(p, p.with_name(p.stem + "_sheet.png"), a.cols, a.rows))


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    c = sub.add_parser("clips"); c.add_argument("--shots", required=True)
    f = sub.add_parser("final"); f.add_argument("file"); f.add_argument("--roblox", action="store_true")
    s = sub.add_parser("sheet"); s.add_argument("file"); s.add_argument("--cols", type=int, default=4)
    s.add_argument("--rows", type=int, default=4)
    a = ap.parse_args()
    {"clips": cmd_clips, "final": cmd_final, "sheet": cmd_sheet}[a.cmd](a)


if __name__ == "__main__":
    main()
