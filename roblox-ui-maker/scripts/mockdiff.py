#!/usr/bin/env python3
"""Score the offline mock against the HTML (called by mockshot.mjs; can be run alone).

Usage (from the project's UI folder): python3 $SK/scripts/mockdiff.py [Screen ...]
For each screen: composite rbx/out/mock/mock_<S>.png over bg_<S>.png, blur both (1.5 px, so sub-pixel
text phase doesn't dominate), print mean abs diff (0-255) overall and on a 3x3 grid, and save
rbx/out/mock/cmp_<S>.png (HTML / mock / heatmap stacked). Look at the worst grid cell first.
Healthy: mean 1-3. Above ~5: something converted wrong (missing art, gradient angle, stroke, font).
"""
import json
import os
import sys

import numpy as np
from PIL import Image, ImageFilter

M = os.path.join('rbx', 'out', 'mock')
names = sys.argv[1:] or [s['name'] for s in json.load(open('rbx.json'))['screens']]
for n in names:
    ref = Image.open(os.path.join(M, f'ref_{n}.png')).convert('RGB')
    bg = Image.open(os.path.join(M, f'bg_{n}.png')).convert('RGBA')
    mk = Image.open(os.path.join(M, f'mock_{n}.png')).convert('RGBA')
    comp = Image.alpha_composite(bg, mk).convert('RGB')
    A = np.asarray(ref.filter(ImageFilter.GaussianBlur(1.5))).astype(float)
    B = np.asarray(comp.filter(ImageFilter.GaussianBlur(1.5))).astype(float)
    d = np.abs(A - B).mean(axis=2)
    h, w = d.shape
    grid = [[d[i * h // 3:(i + 1) * h // 3, j * w // 3:(j + 1) * w // 3].mean() for j in range(3)] for i in range(3)]
    print(f"{n:14s} mean {d.mean():5.2f}  >40: {100 * (d > 40).mean():5.2f}%  grid " +
          ' / '.join(' '.join(f'{v:4.1f}' for v in r) for r in grid))
    heat = Image.fromarray(np.clip(d * 4, 0, 255).astype(np.uint8)).convert('RGB')
    c = Image.new('RGB', (w, h * 3))
    c.paste(ref, (0, 0)); c.paste(comp, (0, h)); c.paste(heat, (0, 2 * h))
    c.resize((w // 2, h * 3 // 2)).save(os.path.join(M, f'cmp_{n}.png'))
