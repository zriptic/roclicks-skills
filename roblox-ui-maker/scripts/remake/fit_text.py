#!/usr/bin/env python3
"""Auto-fits every live label in a project's build.py to its measured reference
box, to within 1px. Run from the project folder with its preview server up.

  fit_text.py PORT WIDTH HEIGHT

build.py must define LABELS = {key: (text, (x0,y0,x1,y1), mode, threshold)}
(mode "ink" = dark outline box, label rendered on white; "fill" = light fill box,
rendered on black) or the short form {key: (text, box)} (= ink, 130), read
text_fit.txt ("key fontsize scaleX dx dy" per line), and support
?labels=KEY&bg=%23fff (show only that label on a flat background, no zoom).
"""
import re
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image

import os
CHROME = os.environ.get("CHROME", "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome")  # macOS default; set CHROME elsewhere
port, W, H = sys.argv[1], sys.argv[2], sys.argv[3]
_src = open("build.py").read()
import os; _ns = {"__file__": os.path.abspath("build.py")}
_pre = _src[:_src.index("LABELS = {")]          # constants LABELS may depend on (e.g. INK)
exec(compile(_pre.split("def ")[0], "build.py", "exec"), _ns)
exec(re.search(r"LABELS = \{.*?\n\}", _src, re.S).group(0), _ns)
LABELS = _ns["LABELS"]
spec = {}
for k, v in LABELS.items():  # noqa: F821  (defined by exec)
    text, box = v[0], v[1]
    mode, thr = (v[2], v[3]) if len(v) > 2 else ("ink", 130)
    spec[k] = (box, mode, thr)
fit = {k: ((b[3] - b[1]) * 0.95, 1.0, 0.0, -3.0) for k, (b, m, t) in spec.items()}


def write():
    open("text_fit.txt", "w").write("\n".join(f"{k} {v[0]:.3f} {v[1]:.4f} {v[2]:.2f} {v[3]:.2f}" for k, v in fit.items()))


for it in range(5):
    write()
    subprocess.run(["python3", "build.py"], capture_output=True)
    worst = 0
    for k, ((x0, y0, x1, y1), mode, thr) in spec.items():
        out = tempfile.mktemp(suffix=".png")
        bg = "%23fff" if mode == "ink" else "%23000"
        subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars", f"--window-size={W},{H}",
                        "--virtual-time-budget=6000", f"--screenshot={out}",
                        f"http://localhost:{port}/?labels={k}&bg={bg}"], capture_output=True)
        px = np.asarray(Image.open(out).convert("RGB")).astype(int)
        m = (px.sum(2) < thr) if mode == "ink" else (px.max(2) > thr)
        ox, oy = max(x0 - 40, 0), max(y0 - 16, 0)
        ys, xs = np.nonzero(m[oy:y1 + 16, ox:x1 + 40])
        if len(xs) == 0:
            sys.exit(f"{k}: nothing rendered: check ?labels mode / window size")
        mx0, my0, mx1, my1 = xs.min() + ox, ys.min() + oy, xs.max() + ox, ys.max() + oy
        fs, sx, dx, dy = fit[k]
        hs = (y1 - y0) / max(my1 - my0, 1)
        fs *= hs
        sx *= (x1 - x0) / max((mx1 - mx0) * hs, 1)
        fit[k] = (fs, sx, dx + x0 - mx0, dy + y0 - my0)
        worst = max(worst, abs(mx0 - x0), abs(my0 - y0), abs(mx1 - x1), abs(my1 - y1))
        if it == 4:
            print(f"{k:14} ref {(x0, y0, x1, y1)} mine {(int(mx0), int(my0), int(mx1), int(my1))} scaleX {sx:.3f}")
    print("iter", it, "worst px", worst)
write()
subprocess.run(["python3", "build.py"])
