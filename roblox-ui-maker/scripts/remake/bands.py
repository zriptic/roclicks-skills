#!/usr/bin/env python3
"""Measure diagonal light/dark stripes ("gloss bands") on a surface and emit
them as crisp CSS gradient layers: from scratch, but 1:1.

Method: residual = reference - heavy low-pass (text/icons masked). Try every
angle; shear the residual along it and average down the stripe direction;
the angle with the sharpest 1D profile is the stripe angle. That profile
(lighter/darker at each offset across the stripes) is converted into a
white-overlay and a black-overlay linear-gradient at that angle, with a stop
every px, so stripe edges stay as sharp as in the reference.

  bands.py REF x0 y0 x1 y1 [--masks m.json] [--r 14]
Prints two CSS background values (lighten, darken) sized to the box, plus the
angle and how much of the residual they explain.
"""
import argparse
import json
import math

import numpy as np
from PIL import Image


def box_blur(a, r):
    b = np.pad(a, r, mode="edge")
    c = np.cumsum(b, 0); c = np.concatenate([np.zeros_like(c[:1]), c], 0)
    b = (c[2 * r + 1:] - c[:-2 * r - 1]) / (2 * r + 1)
    c = np.cumsum(b, 1); c = np.concatenate([np.zeros_like(c[:, :1]), c], 1)
    return (c[:, 2 * r + 1:] - c[:, :-2 * r - 1]) / (2 * r + 1)


def main():
    ap = argparse.ArgumentParser()
    for k in ("ref", "x0", "y0", "x1", "y1"):
        ap.add_argument(k)
    ap.add_argument("--masks", default=""); ap.add_argument("--r", type=int, default=14)
    ap.add_argument("--angle", type=float, default=None, help="force the stripe angle (small plates)")
    ap.add_argument("--pct", type=float, default=None, help="base = this row percentile instead of row mean (stripes that only lighten)")
    a = ap.parse_args()
    x0, y0, x1, y1 = (int(v) for v in (a.x0, a.y0, a.x1, a.y1))
    img = np.asarray(Image.open(a.ref).convert("RGB")).astype(float)[y0:y1 + 1, x0:x1 + 1]
    L = img.mean(2)
    H, W = L.shape
    keep = np.ones((H, W))
    for mx0, my0, mx1, my1 in (json.load(open(a.masks)) if a.masks else []):
        keep[max(my0 - y0, 0):max(my1 - y0 + 1, 0), max(mx0 - x0, 0):max(mx1 - x0 + 1, 0)] = 0
    # low-pass along rows only (stripes are diagonal; vertical gradient must stay)
    lp = np.zeros_like(L)
    r = a.r
    for yy in range(H):
        k = keep[yy]
        if k.sum() < 3:
            continue
        if a.pct is not None:
            lp[yy] = np.percentile(L[yy][k > 0], a.pct)
            continue
        num = np.convolve(L[yy] * k, np.ones(2 * r + 1), "same")
        den = np.convolve(k, np.ones(2 * r + 1), "same")
        lp[yy] = num / np.maximum(den, 1e-6)
    res = (L - lp) * keep
    # kill periodic fine detail (studs ~12px, sparkles ~15px) before the angle
    # search: average over one period in both directions
    kk = box_blur(keep, 6)
    res_s = box_blur(res, 6) / np.maximum(kk, 1e-6) * keep
    ys, xs = np.mgrid[0:H, 0:W]
    best = None
    for deg in ([a.angle] if a.angle is not None else [d for d in np.arange(-70, 71, 1.0) if abs(d) >= 12]):
        t = math.tan(math.radians(deg))
        u = np.round(xs - ys * t).astype(int)          # offset across the stripes
        u -= u.min()
        s = np.bincount(u.ravel(), res_s.ravel()); n = np.bincount(u.ravel(), keep.ravel())
        prof = s / np.maximum(n, 1)
        v = (prof[n > H * 0.3] ** 2).mean() if (n > H * 0.3).any() else 0
        if best is None or v > best[0]:
            best = (v, deg, prof, n, u.min())
    _, deg, _, n, _ = best
    tt = math.tan(math.radians(deg))
    u = np.round(xs - ys * tt).astype(int); u -= u.min()
    prof = np.bincount(u.ravel(), res.ravel()) / np.maximum(np.bincount(u.ravel(), keep.ravel()), 1)
    n = np.bincount(u.ravel(), keep.ravel())
    t = math.tan(math.radians(deg))
    umin = -H * t if t > 0 else 0
    # convert profile into overlay alphas against the mean luminance
    base = lp[keep > 0].mean()
    light, dark = [], []
    for i, dv in enumerate(prof):
        if n[i] < 2:
            dv = 0
        light.append(max(0.0, dv) / max(255 - base, 1))
        dark.append(max(0.0, -dv) / max(base, 1))
    # CSS: gradient angle so that position = x - y*tan (skew along the stripes)
    css_angle = 90 - deg          # CSS angle measured clockwise from "to top"
    # length of the gradient line for that angle over the box
    rad = math.radians(css_angle)
    glen = abs(W * math.sin(rad)) + abs(H * math.cos(rad))
    k = math.cos(math.radians(deg))  # px across stripes per px of u
    def css(alphas, rgb):
        stops = []
        for i, al in enumerate(alphas):
            pos = (i * k) / glen * 100
            stops.append(f"rgba({rgb},{min(al, 1):.3f}) {pos:.2f}%")
        return f"linear-gradient({css_angle:.1f}deg, {', '.join(stops[::1])})"
    explained = 1 - ((res - 0) ** 2).mean() and (prof ** 2).mean() / max((res ** 2)[keep > 0].mean(), 1e-6)
    print(json.dumps({"angle_deg": deg, "explained": round(float(explained), 3),
                      "light": css(light, "255,255,255"), "dark": css(dark, "0,0,0")}))


if __name__ == "__main__":
    main()
