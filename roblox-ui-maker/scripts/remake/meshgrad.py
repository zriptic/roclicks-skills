#!/usr/bin/env python3
"""Measure a surface's smooth colour field and emit it as a vector mesh
gradient (SVG): one horizontal band per `ystep` px, each a linearGradient with
a stop every `xstep` px. The reference is only measured; the output is drawn
geometry, not copied pixels (fine detail is low-passed away; draw it as
separate fitted layers).

  meshgrad.py REF x0 y0 x1 y1 OUT.svg [--masks masks.json] [--ystep 3] [--xstep 8] [--r 6]

Masked areas (text, icons, buttons sitting on the surface) are excluded and
filled from their surroundings by normalized convolution.
Prints the mean abs error of the smooth field vs the unmasked reference.
"""
import argparse

import numpy as np
from PIL import Image


def box_blur(a, rx, ry=None):
    ry = rx if ry is None else ry
    pad = [(ry, ry), (rx, rx)] + [(0, 0)] * (a.ndim - 2)
    b = np.pad(a, pad, mode="edge")
    c = np.cumsum(b, 0); c = np.concatenate([np.zeros_like(c[:1]), c], 0)
    b = (c[2 * ry + 1:] - c[:-2 * ry - 1]) / (2 * ry + 1)
    c = np.cumsum(b, 1); c = np.concatenate([np.zeros_like(c[:, :1]), c], 1)
    return (c[:, 2 * rx + 1:] - c[:, :-2 * rx - 1]) / (2 * rx + 1)


RY = None  # vertical radius override (anisotropic: smooth stripes along rows, keep rims)


def smooth(a, r):
    for _ in range(2):
        a = box_blur(a, r, RY if RY is not None else r)
    return a


def field(ref, box, masks, r):
    x0, y0, x1, y1 = box
    p = ref[y0:y1 + 1, x0:x1 + 1].astype(float)
    keep = np.ones(p.shape[:2])
    for mx0, my0, mx1, my1 in masks:
        keep[max(my0 - y0, 0):max(my1 - y0 + 1, 0), max(mx0 - x0, 0):max(mx1 - x0 + 1, 0)] = 0
    # fill masked pixels along their own row first (surfaces are mostly vertical
    # gradients, so borrowing from rows above/below leaves light/dark patches)
    p = p.copy()
    for y in range(p.shape[0]):
        ok = np.nonzero(keep[y])[0]
        if 0 < len(ok) < p.shape[1]:
            for c in range(3):
                p[y, :, c] = np.where(keep[y] > 0, p[y, :, c], np.interp(np.arange(p.shape[1]), ok, p[y, ok, c]))
    keep_rows = keep.copy()
    keep = np.where(keep.sum(1, keepdims=True) > 0, 1.0, keep)
    out = None
    for rr in (r, 3 * r, 9 * r, 27 * r):
        w = smooth(keep, rr)
        f = smooth(p * keep[..., None], rr) / np.maximum(w, 1e-6)[..., None]
        if out is None:
            out, ok = f, w > 0.2
        else:
            out = np.where(ok[..., None], out, f); ok = ok | (w > 0.2)
    return p, keep_rows.astype(bool), out


def svg(fld, xstep, ystep):
    H, W = fld.shape[:2]
    defs, rects = [], []
    ys = list(range(0, H, ystep))
    for i, y in enumerate(ys):
        h = min(ystep, H - y)
        row = fld[y:y + h].mean(0)
        xs = list(range(0, W, xstep)) + [W - 1]
        stops = "".join(f'<stop offset="{x / max(W - 1, 1):.4f}" stop-color="#{int(row[x][0]):02x}{int(row[x][1]):02x}{int(row[x][2]):02x}"/>' for x in xs)
        defs.append(f'<linearGradient id="g{i}" x1="0" x2="1" y1="0" y2="0">{stops}</linearGradient>')
        rects.append(f'<rect x="0" y="{y}" width="{W}" height="{h + 0.6:.1f}" fill="url(#g{i})"/>')
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}" '
            f'preserveAspectRatio="none" shape-rendering="crispEdges"><defs>{"".join(defs)}</defs>{"".join(rects)}</svg>')


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("ref"); ap.add_argument("x0", type=int); ap.add_argument("y0", type=int)
    ap.add_argument("x1", type=int); ap.add_argument("y1", type=int); ap.add_argument("out")
    ap.add_argument("--masks", default="", help="JSON file: [[x0,y0,x1,y1], ...]")
    ap.add_argument("--ystep", type=int, default=3); ap.add_argument("--xstep", type=int, default=8)
    ap.add_argument("--r", type=int, default=6)
    ap.add_argument("--ry", type=int, default=None, help="vertical radius (default = r)")
    a = ap.parse_args()
    global RY
    RY = a.ry
    ref = np.asarray(Image.open(a.ref).convert("RGB"))
    import json
    masks = [tuple(m) for m in json.load(open(a.masks))] if a.masks else []
    p, keep, fld = field(ref, (a.x0, a.y0, a.x1, a.y1), masks, a.r)
    open(a.out, "w").write(svg(fld, a.xstep, a.ystep))
    print(f"{a.out}: field error on unmasked px {np.abs(p - fld)[keep].mean():.1f}")


if __name__ == "__main__":
    main()
