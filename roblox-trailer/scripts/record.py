#!/usr/bin/env python3
"""Record trailer shots from Roblox Studio with macOS `screencapture` (records the REAL screen).

Before any recording: tell the user to keep the Studio window visible and uncovered, park the mouse
outside it, and not use the computer until the shot finishes. Recordings never include the cursor
(no -C flag) and never audio.

  record.py windows                         list Studio windows + bounds (points)
  record.py calibrate --out DIR [--window S] [--rgb 0,255,255]
        while TrailerDriver.calibrate() shows its flat colour, grab one still and find the viewport
        rectangle -> DIR/region.json (points). Every later shot crops to exactly that.
  record.py shot ID --out DIR --start-ms MS --dur SECS [--preroll 1] [--tail 0.6] [--region x,y,w,h]
                    [--full-crop] [--display N] [--force]
        Waits until MS - preroll (MS = startsAtMs returned by TrailerDriver.run), records
        preroll+dur+tail to DIR/clips/ID.mov and writes DIR/clips/ID.json with the measured start time
        and the trim point (`shot_in`) where the shot really begins in the file.
  record.py stitch ID --out DIR --frames FRAMEDIR [--fps 10] [--interp]
        Fallback without screen recording: numbered PNG/JPEGs (e.g. saved robloxstudio
        capture_screenshot frames) -> DIR/clips/ID.mov at 60 fps.
  record.py clean --out DIR --shots shots.json [--dry-run]
        Delete stray/test recordings: anything in DIR/clips that isn't a current shot id, *_full.mov
        intermediates, test_* files.
"""
import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

JXA_WINDOWS = r'''
ObjC.import("CoreGraphics"); ObjC.import("AppKit");
var all = ObjC.deepUnwrap(ObjC.castRefToObject($.CGWindowListCopyWindowInfo(0, 0)));
var on = ObjC.deepUnwrap(ObjC.castRefToObject($.CGWindowListCopyWindowInfo(
  $.kCGWindowListOptionOnScreenOnly | $.kCGWindowListExcludeDesktopElements, 0)));
var onIds = {}; on.forEach(function (w, i) { onIds[w.kCGWindowNumber] = i; });
var scr = $.NSScreen.mainScreen;
JSON.stringify({
  screen: [scr.frame.size.width, scr.frame.size.height], scale: scr.backingScaleFactor,
  windows: all.map(function (w) { return {
    id: w.kCGWindowNumber, owner: w.kCGWindowOwnerName || "", name: w.kCGWindowName || "",
    layer: w.kCGWindowLayer, bounds: w.kCGWindowBounds, onscreen: (w.kCGWindowNumber in onIds),
    z: (w.kCGWindowNumber in onIds) ? onIds[w.kCGWindowNumber] : -1 }; })
});
'''


def run(cmd, **kw):
    return subprocess.run(cmd, capture_output=True, text=True, **kw)


def window_info():
    r = run(["osascript", "-l", "JavaScript", "-e", JXA_WINDOWS])
    if r.returncode != 0:
        sys.exit(f"window lookup failed: {r.stderr.strip()}")
    return json.loads(r.stdout)


def studio_windows(info, title=None):
    out = []
    for w in info["windows"]:
        if w["owner"] not in ("Roblox Studio", "RobloxStudio") or w["layer"] != 0:
            continue
        b = w["bounds"]
        if b["Width"] < 300 or b["Height"] < 200:
            continue
        if title and title.lower() not in (w["name"] or "").lower():
            continue
        out.append(w)
    return out


def pick_studio(info, title=None):
    ws = [w for w in studio_windows(info, title) if w["onscreen"]]
    if not ws:
        hidden = studio_windows(info, title)
        msg = "Roblox Studio has no visible window"
        if hidden:
            msg += " (it is minimised, hidden or on another Space)"
        sys.exit(msg + ". Ask the user to bring Studio to the front on this display, then retry.")
    # frontmost first; the main window (titled "... - Roblox Studio") beats nameless panels/popups
    ws.sort(key=lambda w: (0 if "roblox studio" in (w["name"] or "").lower() or title else 1, w["z"]))
    return ws[0]


def rect(b):
    return (b["X"], b["Y"], b["Width"], b["Height"])


def overlap(a, b):
    ax, ay, aw, ah = a
    bx, by, bw, bh = b
    return not (ax + aw <= bx or bx + bw <= ax or ay + ah <= by or by + bh <= ay)


def covering_windows(info, region, studio_id):
    """Normal app windows stacked ABOVE Studio that overlap the region (they would end up in the video)."""
    studio_z = next((w["z"] for w in info["windows"] if w["id"] == studio_id), 10 ** 6)
    bad = []
    for w in info["windows"]:
        if not w["onscreen"] or w["z"] < 0 or w["z"] >= studio_z or w["id"] == studio_id:
            continue
        if w["layer"] != 0 or w["owner"] in ("Window Server", "Dock"):
            continue
        if overlap(rect(w["bounds"]), region):
            bad.append(f'{w["owner"]} "{w["name"]}"')
    return bad


def ffprobe_duration(path):
    r = run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "default=nw=1:nk=1", str(path)])
    try:
        return float(r.stdout.strip())
    except ValueError:
        return None


# ---------------------------------------------------------------- windows

def cmd_windows(a):
    info = window_info()
    print(f"main screen {info['screen'][0]}x{info['screen'][1]} pt, scale {info['scale']}")
    ws = studio_windows(info)
    if not ws:
        print("no Roblox Studio windows found")
    for w in ws:
        b = w["bounds"]
        print(f"[{'front' if w['z'] == 0 else ('visible' if w['onscreen'] else 'hidden')}] "
              f"{w['name']!r} x={b['X']} y={b['Y']} w={b['Width']} h={b['Height']} (z={w['z']})")


# ---------------------------------------------------------------- calibrate

def find_colour_box(png, rgb, tol=40):
    """Bounding box (pixels) of the calibration colour, by scanning a raw RGB dump from ffmpeg."""
    r = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries", "stream=width,height",
                        "-of", "csv=p=0", str(png)], capture_output=True, text=True)
    W, H = [int(x) for x in r.stdout.strip().split(",")[:2]]
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", str(png), "-f", "rawvideo", "-pix_fmt", "rgb24", "-"],
                         capture_output=True).stdout
    tr, tg, tb = rgb
    step = 2
    minx, miny, maxx, maxy, hits = W, H, -1, -1, 0
    for y in range(0, H, step):
        row = raw[y * W * 3:(y + 1) * W * 3]
        for x in range(0, W, step):
            i = x * 3
            if abs(row[i] - tr) < tol and abs(row[i + 1] - tg) < tol and abs(row[i + 2] - tb) < tol:
                hits += 1
                if x < minx: minx = x
                if x > maxx: maxx = x
                if y < miny: miny = y
                if y > maxy: maxy = y
    if hits < 500:
        return None, (W, H)
    return (minx, miny, maxx + step, maxy + step), (W, H)


def cmd_calibrate(a):
    out = Path(a.out); out.mkdir(parents=True, exist_ok=True)
    info = window_info()
    w = pick_studio(info, a.window)
    scale = info["scale"]
    x, y, ww, hh = rect(w["bounds"])
    png = out / "calibrate.png"
    r = run(["screencapture", "-x", "-R", f"{x},{y},{ww},{hh}", str(png)])
    if r.returncode != 0 or not png.exists():
        sys.exit(f"screencapture failed: {r.stderr.strip()} (Screen Recording permission?)")
    rgb = tuple(int(v) for v in a.rgb.split(","))
    box, (W, H) = find_colour_box(png, rgb)
    if not box:
        sys.exit(f"calibration colour {rgb} not found in {png}. Run TrailerDriver.calibrate(10) in the client "
                 "first (build_kit.py call --calibrate 10), keep the playtest viewport visible, then retry.")
    px = W / ww  # pixels per point in this still (2 on Retina)
    x0, y0, x1, y1 = box
    # inset 1 pt so no anti-aliased Studio border survives, and keep even pixel sizes for H.264
    region = [x + x0 / px + 1, y + y0 / px + 1, (x1 - x0) / px - 2, (y1 - y0) / px - 2]
    region = [round(v) for v in region]
    region[2] -= region[2] % 2
    region[3] -= region[3] % 2
    meta = {"region": region, "scale": scale, "window": w["name"], "window_bounds": [x, y, ww, hh],
            "calibrated_at": time.strftime("%Y-%m-%d %H:%M:%S")}
    (out / "region.json").write_text(json.dumps(meta, indent=2))
    png.unlink(missing_ok=True)
    print(json.dumps(meta))
    if region[2] / max(region[3], 1) < 1.70 or region[2] / max(region[3], 1) > 1.85:
        print(f"note: viewport aspect {region[2] / region[3]:.3f} is not 16:9; edit.py will crop to 16:9. "
              "Resize the Studio window/panels for a closer fit.")


# ---------------------------------------------------------------- shot

def load_region(out, arg):
    if arg:
        return [float(v) for v in arg.split(",")]
    f = Path(out) / "region.json"
    if f.exists():
        return json.loads(f.read_text())["region"]
    return None


def cmd_shot(a):
    if not re.fullmatch(r"[A-Za-z0-9_\-]+", a.id):
        sys.exit("shot id must be [A-Za-z0-9_-]")
    out = Path(a.out)
    clips = out / "clips"
    clips.mkdir(parents=True, exist_ok=True)
    info = window_info()
    studio = pick_studio(info, a.window)
    region = load_region(out, a.region) or list(rect(studio["bounds"]))
    covers = covering_windows(info, region, studio["id"])
    if covers and not a.force:
        sys.exit("windows are covering the recording area: " + "; ".join(covers)
                 + ". Ask the user to move them (or pass --force).")
    secs = a.preroll + a.dur + a.tail
    target = a.start_ms / 1000.0 - a.preroll if a.start_ms else time.time()
    wait = target - time.time()
    if wait < -0.25 and a.start_ms:
        sys.exit(f"too late by {-wait:.2f}s: the shot already started. Re-run TrailerDriver with a bigger delay.")
    if wait > 120:
        sys.exit("start time is more than 2 minutes away; check --start-ms")
    if wait > 0:
        time.sleep(wait)
    mov = clips / f"{a.id}.mov"
    full = clips / f"{a.id}_full.mov"
    for f in (mov, full):
        f.unlink(missing_ok=True)
    cmd = ["screencapture", "-v", "-x", "-V", f"{secs:.2f}"]
    if a.display:
        cmd += ["-D", str(a.display)]
    if not a.full_crop:
        cmd += ["-R", ",".join(str(round(v)) for v in region)]
    cmd.append(str(full if a.full_crop else mov))
    print(f"REC {a.id}: {secs:.1f}s of the real screen. Hands off the computer.", flush=True)
    t_launch = time.time()
    r = subprocess.run(cmd, capture_output=True, text=True)
    t_end = time.time()
    src = full if a.full_crop else mov
    if r.returncode != 0 or not src.exists():
        sys.exit(f"screencapture failed ({r.returncode}): {r.stderr.strip()}")
    if a.full_crop:
        scale = info["scale"]
        x, y, w, h = [round(v * scale) for v in region]
        w -= w % 2; h -= h % 2
        c = run(["ffmpeg", "-v", "error", "-y", "-i", str(full), "-vf", f"crop={w}:{h}:{x}:{y}",
                 "-c:v", "libx264", "-crf", "12", "-preset", "veryfast", "-pix_fmt", "yuv420p", str(mov)])
        if c.returncode != 0:
            sys.exit("crop failed: " + c.stderr)
        full.unlink(missing_ok=True)
    dur = ffprobe_duration(mov) or secs
    # screencapture spends a moment starting up; the file ends when the process exits, so the true
    # first frame is (end - file duration). That's what makes trimming land on the shot's t=0.
    video_start = t_end - dur
    shot_in = (a.start_ms / 1000.0 - video_start) if a.start_ms else a.preroll
    meta = {
        "id": a.id, "file": mov.name, "region_pt": region, "cursor": False, "audio": False,
        "requested_secs": secs, "file_secs": round(dur, 3), "launch_ms": int(t_launch * 1000),
        "video_start_ms": int(video_start * 1000), "shot_start_ms": a.start_ms, "shot_dur": a.dur,
        "shot_in": round(max(0.0, shot_in), 3), "startup_lag": round(video_start - t_launch, 3),
    }
    (clips / f"{a.id}.json").write_text(json.dumps(meta, indent=2))
    print(json.dumps(meta))
    if shot_in < 0:
        print("warning: recording started after the shot began; raise --preroll or the driver delay")


# ---------------------------------------------------------------- stitch fallback

def cmd_stitch(a):
    frames = sorted(p for p in Path(a.frames).iterdir() if p.suffix.lower() in (".png", ".jpg", ".jpeg"))
    if len(frames) < 2:
        sys.exit("need at least 2 frames")
    clips = Path(a.out) / "clips"; clips.mkdir(parents=True, exist_ok=True)
    tmp = Path(tempfile.mkdtemp(prefix="stitch_"))
    try:
        for i, f in enumerate(frames):
            os.symlink(f.resolve(), tmp / f"f{i:05d}{f.suffix.lower()}")
        ext = frames[0].suffix.lower()
        vf = "scale=trunc(iw/2)*2:trunc(ih/2)*2"
        vf += ",minterpolate=fps=60:mi_mode=mci" if a.interp else ",fps=60"
        mov = clips / f"{a.id}.mov"
        r = run(["ffmpeg", "-v", "error", "-y", "-framerate", str(a.fps), "-i", str(tmp / f"f%05d{ext}"),
                 "-vf", vf, "-c:v", "libx264", "-crf", "14", "-pix_fmt", "yuv420p", str(mov)])
        if r.returncode != 0:
            sys.exit(r.stderr)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    meta = {"id": a.id, "file": mov.name, "stitched": True, "frames": len(frames), "src_fps": a.fps,
            "shot_in": 0.0, "shot_dur": len(frames) / a.fps, "cursor": False, "audio": False}
    (clips / f"{a.id}.json").write_text(json.dumps(meta, indent=2))
    print(json.dumps(meta))


# ---------------------------------------------------------------- clean

def cmd_clean(a):
    clips = Path(a.out) / "clips"
    if not clips.exists():
        print("nothing to clean"); return
    ids = {s["id"] for s in json.loads(Path(a.shots).read_text()).get("shots", [])}
    removed = []
    for f in clips.iterdir():
        stem = f.stem
        stray = (stem not in ids) or stem.endswith("_full") or stem.lower().startswith("test")
        if stray and f.suffix.lower() in (".mov", ".mp4", ".json", ".png"):
            removed.append(f.name)
            if not a.dry_run:
                f.unlink()
    for f in Path(a.out).glob("calibrate*.png"):
        removed.append(f.name)
        if not a.dry_run:
            f.unlink()
    print(("would delete: " if a.dry_run else "deleted: ") + (", ".join(removed) or "nothing"))


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)
    sub.add_parser("windows")
    c = sub.add_parser("calibrate"); c.add_argument("--out", required=True); c.add_argument("--window")
    c.add_argument("--rgb", default="0,255,255")
    s = sub.add_parser("shot"); s.add_argument("id"); s.add_argument("--out", required=True)
    s.add_argument("--start-ms", type=int, help="startsAtMs from TrailerDriver.run (unix ms)")
    s.add_argument("--dur", type=float, required=True); s.add_argument("--preroll", type=float, default=1.0)
    s.add_argument("--tail", type=float, default=0.6); s.add_argument("--region")
    s.add_argument("--window"); s.add_argument("--display", type=int)
    s.add_argument("--full-crop", action="store_true", help="record full screen, then ffmpeg-crop the region")
    s.add_argument("--force", action="store_true")
    st = sub.add_parser("stitch"); st.add_argument("id"); st.add_argument("--out", required=True)
    st.add_argument("--frames", required=True); st.add_argument("--fps", type=float, default=10)
    st.add_argument("--interp", action="store_true", help="motion-interpolate to 60 fps (smoother, slower)")
    cl = sub.add_parser("clean"); cl.add_argument("--out", required=True); cl.add_argument("--shots", required=True)
    cl.add_argument("--dry-run", action="store_true")
    a = p.parse_args()
    {"windows": cmd_windows, "calibrate": cmd_calibrate, "shot": cmd_shot, "stitch": cmd_stitch,
     "clean": cmd_clean}[a.cmd](a)


if __name__ == "__main__":
    main()
