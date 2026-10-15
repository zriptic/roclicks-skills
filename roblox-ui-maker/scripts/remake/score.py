#!/usr/bin/env python3
"""Region-by-region score of a render against the reference.

  score.py REF RENDER regions.json [OUT_HEATMAP]

regions.json: {"regions": {name: [x0,y0,x1,y1]}, "ignore": [[x0,y0,x1,y1], ...]}
(ignore = placeholder icons, which are allowed to differ).
Prints mean abs RGB error per region (0 = identical, 255 = opposite), worst
first, plus the % of pixels off by more than 30. Lower is better; aim < 8. BLUR env (default 1.5) blurs both images first,
so a 1px text offset does not dominate (raw: BLUR=0).
"""
import json
import sys

import numpy as np
from PIL import Image, ImageFilter

import os
BLUR = float(os.environ.get("BLUR", "1.5"))   # blur both first: judges colour/shape, not sub-pixel phase
ref = np.asarray(Image.open(sys.argv[1]).convert("RGB").filter(ImageFilter.GaussianBlur(BLUR))).astype(float)
ren = np.asarray(Image.open(sys.argv[2]).convert("RGB").filter(ImageFilter.GaussianBlur(BLUR))).astype(float)
cfg = json.load(open(sys.argv[3]))
d = np.abs(ref - ren).mean(2)
mask = np.ones(d.shape, bool)
for x0, y0, x1, y1 in cfg.get("ignore", []):
    mask[y0:y1 + 1, x0:x1 + 1] = False
rows = []
for name, (x0, y0, x1, y1) in cfg["regions"].items():
    sub, m = d[y0:y1 + 1, x0:x1 + 1], mask[y0:y1 + 1, x0:x1 + 1]
    if m.sum() == 0:
        continue
    rows.append((sub[m].mean(), (sub[m] > 30).mean() * 100, name))
for err, bad, name in sorted(rows, reverse=True):
    print(f"{name:18} {err:6.1f}   {bad:5.1f}% off>30")
if len(sys.argv) > 4:
    h = np.clip(d * 3, 0, 255) * mask
    Image.fromarray(h.astype("uint8")).filter(ImageFilter.GaussianBlur(1)).save(sys.argv[4])
