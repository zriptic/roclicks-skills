# ROBLOX_FACTS: measured engine + tool facts for GUI work

## The two Studio MCP servers
- **`robloxstudio`** (`mcp__robloxstudio__*`): the default for everything: `get_connected_instances`,
  `execute_luau`, `import_rbxm`, `search_objects`, `get_project_structure`, `get_script_source`,
  `capture_screenshot`, `solo_playtest`, `eval_client_runtime`, `simulate_mouse_input`, `set_device_simulator`,
  `get_runtime_logs`. Load them with ToolSearch (`select:mcp__robloxstudio__execute_luau,...`).
  When several Studios are open, call `get_connected_instances` and pass `instance_id`.
- **`Roblox_Studio`** (`mcp__Roblox_Studio__*`, the built-in server): use it ONLY for `upload_image`
  (robloxstudio's `upload_asset` has no credentials: "No auth configured for Decal upload"). Say so to the
  developer each time you use it. It needs `studio_id` from `mcp__Roblox_Studio__list_roblox_studios` (a different
  id from robloxstudio's instance id).
- If no instance is connected, Studio is closed or the plugin is off: do everything up to the bundle offline
  (HTML, export, gen, mock) and ask the developer to open the place.

## Uploading images (icons, plate art)
1. Serve the files over http (the preview server already serves `ui/`): `python3 -m http.server <port>
   --bind 127.0.0.1` from `ui/`. upload_image takes **http(s) URLs only**, never local paths.
2. `scripts/ledger.py 20` prints the next 20 URLs. Call `mcp__Roblox_Studio__upload_image` with them and the
   `studio_id`. It returns `{url: assetId}`; pipe that JSON into `ledger.py` (`echo '<json>' | python3 ledger.py 20`).
3. **Batches over ~20 time out, and some files still upload**: re-run `ledger.py` without input to see what is
   really left. Never re-upload what the ledger has.
4. Uploads go to whoever Studio is logged in as / the place's owner context. **For a group game, open the
   group's place in Studio before uploading**, so assets belong to the group (assets owned by another account can
   render as nothing in the group's game). Reuse a ledger only between games with the same owner.
5. `scripts/assets.py` writes `AssetIds.luau`. Moderation can delay rendering a minute or two; the id is valid.
6. **Probe an id before relying on it** (edit mode):
   ```lua
   local VALUE = "rbxassetid://<your-image-id>"                    -- a ledger value: paste the real id
   local ID = tonumber(string.match(VALUE, "%d+"))   -- ledger values are strings; fromAssetId wants a number
   local ok, err = pcall(function() return game:GetService("AssetService"):CreateEditableImageAsync(Content.fromAssetId(ID)) end)
   return ok, err  -- "no permission to load asset" => it will render as NOTHING in this game
   ```
   Run ~200 probes in a `task.spawn` writing progress to an attribute; they outlive one request's timeout.
7. Many tiny icons: a sprite sheet (8x8 of 128 px in one 1024 px PNG) + an offset table cuts uploads to one;
   the client sets ImageRectOffset/ImageRectSize.
8. A **Decal** id renders nothing as ImageLabel.Image or Beam.Texture; you need the **Image** id (upload_image
   returns image ids).

## Pushing Luau
- **Never `set_script_source` / `edit_script_lines`**: they expand `\n` inside strings ("Malformed string") while
  reporting success. Bundle as `.rbxmx` (`scripts/bundle.py`, or `scripts/luau_to_rbxmx.py in.luau out.rbxmx Name
  ModuleScript`) and `import_rbxm {source:{path:<absolute>}, parent_path:"game.ServerStorage"}`. Source goes disk
  -> Studio without passing through the conversation.
- **`require` caches across `execute_luau` calls**: after re-importing a module, destroy the old one first (or
  rename) or you run stale code. `require` from execute_luau gives a fresh edit-context copy, not the running
  game's instance: read runtime state through attributes.
- **A plugin context cannot POST** (`HttpService.HttpEnabled` can't be set from it): return compact strings from
  execute_luau and parse them locally.
- **Tool calls in one message are not ordered**: a destroy and an import (or a camera move and a capture) raced.
  Sequence them across calls, or do both inside one execute_luau.

## Coordinates and input
- Studio's top-bar inset is **58 px**. A full-screen `IgnoreGuiInset` root reports AbsolutePosition (0,-58);
  `InputObject.Position` is in GUI space, so world picks use `input.Position - root.AbsolutePosition`.
- **For this skill's ScreenGui (IgnoreGuiInset = true): click at `AbsolutePosition + AbsoluteSize/2` plus 58
  on Y** (measured: the input arrives 58 px higher than the value passed; an older note said no correction is
  needed with IgnoreGuiInset; the measurement won). Confirm the space once by arming `UserInputService.InputBegan`
  and comparing. `MouseEnter`/`MouseLeave` never fire from synthetic input (call hover code directly).
- `capture_screenshot` returns a 2x retina image; its pixels are not click coordinates.
- `ScreenPointToRay` takes GUI space (`input.Position`, touches); `ViewportPointToRay` takes viewport space
  (`UserInputService:GetMouseLocation()`). Mixing them was 58 px off.
- Escape is bound to the Roblox menu; tools can't inject it.

## Text
- TextSize = line height: CSS font-size x 1.215. Integer, max 100.
- Runs of spaces render in full (HTML collapses them).
- `TextFits` is false for overflowing text; `TextBounds` is the real ink box. Check fit by `TextBounds.X`, not
  the label size. TextScaled caps (UITextSizeConstraint) are in screen pixels.
- `Font.fromEnum(Enum.Font.Arcade)` is Press Start 2P.

## Layout
- UIStroke thickness **scales with an ancestor UIScale** (measured late 2026; older docs say it doesn't).
- ScrollingFrame children's Scale resolves against the CANVAS; Scale rows + AutomaticCanvasSize collapse or
  explode. Use pixel rows from the list's AbsoluteSize and Offset padding; recompute on AbsoluteSize change.
  CanvasSize Scale resolves against the ScrollingFrame's parent.
- Clearing all children also removes UIScale/UIListLayout/UICorner children: skip UI* classes.
- Sibling ZIndexBehavior: ZIndex orders siblings only; a cloned template keeps ZIndex 1 and draws behind the art
  it was dropped next to. Use Sibling, never Global, when world sprites use big ZIndex values.
- `GuiService.TopbarInset` is the area Roblox's own buttons occupy; it settles after startup and changes on
  phones. Re-place HUD corners on its change signal.
- PlayerGui is rebuilt on respawn for ScreenGuis with ResetOnSpawn = true: set it false.
- BillboardGui: clips content to its Size even with ClipsDescendants off; Size in studs shrinks with distance;
  StudsOffset is camera-space (+Z toward the camera); buttons on billboards get no clicks under a full-screen
  ScreenGui; AlwaysOnTop billboards did not draw in some playtests; captures never show billboards.
- A CanvasGroup rendered before its images load stays blank: preload first.

## Studio captures and verification
- `capture_screenshot` during a playtest sometimes returns solid magenta; in edit mode it shows only the 3D
  viewport (no ScreenGui). Never conclude "the UI is broken" from a magenta frame. It did capture full GUIs in
  some playtests: try once, then verify by properties.
- From a plugin context `PreloadAsync` reports Failure for every rbxassetid and `IsLoaded` stays false in
  StarterGui: verify images in a playtest client or by the probe above.
- `PreSimulation`/`Heartbeat` don't tick in edit mode: harness code must be driven directly.
- An unfocused Studio window renders at exactly 15 fps (timings in edit-mode tests look slow).
- Device emulation: `mcp__robloxstudio__set_device_simulator` (phone profiles) for a playtest; for edit-mode
  sweeps, resize `Root` + `FitScale` (PropertySweep.atSizes) instead.

## Playtests
- A running playtest may belong to another agent working on the same place: check before `eval_client_runtime`
  or `simulate_mouse_input`. If the team uses a lock attribute (e.g. a `PlayLock` attribute on Workspace), set it
  before you start and clear it after; never take over someone else's.
- Stop every playtest you start. The developer often plays right after an import: only playtest when needed.
- `solo_playtest` then `get_runtime_logs` for errors; `eval_client_runtime` to read the client's PlayerGui.
