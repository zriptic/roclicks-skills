#!/usr/bin/env python3
"""Offline mock of the Roblox GUI: re-render the generated Data_<Screen>.luau trees (exactly what
Builder.luau instantiates) as HTML that follows ROBLOX semantics, so the conversion can be checked
without Studio (Studio playtest captures can come back magenta; edit-mode captures show no GUI).

Usage (from the project's UI folder, preview server running):
    python3 $SK/scripts/mock.py          -> rbx/out/mock/<Screen>.html
    node    $SK/scripts/mockshot.mjs     -> renders page vs mock, prints scores

Semantics modelled: AnchorPoint + UDim2 (scale+offset), UIScale, UICorner, UIStroke Border (inner/outer)
and Contextual (text), UIGradient (multiplies the base colour), ImageColor3 tint, ImageTransparency,
ScaleType Fit/Stretch/Tile, TextSize = line height (CSS font-size = TextSize / 1.215), Visible.
Healthy scores: mean abs diff 1-3 /255 per screen (text rounding and font hinting make up the rest).
"""
import base64
import html
import json
import os

CFG = json.load(open('rbx.json'))
SRC = os.path.abspath(CFG.get('luau_out', 'rbx/luau'))
OUT = os.path.join('rbx', 'out', 'mock')
os.makedirs(OUT, exist_ok=True)
SW, SH = CFG.get('design', [1920, 1080])
FONT_FIX = 1.215
CSS_FONT = {'Montserrat': "'Montserrat'", 'SourceSansPro': "'Source Sans 3'", 'FredokaOne': "'Fredoka One'",
            'Bangers': "'Bangers'", 'Oswald': "'Oswald'", 'RobotoCondensed': "'Roboto Condensed'"}


def data(name):
    s = open(os.path.join(SRC, f'Data_{name}.luau')).read()
    return json.loads(s[s.index('[==[') + 4:s.rindex(']==]')])


def rgba(c, a=1.0):
    return f'rgba({c[0]:.0f},{c[1]:.0f},{c[2]:.0f},{max(0, min(1, a)):.3f})'


_URI = {}


def src(img):  # inlined as data URIs: headless Chrome drops http images at random
    kind, name = img.split(':', 1)
    f = os.path.join('icons', name + '.png') if kind == 'icon' else os.path.join('rbx', 'out', 'upload', name + '.png')
    if f not in _URI:
        _URI[f] = 'data:image/png;base64,' + base64.b64encode(open(f, 'rb').read()).decode() if os.path.exists(f) else ''
    return _URI[f]


def grad_css(g, base=(255, 255, 255), base_a=1.0):
    trs = {round(p, 4): v for p, v in g.get('tr', [])}
    stops = []
    for p, r, gg, b in g['c']:
        a = base_a * (1 - trs.get(round(p, 4), 0))
        stops.append(f'{rgba((r * base[0] / 255, gg * base[1] / 255, b * base[2] / 255), a)} {p * 100:.2f}%')
    return f"linear-gradient({g.get('rot', 90) + 90}deg, {', '.join(stops)})"


def node(d, pw, ph):
    if d.get('visible') is False:
        return ''
    w = (d.get('sw') or 0) * pw + (d.get('w') or 0)
    h = (d.get('sh') or 0) * ph + (d.get('h') or 0)
    if d.get('fill'):
        w, h = pw, ph
    x = (d.get('sx') or 0) * pw + (d.get('x') or 0) - (d.get('ax') or 0) * w
    y = (d.get('sy') or 0) * ph + (d.get('y') or 0) - (d.get('ay') or 0) * h
    if d.get('fill'):
        x = y = 0
    st = [f'left:{x:.2f}px', f'top:{y:.2f}px', f'width:{w:.2f}px', f'height:{h:.2f}px']
    tf = []
    if d.get('rot'):
        tf.append(f"rotate({d['rot']}deg)")
    if d.get('scale'):
        tf.append(f"scale({d['scale']})")
        st.append('transform-origin:0 0')
    if tf:
        st.append('transform:' + ' '.join(tf))
    if d.get('corner'):
        c = d['corner']
        st.append(f"border-radius:{c['s'] * min(w, h) if 's' in c else c['o']:.2f}px")
    if d.get('clip'):
        st.append('overflow:hidden')
    inner = ''
    if d.get('bg') is not None:
        a = 1 - d.get('bt', 0)
        st.append(f"background:{grad_css(d['grad'], d['bg'], a)}" if d.get('grad') else f"background:{rgba(d['bg'], a)}")
    if d.get('stroke') and d['stroke'].get('mode') == 'Border':
        s = d['stroke']
        st.append(f"box-shadow:{'inset ' if s.get('pos') == 'Inner' else ''}0 0 0 {s['t']}px {rgba(s['c'], 1 - s.get('tr', 0))}")
    if d['c'] in ('ImageLabel', 'ImageButton') and d.get('img'):
        u = src(d['img'])
        stype = d.get('st', 'Fit')
        a = 1 - d.get('it', 0)
        size = 'contain' if stype == 'Fit' else ('100% 100%' if stype == 'Stretch' else f"{d['tile'][0]}px {d['tile'][1]}px")
        rep = 'repeat' if stype == 'Tile' else 'no-repeat'
        pos = '0 0' if stype == 'Tile' else 'center'
        ic = d.get('ic')
        if ic and tuple(ic) != (255, 255, 255):
            inner += (f"<i style='position:absolute;inset:0;background:{rgba(ic)};opacity:{a:.3f};"
                      f"-webkit-mask:url({u}) {pos}/{size} {rep}'></i>")
        else:
            inner += f"<i style='position:absolute;inset:0;opacity:{a:.3f};background:url({u}) {pos}/{size} {rep}'></i>"
    if d['c'] == 'TextLabel':
        fs = d['ts'] / FONT_FIX
        fam = CSS_FONT.get(d.get('font'), "'Montserrat'")
        al = {'L': 'flex-start', 'R': 'flex-end', 'C': 'center'}[d.get('xa', 'L')]
        t = html.escape(d['txt'])
        base = (f"position:absolute;inset:0;display:flex;align-items:center;justify-content:{al};white-space:pre;"
                f"font-family:{fam};font-weight:{d.get('wt', 800)};font-size:{fs:.2f}px;line-height:1")
        if d.get('stroke'):
            s = d['stroke']
            inner += f"<span style=\"{base};color:{rgba(s['c'])};-webkit-text-stroke:{2 * s['t']:.2f}px {rgba(s['c'])}\">{t}</span>"
        tc = d.get('tc', [255, 255, 255])
        fill = (f"background:{grad_css(d['grad'], tc)};-webkit-background-clip:text;color:transparent" if d.get('grad')
                else f'color:{rgba(tc)}')
        inner += f"<span style=\"{base};{fill}\">{t}</span>"
    kids = ''.join(node(k, w, h) for k in d.get('k', []))
    return f"<div class='n' style='{';'.join(st)}'>{inner}{kids}</div>"


def page(screens, dim):
    body = ''
    if dim:
        body += f"<div class='n' style='left:0;top:0;width:{SW}px;height:{SH}px;background:rgba(0,8,12,{dim})'></div>"
    for s in screens:
        d = data(s)
        d['visible'] = True
        body += node(d, SW, SH)
    return ("<!doctype html><html><head><meta charset='utf-8'>"
            "<link href='https://fonts.googleapis.com/css2?family=Montserrat:wght@700;800;900&family=Source+Sans+3:wght@600;700&family=Fredoka+One&display=block' rel='stylesheet'>"
            f"<style>*{{margin:0;padding:0;box-sizing:border-box}} body{{width:{SW}px;height:{SH}px;overflow:hidden;position:relative;"
            f"background:transparent}} .n{{position:absolute}}</style></head><body>{body}</body></html>")


if __name__ == '__main__':
    man = data('Manifest')
    pages = {}
    for sc in CFG['screens']:
        pages[sc['name']] = sc['page']
        parts = [sc['name']]
        open(os.path.join(OUT, sc['name'] + '.html'), 'w').write(page(parts, data(sc['name']).get('attrs', {}).get('Dim', 0)))
    json.dump(pages, open(os.path.join(OUT, 'pages.json'), 'w'))
    print('wrote', len(pages), 'mock pages to', OUT)
