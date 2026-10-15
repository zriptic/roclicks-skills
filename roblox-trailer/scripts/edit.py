#!/usr/bin/env python3
"""Cut the recorded shots into a trailer with ffmpeg (+ Pillow for text, since this ffmpeg has no drawtext).

  edit.py build --shots shots.json [--cut roblox|social] [--format landscape|vertical|both] [--out DIR]
  edit.py fonts                      which font each name resolves to
  edit.py card --shots shots.json --index N     render one card/text PNG to preview it

Reads the "edit" block of shots.json (schema: references/editing.md). Per item:
  shot items  {"shot": id, "in": s, "out": s, "speed": 1 | "ramp": [[src_t, speed], ...], "interp": bool,
               "transition": {"type": "cut|fade|whip|whipblur|dip|flash|<any xfade name>", "dur": 0.2},
               "text": {"text", "pos": "bottom|top|center|lower", "size", "from", "to", "color", "stroke"},
               "focus_x": 0..1 (vertical crop centre), "social_only": bool}
  card items  {"card": "title|text", "text", "sub", "dur", "bg": "#hex", "bg2": "#hex", "bg_shot": id,
               "transition": {...}, "social_only": bool}
  globals     size, fps, font, music {file, start, gain_db, fade_out}, sfx [{file, at, gain_db}],
              duck [[a, b], ...] (explicit music dips, seconds of the final cut), duck_db, loudness (LUFS)

Clip times are relative to the shot's own t=0 (record.py stores `shot_in`, the offset into the file).
Output: DIR/<game>_<cut>_<WxH>.mp4 (H.264 high, yuv420p, 60 fps, AAC 48 kHz, +faststart).
"""
import argparse
import json
import math
import re
import shutil
import subprocess
import sys
from pathlib import Path

try:
    from PIL import Image, ImageDraw, ImageFilter, ImageFont
except ImportError:  # pragma: no cover
    sys.exit("Pillow is required (python3 -m pip install pillow)")

SKILL = Path(__file__).resolve().parent.parent
EMOJI_FONT = "/System/Library/Fonts/Apple Color Emoji.ttc"
FONT_DIRS = [SKILL / "assets" / "fonts", Path.home() / "Library/Fonts", Path("/Library/Fonts"),
             Path("/System/Library/Fonts/Supplemental"), Path("/System/Library/Fonts")]
FALLBACK_FONTS = ["FredokaOne-Regular.ttf", "Fredoka", "LuckiestGuy-Regular.ttf", "Arial Rounded Bold.ttf",
                  "SFNSRounded.ttf", "Helvetica.ttc"]
XFADE = {"cut": "fade", "fade": "fade", "whip": "slideleft", "whipright": "slideright", "whipblur": "hblur",
         "dip": "fadeblack", "flash": "fadewhite", "zoom": "zoomin"}
ROBLOX_MAX_SECS = 30.0
ROBLOX_MAX_BYTES = 375 * 1024 * 1024


def sh(cmd, quiet=True):
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        sys.exit("ffmpeg failed:\n" + " ".join(map(str, cmd))[:2000] + "\n" + r.stderr[-3000:])
    return r


def probe_dur(path):
    r = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of",
                        "default=nw=1:nk=1", str(path)], capture_output=True, text=True)
    return float(r.stdout.strip())


# ---------------------------------------------------------------- fonts + text rendering

def find_font(name):
    if name and Path(name).expanduser().exists():
        return str(Path(name).expanduser())
    wanted = [name] if name else []
    for cand in wanted + FALLBACK_FONTS:
        key = re.sub(r"[\s_-]", "", str(cand)).lower().replace(".ttf", "").replace(".otf", "").replace(".ttc", "")
        for d in FONT_DIRS:
            if not d.exists():
                continue
            for f in sorted(d.iterdir()):
                if f.suffix.lower() not in (".ttf", ".otf", ".ttc"):
                    continue
                stem = re.sub(r"[\s_-]", "", f.stem).lower()
                if stem == key or stem.startswith(key):
                    if name and cand != name:
                        print(f"font '{name}' not installed; using {f.name}. For Fredoka One, download "
                              f"FredokaOne-Regular.ttf (Google Fonts, OFL) into {SKILL / 'assets/fonts'}")
                    return str(f)
    return None


def is_emoji(ch):
    o = ord(ch)
    return (0x1F000 <= o <= 0x1FAFF) or (0x2600 <= o <= 0x27BF) or (0x2B00 <= o <= 0x2BFF) or o in (0xFE0F, 0x200D)


def runs(text):
    out, cur, cur_e = [], "", None
    for ch in text:
        e = is_emoji(ch)
        if cur and e != cur_e:
            out.append((cur, cur_e)); cur = ""
        cur += ch; cur_e = e
    if cur:
        out.append((cur, cur_e))
    return out


def render_line(text, font_path, size, color="#ffffff", stroke=None, stroke_w=None):
    """RGBA image of one line; emoji come from Apple Color Emoji (rendered at 160 px, then scaled)."""
    font = ImageFont.truetype(font_path, size)
    sw = stroke_w if stroke_w is not None else max(2, size // 12)
    pieces = []
    for chunk, emoji in runs(text):
        if emoji:
            chunk = chunk.replace("️", "").replace("‍", "")
            if not chunk:
                continue
            try:
                ef = ImageFont.truetype(EMOJI_FONT, 160)
                im = Image.new("RGBA", (200 * len(chunk), 200), (0, 0, 0, 0))
                ImageDraw.Draw(im).text((0, 0), chunk, font=ef, embedded_color=True)
                im = im.crop(im.getbbox() or (0, 0, 1, 1))
                h = int(size * 1.05)
                im = im.resize((max(1, int(im.width * h / im.height)), h), Image.LANCZOS)
                pieces.append(im)
            except OSError:
                print("emoji font unavailable; dropping", chunk)
        else:
            l, t, r, b = font.getbbox(chunk, stroke_width=sw)
            im = Image.new("RGBA", (r - l + 4, int(size * 1.35) + 2 * sw), (0, 0, 0, 0))
            ImageDraw.Draw(im).text((-l + 2, sw), chunk, font=font, fill=color,
                                    stroke_width=sw if stroke else 0, stroke_fill=stroke)
            im = im.crop(im.getbbox() or (0, 0, 1, 1))
            pieces.append(im)
    if not pieces:
        return Image.new("RGBA", (1, 1))
    gap = size // 4
    W = sum(p.width for p in pieces) + gap * (len(pieces) - 1)
    H = max(p.height for p in pieces)
    line = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    x = 0
    for p in pieces:
        line.alpha_composite(p, (x, (H - p.height) // 2))
        x += p.width + gap
    return line


def shadowed(im, radius=10, alpha=150):
    pad = radius * 3
    out = Image.new("RGBA", (im.width + 2 * pad, im.height + 2 * pad), (0, 0, 0, 0))
    sh_ = Image.new("RGBA", out.size, (0, 0, 0, 0))
    mask = im.split()[3].point(lambda v: v * alpha // 255)
    sh_.paste((0, 0, 0, 255), (pad, pad + radius // 2), mask)
    sh_ = sh_.filter(ImageFilter.GaussianBlur(radius))
    out.alpha_composite(sh_)
    out.alpha_composite(im, (pad, pad))
    return out


def hex_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def text_overlay_png(spec, W, H, font_path, path):
    size = int(spec.get("size", 72) * W / 1920) if W >= H else int(spec.get("size", 72) * W / 1080 * 0.9)
    line = shadowed(render_line(spec["text"], font_path, size, spec.get("color", "#ffffff"),
                                spec.get("stroke", "#1a1a1a")))
    if line.width > W * 0.92:
        line = line.resize((int(W * 0.92), int(line.height * W * 0.92 / line.width)), Image.LANCZOS)
    canvas = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    pos = spec.get("pos", "bottom")
    y = {"top": int(H * 0.08), "center": (H - line.height) // 2, "lower": int(H * 0.68)}.get(pos, int(H * 0.80))
    canvas.alpha_composite(line, ((W - line.width) // 2, min(y, H - line.height)))
    canvas.save(path)


def card_pngs(item, W, H, font_path, work, frame_path=None):
    """Background PNG (W*1.06 for a slow drift) + title PNG (centred, animated in ffmpeg)."""
    BW, BH = int(W * 1.06) // 2 * 2, int(H * 1.06) // 2 * 2
    if frame_path and Path(frame_path).exists():
        bg = Image.open(frame_path).convert("RGB")
        scale = max(BW / bg.width, BH / bg.height)
        bg = bg.resize((math.ceil(bg.width * scale), math.ceil(bg.height * scale)), Image.LANCZOS)
        bg = bg.crop(((bg.width - BW) // 2, (bg.height - BH) // 2, (bg.width - BW) // 2 + BW,
                      (bg.height - BH) // 2 + BH))
        bg = bg.filter(ImageFilter.GaussianBlur(28))
        bg = Image.blend(bg, Image.new("RGB", bg.size, (0, 0, 0)), 0.35)
    else:
        c1, c2 = hex_rgb(item.get("bg", "#2a1d5c")), hex_rgb(item.get("bg2", "#0f5fa8"))
        grad = Image.linear_gradient("L").resize((BW, BH))
        bg = Image.composite(Image.new("RGB", (BW, BH), c2), Image.new("RGB", (BW, BH), c1), grad)
    bg_path = work / f"card_{id(item)}_bg.png"
    bg.save(bg_path)
    unit = W / 1920 if W >= H else W / 1080 * 0.85
    title = shadowed(render_line(item.get("text", ""), font_path, int(item.get("size", 170) * unit),
                                 item.get("color", "#ffffff"), item.get("stroke", "#20123a")), radius=16)
    layers = [title]
    if item.get("sub"):
        layers.append(shadowed(render_line(item["sub"], font_path, int(item.get("sub_size", 64) * unit),
                                           item.get("sub_color", "#ffe066"), item.get("stroke", "#20123a"))))
    TW = max(l.width for l in layers)
    TH = sum(l.height for l in layers)
    if TW > W * 0.94:
        f = W * 0.94 / TW
        layers = [l.resize((int(l.width * f), int(l.height * f)), Image.LANCZOS) for l in layers]
        TW, TH = max(l.width for l in layers), sum(l.height for l in layers)
    block = Image.new("RGBA", (TW // 2 * 2 + 2, TH // 2 * 2 + 2), (0, 0, 0, 0))
    y = 0
    for l in layers:
        block.alpha_composite(l, ((block.width - l.width) // 2, y))
        y += l.height
    title_path = work / f"card_{id(item)}_title.png"
    block.save(title_path)
    return bg_path, title_path


# ---------------------------------------------------------------- per-item render

def frame_filter(W, H, fmt, focus_x=0.5, focus_y=0.5, vertical_mode="crop"):
    norm = "setsar=1,fps=60,format=yuv420p"
    if fmt == "vertical" and vertical_mode == "blurpad":
        return (f"split[a][b];[a]scale={W}:{H}:force_original_aspect_ratio=increase,crop={W}:{H},"
                f"gblur=sigma=40,eq=brightness=-0.08[bg];[b]scale={W}:-2[fg];"
                f"[bg][fg]overlay=(W-w)/2:(H-h)/2,{norm}")
    return (f"scale={W}:{H}:force_original_aspect_ratio=increase,"
            f"crop={W}:{H}:(iw-{W})*{focus_x}:(ih-{H})*{focus_y},{norm}")


def speed_chunks(src_len, item):
    """[(start, end, speed)] in source seconds. ramp keys are [src_t, speed], linearly interpolated."""
    ramp = item.get("ramp")
    if not ramp:
        return [(0.0, src_len, float(item.get("speed", 1.0)))]
    keys = sorted((float(t), float(s)) for t, s in ramp)

    def speed_at(t):
        if t <= keys[0][0]:
            return keys[0][1]
        for (t0, s0), (t1, s1) in zip(keys, keys[1:]):
            if t0 <= t <= t1:
                return s0 + (s1 - s0) * (t - t0) / max(t1 - t0, 1e-6)
        return keys[-1][1]

    step = 1 / 15
    out, t = [], 0.0
    while t < src_len - 1e-6:
        e = min(src_len, t + step)
        out.append((t, e, max(0.05, speed_at((t + e) / 2))))
        t = e
    return out


def render_shot(item, clipdir, W, H, fmt, font_path, work, idx, vmode):
    sid = item["shot"]
    meta_p = clipdir / f"{sid}.json"
    mov = clipdir / f"{sid}.mov"
    if not mov.exists():
        sys.exit(f"missing clip {mov} (record it first)")
    base = json.loads(meta_p.read_text()).get("shot_in", 0.0) if meta_p.exists() else 0.0
    a = base + float(item.get("in", 0.0))
    b = base + float(item.get("out", item.get("in", 0.0) + 3.0))
    chunks = speed_chunks(b - a, item)
    parts = []
    fc = f"[0:v]split={len(chunks)}" + "".join(f"[s{i}]" for i in range(len(chunks))) + ";"
    for i, (c0, c1, sp) in enumerate(chunks):
        fc += f"[s{i}]trim=start={a + c0:.4f}:end={a + c1:.4f},setpts=(PTS-STARTPTS)/{sp:.4f}[p{i}];"
        parts.append(f"[p{i}]")
    fc += "".join(parts) + f"concat=n={len(parts)}:v=1:a=0[cat];"
    slow = any(sp < 0.95 for _, _, sp in chunks)
    interp = ",minterpolate=fps=60:mi_mode=mci:mc_mode=aobmc" if (slow and item.get("interp")) else ""
    fc += f"[cat]fps=60{interp},{frame_filter(W, H, fmt, item.get('focus_x', 0.5), item.get('focus_y', 0.5), vmode)}[v0]"
    inputs = ["-i", str(mov)]
    last = "[v0]"
    if item.get("text"):
        t = item["text"]
        png = work / f"text_{idx}_{fmt}.png"
        text_overlay_png(t, W, H, font_path, png)
        t0, t1 = float(t.get("from", 0.15)), float(t.get("to", 99))
        inputs += ["-loop", "1", "-framerate", "60", "-i", str(png)]
        fc += (f";[1:v]format=rgba,fade=t=in:st={t0}:d=0.2:alpha=1,fade=t=out:st={max(t0, t1 - 0.2)}:d=0.2:alpha=1[tx];"
               f"{last}[tx]overlay=0:0:shortest=1:format=auto,format=yuv420p[v1]")
        last = "[v1]"
    out = work / f"seg_{idx:02d}_{fmt}.mp4"
    sh(["ffmpeg", "-v", "error", "-y", *inputs, "-filter_complex", fc, "-map", last, "-an",
        "-c:v", "libx264", "-preset", "veryfast", "-crf", "14", "-pix_fmt", "yuv420p", "-r", "60", str(out)])
    return out


def render_card(item, clipdir, W, H, fmt, font_path, work, idx):
    dur = float(item.get("dur", 2.5))
    frame = None
    if item.get("bg_shot"):
        mov = clipdir / f"{item['bg_shot']}.mov"
        meta_p = clipdir / f"{item['bg_shot']}.json"
        if mov.exists():
            base = json.loads(meta_p.read_text()).get("shot_in", 0.0) if meta_p.exists() else 0.0
            frame = work / f"cardframe_{idx}.png"
            sh(["ffmpeg", "-v", "error", "-y", "-ss", f"{base + float(item.get('bg_t', 1.0)):.3f}", "-i", str(mov),
                "-frames:v", "1", str(frame)])
    bg, title = card_pngs(item, W, H, font_path, work, frame)
    pop = 0.45
    # background drifts slowly; the title pops in (ease-out with a small overshoot) then breathes
    fc = (f"[0:v]crop={W}:{H}:x='(iw-{W})*t/{dur}':y='(ih-{H})/2',setsar=1,fps=60[bg];"
          f"[1:v]format=rgba,scale=w='iw*if(lt(t,{pop}),0.55+0.45*(1-pow(1-t/{pop},3))+0.08*sin(PI*t/{pop}),1+0.015*sin(2*PI*(t-{pop})/2.5))'"
          f":h=-1:eval=frame,fade=t=in:st=0:d=0.18:alpha=1[ti];"
          f"[bg][ti]overlay=x='(W-w)/2':y='(H-h)/2-{int(H * 0.02)}':shortest=1,format=yuv420p[v]")
    out = work / f"seg_{idx:02d}_{fmt}.mp4"
    sh(["ffmpeg", "-v", "error", "-y", "-loop", "1", "-framerate", "60", "-t", f"{dur}", "-i", str(bg),
        "-loop", "1", "-framerate", "60", "-t", f"{dur}", "-i", str(title), "-filter_complex", fc, "-map", "[v]",
        "-an", "-c:v", "libx264", "-preset", "veryfast", "-crf", "14", "-pix_fmt", "yuv420p", "-r", "60",
        "-t", f"{dur}", str(out)])
    return out


# ---------------------------------------------------------------- assemble

def assemble(segs, items, edit, W, H, out_path, total_hint=None):
    durs = [probe_dur(s) for s in segs]
    inputs = []
    for s in segs:
        inputs += ["-i", str(s)]
    fc = ""
    for i in range(len(segs)):
        fc += f"[{i}:v]settb=AVTB,fps=60,format=yuv420p[n{i}];"
    cur, cur_len = "[n0]", durs[0]
    for i in range(1, len(segs)):
        tr = items[i].get("transition") or {"type": "cut"}
        ttype = tr.get("type", "cut")
        d = 1 / 60 if ttype == "cut" else float(tr.get("dur", 0.25 if ttype.startswith("whip") else 0.4))
        d = min(d, durs[i] * 0.45, cur_len * 0.45)
        name = XFADE.get(ttype, ttype)
        off = cur_len - d
        fc += f"{cur}[n{i}]xfade=transition={name}:duration={d:.4f}:offset={off:.4f}[x{i}];"
        cur = f"[x{i}]"
        cur_len = off + durs[i]
    total = cur_len
    fc += f"{cur}null[vout]"

    # audio: music bed (+ optional SFX with sidechain ducking, + explicit duck windows), then loudnorm
    music = edit.get("music") or {}
    sfx = [s for s in (edit.get("sfx") or []) if Path(s["file"]).expanduser().exists()]
    amap = []
    n = len(segs)
    if music.get("file") and Path(music["file"]).expanduser().exists():
        inputs += ["-i", str(Path(music["file"]).expanduser())]
        mi = n; n += 1
        fo = float(music.get("fade_out", 1.5))
        duck_db = float(edit.get("duck_db", -9))
        wins = edit.get("duck") or []
        vol = "1"
        if wins:
            g = 10 ** (duck_db / 20)
            cond = "+".join(f"between(t,{a},{b})" for a, b in wins)
            vol = f"if(gt({cond},0),{g:.3f},1)"
        fc += (f";[{mi}:a]atrim=start={float(music.get('start', 0))}:duration={total:.3f},asetpts=PTS-STARTPTS,"
               f"aresample=48000,volume={float(music.get('gain_db', -2))}dB,volume='{vol}':eval=frame,"
               f"afade=t=in:d=0.25,afade=t=out:st={max(0, total - fo):.3f}:d={fo}[mus]")
        bus = "[mus]"
        if sfx:
            labels = []
            for j, s in enumerate(sfx):
                inputs += ["-i", str(Path(s["file"]).expanduser())]
                ms = int(float(s["at"]) * 1000)
                fc += (f";[{n}:a]aresample=48000,volume={float(s.get('gain_db', 0))}dB,"
                       f"adelay={ms}|{ms}[fx{j}]")
                labels.append(f"[fx{j}]")
                n += 1
            fc += f";{''.join(labels)}amix=inputs={len(labels)}:normalize=0,apad=whole_dur={total:.3f},asplit[sfxa][sfxsc]"
            fc += ";[mus][sfxsc]sidechaincompress=threshold=0.03:ratio=6:attack=15:release=350[musd]"
            fc += ";[musd][sfxa]amix=inputs=2:normalize=0:duration=first[mix]"
            bus = "[mix]"
        lufs = float(edit.get("loudness", -14))
        fc += f";{bus}loudnorm=I={lufs}:TP=-1.0:LRA=11,aresample=48000,atrim=duration={total:.3f}[aout]"
        amap = ["-map", "[aout]", "-c:a", "aac", "-b:a", "192k", "-ar", "48000"]
    elif music.get("file"):
        print(f"music file not found: {music['file']} (cut will be silent)")
    sh(["ffmpeg", "-v", "error", "-y", *inputs, "-filter_complex", fc, "-map", "[vout]", *amap,
        "-c:v", "libx264", "-preset", "slow", "-crf", "18", "-profile:v", "high", "-pix_fmt", "yuv420p",
        "-r", "60", "-movflags", "+faststart", "-t", f"{total:.3f}", str(out_path)])
    return total


def build(a):
    shots_path = Path(a.shots)
    data = json.loads(shots_path.read_text())
    edit = data.get("edit") or sys.exit("shots.json has no 'edit' block")
    root = shots_path.parent
    clipdir = root / "clips"
    out_dir = Path(a.out) if a.out else root / "out"
    out_dir.mkdir(parents=True, exist_ok=True)
    work = root / "build"
    if work.exists():
        shutil.rmtree(work)
    work.mkdir(parents=True)
    font_path = find_font(edit.get("font"))
    if not font_path:
        sys.exit("no usable font found")
    print("font:", font_path)
    items = [it for it in edit["sequence"] if not (a.cut == "roblox" and it.get("social_only"))]
    fmts = ["landscape", "vertical"] if a.format == "both" else [a.format]
    game = re.sub(r"[^A-Za-z0-9]+", "_", data.get("game", "trailer")).strip("_").lower()
    results = []
    for fmt in fmts:
        W, H = (edit.get("size") or [1920, 1080]) if fmt == "landscape" else (1080, 1920)
        vmode = (edit.get("vertical") or {}).get("mode", "crop")
        segs = []
        for i, it in enumerate(items):
            if "card" in it:
                segs.append(render_card(it, clipdir, W, H, fmt, font_path, work, i))
            else:
                segs.append(render_shot(it, clipdir, W, H, fmt, font_path, work, i, vmode))
            print(f"  [{fmt}] {i + 1}/{len(items)} {it.get('shot') or it.get('card')}")
        out = out_dir / f"{game}_{a.cut}_{W}x{H}.mp4"
        total = assemble(segs, items, edit, W, H, out)
        size = out.stat().st_size
        print(f"wrote {out}  {total:.2f}s  {size / 1e6:.1f} MB")
        if a.cut == "roblox":
            if total > ROBLOX_MAX_SECS:
                print(f"WARNING: {total:.1f}s is over the 30 s Roblox video limit (references/roblox-video-specs.md)")
            if size > ROBLOX_MAX_BYTES:
                print("WARNING: over 375 MB")
        results.append(str(out))
    if not a.keep_work:
        shutil.rmtree(work, ignore_errors=True)
    print(json.dumps({"outputs": results}))


def cmd_fonts(a):
    for n in ["Fredoka One"] + FALLBACK_FONTS:
        print(f"{n:<28} -> {find_font(n)}")


def cmd_card(a):
    data = json.loads(Path(a.shots).read_text())
    it = data["edit"]["sequence"][a.index]
    work = Path(a.shots).parent / "build"; work.mkdir(exist_ok=True)
    font = find_font(data["edit"].get("font"))
    W, H = 1920, 1080
    if "card" in it:
        bg, title = card_pngs(it, W, H, font, work)
        im = Image.open(bg).convert("RGBA").crop((0, 0, W, H))
        t = Image.open(title)
        im.alpha_composite(t, ((W - t.width) // 2, (H - t.height) // 2))
    else:
        p = work / "preview_text.png"
        text_overlay_png(it["text"], W, H, font, p)
        im = Image.new("RGBA", (W, H), (60, 120, 60, 255))
        im.alpha_composite(Image.open(p))
    out = work / f"preview_{a.index}.png"
    im.convert("RGB").save(out)
    print(out)


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)
    b = sub.add_parser("build"); b.add_argument("--shots", required=True)
    b.add_argument("--cut", choices=["roblox", "social"], default="social")
    b.add_argument("--format", choices=["landscape", "vertical", "both"], default="landscape")
    b.add_argument("--out"); b.add_argument("--keep-work", action="store_true")
    sub.add_parser("fonts")
    c = sub.add_parser("card"); c.add_argument("--shots", required=True); c.add_argument("--index", type=int, required=True)
    a = p.parse_args()
    {"build": build, "fonts": cmd_fonts, "card": cmd_card}[a.cmd](a)


if __name__ == "__main__":
    main()
