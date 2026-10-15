---
name: roblox-trailer
description: Make gameplay trailers for Roblox games, end to end. It plans a shot list from the game's GAME.md, drives the character in a Studio playtest so it looks hand-played (TrailerDriver.luau handles waypoints, prompts, remotes and a drifting third-person camera), adds cinematic camera moves (CameraRig.luau dolly, orbit, crane, push-in and whip, synced to game events), records only the Studio viewport with macOS screencapture, and edits with ffmpeg (speed ramps, whips, crossfades, title cards with emoji, a music bed with ducking and loudnorm). It exports the 30 s 1920x1080 Roblox video thumbnail cut and a 9:16 Shorts/TikTok cut, and runs QA with a contact sheet. Use whenever the user asks for a trailer, promo video, gameplay video, video thumbnail, teaser, TikTok or YouTube Short of a Roblox game, to "record it", "make it look like I'm playing", "edit a video of the game", or to film or capture gameplay or a cinematic flythrough in Studio.
---

# Roblox trailer

`SK=<path to this skill folder>`. The brief this skill was built for: *"record it, make it look like I'm playing it, and edit it too."*
Everything per game lives in `<game>/trailer/`: `shots.json`, `clips/`, `out/`. The scripts are generic, and every
game-specific name (tags, remotes, prompt text, item ids) lives in shots.json.

## Ground rules (read first)
- **It records the user's real screen.** Before recording, tell the user in chat to keep Studio frontmost and
  uncovered, park the mouse off the game view, and not touch the computer until you say done, and get their OK.
  Record only the calibrated viewport region. Delete test and stray takes with `record.py clean`. Never use `-C` (cursor).
- **Studio etiquette**: use one Studio MCP server for this (written against the community `robloxstudio` server, not
  the built-in Roblox_Studio one). Check that no other agent is using Studio before starting a playtest. Import the
  kit in edit mode, remove it afterwards, and never save the place with it.
- **Honesty**: Roblox rejects videos that show features the game doesn't have, enhanced graphics or ad claims.
  Staging *which* real outcome happens on camera (forcing odds for a take, granting an item) is fine.
  Faking something the game can't do is not; restructure the shot instead (see the Gold→Rainbow montage in the example).
- **No computer-use.** Everything goes through MCP eval calls, Python and ffmpeg.
- Keep cards and text sparse ("theme without noise": no extra noise on tools). The game's own UI is the best text.

## Workflow

### 1. Plan
Read `references/shot-list-template.md`. From the game's GAME.md, FINISHED.md and source, write the shot table
(hook in the first 2-3 s, core loop, rare moment, social, base/progression, an extra system, title card, a CTA for
social only) and show it to the user before recording. Then write `<game>/trailer/shots.json` (schema in
`references/luau-api.md`; start from `assets/shots.template.json`, or `references/example.shots.json` for a full example).
`python3 $SK/scripts/build_kit.py list --shots <shots.json>` sums the raw footage.

### 2. Gameplay-POV and cinematic shots (Luau)
- `scripts/TrailerDriver.luau` runs one shot on a playtest client: teleports to the start pose, disables the
  keyboard controls, walks waypoints (Humanoid:MoveTo, pathfinding, jumps, human jitter), turns to face targets,
  presses ProximityPrompts (InputHoldBegin/End), invokes remotes or bindables, and swaps cameras on cue or on game events.
  Its player cam is a lagging follow with mouse-like drift, tremor and glances. The game HUD stays on for gameplay
  shots and goes off for cinematics; the Roblox top bar, CoreGui and cursor are always off. Every run first stops
  the previous one and restores everything afterwards.
- `scripts/CameraRig.luau` has the cinematic presets: dolly/spline/flyover, bezier, orbit, crane, push-in, whip
  (with motion blur) and static. All are eased through TweenService curves and have configurable durations.
- Get them in: `build_kit.py rbxmx` → `import_rbxm` into ReplicatedStorage (edit mode) → start the playtest → send
  `build_kit.py call --shot ID` with `eval_client_runtime`. Run `build_kit.py server --shot ID` with `eval_server_runtime`
  first if the shot has setup. Details and the full action list: `references/luau-api.md`.

### 3. Record
`references/recording.md`. In short: `record.py calibrate` once (the driver paints the viewport cyan and the script
finds it), then for each shot `record.py shot ID --start-ms <startsAtMs> --dur <dur>`. It waits for the driver's
scheduled start, records preroll + shot + tail of just the viewport, and stores the exact trim offset. If screen
recording is unavailable, `record.py stitch` turns saved capture_screenshot frames into a clip.

### 4. Edit
`references/editing.md`. `edit.py build --cut roblox --format landscape` makes the Roblox upload (30 s max, 1080p60
H.264, no CTA). `--cut social --format both` makes 16:9 plus 9:16. Text is drawn with Pillow because Homebrew's ffmpeg
may have no drawtext. If Fredoka One isn't installed, ask before downloading it into `assets/fonts/`; it falls back to
Arial Rounded Bold.

### 5. QA
`qa.py clips --shots ...` after recording; `qa.py final <mp4> --roblox` after editing. It checks for dropped frames,
black and frozen frames, Studio-UI bands at the edges, the cursor flag and the Roblox limits, and writes a contact sheet.
**Open the sheet with Read and look at it**: a stray Studio panel, a cursor or the wrong HUD state show up there.
Then show the user the cut (path plus sheet) and take notes for a recut. Recuts only need `edit.py`.

### 6. Clean up
Stop the playtest, delete `ReplicatedStorage.TrailerKit`, run `record.py clean --out <trailer> --shots <shots.json>`,
and remove `<trailer>/build/`. Keep `clips/` (the source footage) and `out/`.

## Reference map
| File | When to read it |
|---|---|
| `references/shot-list-template.md` | planning; turning GAME.md into shots |
| `references/luau-api.md` | writing shots.json; driver and rig API; targets, actions, triggers, presets |
| `references/recording.md` | before the first take; calibration, sync, fallbacks, 2-player shots |
| `references/editing.md` | edit block, transitions, cards, fonts and emoji, audio, vertical |
| `references/roblox-video-specs.md` | Roblox upload limits and content rules, with sources |
| `references/worked-example.md` + `example.shots.json` | full worked example (a pet-hatching roll game, "🥚 Pet Roll") |

## Scripts
| Script | Purpose |
|---|---|
| `scripts/TrailerDriver.luau`, `scripts/CameraRig.luau` | runtime (client) |
| `scripts/build_kit.py` | rbxmx kit, eval snippets, inline payload fallback, server snippets, shot list |
| `scripts/record.py` (`record.sh` wrapper) | windows, calibrate, shot, stitch, clean |
| `scripts/edit.py` | build the cuts, preview cards, list fonts |
| `scripts/qa.py` | clip and final checks, contact sheets |
| `scripts/check_luau.sh` | luau-analyze with a Roblox-globals prelude (works without Roblox type definitions installed) |

Validate after changing scripts: `python3 -m py_compile $SK/scripts/*.py` and `$SK/scripts/check_luau.sh $SK/scripts/*.luau`.

## Known gaps (fix them here when you hit them)
- The driver can't click GUI buttons. Use the remote the button calls (`invoke`), as the hatch shot does.
- A fixed `localOffset` from a tag is a first guess; expect to adjust it after the first take of each shot.
- The player cam doesn't model mouse-wheel zoom. Use `look.dist` to change distance between beats.
- **Server setup can't `require` the live game modules**: execute_luau/eval_server_runtime get a FRESH require cache
  (measured 2026-10-11 on a pet-hatching game: `PlayerState.all()` was empty while the player was loaded). Put setup in a
  RunContext=Server Script imported next to the kit that exposes a BindableFunction, and make `server` snippets
  `:Invoke` it. Pattern: a `TrailerHook` Script (trailer only, never saved in the place) that `require`s the game's own
  modules from inside the game's server VM and creates `ServerStorage.TrailerHook` (BindableFunction,
  `:Invoke(cmd, args) -> (ok, result)`), with one small command per setup step (give cash, add an item of a given tier,
  make a timer ready, force the next roll's odds, `restore`). It saves every config value it changes and restores them
  on `restore` and when the Script is destroyed. Package it into an `.rbxmx` the same way `build_kit.py` packages the kit.
- Studio's viewport with Explorer/Properties docked is about 1.26:1 on a 1470x956 pt screen; hide the panels (or
  View > Full Screen) before calibrating, or the 16:9 crop throws away a third of the picture.
