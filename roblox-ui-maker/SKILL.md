---
name: roblox-ui-maker
description: Make Roblox game UI end to end. read the developer's style reference (stud style by default), source textures from ui-resources.com, take icons ONLY from one licensed vector icon pack the developer owns, build every screen in HTML/CSS with all states, let the developer check and approve it, then export to JSON, upload images, generate and build a real ScreenGui in Studio, wire the runtime UI module, and verify. Use for ANY Roblox UI, GUI, HUD, menu, shop, popup, screen, panel, frame, button, toast, billboard, tutorial card, crate/RNG reel or icon request; when the user mentions "ui resources", "ui-resources", "stud style", "html ui", importing a UI into Studio, or gives feedback on a UI's look.
---

# Roblox UI maker

**LICENCES FIRST.** Icons come from ONE licensed icon pack that you (the developer) own; this skill ships no
icons and no textures. Read your pack's licence: most paid packs allow use in your own games but forbid
resale, redistribution, asset packs and AI training (if so, never send the pack's PNGs to any image model).
In game repos, commit `icons.json` + the copy script, not the pack, unless the licence allows it. Textures
are downloaded by you from https://ui-resources.com (UI_RESOURCES.md); credit their creators.

Figma import tools are for designs that already exist in Figma; this skill is for designing new UI (or
remaking a screenshot) through HTML first.

**The loop:** reference -> tokens -> HTML (all states) -> the developer checks -> learn -> import -> verify.
**Read `LESSONS.md` before touching anything** (every rule learned so far, with the bug behind it). It wins
over anything below that disagrees.

## Files in this skill
| File | What |
|---|---|
| `LESSONS.md` | every rule + why. Read first; write the developer's feedback into it (REVIEW_LOOP.md) |
| `STYLE.md` | reading the reference into tokens; presets; CSS token -> Roblox table |
| `UI_RESOURCES.md` | ui-resources.com: what it is, finding/downloading, the stud texture and where to put it |
| `PATTERNS.md` | HUD, shop, crate reel + odds, toasts, confirm, loading, tutorial, bubble, goal pill, lists |
| `PIPELINE.md` | HTML -> JSON -> Roblox in depth: rbx.json, export markers, mapping table, ledger, templates, copies |
| `REVIEW_LOOP.md` | how to show screens, take feedback, get approval |
| `VERIFY.md` | mock render, property sweep, edit-mode harness, playtest clicks, checklists |
| `ROBLOX_FACTS.md` | measured engine + MCP tool facts (inset, TextSize, uploads, captures) |
| `styles/` | `stud.css` (default preset), `glass.css` (dark simulator preset) |
| `templates/examples/` | a working UI project: `build.py`, `kit.css`, `icons.json`, `rbx.json` |
| `templates/luau/` | Builder, UIKit, NumberFormat, Theme, client/UI + Controller, Toasts, UpdateInPlace, PixelRows, ProgressiveReveal, NextGoal, CrateRoll, LoadingScreen, PropertySweep, WorldHitTest |
| `scripts/` | read_reference, copy_icons, cdp/export/dump, gen, ledger, assets, bundle, mock/mockshot/mockdiff, check_copies, luau_to_rbxmx; `remake/` = 1:1 measuring tools |

`SK=<this skill's folder>` below (the folder this SKILL.md is in). Tools you need: python3 with PIL + numpy,
node 22+, Google Chrome (headless renders; env `CHROME` overrides the macOS path), `luau-analyze`, a browser
pane or browser automation tool for viewing pages (in Claude Code desktop: `mcp__Claude_Browser__*`, load with
ToolSearch), a Studio MCP server that can run Luau and import .rbxmx files (this skill was written against the
community `robloxstudio` MCP) and the built-in `Roblox_Studio` MCP for `upload_image` only (ROBLOX_FACTS.md).

## 1. Brief, references, style (required: a style reference)
- Get the brief: which screens, what they do, what data they show, PC + phone. List every state each needs.
- **A style reference image is required.** Use the one the developer gave. If none: ask once ("send a
  screenshot of the style you want; or I'll use the stud style"). If they say just go: stud preset. Most games
  are stud.
- Do the project setup in step 4 first (it creates `ui/`), then save the reference as `ui/ref.png`. Layout
  references (another game's shop) are separate from the STYLE reference.
- Read it from inside `ui/` (STYLE.md section 2): `python3 $SK/scripts/read_reference.py ref.png` -> palette,
  outline px, texture hint, text style, density + `ref_palette.png`, `ref_zoom.png` (Read it to SEE
  studs/gloss) and a draft `style.css`. Confirm each value by eye, keep only overrides of the chosen preset.
- "Like game X" = inspired by, not a copy, unless the developer says "remake this 1:1" (then LESSONS section 7
  and `scripts/remake/`).

## 2. Textures from ui-resources.com
Stud style MUST carry a stud texture. This skill does not bundle one: download the ui-resources "Stud texture"
(tag Stud) yourself from https://ui-resources.com, convert it to a real PNG if needed, and save it as
`ui/stud.png` in your project (4x4 studs per tile, tiled at 112 px with overlay blend). For anything else
(paper, sunbursts, halftones, backgrounds) search the site first and save downloads in `ui/tex/`
(UI_RESOURCES.md: filters, `?tag=Stud`, reading lazy-loaded URLs, `file` + `sips` for WebP-named-png).
Credit creators in build.py's header.

## 3. Icons: your icon pack only
Icons come from ONE licensed vector icon pack the developer owns (one vector pack per project; never mix
packs), never emojis. Find icons by browsing or searching the pack's own folder or catalogue (e.g.
`find <pack> -iname '*coin*'`). After the step-4 setup, edit `ui/icons.json` (`{"slug": "Icon file name or
path inside the pack"}`; the example's list is a starting point) and run
`python3 $SK/scripts/copy_icons.py icons.json --pack <your icon pack>` in `ui/` (add `--prefer " Outline"` or
your pack's equivalent to take outlined variants first). Never emojis, close = text "X". Search synonyms
before calling anything missing.

## 4. Build every screen in HTML/CSS
Set up once in the game repo (do this before steps 1-3 write anything into ui/; `cp -n` never overwrites):
```bash
mkdir -p ui && cp -rn $SK/templates/examples/. ui/ && cd ui
cp <your downloaded stud texture> stud.png && cp -r $SK/styles .     # stud texture from ui-resources.com
cp <reference> ref.png && python3 $SK/scripts/read_reference.py ref.png      # -> style.css (draft)
python3 $SK/scripts/copy_icons.py icons.json --pack <your icon pack> && python3 build.py   # -> *.html + index.html
python3 -m http.server 8870 --bind 127.0.0.1    # run_in_background; or the launch.json entry below + preview_start
```
`.claude/launch.json` in the game repo (then `mcp__Claude_Browser__preview_start {name: "ui"}`):
```json
{ "version": "0.0.1", "configurations": [
  { "name": "ui", "runtimeExecutable": "python3",
    "runtimeArgs": ["-m", "http.server", "8870", "--bind", "127.0.0.1", "--directory", "ui"], "port": 8870 } ] }
```
Edit `build.py` (it is the source of truth; never hand-edit generated .html). Rules that matter most:
- 1920x1080 stage, absolute px; shared components (`plate`, `panel`, `card`, `T`, `I`) so siblings share one
  treatment; only colours vary. Styling comes from tokens: `kit.css` (structure) -> `styles/<preset>.css`
  (`UI_STYLE=glass python3 build.py` to switch) -> `style.css` (this game). `?style=glass` previews live.
- Export markers: `grp(name, html, anchor)` = a top-level Roblox frame anchored to a screen edge; `name=` on
  every live label/icon/button; `sub(..., btn=True, opens='Shop')`; `hid=True` for exported-but-hidden states.
  PIPELINE.md section 2 has the full table.
- All states on `states.html`; phone layout (`hud_phone.html`); every runtime element (toasts, confirm, reward,
  tutorial, billboards) on `templates.html`; show pieces in context over a real game capture once one exists.
- No double quotes inside inline `style="..."`; no element named Active/Visible/Position...; use `hid`
  (opacity 0), never display:none, for things the game toggles.
- Self-check: open each page with `?check` in the browser pane (`checkOverflow()` must return no overflow and
  no broken images); render 2x headless shots (REVIEW_LOOP.md) and look at them.

## 5. Stop: the developer checks it
Show `style.html` + the first screen in the first round, then the rest (REVIEW_LOOP.md). Wait for an explicit
yes. Every correction: find the general rule, write it into `LESSONS.md` (rule, then why), apply it everywhere,
tell the developer in one line what you saved. No Roblox work before approval.

## 6. Import into Roblox (after approval)
Full detail: PIPELINE.md. From `ui/` with the server running:
```bash
# first import only: the Luau runtime + builder (then replace "<Gui>" in ../roblox/ui/client/UI.luau with rbx.json "gui")
mkdir -p ../roblox/ui/client && cp -n $SK/templates/luau/*.luau ../roblox/ui/ && cp -n $SK/templates/luau/client/*.luau ../roblox/ui/client/
rm -f ../roblox/ui/LoadingScreen.client.luau ../roblox/ui/CrateRoll.luau   # these live in ReplicatedFirst / ReplicatedStorage
node $SK/scripts/export.mjs              # layout JSON + 2x transparent PNG per raster piece -> rbx/out/
python3 $SK/scripts/gen.py               # Data_<Screen>.luau, Data_Templates, Data_Manifest -> luau_out; art -> rbx/out/upload
python3 $SK/scripts/mock.py && node $SK/scripts/mockshot.mjs   # offline Roblox-semantics render: mean diff 1-3 per screen
python3 $SK/scripts/ledger.py 20         # next URLs to upload; upload with mcp__Roblox_Studio__upload_image(+studio_id),
                                         # then: echo '<result json>' | python3 $SK/scripts/ledger.py 20 ; repeat until 0 left
python3 $SK/scripts/assets.py            # AssetIds.luau
python3 $SK/scripts/bundle.py            # rbx/out/<Gui>Build.rbxmx
```
Upload rules: <= 20 per batch, open the GROUP's place when the game is group-owned, never
re-upload what the ledger has, probe foreign ids. Then in Studio via `robloxstudio`:
destroy the old `ServerStorage.<Gui>Build` -> `import_rbxm` the .rbxmx into ServerStorage ->
`require(game.ServerStorage.<Gui>Build.Builder).build()` -> enable the gui, `Builder.fit()` twice, disable.
**Never `set_script_source`** (mangles `\n`); always .rbxmx + import_rbxm.
Wire game code (the Controller boots UI + UIKit; demo numbers only with the gui attribute `PreviewMode`):
`client/UI.luau` (open/close/back, juicy buttons with `Button`/`Opens` attributes, Escape,
scrim, popups queue, count-ups) + `UIKit.luau` (template contract: clone, `set` with Shadow twins, icons, bars,
plural/article, worldLabel) + `NumberFormat.luau`. Game code clones templates; it never builds a look with
Instance.new. Log every runtime change to imported screens (PIPELINE.md section 8).

## 7. Verify in Studio
VERIFY.md, in order: no empty images; fit ratios; `PropertySweep.atSizes` at 1920x1080 / 1366x768 / 844x390;
the edit-mode harness (clone the gui, require the clone's UI, drive, `UI.destroy()`, `Archivable=false`);
playtest only when needed (check nobody else's playtest is running): a magenta capture is not a broken UI;
real clicks at AbsolutePosition + size/2 **+58 px**; phone device profile; rapid-click test; lists update in
place. `luau-analyze --mode=nonstrict` every client file; `check_copies.py` so Studio copies match disk.

## 8. Iterate
New feedback -> LESSONS.md -> HTML -> approval -> export only the changed page -> gen -> ledger uploads only new
art -> bundle -> `Builder.buildScreen("<Screen>")` (one panel in place) or `build()` -> fit -> verify.

## Never
Emojis or a second icon pack; AI-generated icons; icon-pack files sent to any model when the licence forbids
AI use; text baked into images; importing before approval; editing Data_*.luau by hand; `set_script_source`;
demo values written while the real game client runs; auto-claimed rewards; a line or marker drawn over a
prize; game-specific ids or names inside this skill folder.
