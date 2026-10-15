#!/usr/bin/env python3
"""clip_frames: read a reference clip (video or GIF) of an effect into labelled
frame sheets, to build an effect against. Stands in for Roqer's reference_clip.

Usage:
  clip_frames.py <clip> [--from S] [--to S] [--count N] [--slowed X] [--full] [-o sheet.png]

  --from/--to   span in seconds of the clip (default: whole clip)
  --count       frames to sample evenly over the span (default 12, max 16)
  --slowed X    the clip plays X times slower than real (labels show real seconds)
  --full        keep the whole frame; by default each frame is cropped to where
                the clip changes across the span (the effect, not the backdrop)

Prints, per frame: effect time (from the span start, real speed), mean
brightness of the changing region, its share of the frame, and the dominant
bright colour. These are approximate (compression, bloom and the background
shift them): read them against the frames. Needs ffmpeg, numpy and Pillow.
"""
import argparse
import json
import os
import subprocess
import tempfile

import numpy
from PIL import Image, ImageDraw


def probe(path):
    out = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries",
                          "stream=r_frame_rate:format=duration", "-of", "json", path],
                         capture_output=True, text=True, check=True).stdout
    info = json.loads(out)
    num, den = info["streams"][0]["r_frame_rate"].split("/")
    return float(info["format"]["duration"]), float(num) / max(1.0, float(den))


def decode(path, start, end, folder):
    """Every frame of the span, decoded once (seeking near the end of a file returns nothing)."""
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-ss", f"{start:.3f}", "-i", path, "-t", f"{end - start:.3f}",
                    "-vsync", "0", os.path.join(folder, "%05d.png")], check=True)
    return sorted(os.path.join(folder, f) for f in os.listdir(folder) if f.endswith(".png"))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("clip")
    ap.add_argument("--from", dest="start", type=float, default=0.0)
    ap.add_argument("--to", dest="end", type=float, default=None)
    ap.add_argument("--count", type=int, default=12)
    ap.add_argument("--slowed", type=float, default=1.0)
    ap.add_argument("--full", action="store_true")
    ap.add_argument("-o", "--out", default=None)
    a = ap.parse_args()

    length, fps = probe(a.clip)
    end = min(a.end if a.end is not None else length, length)
    with tempfile.TemporaryDirectory() as folder:
        files = decode(a.clip, a.start, end, folder)
        if not files:
            raise SystemExit("no frames decoded in that span")
        count = max(2, min(16, a.count, len(files)))
        picks = [round((len(files) - 1) * i / (count - 1)) for i in range(count)]
        times = [a.start + p / fps for p in picks]
        frames = [numpy.asarray(Image.open(files[p]).convert("RGB"), dtype=numpy.float32) / 255.0 for p in picks]

    stack = numpy.stack(frames)
    change = numpy.abs(stack - stack.min(axis=0)).max(axis=(0, 3))
    mask = change > 0.12
    if not a.full and mask.any():
        ys, xs = numpy.where(mask)
        pad = 12
        y0, y1 = max(0, ys.min() - pad), min(mask.shape[0], ys.max() + pad)
        x0, x1 = max(0, xs.min() - pad), min(mask.shape[1], xs.max() + pad)
    else:
        y0, y1, x0, x1 = 0, mask.shape[0], 0, mask.shape[1]

    base = stack.min(axis=0)  # the backdrop: an effect adds light (or dark) on top of it
    rows = []
    for i, (t, frame) in enumerate(zip(times, frames)):
        diff = numpy.abs(frame - base).max(axis=-1) > 0.12
        share = float(diff.mean())
        region = frame[diff] if diff.any() else frame.reshape(-1, 3)
        bright = float(region.mean())
        top = region[region.max(axis=-1) >= numpy.quantile(region.max(axis=-1), 0.8)]
        colour = "#%02x%02x%02x" % tuple(int(c * 255) for c in (top.mean(axis=0) if len(top) else region.mean(axis=0)))
        real = (t - a.start) / a.slowed
        rows.append((i + 1, real, bright, share, colour))

    cell_w = 300
    scale = cell_w / max(1, (x1 - x0))
    cell_h = max(40, int((y1 - y0) * scale))
    columns = 4
    sheet_rows = (count + columns - 1) // columns
    label = 16
    sheet = Image.new("RGB", (columns * cell_w, sheet_rows * (cell_h + label)), (20, 20, 24))
    draw = ImageDraw.Draw(sheet)
    for (n, real, _, _, _), frame in zip(rows, frames):
        crop = Image.fromarray((frame[y0:y1, x0:x1] * 255).astype(numpy.uint8)).resize((cell_w, cell_h))
        r, c = divmod(n - 1, columns)
        sheet.paste(crop, (c * cell_w, r * (cell_h + label) + label))
        draw.text((c * cell_w + 4, r * (cell_h + label) + 2), f"#{n}  {real:.3f}s", fill=(230, 230, 230))
    out = a.out or os.path.splitext(os.path.basename(a.clip))[0] + f"_frames_{a.start:.2f}-{end:.2f}.png"
    sheet.save(out)

    print(f"{a.clip}: {length:.2f} s; span {a.start:.2f}-{end:.2f} s; crop {'full' if a.full else f'x{x0}-{x1} y{y0}-{y1}'}")
    print("frame  time(s)  brightness  share  colour")
    for n, real, bright, share, colour in rows:
        print(f"{n:>5}  {real:7.3f}  {bright:10.2f}  {share * 100:4.0f}%  {colour}")
    peak = max(rows, key=lambda r: r[2] * (0.5 + r[3]))
    print(f"peak near {peak[1]:.3f} s; sheet: {out}")


if __name__ == "__main__":
    main()
