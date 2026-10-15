# LESSONS: every rule learned so far (rule, then why)

This file is the skill's memory. It merges every UI lesson from earlier games and skills. **Read it
before any UI work. When the developer corrects, rejects or praises something, add or update a rule here
in the same turn** (see REVIEW_LOOP.md). Newest rule wins when two disagree; mark the old one superseded.
Format: **rule**, then why (what went wrong or what the developer said).

---

## 1. Sources, icons, licence

- **Icons come ONLY from your licensed icon pack, one pack per project, never emojis.** Emojis and
  hand-drawn icons read as cheap next to pack art; mixing two packs (different line weight, perspective,
  palette) looks sloppy even when each icon is good.
- **Search the whole pack before calling an icon missing** (its folder names / catalogue, then synonyms:
  cash/money, gear/settings, cart/shop/bag). If truly missing, map the idea to an existing icon (potion for
  "honey", target for "goal"); do not draw one.
- **Read the pack's licence. If it forbids AI training, never send its PNGs to an image model.** Composite only.
- **Never push or share a repo containing the raw pack** unless its licence allows redistribution. Commit the
  slug list (`icons.json`) and the copy script, not the pack. Most paid packs forbid redistribution.
- **Prefer outlined variants** (if the pack has them) for outlined/stud styles. They match the thick-outline
  cartoon text.
- **Textures, effects, backgrounds come from ui-resources.com first** (see UI_RESOURCES.md). Stud style MUST
  carry the stud texture. This is the developer's rule; studs are the signature of the look.
- **ui-resources images lazy-load and some `.png` files are really WebP.** Read `img.currentSrc` after
  scrolling; run `file x.png`; convert with `sips -s format png in --out out.png` before any Roblox upload.
  - Roblox accepts PNG/JPG/BMP/TGA only; the ui-resources stud texture itself is a WebP named stud.png.
- **Close buttons are a text "X" (white, black outline) on a red plate, never an icon.** This is the developer's rule.
- **Division of labour:** chrome (plates, panels, cards) = CSS or art with empty interiors and no text;
  icons = the pack; every word = live text. Baked text can never change; icons drawn into plates can't swap.
- **Never reproduce watermarks or designer logos** from a reference; treat them as noise when measuring.

## 2. Style comes from the reference

- **A style reference image is required input.** Ask for one once if none was given. If the developer says
  "just go", use the stud preset. The developer expects the skill to need a reference image to pick the style,
  with stud style the most likely result.
- **Read the reference into tokens before designing** (palette, panel shape, outline thickness, texture,
  font, buttons, icon treatment, density) and show the tokens sheet (`style.html`) with the first screen.
  - Guessed colours and outline widths were the main reason early screens looked "off".
- **"Inspired by X" is not "remake X".** When a game is named only as a style reference, keep the vibe but
  change signature elements (panel shape, cap colours, trim, palette); offer 2-3 directions on the same screen
  first. The developer wanted a slightly different style, not a 1:1 copy.
- **World and UI share ONE style.** Decide it once per game and hold it for maps, props and every GUI.
  - A stud map with a sleek UI was rejected: everything has to share one style.
- **When the developer names a game whose UI to copy, that game's UI style overrides the stud default** (flat, its
  palette, its signature shapes), while the world can stay stud. On a battlegrounds game the developer asked for the
  full UI in the style of the strongest game in the genre (the reference's grey slots, crimson skewed bar).
- **A LAYOUT reference is not a STYLE reference: when the developer names a game "for the layout, not the styling", copy its
  positions, sizes, grouping and what-shows-when nearly exactly, but keep the approved style tokens.** Build
  components and states first; finalise screen positions only once the layout reference is read. The developer asked to follow
  another game's layout almost exactly, adapted a little to the game, without its styling (the stud style itself was liked).
  Copy the reference's percentages, but keep this file's minimums (phone text >= 26, tap targets), and say
  where you scaled up. Big moments move where the reference puts them (headline line, world words), even if
  that removes screens you already built.
- **Stud is the default, not universal.** When a game is declared "not stud" (scroll RPG, sleek shooter), no
  stud plates or textures anywhere, lobby included.
- **"AI-looking UI" = flat beige rounded rectangles, one font, no depth, no motion.** Fix with a themed palette,
  a display font, panels with shadow + texture + sheen + ribbon title, "3D" buttons (dark lip under a coloured
  face, face drops on press), shaped badges, bars with a highlight lip, count-ups and elastic pops.
- **Only add studs where the reference has them.** Zoom with contrast before deciding (read_reference writes a
  3x zoom); some references are glossy (diagonal light stripes, no studs). Apply whichever to every plate.

## 3. Consistency

- **Same-type elements share ONE treatment**: all studded or none, same outline/rim/lip structure, same
  gradient structure, decor centred. One shared component (`plate()`), vary only colour. The developer
  found it odd that some buttons had studs and some didn't. Measurement noise is not a reason for inconsistency.
- **One toast style, one confirm dialog, one close button, one number formatter** across the game.
- **Repeated elements reuse one measured gradient**; when gradient stops are absolute y values, shift them by
  each instance's offset or the second row renders washed out.

## 4. Text (the developer notices text first)

- **World Robux prices: glyph and number in ONE label with NO space** (`"\u{E002}" .. n`). The glyph carries its own
  side bearing, so "\u{E002} 50" reads as a gap; a separate glyph label never shares the baseline. The developer
  found that a podium price with a space looked wrong.
- **BillboardGui.StudsOffsetWorldSpace turns with the adornee's rotation** (measured: a sign part yawed 180 degrees
  mirrored a +Z offset to -Z, despite the docs). Convert world vectors with `adornee.CFrame:VectorToObjectSpace`.
- **To keep a billboard from being covered by a model, slide it along the ray to the camera** (world offset
  `toCam.Unit * z` per frame, size scaled by (d - z)/d), not StudsOffset.Z (camera space: it drifts up the screen from
  low angles) and not AlwaysOnTop (not drawn in captures). A timer label was cut off by very large models.
- **Odds/info text on a machine: transparent board, tier-coloured lines with a dark stroke, in the machine's FRONT
  plane** (like the reference), never a card on the back wall where the displayed item hides it. This is the developer's rule.

- **Robux prices use the Robux glyph, never "R$"**: `utf8.char(0xE002)` / `"\u{E002}"` in Luau (raw U+E002 inside long-string data). It renders as the Robux icon in FredokaOne, Gotham and BuilderSans. HTML can't show it, so mock it with a small Robux icon in the HTML and export the glyph text. The developer asked for the Robux glyph instead of "R$".

- **Display font: Montserrat 800 = the "Gotham Black" look** (900 reads too heavy); Fredoka One suits rounder
  games. Identify a reference's font by silhouette and stem width; must be a font Roblox has
  (`rbxasset://fonts/families/<Name>.json`, verify in Studio).
- **Outlines are thick and near-black**: ~3 px visible on titles, 1.5-2.5 px on body at design scale. An outline
  tinted to the background vanished on dark cards.
- **Outlined text in HTML = element paints outline + drop, `::after` (content: attr(data-t)) paints the fill.**
  Never put `-webkit-text-stroke` on the fill layer: Montserrat's overlapping contours draw lines through P/M/X.
  `data-t` must equal the text.
- **Letter interiors are not flat white**: many titles are white on the top half, colour from mid-letter down
  (`.f-green` etc.). For 1:1 remakes, measure fill per pixel row.
- **Auto-fit text, never hand-tune** (`scripts/remake/fit_text.py` for remakes; `autofit()` in pages).
- **Rotated labels can't be auto-fitted**: measure centre + angle per label.
- **Phone minimums**: a 1920x1080 canvas shows at ~0.36x on a landscape phone: body text >= 26 design px,
  titles 40+, MinTextSize ~14 (6 came out ~2 px).
- **Small text (under ~22 px) loses its outline/drop** when it gets crowded; one client found stroked small
  text too crowded.
- **Price text on locked/unaffordable cards stays white and readable**: use a grey plate, not a desaturate
  filter over the price. The price is exactly what the player needs to read.
- **Don't add words that force TextScaled to shrink** ("$10/s net" shrank the label): show the value, or let the
  container grow (a subtitle may widen up to 1.8x instead of shrinking text).

## 5. Plates, panels, surfaces

- **Dark panel bodies are see-through glass (~0.70-0.80 black). The outer frame gets an outline only, never a
  fill**, or the glass reads opaque.
- **Profile plate edges on all four sides**: thin dark outline (measure: 1-2 px on some, 6 px on chunky) ->
  1-2 px BRIGHT inner rim on all sides (top/side/bottom colours differ) -> gradient -> darker bottom lip.
  A top-only highlight reads flat. Some buttons have no outline: check, don't assume.
- **Stud texture: measure pitch per surface, phase it so a stud's corner lands on the measured point, blend
  with `mix-blend-mode: overlay`.** One global pitch smeared studs; keep studs off the bottom lip.
- **Ornate line work = one SVG overlay with a single userSpace gradient**; a bbox gradient on a zero-height line
  renders nothing.
- **Nested rounded rects: inner radius = outer radius - gap.** Same radius leaves an ugly corner gap.
- **9-slice art: gradient bands must sit inside the fixed slices**, the stretching middle one flat colour, or
  the gradient smears when the panel grows. Light top-left = pressable, dark top-left = a well.
- **Persistent HUD chrome may be slightly transparent (~0.8)** so the world reads through; windows stay opaque art.

## 6. HUD and mobile

- **HUDs stay quiet**: only per-second info (main currency, one goal, health/energy, hotbar, 4-5 core buttons).
  Everything else behind a MORE drawer or in the screen that uses it. Counts become badges on their button.
  - The developer asked for the HUD to be fixed because too much was going on.
- **Start a new player's HUD as cash + one Next-goal pill, reveal pieces when they start to matter** (gems after
  the first gem, capacity only while full, timers only while running); columns close up around hidden rows.
  - About 30 readouts were cut to this and kids understood it. CAUTION: one developer rejected hiding MENU rows in
  an idle game; ask before hiding menu buttons (readout reveal is the safe case).
- **Badges are data-driven: one at a time, only for something actionable.** Static "!" and "1" from the mock
  shipped as permanent noise.
- **No permanent upsell buttons, no timer-driven nag tips.** Players read them as "you're doing it wrong".
- **Immersive/horror HUDs: no panels over the world**: small outlined text on the scene, one objective,
  meters on their button, see-through tap-sized buttons. The developer wanted UI that isn't invasive.
- **Design for thumbs**: tap targets >= 124 design px (~48 screen px), primary 150-190; draw Roblox's top bar,
  thumbstick and jump as dashed placeholders and keep clear; combat cluster under the right thumb; rarely used
  menus become world stands (walk-up prompts). Render a phone HUD and a PC HUD.
- **On mobile the player taps the world, not buttons**: tap acts at the tap point; automate what can be
  automatic; keep buttons only for actions with no world target.
- **Every PC action must exist on touch** (a missing prestige button soft-locked the loop on phones); hide key
  hints when `TouchEnabled and not KeyboardEnabled`.
- **Roblox's top bar keeps its size while your UIScale shrinks**: push top-corner groups below
  `GuiService.TopbarInset` at runtime (live, it settles after startup). The HUD's top-left slid under the
  menu/chat buttons on phones.
- **Toasts move when a screen opens** (dock to a free corner at ~0.6 scale, newest 2) and dock under the
  tutorial card when it shows.

- **Fit to the ScreenGui's own canvas, not `Camera.ViewportSize`**: with ScreenInsets = DeviceSafeInsets the canvas is
  the safe area (notch phones lose ~60 px a side), so a Root sized from the viewport spills under the notch. One rule:
  s = min(safeW/1920, safeH/1080), x1.1 and a 5% title-safe margin when `IsTenFootInterface()`; refit on the
  gui's AbsoluteSize change too (it settles after ViewportSize). Phones and TVs were laid out for the wrong box.
- **Lay out HUD groups by measured boxes, in one pass, including their tap UIScales**: slide a group along the top-bar
  row out of Roblox's buttons (drop below only if taller than the bar), re-centre a centred group between its row
  neighbours (shrink to ~0.85), drop anything else below what it hits. Per-corner pushes ignored tap scales: the
  phone-grown cash pill sat on the payout text. Place hidden groups too (without blocking others), or a group hidden
  "because a panel covers it" jumps back, stops being covered and flickers.
- **Panels: largest k that fits the safe area below the top bar (max ~1.3 phone, 1.15 tablet, 1 PC/TV), keep the
  designed spot when it fits, else the smallest shift**. Shifting a phone panel right to dodge Roblox's buttons left it
  small in the middle-right; while a panel is open, hide HUD groups its final rect (title/X included) touches.
- **Over a bright 3D world, 80% glass reads see-through**: big panel bodies 90%+ opaque; the HTML mock's pale stand-in
  world hides this.
- **Text caps follow every layout UIScale** (FitScale x PhoneScale x tap scale, not open/hover tweens) and are
  re-applied after each layout pass, or phone-grown labels keep PC-sized caps.
- **Touch: a pad child does not fire its parent's Activated.** Give small buttons a "TapPad" (>= 44 px) and route
  it to the same handlers (register handlers in one place that also hooks pads added later).
- **Scrims are their own ScreenGui (IgnoreGuiInset, ScreenInsets None) built from 4 frames around the hole**: a huge
  UIStroke scrim scales with UIScale and the safe canvas and covered only a box on phones. Compute the hole from
  AbsolutePosition on both sides so insets cancel; keep the spot's UIScale live (re-apply per frame).
- **World prompts need a screen-size floor** (touch ~20% of screen height, >= 64 px; gamepad 7%; mouse 4.5%), always
  sized in pixels: a stud-sized BillboardGui reports an AbsoluteSize that is not its drawn size, so anything that
  measures it (spotlights, hit tests) misses on PC. Touch shows a tap glyph, gamepad
  `UserInputService:GetImageForKeyCode`.
- **Console**: panels are SelectionGroups (behaviour Stop), `GuiService.SelectedObject` = the panel's first button on
  open when the last input was a gamepad or on TV, cleared on close; B closes; a face button opens the main menu.

## 7. 1:1 remakes (when the developer says "remake this")

- **"Remake this" = 1:1.** Only placeholder art the developer has no pack art for may differ. They check side by side.
- **Build from scratch, never overlay on / cut plates from / inpaint the reference screenshot.** Rejected three times
  (the developer asked for things made from scratch, not overlaid). The screenshot is only a measuring tape. A stand-in WORLD
  behind the UI may come from it.
- **Measure, never eyeball**: edges from outline runs, gradients from per-row medians, text from ink boxes,
  stud pitch from template sharpness (`scripts/remake/measure.py`). Buttons get the same rigour as text.
- **One panel at a time, score every region numerically and iterate before showing** (`scripts/remake/score.py`).
  - When this was skipped, quality dropped; the developer pointed back to the quest and settings panels as the best work.
- **Verify at the density the developer views at (2x)**: `--force-device-scale-factor=2`.
- **Calibrate plate colours in a closed loop** (`scripts/remake/calibrate_rows.py`): row error 7.4 -> 1.9.
- **The "copy method" (only when the developer asks for it)**: panel art = their reference with ONLY text glyphs removed,
  live text fitted on top.

## 8. HTML authoring

- **Every piece of UI goes through HTML first, including what game code builds at runtime** (toasts, tutorial
  cards, build bars, billboards, touch buttons, banners). The developer asked for any UI not made in HTML first to be
  redone in HTML and checked by them first.
- **Show every state** (normal, hover, pressed, locked, unaffordable, empty, full, loading, error, longest text,
  phone) on a sheet page AND each piece in context over a real game capture at realistic size.
- **Fixed 1920x1080 stage, absolute px**; `?raw` = 1:1 for headless.
- **A double quote inside an inline `style="..."` silently kills that declaration** (hit 4 times: data-URI
  studs, an SVG, `font-family:"Fredoka One"` falling back to Times, inlined shots losing stud overlays). Use
  single-quoted attributes and unquoted `url(data:...)`.
- **Hidden-but-exported elements use `opacity:0` (class `hid`), never `display:none`** (display:none is skipped
  by the exporter, so runtime has nothing to show).
- **Never name an element after a GuiObject property** (Active, Visible, Position, Selected...): `tabs.TabBuy.Active`
  returned the boolean property. gen.py prefixes collisions with N.
- **Data-driven screens keep ONE open and ONE locked example** of each card/row; runtime clones them.
- **Draw demo data that exercises every state** you will need to swap at runtime (tab states, selected tiles).
- **Headless Chrome drops 20-40% of images at random** even after decode: judge LAYOUT from headless, IMAGES
  in the browser pane (count `!naturalWidth`). Inline images as data URIs for scored renders.

## 9. HTML -> Roblox pipeline

- **Many screens -> generate, never hand-write builders**: export.mjs -> gen.py -> Builder. (14 screens,
  5,000 instances, mean mock diff 0.9-2.8/255.)
- **TextSize = CSS font-size x 1.215** (TextSize is line height). Without it every label rendered 83% wide.
- **TextSize is an integer capped at 100**: bigger text = TextSize/f inside a frame with UIScale f. Run the fit
  pass (TextBounds vs HTML width, twice) after building: median ratio 1.000, 90% within 2.3%.
- **HTML collapses runs of spaces; Roblox draws them all** (a label came out 6% wide). gen collapses whitespace.
- **CSS never paints an outer box-shadow under the box**: on glass a spread shadow becomes an outer UIStroke
  ring and a y-offset shadow a clipped crescent, or it darkens the glass.
- **Roblox caps images at 1024 px**: wide stud plates 3-slice on the stud period (cap / one tiled period / cap);
  anything else bigger is shrunk to fit.
- **Upload batches above ~20 time out (some still upload)**: keep the ledger, send only what is missing.
- **A re-export can re-hash unchanged plates** (headless raster noise, mean diff 0.03-0.06/255, fuzzy dedupe missed
  it): before uploading "new" art, compare each to same-size ledger art and alias near-identical keys to the old id
  in uploaded.json instead of re-uploading.
- **A Decal id renders nothing as ImageLabel.Image**: resolve to the Image id (upload_image returns image ids).
- **Assets from another owner render as nothing, silently**: probe ids before designing around them.
- **Push Luau as .rbxmx + import_rbxm, never set_script_source / edit_script_lines** (they expand `\n` inside
  strings; the push reports success and the script fails to compile).
- **Runtime UI ships as templates, not code**: a templates sheet -> a templates folder; game code clones and
  fills. Named labels get the room their parent allows (`FitW` keeps the design width for the fit pass).
- **Strokes/curves that change colour at runtime: export them WHITE and tint with ImageColor3.**
- **Template groups lose their design x**: centred designs whose bbox is not centred land off-centre; place by a
  known element.
- **Icons inside a desaturated (.off) plate must be baked** (the exporter rasterises them); otherwise the icon
  stays full colour on a grey button.
- **SVG circles/paths become raster art; progress rings that must animate are native** (disc + UIStroke track
  + two clipped halves with a hard-edged UIGradient).

## 10. Roblox GUI facts that caused bugs (details in ROBLOX_FACTS.md)

- **UIStroke now scales with UIScale** (measured late 2026). Older code multiplied by the scale and made rings
  6x too fat. Set thickness in design units. (Supersedes the old "UIStroke ignores UIScale" rule.)
- **`simulate_mouse_input` lands 58 px high** on GUIs that don't ignore the inset; add the inset. `MouseEnter`
  never fires from synthetic input: test hover by calling the code directly.
- **`capture_screenshot` returns 2x pixels that are not click coordinates**: read AbsolutePosition instead.
- **ScrollingFrame + Scale-sized rows + AutomaticCanvasSize collapse or explode** (seen at 112 million px).
  Use pixel rows from the list's AbsoluteSize, Offset padding.
- **BillboardGui clips to its Size even with ClipsDescendants off**; size clamped labels in pixels with ~1.5x
  headroom. AlwaysOnTop billboards failed to draw in playtests: lift instead. Billboard buttons get no clicks
  under a full-screen HUD: hit-test projected rects yourself.
- **Text-size caps must be re-applied, not computed once** (UIKit.fit / UI.fitLabel): live labels set at join
  read the viewport/FitScale while it is still ~1x1, the scale clamps to 0.3 and the label stays ~11 px all
  session (in one game the city name, storage and income went tiny in one playtest, fine in the next). The templates
  now refresh the cap on every set and on ViewportSize change.
- **Clearing all children also destroys UIScale/UIListLayout**: skip them when clearing.
- **A clone keeps ZIndex 1 and lands behind panel art** under Sibling ZIndexBehavior: set ZIndex = max sibling + 1.
- **Modal overlays parent to the scaled root, not inside a HUD frame**; use Sibling ZIndexBehavior, not Global.
- **Some phones can't run `--!native`**: leave it off small client modules.

## 11. Data truth (what the HUD shows)

- **Preview/demo values only when the game client is absent.** A preview controller wrote "$30,500 / 125 gems"
  over real values on a fresh save.
- **Overwrite or hide every mock value on a screen's first draw**: grep the mock for sample strings and icons and
  give each a live source or Visible=false (mock flags, "Owned 12", a fixed yellow verdict, permanent badges,
  a "00:00" timer all leaked). Route every open path through the same refresh.
- **Replace every shadow twin**: a parent with two Value/ValueShadow pairs got the wrong twin updated; a hidden
  icon left its shadow. Text helpers pick the NEAREST twin; show/hide covers `{X, XShadow}`.
- **Counts use the game's own definition of "owned"** (destroyed buildings were counted as owned: "x26", inflated prices). Call the
  server's rule or have the server send the count.
- **One denominator everywhere**: "Conquer 7 more" vs "0/8"; "25/20" while damaged; a two-sided power bar with
  one side fixed at half. Derive every n/total and ratio from one function.
- **Tags computed per item, never typed in**: every crate card said "SAVE 10%" while real savings were 10/16/13%.
- **Show net values** (income net of upkeep) and what the rule actually keeps (a "Sell All $0" while a hidden
  rule held goods back).
- **Find labels by exported name, never by sorted index or GetChildren order.**

## 12. Events and timing

- **Know whether a payload carries the before or after value**: the server patched state before firing
  Complete, the client added 1 and showed "Level 3!" on 2->3. Name fields `newLevel`/`prevLevel`.
- **Grace windows for async UI**: an event can land a frame before its banner exists; wait up to ~0.8 s for it
  to appear, then for it to leave. Defer clears ~1.5 s across state transitions, then re-check.
- **Let state deltas land before reading counters** (`task.wait(0.15)` before a popup reads replicated state).

## 13. Copy (words on screen)

- **Error text names the exact blocker and the fix**: "Need 3 wheat", not "Not enough resources" with $7,700
  in the bank; "Needs 5.00K iron but you can only store 377: upgrade your storage"; "Something is in the way:
  clear it first" (name the thing and the tool). Locked items always say what unlocks them.
- **Never show raw ids, "?", "nil" or empty interpolations** ("Research complete: ?", "Season  begins!").
- **Pluralise and pick a/an in one helper** ("Fishermans", "Sword (Gold)s", "a Egg"): `UIKit.plural`,
  `UIKit.article`.
- **Multi-line templates: split at a real space, write EVERY line** ("" for unused), pick the 1- or 2-line
  variant from the wrap. A truncating split dropped a character; an old line 2 lingered.
- **Toasts ~40 characters, one verb**; long ones (>50) get 6 s. Lines in tutorials <= 6 words.

## 14. Numbers

- **One formatter for HUD and panels** (`NumberFormat.luau`). Two disagreed.
- **Short suffix bug**: stripping trailing zeros from whole numbers turned 250K into "25K" and 100K into "1K";
  999,600 rounded to "1000" then "1K". Truncate, never round up into the next suffix, strip zeros only after a
  decimal point. Regression values: 0, 999, 1000, 1234, 99999, 100000, 250000, 999600, 1e6, -2500.
- **Currency prefix first**: "$1.36K", not "1.36K$".
- **Count-up tweens: one per key, cancel the previous, always land on the exact target.** Overlapping tweens
  left a stale value.

## 15. Rewards and money

- **Hide zero rewards** (icon, shadow and number): no "+0 gems".
- **Never auto-claim rewards**: a silent join reward was never seen and broke the starting balance. Claims go
  through a visible button.
- **Classify the moment from the player's view** before picking copy and sound (a won raid played the defeat sting).
- **Pass server-chosen sounds through; don't double-play stingers** (one fanfare per moment).
- **Unaffordable**: grey plate; tapping it says how much is missing and pulses the cash counter.

## 16. Layering

- **One overlay ScreenGui for all runtime UI**: DisplayOrder above the main UI, IgnoreGuiInset, ResetOnSpawn
  false, Sibling ZIndex, created lazily, kept all session.
- **Panels draw above mode HUDs**: a battle HUD at high ZIndex drew through a panel. Hide mode-HUD children on
  open (remember their visibility), restore on close; `close()` re-applies the CURRENT mode, not a default.
- **Translucent bubbles show what's under them**: hide groups under a modal or make it opaque.
- **Popups never cover a panel's close X**; floating buttons step aside while panels/banners show; projected
  world plates avoid HUD widget rects.

## 17. Input

- **No world clicks while a panel is open** (`if UI.anyOpen() then return end`); the Dim scrim is Active.
- **One click, one owner**: UserInputService can't consume input; use a claim API (claim lasts while held +
  0.25 s); count touches yourself (there is no GetTouchesInProgress).
- **Hover uses the exact same pick as click**, highlights only what a click can open, is off while placing /
  in map view / with a screen open / over GUI / on touch, and re-picks at most ~15 Hz.
- **Rebuilding lists eats taps** (Activated needs down and up on the same instance): update rows in place, keyed
  by a structure signature (no live numbers in the signature, or it rebuilds every packet and flickers).
- **Fixed-row mocks silently drop data** (6 rows for 8 resources): grow by rows, scroll, or merge entries;
  compute totals over all data, not drawn rows.
- **Hotkeys respect modes** (sink digits via ContextActionService during battles); one key = one thing per state.

## 18. Escape, close, placement

- **Escape is bound to the Roblox menu**: it may arrive with processed=true; handle it before the processed
  early-return (not while a TextBox is focused), also close on `GuiService.MenuOpened`.
- **Every close path (X, Escape, gamepad B, scrim, code) runs the same close action** (an Esc-close skipped a
  "collect on close" action and left selection rings stuck).
- **Return to the screen the player came from** (`UI.open(name, {keepHistory=true})`).
- **Placement**: right-click is camera only; end on Q/Esc/Cancel; end after a successful place (Shift keeps
  placing, and the bar says so); the ghost starts next to the player until the pointer moves; snap to the
  nearest valid cell only for placement errors; guard actions before state exists; debounce dual key paths.

## 19. Templates (contract details in PATTERNS.md)

- **Clone from the templates folder, fill by name, add UIScale; never Instance.new a look.**
- **Look the template up BEFORE creating a blocker**: a confirm dialog made its full-screen blocker, failed to
  find the card, and left an invisible click-eater.
- **Strip template-only children after cloning** (a key cap from another use showed on an unrelated button; a
  baked "current" ring).
- **Anchor-aware clone positions**: juicy buttons are re-anchored to 0.5,0.5, so `Position.X.Offset` is the
  centre; use `UIKit.leftOf` / `placeBeside` and copy the AnchorPoint.
- **Re-capture the hover rest position** (`JuiceRest`) whenever code moves a button, or the first hover
  snaps it back to its old spot.
- **Parameterise shared dialogs** (kind, title, yes/no text, body lines). One card always said its first use's title on every other use.
- **Banners animate as a whole with a UIScale**, not per-child transparency (only the text faded, leaving a
  bare plate).
- **"Changes made to imported screens at runtime" is a logged list** (hidden mock backgrounds, cloned rows,
  widened labels) so the next agent can find every runtime edit.

## 20. Toasts, popups, reveals

- **Dedupe identical toasts** (restart timer, pulse, re-tween the countdown strip); max ~4; merge bursts.
- **Suppress unsolicited popups** during cutscenes, battles (+12 s), banners, the first 90 s, tutorial,
  placement and open panels; max one per 3 min; drop them (the action stays reachable from a menu).
- **Queue reveals, never close a running one**; the busy flag stays until the queue is empty; failure paths
  also continue the queue.
- **Never draw over the prize**: a reel's centre line through the winning tile was rejected (the developer
  asked for the line to go). Mark the winner from the edges only (top/bottom markers, glow, scale).
- **The developer's "RNG" = one horizontal crate reel**: rarity tiles, gold markers top and bottom, blurred
  background, fast whip then ease-out; x3 spins the same line three times into a tray. Near-misses are cosmetic
  only, never rigged pity tricks aimed at kids. "Satisfying" = tick sounds per tile, rarity-scaled landing juice.
- **Don't spoil a reveal** with a generic "purchase granted" toast.

## 21. Tutorial

- **Card docking**: full size top-centre for ~5 s per step, then compact; bottom-centre at ~0.62 while a screen is
  open; hidden during modal popups.
- **Retarget the pointer to state** (wrong panel open -> point at its X; target hidden -> point at the in-panel
  equivalent); arrow beside top-edge targets, below in-panel buttons, ring on the button's edge, never over text.
- **Clean up after each step** (close screens the next step doesn't use, disarm tools).
- **Teach by showing** (spotlight, arrows, practice actions), calm hostile mobs, no monetisation until done.

## 22. World labels

- **Studs-sized, grow UP, lift in CAMERA space** (`UIKit.worldLabel`): pixel billboards covered whole buildings;
  measured 37% -> 0% coverage. StudsOffset +Z pulls toward the camera (8 studs not
  enough from a low camera, 14 was).
- **Declutter with priority** (actionable first, then important, then the rest; "+N" badge), merge same-side
  plates, cap sizes, range-limit status tags.
- **Speech bubbles**: max 4 on screen, none within 9 studs of another, only within 120 studs, 1.7 s life, one per
  squad per 1.8 s, pooled.
- **NPCs never look like players**: gold ground ring, role bubble, dark name plate with a tag.

## 23. Luau traps that broke UI

- **A local used before its declaration is a nil global** (a code box never appeared; 9,046 frame-loop errors).
  Forward-declare or use module fields; run `luau-analyze`.
- **`(x :: T).Prop = v` on the line after one ending in `)` parses as a call** ("ambiguous syntax"). Use a local.
  (This skill's own UI.luau hit it while being written; luau-analyze caught it.)
- **Weak-keyed tables for registries that must persist were always empty**: use strong tables, prune on Parent.
- **Edit-mode tooling output gets `Archivable = false`** (harness runs saved sound pools and attachments into
  the place, shipping looping sounds to every client).
- **PreloadAsync fetches but doesn't decode**: draw each unique image once in a hidden ScreenGui at boot (screens
  showed bare text for 1-2 s); preload CanvasGroup content before it first renders.
- **No-op listeners for unused server->client remotes** ("Remote event invocation queue exhausted").
- **Rate-limit frame-loop warnings** (once per message) and wrap RenderStepped bodies in pcall.
- **Pooled objects need a generation counter** for delayed callbacks.
- **Guard optional APIs** (`if UI.PageChanged then`): an older runtime copy without it killed the whole bridge.

## 24. Verification habits

- **Verify with numbers, not screenshots** (TextFits, overlaps, IsLoaded per asset, tap sizes). Playtest captures
  can be magenta; edit-mode captures show no ScreenGui; BillboardGuis are never captured.
- **Edit-mode mock harness** (clone the gui, require the clone's UI module, drive it, sweep, `UI.destroy()`).
- **Simulate rapid input** (4 quick clicks must give 4 results).
- **Phone and PC every time**; multi-touch can only be checked by reading code.
- **Check the playtest lock before driving a client**: a running playtest may belong to another agent.
- **Tool calls in one batch are unordered**: camera move + capture raced; sequence across calls.
- **The developer often plays right after an import**: playtest only when asked; verify in edit mode otherwise.

- **A tab whose `Opens` is its own panel must open, not toggle**: UI.toggle closed a team-management panel on its
  own hub tab and the Shop on every shop tab. Game code that gates a button (no save -> team select) strips that
  button's `Opens` so only one owner acts.
- **Exported lists of state buttons are per-cell examples**: a shop cell held only the state the mock showed
  (Buy in one, Equipped in another). Runtime must clone the missing variants into every cell before toggling.
- **Demo text ships**: every label the mock filled must be overwritten or blanked at runtime (a no-save player saw
  the mock's sample team, record and week, and thought Play was broken). Sweep with an edit-mode harness that
  counts path misses.
- **Recolouring a chip/badge recolours its LABEL too unless you separate them**: game code painted a tag chip's text
  in the kind colour, the same colour as the chip, so "PASS"/"RUN" vanished. Chips: background = kind colour, text
  white; every item gets a tag (no blank chip when a kind has no style).
- **Data-driven slot names are positions, not roles**: a "HomeLogo / MyCity" column must show the SAME team for the
  badge, name, record and stars; mixing home/away logic into one slot put the opponent's badge over your name.
- **The demo sweep must check every screen, not only the ones you opened**: compare each label to its import text
  and flag data-looking leftovers (cities, records, money, week/season). A wallet strip copied onto 7 panels showed
  the mock's "$17.6M" on 6 of them.
- **A bottom hint bar and a big bottom panel can't both show**: hide the hint bar while the picker is open (or lift
  the panel), checked at 1920x1080 / 1366x768 / 844x390.
- **fit() must skip full-screen groups** (a vignette pushed under the top bar) and keep centred panels clear of
  Roblox's top-left buttons: slide right if there is room, else shrink under the bar; then drop any HUD group the
  pushed one now overlaps (phone: badge onto the play menu).
- **Team Create edit mode has a LocalPlayer but no PlayerGui**: harness code that hits `WaitForChild("PlayerGui")`
  (UIKit.overlay, Toasts.init) hangs forever; stub them. Return ASCII from execute_luau: a multi-byte char cut by
  string.sub made the MCP call time out.

## 25. Approved work (reuse these approaches)

- The "runtime UI pass": sheet pages with every state + in-context pages over real Studio captures; toasts under
  the tutorial card; build bar inside the hotbar width; mobile actions in the right thumb column; tutorial arrow on
  the side with room; medallion icons on panel buttons. The developer approved it as good.
- A reference GAME VIDEO answered by: sampling its palette and recolouring the map first, Studio captures of
  the recoloured game as mockup backgrounds, real models rendered on a magenta backdrop and keyed into card art,
  the approved kit with the reference's ORGANISATION copied 1:1, world-placed systems moved out of menus.
- A voice-comedy cooking HUD in the default stud preset with no style reference: recipe checklist card (done /
  now / todo rows), countdown-timer pill, chaos pill, talk bar + no-mic Orders panel, start card, verdict panel with
  stars, speech-bubble templates, all shown over a real Studio capture of the map. Approved on the first pass.
- Presenting several flow options (phone + desktop shots, problems grid, comparison, recommendation) on one
  decision page before building the chosen flow.

## 26. Flat "broadcast" styles (learned on a sports game copying another game's UI)
- **A flat reference style (charcoal panels, coloured underline accents, Oswald) exports almost fully NATIVE**: build
  accents as inset y-shadow bands (`box-shadow: inset 0 -4px 0 <c>` -> InnerShade), use `.ot` with no stroke and a solid
  `::after` colour; only gauges/real images become art (3-5 uploads for 25 screens). Keep it that way: every raster
  is an upload.
- **mock.py has no Oswald (or other fonts it doesn't ship)**: mean diffs of 6-9 with matching geometry are font
  fallback, not layout errors; check the cmp_*.png before "fixing".
- **Roblox's Oswald runs ~6% narrower and taller than browser Oswald**: fit() caps big titles at TextSize 100 (fine)
  and the sweep reports height-only TEXT_NOFIT for most labels (line metrics, no clipping). Judge width only.
- **Studio caches `require` across execute_luau calls**: after replacing a Data_ module's Source, Clone the module
  (and Builder) and require the clone, or buildScreen() rebuilds the old layout.
- **When robloxstudio (import_rbxm) is down**: create the bundle's ModuleScripts in edit mode and set `.Source` from
  `HttpService:GetAsync` of the preview server (`rbx/luau/*.luau`); restore HttpEnabled afterwards.
- **Repeated tab labels must still get unique names** (six shop tabs all named after the screen they open collided).
