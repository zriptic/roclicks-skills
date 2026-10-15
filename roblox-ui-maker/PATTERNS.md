# PATTERNS: proven screens, HTML side + Luau side

HTML examples live in `templates/examples/build.py` (function names below); Luau in `templates/luau/`.
All HTML uses the kit components (`T`, `I`, `icn`, `plate`, `panel`, `grp`, `sub`, `box`, `bar`, `badge`,
`closeb`) and names live parts with `name=` so runtime finds them. All runtime looks come from templates.

## HUD (`s_hud`, `hud_groups`)
HTML: `grp('Currencies', ..., 'BL')` cash icon + `CashText` (`.l`, `f-green`, "$" prefix) and gems;
`grp('LeftButtons', ..., 'L')` side buttons = `sub(name, icon + label + hidden Badge, btn=True, opens='Shop')`;
`grp('Goal', goal_pill(), 'T')`. Quiet: only per-second info. A phone variant (`s_hud_phone`) with bigger targets
and dashed Roblox controls.
Luau: `UI.countTo("cash", n, hud, "CashText", NumberFormat.cash)`; badges only from data:
```lua
local function setBadge(btn: Instance?, text: string?)
	local b = btn and btn:FindFirstChild("Badge", true)
	if not b then return end
	UIKit.show(b, text ~= nil)
	if text then UIKit.set(UIKit.find(b, "BadgeText"), text) end
end
setBadge(hud:FindFirstChild("ShopButton", true), if canAffordNewItem then "!" else nil)
```
Reveal pieces as they matter (`ProgressiveReveal.luau`): rules name exported elements (`GemsIcon`, `GemsText`,
`CratesButton` ... anywhere under the HUD), `decide(state)` -> `ProgressiveReveal.apply(hud, visible)` (hides
them; a UIListLayout or your own re-layout closes the gaps). Whole top-level groups: `UI.setGroupHidden("Goal", true)`.

## Shop: tabs + cards (`s_shop`, `card`)
HTML: `panel('Shop', title, colour, icon, body)` (glass + stud header + red text-X close). Tabs: each is
`sub('TabItems', On plate + Off plate, btn=True)`; the active tab's `Off` and the others' `On` are `hid`, so
runtime switches tabs by toggling Visible. Cards in four states, each its own named example: `Card_open` (green
price plate `BtnBuy` + coin + `Price`), `Card_owned` (grey `.off` "Owned" `BtnOwned`), `Card_locked` (`.dim`
tile, `Lock`, red `Desc` naming the unlock), `Card_poor` (grey plate, white price, red `Short` "Need 950 more").
Labels: `ItemName`, `Desc`, `Price`, `Short`; icon `Icon`. NOTE: on `Card_locked` the icon is greyed by a CSS
filter, so it is exported as baked art (a Frame "Icon" with an `Art` image), not a swappable ImageLabel; for
per-item locked icons, use a plain icon + `data-col`/ImageColor3 dimming in the HTML instead.
Luau: the four examples are prototypes. Hide them, clone the one matching each item's state into the example
slot positions (`slotPos[i]`; more items than slots -> make the body a ScrollingFrame and use PixelRows), and
rebuild a card only when its state changes:
```lua
local body = gui.Root.Shop:FindFirstChild("Card_open", true).Parent
local proto, slotPos = {}, {}
for i, n in { "Card_open", "Card_owned", "Card_locked", "Card_poor" } do
	local c = body:FindFirstChild(n) :: GuiObject
	proto[n], slotPos[i] = c, c.Position
	c.Visible = false
end
local cards: { [string]: GuiObject } = {}          -- item id -> live card
local function stateOf(it, cash: number): string
	if it.owned then return "Card_owned" end
	if it.lockedReason then return "Card_locked" end
	return if cash < it.price then "Card_poor" else "Card_open"
end
local function render(items, cash: number)
	for i, it in items do
		local st = stateOf(it, cash)
		local c = cards[it.id]
		if not c or c:GetAttribute("State") ~= st then  -- structure changed: rebuild this card only
			if c then c:Destroy() end
			c = proto[st]:Clone()
			c.Name, c.Visible, c.Position = "Card_" .. it.id, true, slotPos[i]
			c:SetAttribute("State", st); c:SetAttribute("ItemId", it.id)
			c.Parent = body
			cards[it.id] = c
			local buy = UIKit.find(c, "BtnBuy")
			if buy then
				UI.juicy(buy :: GuiButton)
				local id = it.id
				local btn = buy :: GuiButton
				btn.Activated:Connect(function() tryBuy(id) end)  -- server decides; on "poor" toast the shortfall
			end
		end
		UIKit.set(UIKit.find(c, "ItemName"), it.name)    -- every refresh: cheap writes only
		UIKit.set(UIKit.find(c, "Desc"), it.lockedReason or it.desc)
		UIKit.set(UIKit.find(c, "Price"), NumberFormat.short(it.price))
		UIKit.set(UIKit.find(c, "Short"), "Need " .. NumberFormat.short(it.price - cash) .. " more")
		UIKit.icon(UIKit.find(c, "Icon"), it.icon)        -- no-op on the locked card (baked art)
	end
end
-- tabs
for _, tab in { "TabItems", "TabGems", "TabPasses" } do
	local b = gui.Root.Shop:FindFirstChild(tab, true) :: GuiButton
	b.Activated:Connect(function()
		for _, other in { "TabItems", "TabGems", "TabPasses" } do
			local o = gui.Root.Shop:FindFirstChild(other, true)
			o:FindFirstChild("On").Visible = other == tab
			o:FindFirstChild("Off").Visible = other ~= tab
		end
		-- then render(itemsFor(tab), cash)
	end)
end
```
(For long homogeneous lists use `UpdateInPlace.luau`: one template, keyed rows, `fill` + `wire`.)

## Crate opening: single reel + odds (`s_crate`, `s_crate_odds`, `CrateRoll.luau`)
- The SERVER rolls (weights + pity) and grants first. The client builds a reel strip AROUND the known prize
  (`CrateRoll.reelPlan`): ~40-60 tiles, prize at `landing`, the tile after it one rarity better (cosmetic
  near-miss only; never rigged pity tricks).
- HTML: `grp('Reel', 'C')`: dark strip with gold lines, rarity tiles 190 px + 16 gap, edge fades, gold
  triangle markers ABOVE and BELOW the centre; **nothing is drawn over the prize**. Title `grp('CrateTitle','T')`,
  `grp('SkipHint','B')` "Tap to skip".
- Motion: shake the crate ~1.25 s -> burst (flash, ring, particles) -> spin ~5 s first time / ~3.6 s for repeats,
  `Quint Out` to an overshoot of ~0.35 tile then `Back Out` to the final offset (`CrateRoll.reelOffsets`); a tick
  sound and marker wiggle per tile crossing; landing dims the others, pops the prize 1.1x with a rarity glow; tap
  skips straight to the landing. x3 spins the same line three times into a tray.
- Reveal card: rarity header ("RARE!"), rays + sparkles scaled by rarity, name, amount, Claim button (never
  auto-claim), "Open again" with price. Blur the world with a BlurEffect on the CAMERA, not Lighting.
- Odds popup (`s_crate_odds`): one row per reward (mini tile, name, rarity, %), a split bar, the pity rule in
  words. Generated from the SAME table the server rolls from. Check `PolicyService:GetPolicyInfoForPlayerAsync`
  `ArePaidRandomItemsRestricted` before offering paid crates.
- Reel tiles at runtime: clone the exported `Prize` tile (or `Tile1..`) from the CrateOpen `Reel` group for each
  entry of the plan, set its rarity look (export one tile per rarity on templates.html as `Tile_common` ...
  if colours must change) and lay them out every 206 px; scroll the strip, not each tile.
- `CrateRoll.luau` is SHARED (server rolls, client builds the reel, the odds popup reads the same table): put it
  in ReplicatedStorage, not in luau_out.
- Queue reveals: a result arriving mid-reel waits; never close a running reel.

## Toasts (`toast` on templates.html, `client/Toasts.luau`)
Templates `Toast_info|good|error|cash`: coloured stud plate holding `Icon`, glass body, `Msg1`, countdown bar
`Time` (fill F).
```lua
local Toasts = require(gui:WaitForChild("Toasts"))
Toasts.init(UIKit)                                   -- makes the stack in UIKit.overlay(), scaled to the screen
Toasts.show("Need 950 more coins", { kind = "error", icon = "warning" })
Toasts.merged("coins", 25, function(n) return "+" .. NumberFormat.short(n) .. " coins" end, 2)
UI.PageChanged:Connect(function(name) Toasts.dock(name ~= nil) end)
```
Rules: ~40 chars, one verb; 3.5 s (6 s over 50 chars); dedupe identical text (pulse + restart); max 4;
under the tutorial card; while a panel is open dock bottom-right at 0.6 scale, newest 2; never over a close X.

## Confirm dialog (`confirm` on templates.html)
One parameterised dialog: `Confirm` template with `Title`, `Body1`, `Body2`, `BtnYes`/`YesText`, `BtnNo`/`NoText`,
`CloseButton`.
```lua
local function confirm(o: { title: string, text: string, yes: string, no: string?, onYes: () -> () })
	local t = UIKit.template("Confirm")
	local scrim = UIKit.template("Scrim")
	if not (t and scrim) then return end              -- look templates up BEFORE making any blocker
	local l1, l2 = UIKit.wrap2(o.text, 34)
	UIKit.set(UIKit.find(t, "Title"), o.title)
	UIKit.setLines(t, "Body", { l1, l2 or "" }, 2)
	UIKit.set(UIKit.find(t, "YesText"), o.yes)
	UIKit.set(UIKit.find(t, "NoText"), o.no or "Cancel")
	local overlay = UIKit.overlay()
	scrim.Size = UDim2.fromScale(1, 1)
	scrim.Active = true                               -- clicks on the scrim never reach the world
	scrim.Parent = overlay
	t.AnchorPoint = Vector2.new(0.5, 0.5)
	t.Position = UDim2.fromScale(0.5, 0.5)
	UIKit.scaled(t)
	t.Parent = overlay
	local function done() scrim:Destroy(); t:Destroy() end
	local yes = UIKit.find(t, "BtnYes") :: GuiButton
	yes.Activated:Connect(function() done(); o.onYes() end)
	for _, n in { "BtnNo", "CloseButton" } do
		local b = UIKit.find(t, n) :: GuiButton
		b.Activated:Connect(done)
	end
end
```
State the real consequence with server numbers ("You get 120 coins back"). Esc/B run the same close.

## Loading screen (`LoadingScreen.client.luau`)
LocalScript in ReplicatedFirst (NOT in luau_out: bundle.py refuses root .client.luau files). Its child
`LoadingGui` is a ScreenGui holding a clone of the `Loading` template (templates.html: `Title`, bar `LoadBar`
with fill `F`, `Status`) plus a UIScale; make it once in Studio after the templates build (execute_luau:
clone `ReplicatedStorage.<Templates>.Loading` into a new ScreenGui under the script). It then:
`RemoveDefaultLoadingScreen()`, progress from the player attribute `LoadStage` (0-1, set by the main client as
boot steps finish), fade on `ClientReady`, hand over to an intro without a flash (`IntroWillPlay`), and a 75 s
safety timeout so a client error never traps the player.

## Tutorial card + pointer
HTML (templates.html): `TutorialCard` (glass, "STEP n", one instruction line <= 6 words, hint, progress dots,
Skip), `TutorialArrow` (pack arrow icon), highlight ring.
Luau rules (see LESSONS 21): full size top-centre for ~5 s then compact; bottom-centre 0.62 while a screen is
open; hidden under modals. Pointer target resolved every frame from STATE:
```lua
local function uiTarget(step)
	local open = UI.current()
	if open and not step.uses[open] then return gui.Root[open]:FindFirstChild("CloseButton", true) end -- wrong panel: point at its X
	return gui.Root:FindFirstChild(step.button, true)   -- by name, never by GetChildren order
end
-- arrow: beside the target if it is near the top edge (point toward screen centre), below it inside panels,
-- else above; the ring sits on the button edge, never over its text. Hide both when the target isn't visible.
```
Each step pays once, out-of-order actions count, and 1.1 s after a step completes close screens the next step
doesn't use.

## Building bubble (tap a world object)
One bubble (template) above the object: title + level, a one-line state ("Upgrading 0:42"), ONE big context
button (Upgrade / Repair / Rebuild / Finish) showing the cost (+ "starts in Xs" when workers are busy), small
Move / Rotate / Remove buttons (Remove becomes "Sure?" on the button itself), a preview line
("+0.9/s -> +1.35/s Wood"). Placed with `UIKit.worldLabel` (studs-sized, grows up, camera-space lift);
closes when tapping elsewhere; never covers the top tabs; hides the goal pill while open.

## Upgrade preview
Always "before -> after", computed from the SHARED formula module the server uses (never from card text),
refreshed on level/state/tier change. At the cap: "Max for Tier N" + "Reach Tier N+1 to upgrade", not "Max level".

## Tier checklist
A tier chip ("T3") on the goal pill toggles a checklist panel: header (medal + "Tier 3: Name"), one row per
requirement (pack check or X icon, label, status "Done" / "420 / 700" / "Lab"), the current blocker outlined
gold, footer "Unlocks: ...". Stays live while open; tap outside or the chip to close. Gate nodes in trees get a
TIER tag and a halo on the next gate; pressing a gate while short toasts exactly what's missing.

## Next-goal pill (`goal_pill`, `NextGoal.luau`)
HTML: glass box, gold "NEXT" mini plate with a target icon, `GoalIcon`, `GoalText`, `GoalCount`, `GoalBar`
(fill F). Ready state: green "READY" plate (export as a `hid` variant).
Luau: ordered rules, first unmet wins, computed from shared formulas:
```lua
local function renderPill(g)                       -- g = NextGoal.resolve(state, config)
UI.setGroupHidden("Goal", g == nil)
if not g then return end
UIKit.set(UIKit.find(hud, "GoalText"), g.text)
UIKit.show(UIKit.find(hud, "GoalCount"), g.need ~= nil)
if g.need then UIKit.set(UIKit.find(hud, "GoalCount"), NumberFormat.short(g.have or 0) .. " / " .. NumberFormat.short(g.need)); UIKit.bar(UIKit.find(hud, "GoalBar"), (g.have or 0) / g.need) end
end
-- refresh on state change (keyed by g.id..have..need, see NextGoal.luau); GoalPill.Activated ->
-- Actions[g.action](g.arg); a separate 1 s loop updates only the countdown text when g.endsAt is set
```
Walk the exact blocker ("Get 700 Iron for Tier 3 420/700", "Lab busy: X finishes first 2:39"); hide during the
tutorial and while a bubble is open.

## Number formatter (`NumberFormat.luau`)
`full` (1,234,567), `short` (1.23K, 250K, 999K, 1M; truncates; strips zeros only after a decimal point),
`cash` ("$1.36K", "-$2.5K"), `rate` ("1.35/s"), `time` ("1:15", "1:02:05"), `_test()` (run after any change).
One module for the whole game; delete any other formatter.

## Update-in-place lists (`UpdateInPlace.luau`, `PixelRows.luau`)
```lua
local list = UpdateInPlace.new(container, rowTemplate, fill, wire)
UpdateInPlace.render(list, items)   -- items = { {key=..., locked=...}, ... }; call on every data change
```
Rows rebuild only when the key set / lock states change (structure signature, no live numbers); otherwise
`fill` writes labels into existing rows. `wire` connects buttons once per row. Scrolling lists: pixel-height
rows from the list's AbsoluteSize (`PixelRows.bind(list, visibleRows, gap)`), Offset padding,
`AutomaticCanvasSize = Y`; never Scale rows with AutomaticCanvasSize.

## World hit-testing (`WorldHitTest.luau`)
Forgiving picks for world labels/buildings: min pick box 56 px touch / 34 mouse, padding 12/4, direct hit beats
padded, nearest within 34/16 px as fallback; tap = moved < 7 px (mouse) or < max(14, 2.5% short side) (touch),
within 0.5 / 0.65 s, no second finger, not claimed by UI.
