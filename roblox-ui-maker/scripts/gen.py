#!/usr/bin/env python3
"""HTML -> Roblox, step 2 of 4: turn the export (rbx/out/*.json + raw PNGs) into Roblox GUI data.

Usage (run from the project's UI folder, after export.mjs):
    python3 $SK/scripts/gen.py

Reads  rbx.json (see PIPELINE.md), rbx/out/<page>.json, rbx/out/raw/<page>_<rid>.png
Writes rbx/out/upload/<key>.png     unique art, deduped by content (key = 'a' + md5 prefix, stable
                                    across re-exports); wide stud plates are 3-sliced
       rbx/out/upload_list.json     every art key + every icon slug the data references
       <luau_out>/Data_<Screen>.luau one JSON tree per screen  (return [==[ json ]==])
       <luau_out>/Data_Templates.luau  runtime templates (if rbx.json lists template pages)
       <luau_out>/Data_Manifest.luau   gui name, design size, screen order (read by Builder.luau)
Image fields are keys ("art:<key>", "icon:<slug>") that Builder resolves through AssetIds.luau.

Conversion rules live in PIPELINE.md ("CSS -> Roblox mapping"). The important ones:
  TextSize = CSS font-size * 1.215 (Roblox TextSize is line height); TextSize > 100 -> UIScale wrapper
  outlined text -> TextLabel + UIStroke (half the CSS stroke) + "<Name>Shadow" twin for the drop
  opacity:0 / class "hid" -> Visible=false (exists for runtime toggling)
  images > 1024 px: stud plates 3-slice on the stud period, anything else is shrunk to fit
"""
import hashlib
import json
import math
import os
import re
import sys

import numpy as np
from PIL import Image

CFG = json.load(open('rbx.json'))
OUT = os.path.abspath(os.path.join('rbx', 'out'))
RAW = os.path.join(OUT, 'raw')
UP = os.path.join(OUT, 'upload')
SRC = os.path.abspath(CFG.get('luau_out', 'rbx/luau'))
os.makedirs(UP, exist_ok=True)
os.makedirs(SRC, exist_ok=True)
SW, SH = CFG.get('design', [1920, 1080])
FONT_FIX = 1.215   # Roblox TextSize is line height; CSS font-size is the em
S = 2              # raster capture scale (export.mjs shoots at 2x)
MAXPX = 1024       # Roblox caps uploaded images at 1024 px per side

# CSS family -> Roblox font family file (rbxasset://fonts/families/<X>.json). Verify a new one in
# Studio first: Font.new("rbxasset://fonts/families/X.json") on a TextLabel, check TextBounds > 0.
FONTS = {
    'Montserrat': 'Montserrat', 'Fredoka One': 'FredokaOne', 'Fredoka': 'FredokaOne',
    'Source Sans 3': 'SourceSansPro', 'Source Sans Pro': 'SourceSansPro', 'Bangers': 'Bangers',
    'Oswald': 'Oswald', 'Roboto Condensed': 'RobotoCondensed', 'Roboto': 'Roboto',
    'Permanent Marker': 'PermanentMarker', 'Luckiest Guy': 'LuckiestGuy', 'Press Start 2P': 'PressStart2P',
    'Nunito': 'Nunito', 'Titillium Web': 'TitilliumWeb', 'Ubuntu': 'Ubuntu', 'Arimo': 'Arimo',
    'Kalam': 'Kalam', 'Jura': 'Jura', 'Gotham': 'GothamSSm',
}
_warned = set()


def font_of(ff):
    f = CFG.get('font_map', {}).get(ff) or FONTS.get(ff)   # rbx.json "font_map" overrides, e.g. {"Montserrat": "GothamSSm"}
    if not f:
        if ff not in _warned:
            print(f'WARN font {ff!r} has no Roblox mapping: using Montserrat (add it to FONTS in gen.py)')
            _warned.add(ff)
        f = 'Montserrat'
    return f


def load(page):
    p = os.path.join(OUT, page + '.json')
    if not os.path.exists(p):
        sys.exit(f'missing {p}: run export.mjs for page {page!r} first')
    return json.load(open(p))


def find_group(tree, name):
    for g in tree:
        if g['k'] == 'group' and g['n'] == name:
            return g
    raise KeyError(f'group {name!r} not found (grp(name, ...) in the page?)')


# ------------------------------------------------------------------ art registry
ART = {}
ICONS = set()
_seen = []


def _same(a, b):
    if a.shape != b.shape:
        return False
    d = np.abs(a.astype(np.int16) - b.astype(np.int16))
    return d.mean() < 1.2 and (d.max(axis=2) > 28).mean() < 0.004


def art_key(img):
    """Fuzzy dedupe (identical-looking captures share one upload) + content-hash name."""
    a = np.asarray(img.convert('RGBA'))
    for b, k in _seen:
        if _same(a, b):
            return k
    k = 'a' + hashlib.md5(a.tobytes()).hexdigest()[:10]
    _seen.append((a, k))
    img.save(os.path.join(UP, k + '.png'))
    ART[k] = dict(w=img.width, h=img.height)
    return k


def raster_art(page, node):
    """Art children (absolute coords) for a raster node: one image, or L / tiled middle / R slices."""
    img = Image.open(os.path.join(RAW, f"{page}_{node['rid']}.png")).convert('RGBA')
    x, y, w, h = node['r']
    ml, mt, mr, mb = node.get('m') or [0, 0, 0, 0]
    fx, fy, fw, fh = x - ml, y - mt, w + ml + mr, h + mt + mb
    st = node.get('stud')
    if img.width <= MAXPX and img.height <= MAXPX:
        return [dict(c='ImageLabel', n='Art', X=fx, Y=fy, w=fw, h=fh, img='art:' + art_key(img), st='Stretch')]
    if not st or img.height > MAXPX or w < 3 * st['P']:
        k = MAXPX / max(img.width, img.height)   # not slicable: shrink (slightly softer, never wrong)
        small = img.resize((round(img.width * k), round(img.height * k)), Image.LANCZOS)
        return [dict(c='ImageLabel', n='Art', X=fx, Y=fy, w=fw, h=fh, img='art:' + art_key(small), st='Stretch')]
    P, x0 = st['P'], st['x0']
    cap = 48
    a = x0 + math.ceil((cap - x0) / P) * P      # left cap ends on a stud period boundary
    n = int((w - a - cap) // P)
    b = a + n * P

    def crop(u0, u1):
        return img.crop((round((ml + u0) * S), 0, round((ml + u1) * S), img.height))
    L = art_key(crop(-ml, a)); T = art_key(crop(a, a + P)); R = art_key(crop(b, w + mr))
    return [dict(c='ImageLabel', n='ArtL', X=fx, Y=fy, w=a + ml, h=fh, img='art:' + L, st='Stretch'),
            dict(c='ImageLabel', n='ArtT', X=x + a, Y=fy, w=n * P, h=fh, img='art:' + T, st='Tile', tile=[P, fh]),
            dict(c='ImageLabel', n='ArtR', X=x + b, Y=fy, w=w + mr - b, h=fh, img='art:' + R, st='Stretch')]


# ------------------------------------------------------------------ helpers
def col(c): return [round(c[0]), round(c[1]), round(c[2])] if c else [255, 255, 255]
def alpha(c): return c[3] if c and len(c) > 3 else 1


def slug(t, n=24):
    s = re.sub(r'[^A-Za-z0-9]+', ' ', t or '').title().replace(' ', '')
    return s[:n] or 'X'


# GuiObject property names: a child named like one shadows it ("tabs.TabBuy.Active" returned the
# boolean property). Exported names that collide get an "N" prefix.
PROPS = {'Active', 'Visible', 'Position', 'Size', 'Name', 'Parent', 'Selected', 'Rotation', 'ZIndex',
         'Text', 'Image', 'Transparency', 'BackgroundColor3', 'AnchorPoint', 'LayoutOrder', 'ClassName'}


def safe(name):
    if name in PROPS:
        if name not in _warned:
            print(f'WARN element named {name!r} collides with a GuiObject property: exported as N{name}. Rename it in the HTML (e.g. ItemName).')
            _warned.add(name)
        return 'N' + name
    return name


def seq(stops, rot):
    """CSS stops [[pos, rgba]] -> UIGradient dict with strictly increasing keypoints (max 20)."""
    pts = [[min(1, max(0, p)), c] for p, c in stops]
    if pts[0][0] > 0:
        pts.insert(0, [0, pts[0][1]])
    if pts[-1][0] < 1:
        pts.append([1, pts[-1][1]])
    out, last = [], -1
    for p, c in pts:
        if p <= last:
            p = last + 0.001
        out.append([p, c])
        last = p
    if out[-1][0] > 1:
        m = out[-1][0]
        out = [[p / m, c] for p, c in out]
    out = out[:20]
    g = dict(rot=rot, c=[[round(p, 4)] + col(c) for p, c in out])
    if any(alpha(c) < 1 for _, c in out):
        g['tr'] = [[round(p, 4), round(1 - alpha(c), 3)] for p, c in out]
    return g


def dimmed(c, dim):
    if not dim:
        return c
    b, s = dim
    r, g, bb = c[:3]
    lum = .299 * r + .587 * g + .114 * bb
    return [(lum + (v - lum) * s) * b for v in (r, g, bb)] + list(c[3:])


def corner(rad, grow=0):
    if not rad:
        return None
    if 's' in rad:
        return dict(s=rad['s'])
    o = rad.get('o', 0) + grow
    return dict(o=round(o, 2)) if o > 0 else None


def hide(nodes, n):
    if n.get('op', 1) == 0:
        for x in nodes:
            x['visible'] = False
    return nodes


# ------------------------------------------------------------------ conversion
class Conv:
    def __init__(self, page):
        self.page = page
        self.inbtn = 0   # inside a button sub: plates are looks, not buttons of their own

    def text(self, t):
        x, y, w, h = t['r']
        ts = t['fs'] * FONT_FIX * t['sq']
        H = t['fs'] * FONT_FIX
        cy = y + h / 2
        base = dict(c='TextLabel', txt=re.sub(r'\s+', ' ', t['t'] or '').strip(),  # HTML collapses spaces; Roblox draws them all
                    font=font_of(t.get('ff', 'Montserrat')), wt=t['wt'], xa=t['al'])
        name = safe(t.get('n') or ('T_' + slug(t['t'])))
        nodes = []
        oc = col(dimmed(t['oc'], t['dim'])) if t.get('oc') else [18, 18, 18]
        stroke = dict(t=round(t['sw'] / 2, 2), c=oc, join='Round', mode='Contextual') if t['sw'] > 0 else None

        def label(nm, color, dy, grad):
            n = dict(base, n=nm, X=x, Y=cy - H / 2 + dy, w=max(w, 1), h=H, ts=ts, tc=color)
            if stroke:
                n['stroke'] = stroke
            if grad:
                n['grad'] = grad
            return n
        if t['sw'] > 0 and t['dy'] > 0:   # the drop shadow is a twin label offset down
            nodes.append(label(name + 'Shadow', oc, t['dy'], None))
        grad = None
        if t.get('fill'):
            lh = t['lh']
            stops = [[(p * lh + (H - lh) / 2) / H, dimmed(c, t['dim'])] for p, c in t['fill']]
            grad = seq(stops, 90)
            color = [255, 255, 255]
        else:
            color = col(dimmed(t['color'], t['dim']))
        nodes.append(label(name, color, 0, grad))
        hide(nodes, t)
        if ts > 100:  # TextSize caps at 100: draw at <=100 inside a UIScale wrapper
            f = ts / 100
            X0 = min(n['X'] for n in nodes); Y0 = min(n['Y'] for n in nodes)
            X1 = max(n['X'] + n['w'] for n in nodes); Y1 = max(n['Y'] + n['h'] for n in nodes)
            inner = []
            for n in nodes:
                n2 = dict(n, X=X0 + (n['X'] - X0) / f, Y=Y0 + (n['Y'] - Y0) / f, w=n['w'] / f, h=n['h'] / f, ts=n['ts'] / f)
                if 'stroke' in n2:
                    n2['stroke'] = dict(n2['stroke'], t=n2['stroke']['t'] / f)
                inner.append(n2)
            return [dict(c='Frame', n=name + 'Big', X=X0, Y=Y0, w=(X1 - X0) / f, h=(Y1 - Y0) / f, scale=f, k=inner)]
        return nodes

    def icon(self, i):
        x, y, w, h = i['r']
        if not i.get('icon'):
            return []
        ICONS.add(i['icon'])
        nm = safe(i.get('n') or ('I_' + i['icon']))
        out = []
        if i.get('sh'):
            s = i['sh']
            out.append(dict(c='ImageLabel', n=nm + 'Shadow', X=x + s['x'], Y=y + s['y'], w=w, h=h, img='icon:' + i['icon'],
                            ic=col(s['c']), it=round(1 - alpha(s['c']), 3), st='Fit'))
        main = dict(c='ImageLabel', n=nm, X=x, Y=y, w=w, h=h, img='icon:' + i['icon'], st='Fit')
        if i.get('tint') is not None:
            v = round(255 * min(1, i['tint']))
            main['ic'] = [v, v, v]
        out.append(main)
        return hide(out, i)

    def raster(self, r, btn=None):
        x, y, w, h = r['r']
        if r.get('n'):
            nm = r['n']
        elif r.get('why') == 'filtered-icon':
            nm = 'I_locked'
        elif r.get('close'):
            nm = 'CloseButton'
        elif r.get('head'):
            nm = 'Header'
        else:
            first = next((c for c in r.get('ch', []) if c['k'] == 'text'), None)
            nm = 'Btn' + slug(first['t']) if first else ('Shape' if r.get('why') == 'svg' else 'Plate')
        if btn is None:
            btn = (bool(r.get('plate')) and not r.get('head') and not self.inbtn) or bool(r.get('btn')) or bool(r.get('close'))
        node = dict(c='TextButton' if btn else 'Frame', n=safe(nm), X=x, Y=y, w=w, h=h, k=raster_art(self.page, r))
        if r.get('tint'):
            hx = r['tint'].lstrip('#')
            tc = [int(hx[i:i + 2], 16) for i in (0, 2, 4)]
            for a in node['k']:
                a['ic'] = tc
        for c in r.get('ch', []):
            node['k'] += self.conv(c)
        attrs = dict(r.get('attrs') or {})
        if btn:
            attrs['Button'] = True
        if attrs:
            node['attrs'] = attrs
        return hide([node], r)

    def frame(self, f):
        x, y, w, h = f['r']
        cls = f.get('cls', '')
        nm = f.get('n')
        if not nm:
            for k in ('panel', 'glass', 'inset', 'tile', 'row', 'card', 'bar', 'badge', 'chip', 'pill'):
                if re.search(r'\b%s\b' % k, cls):
                    nm = k.capitalize()
                    break
            else:
                nm = 'F'
        g = f.get('grad')
        bg = f.get('bg')
        if g and g['type'] == 'conic':   # cooldown wedge: two clipped halves, see Builder.cooldown
            stops = g['stops']
            frac = next((p for p, c in stops[1:] if alpha(c) != alpha(stops[0][1])), stops[-1][0])
            return [dict(c='Frame', n='Cooldown', X=x, Y=y, w=w, h=h, clip=True, attrs={'Frac': round(frac, 4)},
                         cool=dict(c=col(stops[0][1]), tr=round(1 - alpha(stops[0][1]), 3)), corner=corner(f.get('rad')))]
        if g and g['type'] == 'radial':   # soft glow -> glow image tinted with the first stop
            ART['glow'] = dict(w=256, h=256)
            c0 = g['stops'][0][1]
            return hide([dict(c='ImageLabel', n=safe(nm if f.get('n') else 'Glow'), X=x, Y=y, w=w, h=h, img='art:glow',
                              st='Stretch', ic=col(c0), it=round(1 - alpha(c0), 3))], f)
        node = dict(c='TextButton' if f.get('btn') else 'Frame', n=safe(nm), X=x, Y=y, w=w, h=h, rot=round(f.get('rot') or 0, 2))
        attrs = dict(f.get('attrs') or {})
        if f.get('btn'):
            attrs['Button'] = True
        if attrs:
            node['attrs'] = attrs
        opaque = False
        if g:
            node['bg'] = [255, 255, 255]
            node['bt'] = 0
            node['grad'] = seq(g['stops'], g['angle'] - 90)
            opaque = all(alpha(c) >= 1 for _, c in g['stops'])
        elif bg:
            node['bg'] = col(bg)
            node['bt'] = round(1 - alpha(bg), 3)
            opaque = alpha(bg) >= 1
        cr = corner(f.get('rad'))
        if cr:
            node['corner'] = cr
        bw = f.get('bw', 0)
        if bw and f.get('bs') != 'dashed':
            node['stroke'] = dict(t=round(bw, 2), c=col(f['bc']), tr=round(1 - alpha(f['bc']), 3), pos='Inner', mode='Border')
        if f.get('clip'):
            node['clip'] = True
        before, kids, after = [], [], []
        r_o = (f.get('rad') or {}).get('o', 0)
        for s in f.get('sh', []):
            c = s['c']
            if not s['inset']:
                if s['blur'] > 0:
                    continue   # blurred shadows are dropped (bake them into a raster if they matter)
                if not opaque and s['x'] == 0 and s['y'] == 0 and s['spread'] > 0:
                    # CSS never paints an outer shadow under the box: on see-through glass it is a ring
                    before.append(dict(c='Frame', n='ShadowRing', X=x, Y=y, w=w, h=h, corner=cr,
                                       stroke=dict(t=round(s['spread'], 2), c=col(c), tr=round(1 - alpha(c), 3), pos='Outer', mode='Border')))
                elif not opaque and s['y'] > 0 and s['x'] == 0 and s['spread'] == 0:
                    # y-offset shadow under glass -> a clipped crescent below the box only
                    before.append(dict(c='Frame', n='DropShadow', X=x, Y=y + h, w=w, h=s['y'], clip=True, k=[
                        dict(c='Frame', n='Shape', X=x, Y=y + s['y'], w=w, h=h, bg=col(c), bt=round(1 - alpha(c), 3), corner=cr)]))
                else:
                    sp = s['spread']
                    before.append(dict(c='Frame', n='DropShadow', X=x + s['x'] - sp, Y=y + s['y'] - sp, w=w + 2 * sp, h=h + 2 * sp,
                                       bg=col(c), bt=round(1 - alpha(c), 3), corner=corner(f.get('rad'), sp)))
            else:
                ri = max(0, r_o - bw)
                if s['x'] == 0 and s['y'] == 0 and s['spread'] > 0:
                    kids.append(dict(c='Frame', n='InnerRing', X=x + bw, Y=y + bw, w=w - 2 * bw, h=h - 2 * bw,
                                     corner=dict(o=ri) if ri else (cr if isinstance(cr, dict) and 's' in cr else None),
                                     stroke=dict(t=round(s['spread'], 2), c=col(c), tr=round(1 - alpha(c), 3), pos='Inner', mode='Border')))
                elif s['y'] != 0:
                    band = abs(s['y'])
                    inset = ri * 0.6
                    yy = y + bw if s['y'] > 0 else y + h - bw - band
                    kids.append(dict(c='Frame', n='InnerShade', X=x + bw + inset, Y=yy, w=w - 2 * bw - 2 * inset, h=band,
                                     bg=col(c), bt=round(1 - alpha(c), 3)))
        if f.get('outline'):
            o = f['outline']
            after.append(dict(c='Frame', n='Outline', X=x - o['off'], Y=y - o['off'], w=w + 2 * o['off'], h=h + 2 * o['off'],
                              corner=corner(f.get('rad'), o['off']),
                              stroke=dict(t=o['w'], c=col(o['c']), tr=round(1 - alpha(o['c']), 3), pos='Outer', mode='Border')))
        for c in f.get('ch', []):
            kids += self.conv(c)
        node['k'] = kids
        out = before + [node] + after
        return hide(out, f)

    def svgline(self, ln):
        x1, y1, x2, y2 = ln['p']
        L = math.hypot(x2 - x1, y2 - y1)
        sw = ln['sw']
        cap = sw if ln.get('cap') == 'round' else 0
        cx, cy = (x1 + x2) / 2, (y1 + y2) / 2
        w = L + cap
        n = dict(c='Frame', n=safe(ln.get('n') or 'Line'), X=cx - w / 2, Y=cy - sw / 2, w=w, h=sw,
                 rot=round(math.degrees(math.atan2(y2 - y1, x2 - x1)), 2), bg=col(ln['c']), bt=round(1 - alpha(ln['c']), 3))
        if cap:
            n['corner'] = dict(s=0.5)
        return [n]

    def conv(self, n):
        k = n['k']
        if k == 'group':   # nested group (a component inside a template): just its contents
            return [c2 for c in n['ch'] for c2 in self.conv(c)]
        if k == 'text':
            return self.text(n)
        if k == 'icon':
            return self.icon(n)
        if k == 'raster':
            return self.raster(n)
        if k == 'frame':
            return self.frame(n)
        if k == 'line':
            return self.svgline(n)
        if k == 'sub':
            self.inbtn += 1 if n.get('btn') else 0
            kids = [c2 for c in n['ch'] for c2 in self.conv(c)]
            self.inbtn -= 1 if n.get('btn') else 0
            X0, Y0, X1, Y1 = bbox(kids)
            node = dict(c='TextButton' if n.get('btn') else 'Frame', n=safe(n['n']), X=X0, Y=Y0, w=X1 - X0, h=Y1 - Y0, k=kids)
            attrs = dict(n.get('attrs') or {})
            if n.get('btn'):
                attrs['Button'] = True
            if attrs:
                node['attrs'] = attrs
            return hide([node], n)
        raise ValueError(k)


def bbox(nodes):
    xs = [(n['X'], n['Y'], n['X'] + n['w'], n['Y'] + n['h']) for n in nodes if not n.get('fill')]
    if not xs:
        return 0, 0, SW, SH
    return min(a[0] for a in xs), min(a[1] for a in xs), max(a[2] for a in xs), max(a[3] for a in xs)


def relativize(nodes, ox, oy):
    """Absolute stage px -> px relative to the parent node."""
    for n in nodes:
        X, Y = n.pop('X'), n.pop('Y')
        n['x'] = round(X - ox, 2)
        n['y'] = round(Y - oy, 2)
        n['w'] = round(n['w'], 2)
        n['h'] = round(n['h'], 2)
        if n.get('fill'):
            n['x'] = n['y'] = 0
        if 'ts' in n:
            n['ts'] = round(n['ts'], 2)
        for key in [k for k, v in n.items() if v is None or (k == 'rot' and v == 0)]:
            n.pop(key)
        if n.get('k'):
            relativize(n['k'], X, Y)
        elif 'k' in n:
            n.pop('k')


def widen(nodes, pw):
    """Named (runtime-set) labels get the room their parent allows, so longer live text keeps the
    design size instead of overflowing. FitW keeps the design width for Builder.fit."""
    for n in nodes:
        nm = n.get('n') or ''
        if n.get('c') == 'TextLabel' and nm and not nm.startswith('T_') and pw and pw > 0:
            x, w = n['x'], n['w']
            n.setdefault('attrs', {})['FitW'] = w
            if n.get('xa') == 'L':
                n['w'] = round(max(w, pw - x - 10), 2)
            elif n.get('xa') == 'R':
                right = x + w
                n['x'] = round(min(x, 10), 2)
                n['w'] = round(max(w, right - n['x']), 2)
            else:
                cx = x + w / 2
                half = min(cx, pw - cx) - 8
                if half * 2 > w:
                    n['x'] = round(cx - half, 2)
                    n['w'] = round(2 * half, 2)
        if n.get('k'):
            cw = n.get('w') or 0
            if n.get('sw'):
                cw = SW
            widen(n['k'], cw if cw > 0 else pw)


ANCH = {'TL': (0, 0), 'T': (.5, 0), 'TR': (1, 0), 'L': (0, .5), 'C': (.5, .5), 'R': (1, .5),
        'BL': (0, 1), 'B': (.5, 1), 'BR': (1, 1)}


def group_node(name, anchor, kids):
    """A grp() becomes a frame anchored to a screen edge/corner: it keeps its design distance from
    that edge on any screen shape (the root is resized to the viewport at runtime)."""
    anchor = anchor or 'C'
    if anchor == 'FILL':
        for n in kids:
            if abs(n['X']) < 1 and abs(n['Y']) < 1 and abs(n['w'] - SW) < 2 and abs(n['h'] - SH) < 2:
                n['fill'] = True
        relativize(kids, 0, 0)
        return dict(c='Frame', n=name, x=0, y=0, w=0, h=0, sw=1, sh=1, k=kids)
    if anchor not in ANCH:
        sys.exit(f'group {name}: unknown anchor {anchor!r} (use TL T TR L C R BL B BR FILL)')
    X0, Y0, X1, Y1 = bbox(kids)
    ax, ay = ANCH[anchor]
    px = X0 + (X1 - X0) * ax - SW * ax
    py = Y0 + (Y1 - Y0) * ay - SH * ay
    relativize(kids, X0, Y0)
    return dict(c='Frame', n=name, x=round(px, 2), y=round(py, 2), sx=ax, sy=ay, ax=ax, ay=ay,
                w=round(X1 - X0, 2), h=round(Y1 - Y0, 2), k=kids, attrs={'Anchor': anchor})


def dim_alpha(tree):
    try:
        g = find_group(tree, 'Dim')
        return alpha(g['ch'][0].get('bg'))
    except (KeyError, IndexError):
        return 0


def write(name, data, label):
    js = json.dumps(data, separators=(',', ':'))
    assert ']==]' not in js
    open(os.path.join(SRC, f'Data_{name}.luau'), 'w').write(
        f'-- generated by roblox-ui-maker/scripts/gen.py from {label} (do not edit; edit the HTML and re-run)\n'
        f'return [==[{js}]==]\n')


def count(n):
    return 1 + sum(count(c) for c in n.get('k', []))


def main():
    screens = []
    for sc in CFG.get('screens', []):
        tree = load(sc['page'])
        gnodes = []
        for gname in sc['groups']:
            if isinstance(gname, dict):   # a group borrowed from another page
                g = find_group(load(gname['page']), gname['group'])
                gn = group_node(gname['group'], g['a'], [k for c in g['ch'] for k in Conv(gname['page']).conv(c)])
                if gname.get('visible') is False:
                    gn['visible'] = False
                gnodes.append(gn)
                continue
            g = find_group(tree, gname)
            gnodes.append(group_node(gname, g['a'], [k for c in g['ch'] for k in Conv(sc['page']).conv(c)]))
        data = dict(c='Frame', n=sc['name'], x=0, y=0, w=0, h=0, sw=1, sh=1, k=gnodes,
                    visible=bool(sc.get('visible')), attrs={'Dim': sc.get('dim', dim_alpha(tree))})
        widen(data['k'], SW)
        write(sc['name'], data, f"{sc['page']}.html")
        screens.append(dict(name=sc['name'], hud=bool(sc.get('hud')), visible=bool(sc.get('visible'))))
        print(f"screen {sc['name']:14s} {count(data):5d} instances")
    temps = []
    for page in CFG.get('templates', []):
        conv = Conv(page)
        for g in load(page):
            if g['k'] != 'group':
                continue
            kids = [k for c in g['ch'] for k in conv.conv(c)]
            if not kids:
                continue
            X0, Y0, X1, Y1 = bbox(kids)
            relativize(kids, X0, Y0)
            temps.append(dict(c='Frame', n=g['n'], x=0, y=0, w=round(X1 - X0, 2), h=round(Y1 - Y0, 2), k=kids))
    if temps:
        data = dict(c='Folder', n=CFG.get('templates_folder', CFG['gui'] + 'Templates'), k=temps)
        widen(temps, SW)
        write('Templates', data, ', '.join(CFG['templates']))
        print(f'templates {len(temps)}: ' + ', '.join(t['n'] for t in temps))
    manifest = dict(gui=CFG['gui'], templates=CFG.get('templates_folder', CFG['gui'] + 'Templates') if temps else None,
                    design=[SW, SH], screens=screens)
    write('Manifest', manifest, 'rbx.json')
    if 'glow' in ART:   # radial glow helper: white, alpha falling linearly to 0 at the edge
        n = 256
        yy, xx = np.mgrid[0:n, 0:n]
        d = np.hypot(xx - n / 2 + .5, yy - n / 2 + .5) / (n / 2)
        a = np.clip(1 - d, 0, 1)
        Image.fromarray(np.dstack([np.full((n, n), 255)] * 3 + [a * 255]).astype(np.uint8)).save(os.path.join(UP, 'glow.png'))
    json.dump(dict(art=sorted(ART), icons=sorted(ICONS)), open(os.path.join(OUT, 'upload_list.json'), 'w'), indent=1)
    print(f'art {len(ART)} unique images, icons {len(ICONS)} -> rbx/out/upload_list.json; Data_*.luau -> {SRC}')
    print('Next: python3 .../scripts/ledger.py 20   (lists what still needs uploading)')


if __name__ == '__main__':
    main()
