# REFERENCE EXAMPLE of a 1:1 remake builder (from an earlier project; not runnable as-is: it expects that
# project's ref.png, icons/ and tex/ files). Copy its STRUCTURE for a new remake: shared plate() component,
# measured gradients/stud pitch, LABELS table for fit_text.py, ?raw / ?labels=KEY&bg= modes. See LESSONS.md 7.
"""Builds index.html: the Shop panel drawn FROM SCRATCH.

No pixels are taken from ref.png. It is only the measuring tape: every number
below (positions, gradient stops, stud pitch/shape, dividing curves, ray
angles) was measured from it. Icons come from the project's icon pack; text is live.

Run: python3 build.py
"""
from pathlib import Path
from urllib.parse import quote
import numpy as np

HERE = Path(__file__).parent


def lstud(P, vx, vy0, vy1, hy, hx1, stroke, color):
    """One stud tile: an 'L' (vertical bar at vx from vy0..vy1, foot along hy
    to hx1). Coordinates may run past P; the tile is drawn 3x3 so wrapped
    parts land correctly."""
    parts = []
    for ox in (-P, 0, P):
        for oy in (-P, 0, P):
            parts.append(f'<path d="M{vx+ox:.2f} {vy0+oy:.2f}V{hy+oy:.2f}H{hx1+ox:.2f}" '
                         f'fill="none" stroke="{color}" stroke-width="{stroke}" '
                         f'stroke-linecap="square"/>')
    svg = f'<svg xmlns="http://www.w3.org/2000/svg" width="{P}" height="{P}" viewBox="0 0 {P} {P}">{"".join(parts)}</svg>'
    return f"url('data:image/svg+xml,{quote(svg)}')"   # single quotes: also used inside style="..."


def square_stud(P, x, y, s, color):
    svg = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{P}" height="{P}" viewBox="0 0 {P} {P}">'
           f'<rect x="{x}" y="{y}" width="{s}" height="{s}" rx="1.5" fill="none" stroke="{color}" stroke-width="1.6"/></svg>')
    return f"url('data:image/svg+xml,{quote(svg)}')"   # single quotes: also used inside style="..."


def stud_bg(url, P, left, top):
    """background shorthand pieces so the tile grid sits on the reference's
    absolute stage grid (phase = stage coordinate mod P)."""
    return f"{url} {-(left % P):.2f}px {-(top % P):.2f}px / {P}px {P}px repeat"


def curve_path(pts, w, h, ox, oy, below=True):
    """Smooth closed path: the dividing curve through pts (stage coords, fitted
    from the reference), closed down (lower region) to the card bottom."""
    xs = np.array([p[0] for p in pts], float) - ox
    ys = np.array([p[1] for p in pts], float) - oy
    c = np.polyfit(xs, ys, 3)
    X = np.linspace(-2, w + 2, 60)
    Y = np.polyval(c, X)
    d = f"M{X[0]:.1f} {Y[0]:.1f}" + "".join(f"L{x:.1f} {y:.1f}" for x, y in zip(X[1:], Y[1:]))
    d += f"L{w+2} {h+2}L-2 {h+2}Z" if below else f"L{w+2} -2L-2 -2Z"
    return d


# ------------------------------------------------------------------ measured data
# Panel frame: black 5px outline, 5px/3px drop to the lower right, cream body
FRAME = dict(left=191, top=110, w=818, h=456)
CREAM = "#fdfcf0"
CREAM_STUD = lstud(21.2, 11.5, 7, 15.5, 15.5, 21, 1.7, "rgba(90,88,60,.30)")

HEADER_STOPS = [(0, "#00e2fb"), (4, "#01e1fd"), (8, "#02dcff"), (16, "#01d2ff"), (24, "#01cbfe"),
                (32, "#01bafd"), (40, "#00b5fe"), (48, "#00abfc"), (56, "#029bfe"), (64, "#0197fd"),
                (72, "#018afd"), (80, "#0279fd"), (85, "#0e76e6")]

CARDS = {
    # box = outer black edge (x0, y0, x1, y1); curve = fitted dividing line
    "vip": dict(box=(212, 217, 589, 363),
                upper=[(0, "#fde401"), (35, "#fec302"), (75, "#ffb502")],
                lower=[(0, "#ffc34e"), (30, "#fda04c"), (100, "#fc9c4d")],
                curve=[(222, 301.7), (262, 278.6), (302, 272.1), (342, 277.5), (382, 289.6),
                       (422, 303.5), (462, 314.4), (502, 317.1), (542, 306.8), (582, 278.5)],
                stud=(18.65, lstud(18.65, 17.5, 6, 14, 14, 25, 1.9, "rgba(120,50,0,.20)")),
                rays=dict(cx=298, cy=290, n=10, a=.10), glow=(298, 290, 70, .35)),
    "jump": dict(box=(611, 217, 988, 363),
                 upper=[(0, "#e609ff"), (40, "#d314f6"), (100, "#c81cf0")],
                 lower=[(0, "#be63f7"), (50, "#aa5af9"), (100, "#9b54fe")],
                 curve=[(621, 296.9), (661, 290.0), (701, 282.4), (741, 274.9), (781, 268.5),
                        (821, 264.1), (861, 262.9), (901, 265.6), (941, 273.4), (981, 287.2)],
                 stud=(18.65, lstud(18.65, 17.2, 5, 13, 13, 24, 1.9, "rgba(60,0,90,.20)")),
                 rays=dict(cx=686, cy=290, n=9, a=.16), glow=(686, 290, 60, .30)),
    "cash": dict(box=(212, 382, 988, 551),
                 upper=[(0, "#f6fe04"), (50, "#e0f805"), (100, "#ccfc07")],
                 lower=[(0, "#c2fe53"), (40, "#a1f84d"), (100, "#75f64d")],
                 curve=[(222, 511.8), (302, 489.4), (382, 473.6), (462, 463.8), (542, 459.1),
                        (622, 459.0), (702, 462.7), (782, 469.5), (862, 478.7), (942, 489.7), (982, 495.6)],
                 stud=(22.1, lstud(22.1, 9.5, 1, 8, 8, 19, 2.1, "rgba(70,90,0,.18)")),
                 beams=[(320, 468), (880, 440)]),
}

# faint cash bundles scattered on the 2X CASH card (placed from the reference)
DECOR = [(372, 402, 50, -12), (492, 397, 50, 10), (627, 402, 50, -8), (650, 420, 45, 14),
         (772, 402, 42, -15), (932, 397, 46, 8), (362, 482, 50, 12), (417, 482, 50, -10),
         (532, 487, 44, 6), (642, 477, 44, -14), (737, 497, 32, 10), (342, 422, 34, -6),
         (937, 457, 44, -10)]

TEXT_CSS = """
  /* Fill = measured vertical gradient of the reference letters (px from the
     element top); --band = the tinted band just inside the outline, drawn as a
     stroke on the fill layer (half of --bw lands inside the glyph). --sw is the
     measured outline + --bw, so the visible dark edge keeps its measured width. */
  #Title { left: 280px; top: 133px; font-size: 48.2px; --sx: .953; --sw: 6px; --sc: #000026; --sd: 2px;
           --fill: #fcfdfd; --band: #c8e6fa; --inset: url(#in15); }
  #CloseText { left: 943px; top: 132px; font-size: 51.4px; --sx: .9; --sw: 8px; --sc: #210000; --sd: 2px;
           --fill: #fefcfa; --band: #f6c8d1; --inset: url(#in15); }
  /* Titles are Montserrat ExtraBold (800): 900 is visibly heavier than the reference.
     Fills: white top half, measured per-row gradient from mid-letter down
     (stops = reference row y - element top). */
  #VipTitle  { left: 455px; top: 238px; font-size: 57.3px; --sx: 1.036; font-weight: 800; --sw: 7px; --sc: #140400; --sd: 5px;
           --fill: linear-gradient(#fefdfd 27.5px, #fefaeb 31.5px, #fdf5da 34.5px, #fdf0bd 38.5px, #feeaab 41.5px, #fde58f 45.5px, #fcdf7a 48.5px);
           --band: #f5e6b6; --inset: url(#in10); }
  #JumpTitle { left: 764px; top: 247.5px; font-size: 41px; --sx: 1.021; font-weight: 800; --sw: 6px; --sc: #0f0014; --sd: 3px;
           --fill: linear-gradient(#fcfdfc 18.5px, #f4f2fc 20.5px, #e9e4f9 22.5px, #dbcef9 24.5px, #cdb7f6 26.5px, #c3a4f5 28.5px, #b591f6 30.5px, #a572f6 33.5px);
           --band: #d4aaf4; --inset: url(#in12); }
  #CashTitle { left: 465px; top: 436px; font-size: 60px; --sx: 1.005; font-weight: 800; --sw: 6px; --sc: #0b0c00; --sd: 4px;
           --fill: linear-gradient(#fdfdfb 24px, #f6fef2 30px, #e5fddd 34px, #d4fcc8 37px, #c4fdb4 40px, #b9fea3 43px, #a6fd90 46px, #96fb76 49px);
           --band: #d2f6a2; --inset: url(#in12); }
  .price { --sw: 4px; --sc: #001b00; --sd: 2px; --band: #e6f8e0; --inset: url(#in10); }
  .p299, .p149 { --fill: linear-gradient(#f9f9f9 12px, #ebfaed 14px, #d8facb 17px, #cff5c2 18px); }
  .p199 { --fill: linear-gradient(#f9f9f9 11px, #ebfaed 14px, #d8facb 18px, #cff5c2 20px); }
  .p299 { left: 31px; top: 6px; font-size: 24px; --sx: .867; }
  .p149 { left: 33px; top: 6px; font-size: 24px; --sx: .857; }
  .p199 { left: 43px; top: 12px; font-size: 26.9px; --sx: .99; }
"""


def grad(stops, total):
    return "linear-gradient(" + ", ".join(f"{c} {p / total * 100 if total != 100 else p:.1f}%" for p, c in stops) + ")"


def card_html(key, c):
    x0, y0, x1, y1 = c["box"]
    w, h = x1 - x0 + 1, y1 - y0 + 1
    iw, ih = w - 6, h - 6                       # inside the 3px black edge
    ox, oy = x0 + 3, y0 + 3
    up = "".join(f'<stop offset="{p}%" stop-color="{col}"/>' for p, col in c["upper"])
    lo = "".join(f'<stop offset="{p}%" stop-color="{col}"/>' for p, col in c["lower"])
    ymin = min(y for _, y in c["curve"]) - oy
    svg = f'''<svg class="abs" width="{iw}" height="{ih}" viewBox="0 0 {iw} {ih}" style="left:0;top:0">
      <defs><linearGradient id="{key}U" x1="0" y1="0" x2="0" y2="{ymin + 30:.0f}" gradientUnits="userSpaceOnUse">{up}</linearGradient>
            <linearGradient id="{key}L" x1="0" y1="{ymin:.0f}" x2="0" y2="{ih}" gradientUnits="userSpaceOnUse">{lo}</linearGradient></defs>
      <rect width="{iw}" height="{ih}" fill="url(#{key}U)"/>
      <path d="{curve_path(c['curve'], iw, ih, ox, oy)}" fill="url(#{key}L)"/>
    </svg>'''
    layers = [svg]
    if "rays" in c:
        r = c["rays"]; n = r["n"]; step = 360 / n
        layers.append(f'<div class="abs rays" style="inset:0; background: repeating-conic-gradient(from 0deg at {r["cx"]-ox}px {r["cy"]-oy}px, '
                      f'rgba(255,255,255,{r["a"]}) 0deg {step*0.55:.1f}deg, transparent {step*0.55:.1f}deg {step:.1f}deg); '
                      f'-webkit-mask: radial-gradient(circle at {r["cx"]-ox}px {r["cy"]-oy}px, #000 20%, transparent 75%); '
                      f'mask: radial-gradient(circle at {r["cx"]-ox}px {r["cy"]-oy}px, #000 20%, transparent 75%)"></div>')
    if "glow" in c:
        gx, gy, gr, ga = c["glow"]
        layers.append(f'<div class="abs" style="inset:0; background: radial-gradient(circle {gr}px at {gx-ox}px {gy-oy}px, rgba(255,255,255,{ga}), transparent)"></div>')
    for bx, by in c.get("beams", []):
        layers.append(f'<div class="abs" style="inset:0; background: conic-gradient(from 0deg at {bx-ox}px {by-oy}px, '
                      f'rgba(255,255,255,.55) 0deg 14deg, transparent 22deg 158deg, rgba(255,255,255,.55) 166deg 194deg, '
                      f'transparent 202deg 338deg, rgba(255,255,255,.55) 346deg 360deg); '
                      f'-webkit-mask: radial-gradient(circle at {bx-ox}px {by-oy}px, #000 25%, transparent 70%); '
                      f'mask: radial-gradient(circle at {bx-ox}px {by-oy}px, #000 25%, transparent 70%)"></div>')
    if key == "cash":
        for dx, dy, s, rot in DECOR:
            layers.append(f'<img class="abs" src="icons/cash.png" alt="" style="left:{dx-ox-s*.1:.0f}px; top:{dy-oy-s*.1:.0f}px; width:{s*1.25:.0f}px; height:{s*1.25:.0f}px; opacity:.42; transform:rotate({rot}deg)">')
    P, url = c["stud"]
    layers.append(f'<div class="abs" style="inset:0; background:{stud_bg(url, P, ox, oy)}"></div>')
    return (f'<div class="card abs" id="{key}Card" style="left:{x0}px; top:{y0}px; width:{w}px; height:{h}px">'
            f'<div class="abs clip" style="left:3px; top:3px; width:{iw}px; height:{ih}px">{"".join(layers)}</div></div>')


def main():
    f = FRAME
    header_bg = grad(HEADER_STOPS, 85)
    cards = "\n".join(card_html(k, c) for k, c in CARDS.items())
    # close parallelogram (stage coords): black stripe 7px along the diagonal
    def dl(y): return 935 - 0.732 * (y - 116)
    cx0, cy0 = 862, 115
    poly_black = f"{dl(115)-cx0:.1f},0 {1004-cx0},0 {1004-cx0},{200-cy0} {dl(200)-cx0:.1f},{200-cy0}"
    poly_red = f"{dl(115)+7-cx0:.1f},0 {1004-cx0},0 {1004-cx0},{200-cy0} {dl(200)+7-cx0:.1f},{200-cy0}"
    close_stops = [(0, "#fc0689"), (14, "#fc0a75"), (35, "#ff0c6c"), (50, "#fe0e5a"), (64, "#fc0e4c"),
                   (78, "#fd0a3c"), (92, "#ff0529"), (100, "#e8103a")]
    cstops = "".join(f'<stop offset="{p}%" stop-color="{c}"/>' for p, c in close_stops)

    html = f'''<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>Shop Panel</title>
<meta name="viewport" content="width=device-width, initial-scale=1">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link href="https://fonts.googleapis.com/css2?family=Montserrat:wght@800;900&display=swap" rel="stylesheet">
<style>
  /* Generated by build.py, drawn from scratch; ref.png is only the measuring tape. */
  :root {{ --f: "Montserrat", sans-serif; }}
  * {{ box-sizing: border-box; margin: 0; padding: 0; }}
  html, body {{ height: 100%; }}
  body {{ background: #111; display: grid; place-items: center; overflow: hidden; }}
  body.raw {{ display: block; }}
  #Stage {{ position: relative; width: 1200px; height: 675px; overflow: hidden; }}
  .abs {{ position: absolute; }}
  img.abs {{ display: block; }}
  .clip {{ overflow: hidden; }}
  .world {{ position: absolute; inset: 0; background: url("plates/_world.png") 0 0 / 1200px 675px; }}
  #Ref {{ position: absolute; inset: 0; width: 1200px; height: 675px; opacity: 0; pointer-events: none; z-index: 50; }}

  .ot {{ position: absolute; font-family: var(--f); font-weight: 900; line-height: 1; white-space: nowrap;
         transform: scaleX(var(--sx, 1)); transform-origin: 0 0;
         color: var(--sc); -webkit-text-stroke: var(--sw) var(--sc); text-shadow: 0 var(--sd) 0 var(--sc); }}
  /* Letter interiors: ::before = whole glyph in the band colour; ::after = the
     gradient fill shrunk inward by the band width (SVG erode filter), so the
     band shows only just inside the outline. No strokes on these layers: the
     variable font's overlapping contours would draw lines through the letters. */
  .ot::before, .ot::after {{ content: attr(data-t); position: absolute; left: 0; top: 0; text-shadow: none;
               -webkit-text-stroke: 0; }}
  .ot::before {{ color: var(--band, transparent); }}
  .ot::after {{ background: var(--fill, #fff); -webkit-background-clip: text; background-clip: text; color: transparent;
               filter: var(--inset, none); }}

  #Frame {{ left: {f["left"]}px; top: {f["top"]}px; width: {f["w"]}px; height: {f["h"]}px; background: #000;
            box-shadow: 5px 3px 0 #010005; }}
  #Cream {{ left: 196px; top: 115px; width: 808px; height: 446px; background: {stud_bg(CREAM_STUD, 21.2, 196, 115)}, {CREAM}; }}
  #Header {{ left: 196px; top: 115px; width: 808px; height: 85px;
             background: {stud_bg(lstud(21.2, 11.5, 7, 15.5, 15.5, 21, 1.7, "rgba(0,50,140,.16)"), 21.2, 196, 115)}, {header_bg}; }}
  #HeaderLine {{ left: 196px; top: 200px; width: 808px; height: 6px; background: #000; }}

  .card {{ background: #040404; }}
  .card > .clip {{ box-shadow: inset 0 0 0 1.5px rgba(255,251,224,.95); }}
  .card > .clip::after {{ content: ""; position: absolute; inset: 0; box-shadow: inset 0 0 0 1.5px rgba(255,251,224,.9); pointer-events: none; }}

  .btn {{ position: absolute; cursor: pointer; border: 3px solid #050100; }}
  .price {{ }}
  .pbtn {{ background: #3dfd19; box-shadow: inset 0 2px 0 #effee6, inset 0 -2px 0 #dcffd1, inset 2px 0 0 #dcffd1, inset -2px 0 0 #b9ffa8; }}
  .gbtn {{ border-width: 4px 3px 3px 4px; }}
  .gV {{ background: #ebd470; box-shadow: inset 0 0 0 2px #f5f0d9; }}
  .gJ {{ background: #c058c8; box-shadow: inset 0 0 0 2px #fbdafe; }}
  .gC {{ background: #ffffde; box-shadow: inset 0 0 0 2px #fdfdf5; }}
  {TEXT_CSS}
</style>
</head>
<body>
  <svg width="0" height="0" style="position:absolute" aria-hidden="true"><defs>
    <filter id="in10" x="-5%" y="-5%" width="110%" height="110%"><feMorphology operator="erode" radius="1"/></filter>
    <filter id="in12" x="-5%" y="-5%" width="110%" height="110%"><feMorphology operator="erode" radius="1.25"/></filter>
    <filter id="in15" x="-5%" y="-5%" width="110%" height="110%"><feMorphology operator="erode" radius="1.5"/></filter>
  </defs></svg>
  <div id="Stage">
    <div class="world"></div>
    <div id="Frame" class="abs"></div>
    <div id="Cream" class="abs"></div>
    <div id="Header" class="abs"></div>
    <div id="HeaderLine" class="abs"></div>
    <svg id="CloseButton" class="abs" width="{1004-cx0}" height="{200-cy0}" style="left:{cx0}px; top:{cy0}px; cursor:pointer">
      <defs><linearGradient id="closeG" x1="0" y1="0" x2="0" y2="1">{cstops}</linearGradient></defs>
      <polygon points="{poly_black}" fill="#000"/>
      <polygon points="{poly_red}" fill="url(#closeG)"/>
    </svg>
    <div id="CloseText" class="ot" data-t="X">X</div>

    <img class="abs" src="icons/cart.png" alt="" style="left:209.6px; top:129.6px; width:56.9px; height:56.9px">
    <div id="Title" class="ot" data-t="SHOP">SHOP</div>

    {cards}

    <img class="abs" src="icons/crown.png" alt="" style="left:249.5px; top:241.5px; width:98.1px; height:98.1px">
    <div id="VipTitle" class="ot" data-t="VIP">VIP</div>
    <div class="btn gbtn gV" style="left:403px; top:304px; width:41px; height:40px">
      <img class="abs" src="icons/gift.png" alt="" style="left:6px; top:5px; width:22px; height:22px"></div>
    <div class="btn pbtn" style="left:450px; top:304px; width:115px; height:39px">
      <div class="ot price p299" data-t="$299" style="margin:-3px 0 0 -3px">$299</div></div>

    <img class="abs" src="icons/potion.png" alt="" style="left:639px; top:244px; width:94px; height:94px">
    <div id="JumpTitle" class="ot" data-t="2X JUMP">2X JUMP</div>
    <div class="btn gbtn gJ" style="left:796px; top:304px; width:39px; height:39px">
      <img class="abs" src="icons/gift_purple.png" alt="" style="left:5px; top:6px; width:20px; height:20px"></div>
    <div class="btn pbtn" style="left:841px; top:304px; width:116px; height:39px">
      <div class="ot price p149" data-t="$149" style="margin:-3px 0 0 -3px">$149</div></div>

    <img class="abs" src="icons/cash.png" alt="" style="left:249px; top:388px; width:144px; height:144px">
    <img class="abs" src="icons/cash.png" alt="" style="left:832.4px; top:390.9px; width:97.1px; height:97.1px">
    <div id="CashTitle" class="ot" data-t="2X CASH">2X CASH</div>
    <div class="btn gbtn gC" style="left:763px; top:484px; width:52px; height:51px">
      <img class="abs" src="icons/gift.png" alt="" style="left:6px; top:6px; width:31px; height:31px"></div>
    <div class="btn pbtn" style="left:821px; top:484px; width:148px; height:53px">
      <div class="ot price p199" data-t="$199" style="margin:-3px 0 0 -3px">$199</div></div>

    <img id="Ref" src="ref.png" alt="">
  </div>

  <label id="Controls" style="position:fixed;left:12px;bottom:12px;font:600 13px system-ui;color:#ddd;display:flex;gap:8px;align-items:center">Compare with reference
    <input id="RefSlider" type="range" min="0" max="100" value="0">
  </label>
  <script>
    const q = new URLSearchParams(location.search);
    const raw = q.has('raw');
    if (raw) {{ document.body.classList.add('raw'); document.getElementById('Controls').style.display = 'none'; }}
    const stage = document.getElementById('Stage');
    const fit = () => {{ if (!raw) stage.style.zoom = Math.min(innerWidth / 1200, (innerHeight - 50) / 675); }};
    addEventListener('resize', fit); fit();
    const ref = document.getElementById('Ref');
    document.getElementById('RefSlider').addEventListener('input', e => {{ ref.style.opacity = e.target.value / 100; }});
  </script>
</body>
</html>
'''
    (HERE / "index.html").write_text(html)
    print("wrote index.html")


main()
