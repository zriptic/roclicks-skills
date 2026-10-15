#!/usr/bin/env python3
"""Row-colour calibration for small plates in a 1:1 remake (TEMPLATE: edit PLATES per project).

Render your page (2x, downsampled to the reference size), compare each row's mean colour
(text/icon pixels excluded) with the reference, and shift that row's colour in profiles.json by
the difference. 3 rounds took row error 7.4 -> 1.9 on a real remake.

Usage (from the remake folder, which holds ref.png, build.py and profiles.json):
    RENDER_CMD="bash shot.sh" RENDER_PNG=mine.png python3 calibrate_rows.py
  RENDER_CMD must re-render the page to RENDER_PNG at the reference's pixel size.
  profiles.json = {key: [[y, "rrggbb"], ...]} (per-row colours your build.py draws plates from).
  PLATES (below) = {key: (x0, x1 columns to average, exclude box or None)} measured on ref.png.
"""
import json, subprocess, numpy as np
from PIL import Image
import os
RENDER_CMD = os.environ.get("RENDER_CMD", "bash shot.sh")
RENDER_PNG = os.environ.get("RENDER_PNG", "mine.png")
PLATES = {  # EXAMPLE VALUES from one remake; replace. profile key: (x0, x1 columns to average, exclude box or None)
    "close_base": (737, 787, (745, 105, 777, 137)),
    "btn19": (166, 311, (200, 322, 268, 356)), "btn49": (606, 761, (645, 492, 717, 526)),
    "tab1": (48, 119, (56, 159, 113, 240)), "tab2": (48, 119, (56, 247, 113, 330)),
    "tab3": (48, 119, (56, 335, 113, 418)), "tab4": (48, 119, (56, 423, 113, 506)),
    "tag": (605, 781, (610, 191, 777, 211)),
}
ref = np.asarray(Image.open("ref.png").convert("RGB")).astype(float)
def rowmean(img, y, x0, x1, ex):
    xs = np.arange(x0, x1 + 1); p = img[y, x0:x1 + 1]
    ok = ~((p.min(1) > 235) | (p.sum(1) < 200))
    if ex and ex[1] <= y <= ex[3]:
        ok &= ~((xs >= ex[0]) & (xs <= ex[2]))
    return p[ok].mean(0) if ok.sum() > 2 else None
for it in range(3):
    subprocess.run(["python3", "build.py"], capture_output=True)
    subprocess.run(RENDER_CMD, shell=True, capture_output=True)
    mine = np.asarray(Image.open(RENDER_PNG).convert("RGB")).astype(float)
    P = json.load(open("profiles.json")); tot = []
    for key, (x0, x1, ex) in PLATES.items():
        rows = P[key]; new = []
        for y, c in rows:
            col = np.array([int(c[i:i + 2], 16) for i in (0, 2, 4)], float)
            r, m = rowmean(ref, y, x0, x1, ex), rowmean(mine, y, x0, x1, ex)
            if r is not None and m is not None:
                d = r - m; tot.append(np.abs(d).mean()); col = np.clip(col + 0.8 * d, 0, 255)
            new.append([y, "%02x%02x%02x" % tuple(int(round(v)) for v in col)])
        P[key] = new
    json.dump(P, open("profiles.json", "w"), indent=0)
    print("iter", it, "mean row error before correction %.1f" % np.mean(tot), flush=True)
subprocess.run(["python3", "build.py"], capture_output=True)
