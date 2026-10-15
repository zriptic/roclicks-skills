--!strict
-- UIKit: the template-usage contract. Every runtime UI element (toast, confirm, tutorial card,
-- billboard, list row ...) is an approved template designed in HTML and built by Builder into
-- ReplicatedStorage.<TemplatesFolder>. Game code clones and fills; it never builds look with
-- Instance.new. Copy into <luau_out>/UIKit.luau (Builder ships it inside the ScreenGui too).
--
--   local K = require(PlayerGui.<Gui>.UIKit)
--   K.init(gui:GetAttribute("TemplatesFolder"), gui.AssetIds)   -- once (Controller does it)
--   local t = K.template("Toast_info")          -- clone (nil + warn if missing: check BEFORE blocking input)
--   K.set(K.find(t, "Msg1"), "Saved!")          -- sets the label AND its nearest "Msg1Shadow" twin
--   K.icon(K.find(t, "Icon"), "coin")           -- icon slug from AssetIds.icons (+ "IconShadow" twin)
--   K.bar(K.find(t, "Bar"), 0.4)                -- Bar frame with fill child "F"
--   K.scaled(t)                                 -- adds UIScale = K.uiScale() (design px -> screen)
--   t.Parent = K.overlay()                      -- the ONE overlay ScreenGui for runtime UI
--   K.plural("Fisherman", 3) / K.article("egg") / K.wrap2(text, 34) / K.showPair(icon, label, on)
--
-- Contract every template follows (PIPELINE.md "Template contract"):
--   * Frame at (0,0) sized in design px; pressable parts are TextButtons with attribute Button = true
--   * live labels have a data-n name in the HTML; drop shadows are "<Name>Shadow" twins
--   * bars: frame "Bar" (or any name) with a fill child "F"; FullW cached as an attribute
--   * state children (sample buttons, key caps, "current" rings) are stripped with K.strip
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local K = {}
local folderName: string? = nil -- K.init, else the main gui's TemplatesFolder attribute (set by Builder)
local assets: any = nil

function K.init(templatesFolder: string?, assetIds: Instance?)
	folderName = templatesFolder
	if assetIds and assetIds:IsA("ModuleScript") then assets = require(assetIds) :: any end
end

local function folder(): Instance?
	if not folderName then
		for _, g in K.playerGui():GetChildren() do
			local n = g:GetAttribute("TemplatesFolder")
			if typeof(n) == "string" then folderName = n break end
		end
	end
	return if folderName then ReplicatedStorage:FindFirstChild(folderName) else nil
end

local function ids(): any
	if not assets then
		local f = folder()
		local m = f and f:FindFirstChild("AssetIds")
		assets = if m then require(m :: ModuleScript) else { icons = {}, art = {} }
	end
	return assets
end

-- design px -> screen px (same basis as the main ScreenGui's FitScale)
function K.uiScale(designW: number?, designH: number?): number
	local cam = workspace.CurrentCamera
	local vp = cam and cam.ViewportSize or Vector2.new(1920, 1080)
	return math.clamp(math.min(vp.X / (designW or 1920), vp.Y / (designH or 1080)), 0.3, 2)
end

function K.template(name: string): GuiObject?
	local f = folder()
	local t = f and f:FindFirstChild(name)
	if not t then
		warn("[UIKit] missing template " .. name .. " (designed in templates.html? rebuilt?)")
		return nil
	end
	return t:Clone() :: GuiObject
end

function K.scaled(g: GuiObject, extra: number?): UIScale
	local s = g:FindFirstChild("KitScale") :: UIScale?
	if not s then
		local ns = Instance.new("UIScale")
		ns.Name = "KitScale"
		ns.Parent = g
		s = ns
	end
	local us = s :: UIScale
	us.Scale = K.uiScale() * (extra or 1)
	return us
end

-- first non-shadow descendant with that name (names come from data-n in the HTML)
function K.find(scope: Instance?, name: string): Instance?
	if not scope then return nil end
	for _, d in scope:GetDescendants() do
		if d.Name == name then return d end
	end
	return nil
end

-- the "<Name>Shadow" twin NEAREST to the label (a parent can hold two Value/ValueShadow pairs;
-- taking the first one found left a stale number drawn under the real one)
function K.twin(g: GuiObject): GuiObject?
	local best, bd = nil, math.huge
	if not g.Parent then return nil end
	for _, c in g.Parent:GetChildren() do
		if c.Name == g.Name .. "Shadow" and c:IsA("GuiObject") then
			local d = math.abs(c.Position.X.Offset - g.Position.X.Offset) + math.abs(c.Position.Y.Offset - g.Position.Y.Offset)
				+ 1000 * (math.abs(c.Position.X.Scale - g.Position.X.Scale) + math.abs(c.Position.Y.Scale - g.Position.Y.Scale))
			if d < bd then best, bd = c, d end
		end
	end
	return best
end

-- live text keeps its design size and only shrinks when the box is too small (floor 14 px: a
-- MinTextSize of 6 came out ~2 px on phones)
-- The cap is re-applied on every set AND when the viewport changes: computed once at join, the viewport
-- can still be ~1x1, uiScale clamps to 0.3 and the label stays ~11 px for the whole session.
local fitted: { TextLabel } = {}
local function applyCap(l: TextLabel)
	local c = l:FindFirstChild("KitFitCap") :: UITextSizeConstraint?
	if not c then
		return
	end
	local design = l:GetAttribute("KitDesignSize") or l.TextSize
	c.MaxTextSize = math.max(8, math.floor(design * K.uiScale())) -- cap is in SCREEN px
	c.MinTextSize = math.min(14, c.MaxTextSize)
end
local function fit(l: TextLabel)
	if l:GetAttribute("KitFit") then
		applyCap(l)
		return
	end
	l:SetAttribute("KitFit", true)
	l:SetAttribute("KitDesignSize", l.TextSize)
	local c = Instance.new("UITextSizeConstraint")
	c.Name = "KitFitCap"
	c.Parent = l
	applyCap(l)
	l.TextScaled = true
	l.TextTruncate = Enum.TextTruncate.AtEnd
	table.insert(fitted, l)
	if #fitted == 1 and workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			for i = #fitted, 1, -1 do
				if fitted[i].Parent then
					applyCap(fitted[i])
				else
					table.remove(fitted, i)
				end
			end
		end)
	end
end

function K.set(label: Instance?, text: any)
	if not (label and label:IsA("TextLabel")) then return end
	local s = tostring(text)
	local sh = K.twin(label)
	if label.Text ~= s then
		fit(label)
		label.Text = s
		if sh and sh:IsA("TextLabel") then
			fit(sh)
			sh.Text = s
		end
	end
end

-- show/hide a label or icon together with its Shadow twin
function K.show(g: Instance?, on: boolean)
	if g and g:IsA("GuiObject") then
		g.Visible = on
		local sh = K.twin(g)
		if sh then sh.Visible = on end
	end
end

-- reward rows: hide icon + number (and twins) when the amount is zero; never show "+0"
function K.showPair(icon: Instance?, label: Instance?, amount: number, fmt: ((number) -> string)?)
	local on = amount > 0
	K.show(icon, on)
	K.show(label, on)
	if on then K.set(label, (fmt or tostring)(amount)) end
end

function K.icon(img: Instance?, slug: string?)
	if not (img and img:IsA("ImageLabel") and slug) then return end
	local id = ids().icons[slug]
	if not id then
		warn("[UIKit] icon not uploaded: " .. slug)
		return
	end
	img.Image = id
	local sh = K.twin(img)
	if sh and sh:IsA("ImageLabel") then sh.Image = id end
end

-- Bar frame with a fill child "F": width = FullW * frac (FullW remembered the first time)
function K.bar(bar: Instance?, frac: number)
	if not bar then return end
	local f = bar:FindFirstChild("F") :: Frame?
	if not f then return end
	local full = f:GetAttribute("FullW") :: number?
	if not full then
		full = (bar :: Frame).Size.X.Offset - 2 * f.Position.X.Offset
		f:SetAttribute("FullW", full)
	end
	frac = math.clamp(frac, 0, 1)
	f.ClipsDescendants = true
	f.Visible = frac > 0.005
	f.Size = UDim2.new(0, math.max(4, (full :: number) * frac), f.Size.Y.Scale, f.Size.Y.Offset)
end

-- a runtime child added next to panel art must draw above it (a clone keeps ZIndex 1 and lands
-- BEHIND the art it was dropped beside under Sibling ZIndexBehavior)
function K.above(child: GuiObject, parent: Instance?)
	local z = 1
	for _, s in (parent or child.Parent :: Instance):GetChildren() do
		if s ~= child and s:IsA("GuiObject") then z = math.max(z, s.ZIndex) end
	end
	child.ZIndex = z + 1
end

-- destroy template-only children (sample buttons, a key cap from another use, a baked "current"
-- ring) right after cloning. Example: K.strip(card, {"KeyCap", "KeyCapShadow", "Sample"})
function K.strip(t: Instance, names: { string })
	for _, n in names do
		for _, d in t:GetDescendants() do
			if d.Name == n then d:Destroy() end
		end
	end
end

-- left edge of a GuiObject regardless of its AnchorPoint (the UI module re-anchors juicy buttons to
-- 0.5,0.5, so Position.X.Offset is the CENTRE for them). Use for "place a clone beside X".
function K.leftOf(g: GuiObject): number
	return g.Position.X.Offset - g.AnchorPoint.X * g.Size.X.Offset
end
function K.placeBeside(clone: GuiObject, src: GuiObject, gap: number)
	clone.AnchorPoint = src.AnchorPoint
	local left = K.leftOf(src) + src.Size.X.Offset + gap
	clone.Position = UDim2.new(src.Position.X.Scale, left + clone.AnchorPoint.X * clone.Size.X.Offset,
		src.Position.Y.Scale, src.Position.Y.Offset)
	K.rest(clone)
end
-- any code that MOVES a juicy button must re-capture its hover rest position, or the first hover
-- tweens it back to where it used to be
function K.rest(b: GuiObject)
	b:SetAttribute("JuiceRest", b.Position)
end

---------------------------------------------------------------- copy helpers
local IRREGULAR = { Man = "Men", man = "men", Child = "Children", Person = "People", Mouse = "Mice", Fish = "Fish", Sheep = "Sheep" }
-- plural("Fisherman", 3) -> "Fishermen"; plural("Sword (Gold)", 2) -> "Swords (Gold)"; plural("Box", 2) -> "Boxes"
function K.plural(name: string, n: number): string
	if n == 1 then return name end
	local head, tail = string.match(name, "^(.-)(%s*%b())$")
	head = head or name
	tail = tail or ""
	for sing, pl in IRREGULAR do
		if string.sub(head, -#sing) == sing then return string.sub(head, 1, -#sing - 1) .. pl .. tail end
	end
	if string.match(head, "[sxz]$") or string.match(head, "[cs]h$") then return head .. "es" .. tail end
	if string.match(head, "[^aeiou]y$") then return string.sub(head, 1, -2) .. "ies" .. tail end
	return head .. "s" .. tail
end
-- article("Infantry Fighting Vehicle") -> "an"
function K.article(word: string): string
	local w = string.lower(word)
	if string.match(w, "^uni") or string.match(w, "^eu") or string.match(w, "^one") then return "a" end
	if string.match(w, "^hour") or string.match(w, "^honest") then return "an" end
	return if string.match(w, "^[aeiou]") then "an" else "a"
end
-- split for two-line templates at a real space (no space: keep every character)
function K.wrap2(text: string, n: number): (string, string?)
	if #text <= n then return text, nil end
	for i = n, 1, -1 do
		if string.sub(text, i, i) == " " then return string.sub(text, 1, i - 1), string.sub(text, i + 1) end
	end
	return string.sub(text, 1, n), string.sub(text, n + 1)
end
-- write EVERY line of a multi-line template ("" for unused) so an old line never lingers
function K.setLines(t: Instance, prefix: string, lines: { string }, max: number)
	for i = 1, max do K.set(K.find(t, prefix .. i), lines[i] or "") end
end

---------------------------------------------------------------- world labels (BillboardGui)
-- Size in studs (shrinks with distance), content clamped to [minPx, maxPx], grows UP from the
-- anchor, hides when the camera is very close. StudsOffset is CAMERA space: +Y lifts on screen,
-- +Z pulls toward the camera (clears flagpoles/avatars in front). For a camera looking down at a
-- building, lift by about half its footprint or the roof's far edge covers the label.
type WL = { bb: BillboardGui, content: GuiObject, cw: number, scale: UIScale, minPx: number, maxPx: number, fadeNear: number? }
local labels: { [BillboardGui]: WL } = {}
local stepping = false
function K.worldLabel(bb: BillboardGui, content: GuiObject, o: { studs: number, minPx: number?, maxPx: number?, fadeNear: number?, lift: number?, toward: number? })
	local cw, ch = content.Size.X.Offset, content.Size.Y.Offset
	bb.Size = UDim2.new(o.studs, 0, o.studs * ch / math.max(1, cw), 0)
	bb.SizeOffset = Vector2.new(0, 0.5)
	bb.StudsOffset = Vector3.new(0, o.lift or 0, o.toward or 0)
	bb.LightInfluence = 0
	bb.AlwaysOnTop = false -- AlwaysOnTop billboards failed to draw in playtests; lift instead
	content.AnchorPoint = Vector2.new(0.5, 1)
	content.Position = UDim2.new(0.5, 0, 1, 0)
	local sc = content:FindFirstChild("FitScale") :: UIScale?
	if not sc then
		local ns = Instance.new("UIScale")
		ns.Name = "FitScale"
		ns.Parent = content
		sc = ns
	end
	labels[bb] = { bb = bb, content = content, cw = cw, scale = sc :: UIScale, minPx = o.minPx or math.min(cw, 70), maxPx = o.maxPx or cw, fadeNear = o.fadeNear }
	if not stepping then
		stepping = true
		RunService.RenderStepped:Connect(function()
			local cam = workspace.CurrentCamera
			for b, L in labels do
				if not b.Parent then labels[b] = nil continue end
				local px = math.clamp(b.AbsoluteSize.X, L.minPx, L.maxPx)
				L.scale.Scale = px / L.cw
				if L.fadeNear and cam then
					local a = b.Adornee
					local p = if a and a:IsA("BasePart") then a.Position elseif a and a:IsA("Model") then a:GetPivot().Position else nil
					if p then L.content.Visible = (cam.CFrame.Position - p).Magnitude > L.fadeNear end
				end
			end
		end)
	end
	-- NOTE: a BillboardGui clips content to its Size even with ClipsDescendants off. If minPx can
	-- exceed the studs size (phones), size the billboard in PIXELS with ~1.5x headroom instead.
end

-- "edit-mode tooling must not save into the place": anything a harness creates while Studio is
-- not running gets Archivable = false
function K.scratch(inst: Instance): Instance
	if not RunService:IsRunning() then inst.Archivable = false end
	return inst
end

-- the ONE overlay ScreenGui for every runtime element (toasts, dialogs, tutorial, touch buttons):
-- above the imported UI, ignores the inset, survives respawn, created on first use.
function K.overlay(): ScreenGui
	local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
	local o = pg:FindFirstChild("UIOverlay") :: ScreenGui?
	if not o then
		local g = Instance.new("ScreenGui")
		g.Name = "UIOverlay"
		g.DisplayOrder = 20
		g.IgnoreGuiInset = true
		g.ResetOnSpawn = false
		g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		g.Parent = pg
		o = g
	end
	return o :: ScreenGui
end

function K.playerGui(): PlayerGui
	return Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui
end

return K
