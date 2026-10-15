#!/usr/bin/env python3
"""Read a STYLE reference image and draft the style tokens (step 1 of the workflow).

Usage:
    python3 $SK/scripts/read_reference.py ref.png [--out style.css] [--box x0 y0 x1 y1]

Prints, and writes as a draft style.css (CSS tokens that override the preset):
  * palette       10 dominant colours (k-means on the UI pixels) with their share, as hex
  * outline       typical dark-outline thickness in px (runs of near-black pixels across edges)
  * texture       weak stud/glass/flat guess + <ref>_zoom.png, a 3x zoom of the most colourful plate area:
                  READ that image to decide studs vs flat vs glossy (the guess alone is not reliable)
  * text          share of near-white pixels with dark rings (outlined white text) -> outline guess
  * density       edge density (busy vs calm) to pick spacing
It also saves <ref>_palette.png (swatches with hex) to show the developer next to the first screen.

These are MEASURED HINTS, not the answer: open the reference, zoom (scripts/remake/measure.py crop),
confirm each value, then pick the preset (styles/stud.css or styles/glass.css) and keep only the
overrides in style.css. --box limits the reading to the UI part of a full-screen capture.
"""
import argparse
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter


def kmeans(px, k=10, it=12, seed=1):
    rng = np.random.default_rng(seed)
    c = px[rng.choice(len(px), k, replace=False)].astype(float)
    for _ in range(it):
        d = ((px[:, None, :] - c[None]) ** 2).sum(2)
        lab = d.argmin(1)
        for j in range(k):
            m = px[lab == j]
            if len(m):
                c[j] = m.mean(0)
    share = np.bincount(lab, minlength=k) / len(px)
    order = np.argsort(-share)
    return c[order], share[order]


def hexc(c):
    return '#%02x%02x%02x' % tuple(int(round(v)) for v in c)


def period(sig, lo=8, hi=80):
    sig = sig - sig.mean()
    f = np.fft.rfft(sig, n=len(sig) * 2)
    ac = np.fft.irfft(f * np.conj(f))[:len(sig)]
    ac /= ac[0] + 1e-9
    seg = ac[lo:hi]
    i = int(seg.argmax())
    return lo + i, float(seg[i])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('ref')
    ap.add_argument('--out', default='style.css')
    ap.add_argument('--box', nargs=4, type=int)
    a = ap.parse_args()
    im = Image.open(a.ref).convert('RGB')
    if a.box:
        im = im.crop(tuple(a.box))
    arr = np.asarray(im).astype(float)
    H, W, _ = arr.shape
    small = np.asarray(im.resize((max(1, W // 4), max(1, H // 4)))).reshape(-1, 3).astype(float)
    cols, share = kmeans(small, 10)
    lum = arr.mean(2)

    # outline thickness: horizontal runs of near-black pixels bounded by brighter pixels
    dark = lum < 45
    runs = []
    for y in range(0, H, 3):
        row = dark[y]
        x = 0
        while x < W:
            if row[x]:
                s = x
                while x < W and row[x]:
                    x += 1
                if 1 <= x - s <= 14 and s > 0 and x < W:
                    runs.append(x - s)
            x += 1
    outline = float(np.percentile(runs, 80)) if runs else 0.0   # p80: plate/panel outlines, not thin text strokes
    text_ol = float(np.median(runs)) if runs else 0.0

    # texture: stud repeat in both axes on the high-pass luminance of mid-tone (coloured) areas
    hp = lum - np.asarray(Image.fromarray(lum.astype(np.uint8)).filter(ImageFilter.GaussianBlur(6))).astype(float)
    sat = arr.max(2) - arr.min(2)
    mask = (sat > 60) & (lum > 60)                      # coloured plate faces, where studs live
    def avg_period(img, m, lo=12, hi=90):
        # autocorrelate each row that is mostly plate face, then average the autocorrelations
        # (averaging the rows first cancels out: plates have different stud phases)
        acs = []
        for r, mr in zip(img, m):
            if mr.sum() < 120:
                continue
            v = np.where(mr, r - r[mr].mean(), 0.0)
            f = np.fft.rfft(v, n=len(v) * 2)
            ac = np.fft.irfft(f * np.conj(f))[:len(v)]
            if ac[0] > 0:
                acs.append(ac / ac[0])
        if not acs:
            return 0, 0.0
        ac = np.mean(acs, 0)
        seg = ac[lo:hi]
        i = int(seg.argmax())
        return lo + i, float(seg[i])
    px_, sx = avg_period(hp, mask)
    py_, sy = avg_period(hp.T, mask.T)
    stud = sx > 0.15
    semi = ((lum > 15) & (lum < 60)).mean()
    texture = 'stud?' if stud else ('glass?' if semi > 0.25 else 'flat?')
    # The automatic texture guess is weak (overlay-blended studs are low contrast). The reliable check
    # is LOOKING: save a 3x zoom of the most colourful plate area and Read it.
    win = (min(240, W), min(140, H))
    best, bxy = -1, (0, 0)
    score = (sat * (lum > 60)).astype(float)
    for y0 in range(0, H - win[1] + 1, 20):
        for x0 in range(0, W - win[0] + 1, 20):
            v = score[y0:y0 + win[1], x0:x0 + win[0]].mean()
            if v > best:
                best, bxy = v, (x0, y0)
    zoom = im.crop((bxy[0], bxy[1], bxy[0] + win[0], bxy[1] + win[1])).resize((win[0] * 3, win[1] * 3), Image.NEAREST)

    # text: near-white pixels that sit next to dark pixels (outlined white text)
    white = lum > 225
    ring = np.zeros_like(white)
    ring[2:-2, 2:-2] = white[2:-2, 2:-2] & (dark[:-4, 2:-2] | dark[4:, 2:-2] | dark[2:-2, :-4] | dark[2:-2, 4:])
    outlined_text = ring.sum() / max(1, white.sum())

    edges = np.asarray(im.convert('L').filter(ImageFilter.FIND_EDGES)).astype(float)
    density = float((edges > 40).mean())

    print(f'reference {a.ref}  {W}x{H}')
    print('palette   ' + '  '.join(f'{hexc(c)} {s * 100:.0f}%' for c, s in zip(cols, share)))
    print(f'outline   plates/panels ~{outline:.1f} px, thin (text) ~{text_ol:.1f} px near-black ({len(runs)} runs)')
    print(f'texture   {texture}  (strongest repeat x {px_}px r={sx:.2f}; semi-dark share {semi:.2f}) -> CONFIRM by reading the zoom PNG')
    print(f'text      outlined-white ratio {outlined_text:.2f} ({"outlined text" if outlined_text > 0.15 else "plain text"})')
    print(f'density   edge share {density:.3f} ({"busy: tighter spacing" if density > 0.12 else "calm: roomy spacing"})')

    # swatch image
    sw = Image.new('RGB', (110 * len(cols), 150), '#111')
    d = ImageDraw.Draw(sw)
    for i, (c, s) in enumerate(zip(cols, share)):
        d.rectangle([i * 110 + 5, 5, i * 110 + 105, 105], fill=tuple(int(v) for v in c))
        d.text((i * 110 + 8, 112), hexc(c), fill='#fff')
        d.text((i * 110 + 8, 130), f'{s * 100:.0f}%', fill='#aaa')
    base = os.path.splitext(a.ref)[0]
    sw.save(base + '_palette.png')
    zoom.save(base + '_zoom.png')

    preset = 'stud'   # the default; switch only when the zoom clearly shows no studs (e.g. dark glass -> glass)
    dark_cols = [c for c in cols if c.mean() < 60]
    css = [f'/* style.css: per-game tokens read from {os.path.basename(a.ref)} by read_reference.py (DRAFT: confirm each by eye).',
           f'   Preset to load before this file: styles/{preset}.css. Keep only values that differ from the preset. */',
           ':root {',
           f'  /* palette: {" ".join(hexc(c) for c in cols)} */']
    if dark_cols:
        css.append(f'  --ink: {hexc(dark_cols[0])};')
    if outline:
        css.append(f'  --plate-ow: {max(2, round(outline))}px;  --panel-bw: {max(2, round(outline * 1.15))}px;')
        css.append(f'  --stroke-k: {max(0.4, min(1.6, text_ol / 3.5)):.2f};   /* visible text outline ~{text_ol:.1f}px vs the preset 3.5 (7px stroke, half outside) */')
    if texture == 'stud?':
        css.append(f'  /* --stud: {px_ * 4}px;   if the zoom shows studs every {px_}px (stud.png holds 4x4 studs) */')
    css.append('  /* no studs in the zoom? -> --stud-op: 0; --head-stud-op: 0; (flat plates) */')
    css.append('}')
    css.append('/* colour ramps: copy the nearest .c-* from the preset and set --top/--mid/--bot/--lip from the palette */')
    open(a.out, 'w').write('\n'.join(css) + '\n')
    print(f'wrote {a.out} (draft tokens), {base}_palette.png, {base}_zoom.png (Read it: studs? gloss? outline?); preset: styles/{preset}.css (default; use glass.css only if the zoom shows flat dark panels without studs)')


if __name__ == '__main__':
    main()
