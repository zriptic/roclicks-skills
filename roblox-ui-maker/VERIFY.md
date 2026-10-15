# VERIFY: proving the Roblox UI matches the approved HTML

Studio cannot be trusted to show a GUI: playtest captures can come back solid magenta, edit-mode captures
render only the 3D viewport, BillboardGuis never appear in captures. So verify with NUMBERS first, pictures
second. Run these in order; report each result to the developer.

## 1. Offline mock (before Studio)
`python3 $SK/scripts/mock.py && node $SK/scripts/mockshot.mjs` re-renders the generated Data with Roblox
semantics and scores it against the HTML. Healthy: mean 1-3 /255 per screen. Read `rbx/out/mock/cmp_<S>.png`
(HTML / mock / heatmap) for any screen above ~4: the heat shows where (missing art, gradient angle, stroke).

## 2. Build checks (edit mode, right after build)
```lua
-- every image has an id (empty = not uploaded or AssetIds stale)
local gui, empty = game.StarterGui.GameUI, {}
for _, d in gui:GetDescendants() do
  if (d:IsA("ImageLabel") or d:IsA("ImageButton")) and d.Image == "" then table.insert(empty, d:GetFullName()) end
end
return #empty .. " empty images\n" .. table.concat(empty, "\n", 1, math.min(#empty, 20))
```
- Fit pass results (`Builder.fit()` twice, gui Enabled): second run's worst <= ~2%.
- Probe asset ids you did not upload this session (ROBLOX_FACTS.md "Probe an id"): another owner's id renders
  as nothing.

## 3. Property sweep (objective layout check)
Import `templates/luau/PropertySweep.luau` (in the bundle folder) and run on a clone, at PC and phone sizes:
```lua
local Sweep = require(game.ServerStorage.GameUIBuild.PropertySweep)
local g = game.StarterGui.GameUI:Clone(); g.Archivable = false; g.Enabled = true; g.Parent = game.StarterGui
for _, s in g.Root:GetChildren() do if s:IsA("Frame") and s.Name ~= "Dim" then s.Visible = true end end
task.wait(0.5)
local out = Sweep.atSizes(g.Root, { Vector2.new(1920, 1080), Vector2.new(1366, 768), Vector2.new(844, 390) },
  { minTap = 44, touch = true })
g:Destroy()
return out
```
Read every line: `TEXT_NOFIT` (text overflows: widen the box in HTML or shorten copy), `TEXT_SUSPECT` (raw id,
"?", "nil"), `TAP_SMALL` (< 44 screen px on the phone size), `CLIPPED`, `OVERLAP` (two buttons on top of each
other), `IMG_NOTLOADED` (judge per asset: offscreen instances read false; in edit mode IsLoaded is unreliable,
use the probe), `BILLBOARD`. 844x390 is a landscape phone.

## 4. Edit-mode mock harness (drive the runtime API without a playtest)
Clone the ScreenGui, require THE CLONE's UI module, drive it, sweep, then `UI.destroy()` and destroy the clone.
```lua
local g = game.StarterGui.GameUI:Clone(); g.Name = "GameUI_Harness"; g.Archivable = false
g.Enabled = true; g.Parent = game.StarterGui
local UI = require(g.UI)          -- the clone's module: require caches by instance, so a clone is fresh
UI.init(g)
UI.open("Shop")
local NF = require(g.NumberFormat)
UI.setText(g.Root.HUD, "CashText", NF.cash(1250))
task.wait(0.6)                    -- let tweens settle (an unfocused Studio window runs at 15 fps)
local cash = g.Root.HUD:FindFirstChild("CashText", true)
local report = string.format("open=%s cash=%q dim=%s", tostring(UI.current()), cash.Text, tostring(g.Root.Dim.Visible))
UI.close(); UI.destroy(); g:Destroy()
return report
```
Rules: everything the harness creates gets `Archivable = false` (harness runs once saved sound pools and
attachments into the place). PreSimulation/Heartbeat don't tick in edit mode: call update functions directly.

## 5. Playtest (only when needed: input changes, real data, sounds)
1. Check nobody else is playtesting (another agent may own the running session); take the team's play lock if
   there is one, release it after.
2. `solo_playtest` start; `get_runtime_logs` (no errors, no warnings from the UI module or Builder).
3. Try `capture_screenshot` once; if magenta, continue by properties.
4. Real clicks: read the target in the client (`eval_client_runtime`):
   `local b = game.Players.LocalPlayer.PlayerGui.GameUI.Root.HUD:FindFirstChild("ShopButton", true); return b.AbsolutePosition + b.AbsoluteSize/2`
   then `simulate_mouse_input` at that point **+ 58 px on Y** (the inset; confirm once by arming
   `UserInputService.InputBegan` and comparing). Verify the EFFECT (`UI.current()` == "Shop"), not just the click.
   Hover can't be tested by synthetic input: call the hover code directly.
5. Rapid input: 4 quick clicks on a "+1" button must give 4 results (rebuild-eats-taps bug).
6. Phone: `set_device_simulator` to a phone profile, re-run the sweep in the client, check tap targets, the top
   bar inset (no HUD under Roblox's buttons), thumb zones.
7. Stop the playtest; clear the lock.

## 6. Updating panels in place
When a list/panel refreshes (timers, live prices), it must update existing rows, not rebuild them:
- Build once; rebuild only when the structure signature (keys + lock states, NO live numbers) changes
  (`templates/luau/UpdateInPlace.luau`).
- Never refresh hidden panels; per-second refresh only for timers; skip rebuilds while a spin/tween runs.
- Test: hold a button down across a refresh tick; it must still fire on release. Watch for hover scale resetting
  every second (= a rebuild).

## Checklists
**New screen (HTML)**
- [ ] Style tokens come from the reference (style.css), stud preset by default
- [ ] One shared component per element type; same treatment for siblings
- [ ] Icons from your one icon pack only (outline variants), close = text X
- [ ] Every state drawn: normal / hover / pressed / locked / unaffordable / owned / empty / full / error / longest text
- [ ] Phone layout: targets >= 124 design px, body text >= 26, Roblox controls kept clear, every action reachable
- [ ] In context over a real capture of the game (or the stand-in world) at realistic size
- [ ] `?check` clean: no overflow, no broken images
- [ ] Live labels named (`name=`), runtime-toggled pieces `hid`, one open + one locked example per list
- [ ] No double quotes inside inline styles; no element named after a GuiObject property
- [ ] Shown to the developer and approved

**Import**
- [ ] export -> gen -> mock scores 1-3 -> ledger all uploaded -> assets.py -> bundle -> build -> fit x2
- [ ] No empty images, sweep clean at 1920x1080 / 1366x768 / 844x390
- [ ] luau-analyze on client files (no syntax errors)
- [ ] Copies in sync (check_copies.py), runtime changes logged in the game's RUNTIME_UI notes

**Runtime wiring**
- [ ] Opening a screen refreshes it with real data (no mock values leak)
- [ ] All close paths (X, Esc, B, scrim) run the same close action; selection cleared
- [ ] No world clicks while a panel is open; hotkeys respect modes
- [ ] Toasts dedupe, dock when panels open, never cover a close X
- [ ] Popups queued and suppressed during tutorial/placement/banners
- [ ] Numbers via NumberFormat; plurals/articles via UIKit; zero rewards hidden; errors name the blocker
