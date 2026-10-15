# TrailerDriver + CameraRig: shots.json schema and runtime API

Both modules are generic: tags, paths, remotes and prompt text all come from `shots.json`.
Validate after any edit with `scripts/check_luau.sh scripts/*.luau`.

## Getting them into a playtest

Recommended: the kit, which is imported once and never pasted.
1. `python3 scripts/build_kit.py rbxmx --shots <game>/trailer/shots.json` writes `trailer/TrailerKit.rbxmx`
   (ModuleScripts TrailerDriver, CameraRig and Shots, the last being shots.json embedded).
2. In EDIT mode, destroy any old `ReplicatedStorage.TrailerKit`, then `import_rbxm` the file into ReplicatedStorage.
3. Start the playtest (`solo_playtest start mode=play`, or `multiplayer_playtest start numPlayers=2` for social shots).
4. `build_kit.py call --shots ... --shot s02_roll` prints a short snippet; send it with `eval_client_runtime`.
   The snippet requires fresh clones, so a re-imported kit always wins over the eval VM's require cache.
5. When done: stop the playtest, delete `ReplicatedStorage.TrailerKit` in edit mode, and never save the place with it.

Fallback: `build_kit.py payload --shot s02_roll --out p.luau` writes one self-contained chunk (about 48 KB) for
`eval_client_runtime`. Use it only if import_rbxm is unavailable.

## Runtime API (client)
| Call | Returns / does |
|---|---|
| `D.run(shot, {rig=CameraRig, delay=6, actor="client-1", hold=0, keep=false})` | `{ok, shot, actor, startsAtMs, endsAtMs, dur}` straight away. The first frame is posed and held during `delay`; the timeline starts at `startsAtMs` (unix ms, the same clock as the Mac). Cleans up after `dur` (+`hold`). |
| `D.stop()` | Stops any run (even one started from another eval VM, through the marker `LocalPlayer.__TrailerRig`) and restores everything. Safe to call at any time. |
| `D.status()` | `{running, shot, startsAtMs, endsAtMs, error, last}`. `last` is the previous run's end reason and action log (attribute `TrailerLast`). |
| `D.calibrate(secs, {r,g,b}?)` | Full-viewport flat cyan (default) with the top bar and CoreGui hidden, for `record.py calibrate`. |
| `D.hud(bool)`, `D.chrome(bool)` | Manual game-HUD or Roblox-chrome toggle. |
| `CameraRig.evaluate(spec, t, resolve?)` | `(CFrame, fov, blur01)`, pure. |
| `CameraRig.play(spec, {onDone, resolve, keepCamera})` / `CameraRig.playOn(signal, spec, {arg1, delay})` | Standalone cinematic playback, optionally started by a game event. |

What a run changes and restores: CameraType/Subject/FOV, each PlayerGui ScreenGui's `Enabled`, every
CoreGuiType, `TopbarEnabled`, `MouseIconEnabled`, PlayerModule controls (disabled so the keyboard can't fight
MoveTo), Humanoid AutoRotate/WalkSpeed, and a `Lighting.__TrailerBlur`. A new `run` always stops the old one first.

## Targets (anywhere a position or object is wanted)
`[x,y,z]` · `{pos=[x,y,z]}` · `{path="Workspace.Map.Lever"}` · `{tag="RollStage"}` (the nearest one to the character
unless `index` or `nearest=false`) · `{tag="TradePad", attrs={Side="A", Action="Add"}}` · `{player="self"|"other"|"Name"}`.
Modifiers: `child="PartName"` (a descendant), `localOffset=[x,y,z]` (studs in the target's own frame), `offset=[x,y,z]` (world).
Start with `localOffset` from a tag and correct it after one test take.

## shots.json
```json
{
  "game": "Name", "title": "Title card text",
  "record": { "preroll": 1.0, "tail": 0.6, "delay": 6 },
  "shots": [ { shot }, ... ],
  "edit": { ... see editing.md ... }
}
```
### shot
| key | meaning |
|---|---|
| `id` | stable id, `[A-Za-z0-9_-]`; names the clip |
| `kind` | `gameplay` (player cam, HUD on), `cinematic` (rig camera, HUD off), `prep` (runs the game setup, leaves the camera alone, isn't recorded) |
| `dur` | seconds of action to record |
| `hud` | override the HUD default; `coreGui: true` keeps chat and the player list (rarely wanted) |
| `start` | `{at: target, face: target, lift: 3}`: teleported before the delay, so the preroll frames are clean |
| `player` | player-cam settings: `dist 13, height 2.4, pitch -16, lag 7, yawLag 2, drift 1, tremor 1, glances true, fov 70, yaw (fixed deg), collide true` |
| `camera` | opening camera: a CameraRig spec, or `{preset:"player"}` (default) |
| `timeline` | events: `{t: secs, do: action, ...}` or `{on: trigger, do: action, ...}` |
| `actors` | `{"client-2": {start, timeline, camera?}}`: a second player's script, run on that client with `actor="client-2"` |
| `server` / `server_after` | Luau string or list of lines for `eval_server_runtime`, run before and after the take (give items, force a timer, restore config) |
| `seed` | changes the hand-held drift and glance pattern for a retake |
| `needs_players` | documentation only: use multiplayer_playtest |

### actions (`do`)
| action | args |
|---|---|
| `walk` | `to` or `path:[targets]` (each may carry `jump:true`), `speed`, `pathfind`, `jitter` (studs of human wobble), `reach` 1.5, `timeout` 12 |
| `jump` | none |
| `face` | `target`, `time` 0.35 (smooth turn of the character) |
| `look` | player cam: `yaw`/`pitch` (deg, relative), `time`, `overshoot` (0-0.15), `target` (keep aiming), `release`, `dist` |
| `prompt` | `match` (ActionText/ObjectText/Name substring), `near` target, `radius` 25, optional `path`/`tag` root, `hold` secs. Uses `ProximityPrompt:InputHoldBegin/End`, which works with custom-styled prompts too. |
| `invoke` / `fire` | `remote` path, `args` list. `"$attr:Name"` inside args becomes `LocalPlayer:GetAttribute("Name")`, so server setup can pass item ids. `save` keeps the result. |
| `bindable` | `path` to a BindableEvent or BindableFunction, `args` |
| `equip` | `tool` name from the Backpack |
| `teleport` | `to`, `face`, `lift` |
| `camera` | `{preset:"player", blend}` or `{spec:{CameraRig spec}, blend}` (blend = seconds of crossfade) |
| `hud` | `show` true/false |
| `attr` | `path`, `name`, `value` (client-side attribute) |
| `emit` | `cue`, which fires a local cue that `{on:{cue}}` events can wait for |

### triggers (`on`), for syncing to game events
`{event:"ReplicatedStorage.Remotes.Reveal", arg1:"Roll"}` (RemoteEvent OnClientEvent, or a BindableEvent) ·
`{childAdded:"Workspace.Hatching", name:"pattern"}` · `{tagAdded:"Tag"}` · `{attribute:{path, name}}` · `{cue:"name"}`.
Plus `delay` (secs) and `once` (default true).

### CameraRig presets (`spec.preset`)
| preset | fields |
|---|---|
| `dolly` / `spline` / `flyover` | `points:[targets]` (Catmull-Rom, constant speed), `look: target | "ahead"` |
| `bezier` | `points:[p0,p1,p2,p3]`, `look` |
| `orbit` | `center`, `radius`(→`radius1`), `height`(→`height1`), `from` deg, `sweep` deg, `lookHeight` |
| `crane` | `center`, `angle`, `dist0→dist1`, `h0→h1`, `lookH0→lookH1` (low and close, rising to a reveal) |
| `pushin` | `center`, `from` target or `angle`+`rise`, `dist0→dist1`, `lookHeight` |
| `whip` | `pos`, `fromLook`, `toLook`, `whipAt` (fraction of dur), `whipLen` secs, `whipEase`, `blurMax` 18 (motion blur peaks mid-whip) |
| `static` | `pos`, `look` |
All take `dur`, `ease` (`sineInOut` by default; any TweenService style + In/Out/InOut, e.g. `quintOut`, `linear`),
`fov` or `fov0→fov1`, `roll` deg, and `shake {amp 0.12, freq 0.5, seed}` (subtle hand-held).

## Why the player cam looks hand-played
- Focus follows the character through a spring (`lag`), so starts and stops have a soft lead and lag.
- Yaw swings behind the character only **while moving**. Standing still, it holds, as a real player's camera does.
- Slow Perlin drift (yaw ±6°, pitch ±2.5°), a tiny tremor, and seeded "glances" every 3.5-7 s (±7-20°, ease in, hold, ease back).
- `look` turns ease like a mouse flick with optional overshoot. The camera never snaps.
- It raycasts against walls like the default camera.
Robotic? Raise `drift`, lower `yawLag`. Seasick? Set `drift 0.5`, `glances false`.
