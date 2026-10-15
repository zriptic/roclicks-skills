# REFERENCE EXAMPLE of a 1:1 remake builder (from an earlier project; not runnable as-is: it expects that
# project's ref.png, icons/ and tex/ files). Copy its STRUCTURE for a new remake: shared plate() component,
# measured gradients/stud pitch, LABELS table for fit_text.py, ?raw / ?labels=KEY&bg= modes. See LESSONS.md 7.
"""Builds index.html: the Codes frame drawn FROM SCRATCH (ref.png = measuring tape).

Shared components keep everything consistent: every plate (header, close,
redeem) is the same `plate()`: black outline, light inner rim, measured
vertical gradient, and the SAME ui-resources stud texture (tex/stud.png, 4x4
studs per tile) at a measured pitch. Text is live Montserrat, auto-fitted by
fit_text.py. The world behind (_world.png) is only a stand-in, not UI.

Run: python3 build.py
"""
from pathlib import Path

HERE = Path(__file__).parent

STUD_TILE_PX = 223.5            # one stud's pitch inside tex/stud.png (894px / 4)
STUD_IN_TILE = 45               # stud square's top-left inside its cell (texture px)


def stud_layer(pitch, x0, y0, stud_x, stud_y, opacity):
    """Stud texture scaled to `pitch`, phased so a stud's top-left lands on the
    measured (stud_x, stud_y) stage point. x0/y0 = the layer's stage origin."""
    s = pitch / STUD_TILE_PX
    tile = pitch * 4
    ox = (stud_x - STUD_IN_TILE * s - x0) % tile
    oy = (stud_y - STUD_IN_TILE * s - y0) % tile
    return (f'<div class="abs fill studs" style="background:url(icons/stud.png) {ox:.2f}px {oy:.2f}px / {tile:.2f}px {tile:.2f}px;'
            f'opacity:{opacity}"></div>')


def vgrad(pairs, y0):
    return "linear-gradient(" + ", ".join(f"#{c} {y - y0}px" for y, c in pairs) + ")"


def plate(id_, box, radius, border, rim_top, rim_bot, grad, stud, extra=""):
    """box = outer outline (x0, y0, x1, y1) inclusive."""
    x0, y0, x1, y1 = box
    w, h = x1 - x0 + 1, y1 - y0 + 1
    ix0, iy0 = x0 + border, y0 + border
    layers = [f'<div class="abs fill" style="background:{vgrad(grad, iy0)}"></div>']
    if stud:
        pitch, sx, sy, op = stud
        layers.append(stud_layer(pitch, ix0, iy0, sx, sy, op))
    layers.append(f'<div class="abs fill" style="border-radius:{radius - border}px;'
                  f'box-shadow:inset 0 2px 0 #{rim_top}, inset 0 -2px 0 #{rim_bot}, inset 2px 0 0 #{rim_top}99, inset -2px 0 0 #{rim_top}99"></div>')
    return (f'<div id="{id_}" class="abs plate" style="left:{x0}px;top:{y0}px;width:{w}px;height:{h}px;'
            f'border-radius:{radius}px;padding:{border}px">'
            f'<div class="abs clip" style="inset:{border}px;border-radius:{radius - border}px">{"".join(layers)}</div>{extra}</div>')


# ------------------------------------------------------------------ measured parts
HEADER = dict(box=(46, 46, 1023, 133), radius=11, border=3, rim_top="81b2e3", rim_bot="8fcdf5",
              grad=[(52, "1869b8"), (53, "116cc2"), (60, "1476c7"), (70, "1c7cce"), (80, "2684d6"), (90, "2a8dd7"),
                    (100, "3397de"), (110, "3a9ee3"), (120, "42a7e9"), (126, "48aee9")],
              stud=(37.35, 337, 62, .6))
CLOSE = dict(box=(949, 58, 1011, 121), radius=9, border=3, rim_top="f5777d", rim_bot="ce5cb3",
             grad=[(62, "fc6369"), (66, "f84955"), (72, "f44255"), (80, "ea4664"), (88, "e14575"), (96, "d53b6d"),
                   (104, "d34081"), (112, "cd4593"), (116, "d34fae")],
             stud=(9.7, 956, 64, .55))
REDEEM = dict(box=(775, 336, 953, 390), radius=7, border=2, rim_top="75f3cf", rim_bot="70dc75",
              grad=[(338, "5dfbc8"), (341, "47f8ac"), (348, "4bf3a4"), (355, "42e686"), (362, "45e07c"), (370, "4be079"),
                    (377, "41d15c"), (384, "46c94d"), (387, "43c74b")],
              stud=(9.7, 780, 341, .55))

# (id, text, measured box, measure mode, fit threshold)
#   ink  = dark outline box (label drawn on white, dark pixels counted)
#   fill = light fill box (label drawn on black, pixels brighter than threshold)
LABELS = {
    "Title": ('Codes', (128, 68, 292, 108), "ink", 110),
    "CloseX": ('X', (965, 75, 995, 104), "ink", 120),
    "Line1": ('Follow <b>@yourgame</b> on Twitter for in-game codes', (108, 226, 962, 259), "fill", 200),
    "Line2": ('and rewards!', (418, 271, 651, 295), "fill", 200),
    "Placeholder": ('Enter code here...', (123, 350, 437, 375), "fill", 100),
    "RedeemText": ('Redeem!', (798, 351, 930, 376), "ink", 150),
}
TEXT_FIT = {}
if (HERE / "text_fit.txt").exists():
    for line in (HERE / "text_fit.txt").read_text().splitlines():
        k, fs, sx, dx, dy = line.split()
        TEXT_FIT[k] = (float(fs), float(sx), float(dx), float(dy))


def label(key):
    text, box, mode, _ = LABELS[key]
    fs, sx, dx, dy = TEXT_FIT.get(key, ((box[3] - box[1]) * 0.95, 1.0, 0.0, -3.0))
    plain = text.replace("<b>", "").replace("</b>", "")
    top = box[1] + dy
    extra = ""
    if key == "Title":   # measured per-row fill, stops relative to this element's top
        rows = [(72, "f2fafc"), (80, "e7f7fd"), (88, "d9f3fc"), (96, "caf0fe"), (103, "c0ecfa")]
        extra = ";--fill:linear-gradient(" + ", ".join(f"#{c} {y - top:.1f}px" for y, c in rows) + ")"
    return (f'<div id="{key}" class="t {key}" data-t="{plain}" style="left:{box[0] + dx:.1f}px;top:{top:.1f}px;'
            f'font-size:{fs:.2f}px;--sx:{sx:.4f}{extra}">{text}</div>')


def main():
    css_labels = """
  .t { position: absolute; line-height: 1; white-space: nowrap; font-family: "Montserrat", sans-serif;
       transform: scaleX(var(--sx, 1)); transform-origin: 0 0; pointer-events: none; }
  /* outlined labels: element = outline + drop, ::after = fill */
  .Title, .CloseX, .RedeemText { font-weight: 800; color: var(--sc); -webkit-text-stroke: var(--sw) var(--sc);
       text-shadow: 0 var(--sd) 0 var(--sc); }
  .Title::after, .CloseX::after, .RedeemText::after { content: attr(data-t); position: absolute; left: 0; top: 0;
       -webkit-text-stroke: 0; text-shadow: none; background: var(--fill, #fcfcfc);
       -webkit-background-clip: text; background-clip: text; color: transparent; }
  .Title { --sw: 7px; --sc: #000911; --sd: 4px; }
  .CloseX { --sw: 6px; --sc: #290f18; --sd: 3px; }
  .RedeemText { --sw: 5px; --sc: #122216; --sd: 2px; }
  /* body copy: thin dark outline, flat white; handle yellow */
  .Line1, .Line2 { font-weight: 700; color: #fcfcfc; -webkit-text-stroke: 2px #100f13; paint-order: stroke fill; }
  .Line1 b { font-weight: 700; color: #f6ee68; }
  .Placeholder { font-weight: 700; color: #878181; }
"""
    fill_title = [(72, "f2fafc"), (80, "e7f7fd"), (88, "d9f3fc"), (96, "caf0fe"), (103, "c0ecfa")]
    title_fill = ", ".join(f"#{c} {y - 68}px" for y, c in fill_title)  # relative to label top, refined after fit
    html = f'''<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>Codes Frame</title>
<meta name="viewport" content="width=device-width, initial-scale=1">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link href="https://fonts.googleapis.com/css2?family=Montserrat:wght@700;800&display=block" rel="stylesheet">
<style>
  /* Generated by build.py, drawn from scratch; ref.png is only the measuring tape. */
  * {{ box-sizing: border-box; margin: 0; padding: 0; }}
  html, body {{ height: 100%; }}
  body {{ background: #111; display: grid; place-items: center; overflow: hidden; }}
  body.raw {{ display: block; }}
  #Stage {{ position: relative; width: 1060px; height: 520px; overflow: hidden; }}
  .abs {{ position: absolute; }}
  .fill {{ inset: 0; }}
  .clip {{ overflow: hidden; }}
  .studs {{ mix-blend-mode: overlay; }}
  #World {{ inset: 0; background: url(_world.png) 0 0 / 1060px 520px; }}
  #Ref {{ position: absolute; inset: 0; width: 1060px; height: 520px; opacity: 0; pointer-events: none; z-index: 50; }}
  .plate {{ background: #04090d; }}

  /* glass body: 3px black outline, faint light rim, 74% black (measured by
     continuity of the world across the outline) */
  #Body {{ left: 46px; top: 145px; width: 979px; height: 341px; border-radius: 9px; border: 3px solid #050303;
           background: rgba(0,0,0,.74); box-shadow: inset 0 0 0 2px rgba(255,255,255,.16); }}
  #Input {{ left: 107px; top: 325px; width: 857px; height: 76px; border-radius: 4px; background: rgba(0,0,0,.5); }}
  #Input input {{ all: unset; position: absolute; inset: 0; }}
  {css_labels}

  body.labels #Stage > :not(.t) {{ display: none; }}
  body.labels #Stage {{ background: var(--lbg, #fff); }}
  #Controls {{ position: fixed; left: 12px; bottom: 12px; font: 600 13px system-ui; color: #ddd; display: flex; gap: 8px; align-items: center; }}
  body.raw #Controls {{ display: none; }}
</style>
</head>
<body>
  <div id="Stage">
    <div id="World" class="abs"></div>
    {plate("Header", **HEADER)}
    <img class="abs" src="icons/twitter.png" alt="" style="left:{95 - 59.6/2:.1f}px;top:{90 - 59.6/2:.1f}px;width:59.6px;height:59.6px">
    {plate("CloseButton", **CLOSE)}
    <div id="Body" class="abs"></div>
    <div id="Input" class="abs"><input aria-label="Code" spellcheck="false"></div>
    {plate("RedeemButton", **REDEEM)}
    {"".join(label(k) for k in LABELS)}
    <img id="Ref" src="ref.png" alt="">
  </div>
  <label id="Controls">Compare with reference <input id="RefSlider" type="range" min="0" max="100" value="0"></label>
  <script>
    const q = new URLSearchParams(location.search);
    const raw = q.has('raw') || q.has('labels');
    if (raw) document.body.classList.add('raw');
    if (q.has('labels')) {{
      document.body.classList.add('labels');
      document.body.style.setProperty('--lbg', q.get('bg') || '#fff');
      const only = q.get('labels');
      document.querySelectorAll('.t').forEach(e => {{ if (only && e.id !== only) e.style.display = 'none'; }});
    }}
    const stage = document.getElementById('Stage');
    const fit = () => {{ if (!raw) stage.style.zoom = Math.min(innerWidth / 1060, (innerHeight - 50) / 520); }};
    addEventListener('resize', fit); fit();
    document.getElementById('RefSlider').addEventListener('input', e => {{ document.getElementById('Ref').style.opacity = e.target.value / 100; }});
    // placeholder is live: hide it while typing
    const inp = document.querySelector('#Input input'), ph = document.getElementById('Placeholder');
    inp.addEventListener('input', () => {{ ph.style.visibility = inp.value ? 'hidden' : 'visible'; }});
  </script>
</body>
</html>
'''
    (HERE / "index.html").write_text(html)
    print("wrote index.html")


main()
