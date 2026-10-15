#!/usr/bin/env python3
"""Measuring tape for a reference UI screenshot. The reference is ONLY measured,
never pasted into the result.

Usage (all coordinates are reference pixels):
  measure.py REF edges   x0 y0 x1 y1            black-outline runs along rows/cols of a region
  measure.py REF col     x  y0 y1 [step]         hex colour per row down column x
  measure.py REF row     y  x0 x1 [step]         hex colour per column along row y
  measure.py REF vprof   x0 y0 x1 y1 [step]      median colour per row (ignores ink + white text)
  measure.py REF inkbox  x0 y0 x1 y1 [thr=130]   bbox of dark outline pixels (sum(rgb) < thr)
  measure.py REF fillbox x0 y0 x1 y1 [thr=215]   bbox of light fill pixels (min(rgb) > thr)
  measure.py REF textfill x0 y0 x1 y1 [thr=200]  outline colour + fill colour per row (gradient stops)
  measure.py REF pitch   x0 y0 x1 y1 [lo hi]     stud pitch along x by template sharpness (+ y)
  measure.py REF crop    x0 y0 x1 y1 OUT [scale] zoomed crop for eyeballing
"""
import sys
import numpy as np
from PIL import Image

HEX = lambda c: "%02x%02x%02x" % tuple(int(v) for v in c)


def runs(v):
    if len(v) == 0:
        return []
    out, s, p = [], v[0], v[0]
    for x in v[1:]:
        if x != p + 1:
            out.append((int(s), int(p))); s = x
        p = x
    out.append((int(s), int(p)))
    return out


def erode(m):
    o = m.copy(); o[1:] &= m[:-1]; o[:-1] &= m[1:]; o[:, 1:] &= m[:, :-1]; o[:, :-1] &= m[:, 1:]
    return o


def main():
    ref, cmd, *a = sys.argv[1:]
    im = np.asarray(Image.open(ref).convert("RGB")).astype(float)
    n = [float(x) if "." in x else int(x) for x in a if x.replace(".", "").lstrip("-").isdigit()]
    if cmd == "edges":
        x0, y0, x1, y1 = n[:4]
        dark = im.sum(2) < 150
        for y in range(y0, y1, max(1, (y1 - y0) // 6)):
            print("row", y, runs(np.nonzero(dark[y, x0:x1])[0] + x0))
        for x in range(x0, x1, max(1, (x1 - x0) // 6)):
            print("col", x, runs(np.nonzero(dark[y0:y1, x])[0] + y0))
    elif cmd == "col":
        x, y0, y1 = n[:3]; st = n[3] if len(n) > 3 else 1
        print(" ".join(f"{y}:{HEX(im[y, x])}" for y in range(y0, y1, st)))
    elif cmd == "row":
        y, x0, x1 = n[:3]; st = n[3] if len(n) > 3 else 1
        print(" ".join(f"{x}:{HEX(im[y, x])}" for x in range(x0, x1, st)))
    elif cmd == "vprof":
        x0, y0, x1, y1 = n[:4]; st = n[4] if len(n) > 4 else 3
        out = []
        for y in range(y0, y1, st):
            px = im[y, x0:x1]; ok = (px.sum(1) > 150) & ~(px.min(1) > 225)
            if ok.sum() > 2:
                out.append(f"{y}:{HEX(np.median(px[ok], 0))}")
        print(" ".join(out))
    elif cmd in ("inkbox", "fillbox"):
        x0, y0, x1, y1 = n[:4]
        p = im[y0:y1, x0:x1]
        if cmd == "inkbox":
            m = p.sum(2) < (n[4] if len(n) > 4 else 130)
        else:
            m = p.min(2) > (n[4] if len(n) > 4 else 215)
        ys, xs = np.nonzero(m)
        print((x0 + xs.min(), y0 + ys.min(), x0 + xs.max(), y0 + ys.max()))
    elif cmd == "textfill":
        x0, y0, x1, y1 = n[:4]; thr = n[4] if len(n) > 4 else 200
        p = im[y0:y1, x0:x1]; ink = p.sum(2) < thr
        inside = np.zeros_like(ink)
        for r in range(ink.shape[0]):
            q = np.nonzero(ink[r])[0]
            if len(q) > 1:
                inside[r, q[0]:q[-1]] = True
        core = erode(erode(inside & ~ink & (p.mean(2) > 110)))
        print("outline", HEX(np.median(p[ink], 0)))
        print(" ".join(f"{r + y0}:{HEX(np.median(p[r][core[r]], 0))}" for r in range(core.shape[0]) if core[r].sum() >= 3))
    elif cmd == "pitch":
        x0, y0, x1, y1 = n[:4]; lo, hi = (n[4], n[5]) if len(n) > 5 else (6, 60)
        L = im.mean(2)
        for axis, name in ((0, "x"), (1, "y")):
            prof = L[y0:y1, x0:x1].mean(axis)
            prof = prof - np.convolve(prof, np.ones(21) / 21, "same")
            prof = prof[10:-10]
            xs = np.arange(len(prof)) + (x0 if axis == 0 else y0) + 10
            res = []
            for P in np.arange(lo, hi, 0.05):
                ph = np.floor((xs % P) * 2).astype(int)
                s = np.bincount(ph, prof); c = np.bincount(ph); t = s[c > 0] / c[c > 0]
                res.append(((t ** 2).mean(), round(float(P), 2)))
            print(name, "best pitches", [p for _, p in sorted(res, reverse=True)[:3]])
    elif cmd == "crop":
        x0, y0, x1, y1 = n[:4]; out = a[4]; s = float(a[5]) if len(a) > 5 else 4
        Image.open(ref).convert("RGB").crop((x0, y0, x1, y1)).resize(
            (int((x1 - x0) * s), int((y1 - y0) * s)), Image.NEAREST).save(out)
        print("wrote", out)
    else:
        print(__doc__)


if __name__ == "__main__":
    main()
