# STYLE: the reference decides the look; tokens carry it

The style of every screen comes from **the developer's style reference image**, read into **tokens** (CSS
variables). Most games end up in the **stud** style, so the stud preset is the default and a stud-like
reference only tweaks it.

## 1. Get the reference (required input)
- Use the image the developer gave (screenshot of a game they like, a mockup, a style guide). Save it as `ui/ref.png`
  (convert webp/jpg with `sips -s format png`).
- None given: ask once: "Send me a screenshot of the style you want (any game UI you like). If you just want me
  to go, I'll use the stud style." If they say go / don't care: stud preset, no ref.png.
- Several references: one is the STYLE reference; the rest are layout/feature references. Ask which if unclear.
- A reference video: grab 3-5 frames (`ffmpeg -ss <t> -i v.mp4 -frames:v 1 f1.png`) and read the clearest UI frame.

## 2. Read the reference (10 minutes, before any screen)
From inside `ui/` run `python3 $SK/scripts/read_reference.py ref.png` (`$SK` = this skill's folder) (add `--box x0 y0 x1 y1`
to read only the UI part). It prints hints and writes `ref_palette.png`, `ref_zoom.png` and a draft `style.css`.
Then LOOK (Read ref.png and ref_zoom.png; zoom more with `scripts/remake/measure.py ref.png crop x0 y0 x1 y1
out.png 4`) and fill in this checklist:

| Read | How | Token(s) |
|---|---|---|
| Palette | `ref_palette.png` hexes; sample exact pixels with `measure.py col/row` | `--ink`, ramp `--top/--mid/--bot/--lip` per colour, `--glass` |
| Panel shape | corner radius (px at design scale), border width, is the body see-through? | `--panel-rad`, `--panel-bw`, `--panel-ol`, `--glass` alpha |
| Outline thickness | dark run widths (script prints plates/panels and thin/text) | `--plate-ow`, `--panel-bw`, `--stroke-k` |
| Texture | ref_zoom.png: studs? (count px between studs) / flat / glossy stripes / glass / paper | `--stud`, `--stud-op`, `--head-stud-op`, preset choice |
| Font | weight (heavy rounded = Fredoka One, heavy geometric = Montserrat 800), outline, drop, gradient fill | `--font`, `--text-ol`, `--drop-k`, `--text-fill`, `.f-*` |
| Buttons | outline + rim + lip? flat? pill? icon left of label? | ramp tokens, `--plate-rad`, `--lip-h` |
| Icons | outline variant or plain, drop shadow, size relative to buttons | outlined vs plain (copy_icons `--prefer`), `.ic` filter |
| Spacing / density | gaps between items, margins to screen edges, busy vs calm | layout constants in build.py |

Write the confirmed values into `ui/style.css` (only what differs from the preset) and pick the preset
(`UI_STYLE=stud` default, `UI_STYLE=glass`). Build, then show the developer `style.html` (reference | palette + tokens |
the kit drawn in those tokens) **together with the first screen**. Fix tokens from their feedback before making
more screens.

## 3. Presets (`styles/`)
Load order on every page: `kit.css` (structure only) -> `styles/<preset>.css` -> `style.css` (per game).
Any page also accepts `?style=glass` to preview another preset live.

### stud (default): `styles/stud.css`
- **Surfaces**: see-through dark glass panels `rgba(8,14,22,.76)`, 7 px near-black `#070a0e` border, 30 px
  radius, 2 px faint white inner rim, 10 px hard drop shadow. Small cards/toasts: 5 px border, alpha .80.
- **Plates (buttons, tabs, headers)**: 6 px tinted near-black outline -> 2 px bright top rim + 2 px side rims ->
  vertical face gradient top/mid (48%)/bottom -> 11 px darker two-tone lip -> 4 px drop. Sizes: default
  (r 20), `.sm` (outline 4, r 14, lip 7), `.xsm` (outline 4, r 11, lip 6). Header plates r 30/30/18/18.
- **Stud texture**: `ui/stud.png`, downloaded by you from ui-resources.com ("Stud texture", 4x4 studs per
  tile; see UI_RESOURCES.md) tiled at 112 px (84 on `.sm`, 72 on `.xsm`, 120 on headers), offset 3/4 px,
  `mix-blend-mode: overlay`, opacity .95, stopping above the lip. The overlay takes the plate colour, so one texture serves every colour.
- **Text**: Montserrat 800, white face with a subtle grey bottom (`#fff 52% -> #e4e7ea`), near-black `#121212`
  outline (7 px CSS stroke = ~3.5 px visible; `.l` 9, `.s` 5, `.xs` 4, `.xl` 12) and a hard drop (3 px; 2-6 by
  size). Coloured fills: white top half, colour from mid-letter down (`.f-green`, `.f-gold`...).
- **Colour ramps**: blue, green, red, yellow, orange, purple, grey, dark, gold (`.c-*`). Green = go/buy,
  red = destructive/close, blue = neutral/secondary, gold = rewards, grey = owned/unaffordable.
- **Button states**: normal; hover = scale 1.06 + lift 3 px (+ hover sound); pressed = 0.92 + sink 4 px;
  release = Back spring; locked = `.off` (saturate .15, brightness .82) or a grey plate when a price must stay
  readable. Every state is drawn on `states.html`.
- **Icons**: your pack's outlined variants (if it has them) with a 3 px hard drop shadow.

### glass (dark simulator style): `styles/glass.css`
Layered dark navy panels `RGB(19,21,31)` at 0.58 transparency, 3 px black stroke, 16 px radius; NO studs on
buttons (studs only on the header strip at 0.6); flat rounded buttons with a thin black stroke and a 6 px lip;
white text, thin black outline (x0.55), no drop; font GothamSSm ExtraBold in Roblox (Montserrat 800 in HTML;
add `"font_map": {"Montserrat": "GothamSSm"}` to rbx.json so gen.py maps it).
Same kit.css, same build.py: only tokens change. That is the point: a new look = a new token file.

### Other directions games have used (write a new preset file when one fits)
- Parchment scrolls with ink-brush bands (anime RPG): paper texture, brush masks, dark ink outlines, no studs.
- Skewed plates, heavy italic Montserrat, hot-orange accent (arena PvP): no studs, sharp corners, skewX(-8deg).
- Chunky steel panels, hard black outlines, banded vertical gradients, gold titles, cyan claim buttons (western).
- Honey-and-cocoa candy (cosy idle): rounded display font, glossy candy buttons, hexagon badges.
- Nautical punk (comic): Bangers/Oswald/Permanent Marker, paper + halftone + scratch textures, tape labels.

## 4. Token table: CSS token -> Roblox
The exporter converts the computed CSS automatically; this table is for reading the Data files, hand fixes and
runtime bits (`templates/luau/Theme.luau` holds the same values in Roblox units).

| Token (CSS) | Stud value | Roblox |
|---|---|---|
| `--ink` | `#070a0e` | UIStroke.Color of outlines; `Theme.ink` |
| `--glass` | `rgba(8,14,22,.76)` | Frame BackgroundColor3 (8,14,22), BackgroundTransparency 0.24 |
| `--panel-bw` / `--panel-rad` | 7 px / 30 px | UIStroke Border Inner, Thickness 7 / UICorner 30 (design px under FitScale) |
| `--plate-ow`, ramps, `--stud` | 6 px, `.c-*`, 112 px | baked into the plate PNG (ImageLabel ScaleType Stretch; 3-slice + Tile when > 1024 px wide) |
| `--font` | Montserrat 800 | `Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.ExtraBold)` |
| `--font2` | Source Sans 3 600 | `.../SourceSansPro.json`, SemiBold |
| font-size N px | e.g. 40 | TextSize = N x 1.215 (TextSize is line height); > 100 -> UIScale wrapper |
| text stroke `--sw` x `--stroke-k` | 7 px | UIStroke (Contextual) Thickness = CSS stroke / 2, LineJoinMode Round |
| text drop `--dy` | 3 px | a second TextLabel `<Name>Shadow`, outline colour, offset +dy |
| `--text-fill` / `.f-*` | gradients | TextColor3 white + UIGradient Rotation 90 |
| `.off` | saturate .15 brightness .82 | baked into the plate PNG (and icons inside it) |
| hover / press | 1.06, -3 px / 0.92, +4 px | UIScale tweens in UI.luau `juicy()`; `Theme.motion` |
| `.hid` | opacity 0 | Visible = false |

Roblox font families commonly used (check any in Studio before relying on it): Montserrat, FredokaOne, SourceSansPro, GothamSSm, Bangers, Oswald,
RobotoCondensed, Roboto, PermanentMarker, LuckiestGuy, PressStart2P (`Enum.Font.Arcade` resolves to it),
Nunito, TitilliumWeb, Ubuntu, Arimo, Kalam, Jura. Check any other with a TextLabel in Studio first.

## 5. Motion (all styles)
Open: Back ease-out pop 0.4 -> 1 (0.38 s); close: quick Back ease-in to 0 (0.18 s); scrim fades 0.25 s.
Buttons: hover grow + lift + sound, press sink, release spring, click sound. Numbers count up (0.45 s).
Idle: reward icons bob, badges breathe. Reveals: elastic pop. Rarity scales the juice.
