#!/usr/bin/env python3
"""Copy the icons a project uses from YOUR icon pack into <project>/icons/<slug>.png.

Works on any folder of PNG icons (a licensed pack you own). Nothing about the pack is hardcoded:
pass its folder with --pack.

Usage (run from the project's UI folder, e.g. ui/):
    python3 $SK/scripts/copy_icons.py icons.json --pack <path to your icon pack>
    python3 $SK/scripts/copy_icons.py icons.json --pack <pack> --prefer " Outline"   # prefer outlined variants
    python3 $SK/scripts/copy_icons.py icons.json --pack <pack> --size 256            # resize to 256x256 (keeps aspect, pads)

icons.json maps a short slug (what the HTML and Luau use) to an icon in the pack, either
  - a path relative to the pack folder:          {"cash": "Currency/Cash/Green Cash.png"}
  - or a file name stem (searched recursively):   {"cash": "Green Cash", "gem": "Purple Gem", "x": "X"}
A stem matches "<stem>.png" and also "<stem> <N>px.png" (a common size suffix); when several files
match, the largest image wins. With --prefer SUFFIX, "<stem><SUFFIX>" is tried first (many packs ship
an outlined variant, which suits outlined/stud styles); without it the plain file is tried first.

MISSING lines mean the name is wrong: search the pack again (synonyms: cash/money, gear/settings,
cart/shop/bag), never substitute an emoji or an icon from a different pack (one pack per project).

Slugs become file names and later asset-ledger keys ("icon:<slug>"), so keep them lowercase
[a-z0-9_] and never rename one after it has been uploaded.

Licence: commit icons.json and this script to your game repo, not the pack's files, unless the
pack's licence allows redistribution. Never send pack images to an image model if the licence
forbids AI use.
"""
import argparse
import json
import os
import re
import sys

from PIL import Image

SIZE_SUFFIX = re.compile(r'\s+\d+px$', re.I)


def index_pack(pack):
    """stem (lowercase, size suffix stripped) -> list of absolute paths"""
    idx = {}
    for d, _, files in os.walk(pack):
        for f in files:
            if not f.lower().endswith('.png'):
                continue
            stem = SIZE_SUFFIX.sub('', os.path.splitext(f)[0]).strip().lower()
            idx.setdefault(stem, []).append(os.path.join(d, f))
    return idx


def largest(paths):
    def area(p):
        try:
            w, h = Image.open(p).size
            return w * h
        except Exception:
            return 0
    return max(paths, key=area)


def find(pack, idx, name, prefer):
    direct = os.path.join(pack, name)
    if os.path.isfile(direct):
        return direct
    stem = SIZE_SUFFIX.sub('', os.path.splitext(name)[0]).strip().lower()
    order = [stem + prefer.lower(), stem] if prefer else [stem]
    for s in order:
        if s in idx:
            return largest(idx[s])
    return None


def main(argv):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('mapping', help='icons.json: {"slug": "stem or relative path"}')
    ap.add_argument('--pack', required=True, help='folder of your icon pack (searched recursively)')
    ap.add_argument('--prefer', default='', help='variant suffix to try first, e.g. " Outline"')
    ap.add_argument('--size', type=int, default=0, help='optional square output size in px (0 = keep)')
    ap.add_argument('--out', default='icons', help='output folder (default ./icons)')
    a = ap.parse_args(argv)

    pack = os.path.abspath(os.path.expanduser(a.pack))
    if not os.path.isdir(pack):
        print('no such pack folder:', pack)
        return 1
    mapping = json.load(open(a.mapping))
    idx = index_pack(pack)
    os.makedirs(a.out, exist_ok=True)
    bad = 0
    for slug, name in mapping.items():
        assert re.fullmatch(r'[a-z0-9_]+', slug), f'bad slug {slug!r}: use lowercase a-z 0-9 _'
        hit = find(pack, idx, name, a.prefer)
        if not hit:
            print('MISSING', slug, repr(name))
            bad += 1
            continue
        im = Image.open(hit).convert('RGBA')
        if a.size:
            im.thumbnail((a.size, a.size), Image.LANCZOS)
            canvas = Image.new('RGBA', (a.size, a.size), (0, 0, 0, 0))
            canvas.paste(im, ((a.size - im.width) // 2, (a.size - im.height) // 2))
            im = canvas
        im.save(os.path.join(a.out, slug + '.png'))
    print(len(mapping) - bad, f'copied to ./{a.out},', bad, 'missing')
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
