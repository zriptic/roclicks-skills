--!nocheck
-- Builder: turns the generated Data_<Screen> modules (scripts/gen.py, from the approved HTML) into a
-- real ScreenGui in StarterGui, plus a runtime templates folder in ReplicatedStorage.
-- Generic: copy unchanged into <luau_out>/Builder.luau. Everything game-specific comes from
-- Data_Manifest (gui name, design size, screen order) and AssetIds.
--
-- Run from Studio (robloxstudio execute_luau), after import_rbxm of the bundle into ServerStorage:
--   return require(game.ServerStorage.<Gui>Build.Builder).build()
--   -- then, with the gui temporarily Enabled = true so text measures:
--   return require(game.ServerStorage.<Gui>Build.Builder).fit()      -- run twice
--
-- Layout: every screen is a full-size Frame under Root. Root is the design size (e.g. 1920x1080)
-- with a UIScale "FitScale"; the runtime UI module resizes Root to viewport / scale, so groups
-- anchored to edges (anchor TL/T/TR/L/C/R/BL/B/BR in the HTML grp()) hug the real screen edges.
local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Builder = {}

local WEIGHT = {
	[100] = Enum.FontWeight.Thin, [200] = Enum.FontWeight.ExtraLight, [300] = Enum.FontWeight.Light,
	[400] = Enum.FontWeight.Regular, [500] = Enum.FontWeight.Medium, [600] = Enum.FontWeight.SemiBold,
	[700] = Enum.FontWeight.Bold, [800] = Enum.FontWeight.ExtraBold, [900] = Enum.FontWeight.Heavy,
}

local function c3(t): Color3
	return Color3.fromRGB(t[1], t[2], t[3])
end

local function decode(mod: Instance?)
	assert(mod, "missing Data module (did the bundle import?)")
	return HttpService:JSONDecode(require(mod :: ModuleScript))
end

local function asset(assets, key: string?): string
	if not key then return "" end
	local kind, name = string.match(key, "^(%w+):(.+)$")
	local id = kind == "icon" and assets.icons[name] or kind == "art" and assets.art[name] or nil
	if not id then
		warn("[Builder] no asset id for " .. key .. " (upload it: ledger.py, then assets.py, re-bundle)")
		return ""
	end
	return id
end

-- Conic cooldown wedge (dark from 12 o'clock clockwise to frac*360) from two clipped halves, each
-- holding a rotating half-plane. Public so the runtime can call Builder.cooldown-style updates.
function Builder.cooldown(frame: Frame, frac: number, color: Color3, transparency: number)
	for _, n in { "R", "L" } do
		local half = frame:FindFirstChild(n)
		if not half then
			half = Instance.new("Frame")
			half.Name = n
			half.BackgroundTransparency = 1
			half.ClipsDescendants = true
			half.Size = UDim2.fromScale(0.5, 1)
			half.Position = UDim2.fromScale(n == "R" and 0.5 or 0, 0)
			local rotor = Instance.new("Frame")
			rotor.Name = "Rotor"
			rotor.BackgroundTransparency = 1
			rotor.AnchorPoint = Vector2.new(0.5, 0.5)
			rotor.Position = UDim2.fromScale(n == "R" and 0 or 1, 0.5)
			rotor.Size = UDim2.fromScale(6, 3)
			local plane = Instance.new("Frame")
			plane.Name = "Plane"
			plane.BorderSizePixel = 0
			plane.Size = UDim2.fromScale(0.5, 1)
			plane.Position = UDim2.fromScale(n == "R" and 0 or 0.5, 0)
			plane.Parent = rotor
			rotor.Parent = half
			half.Parent = frame
		end
		local rotor = half:FindFirstChild("Rotor")
		local plane = rotor:FindFirstChild("Plane")
		plane.BackgroundColor3 = color
		plane.BackgroundTransparency = transparency
		local a = math.clamp(frac, 0, 1) * 360
		if n == "R" then
			half.Visible = a > 0
			rotor.Rotation = math.min(a, 180)
		else
			half.Visible = a > 180
			rotor.Rotation = math.max(a - 180, 0)
		end
	end
	frame:SetAttribute("Frac", frac)
end

local function make(d, parent: Instance, z: number, assets): Instance
	if d.c == "Folder" then
		local f = Instance.new("Folder")
		f.Name = d.n
		for i, child in d.k or {} do make(child, f, 1, assets) end
		f.Parent = parent
		return f
	end
	local inst = Instance.new(d.c)
	inst.Name = d.n or d.c
	inst.BorderSizePixel = 0
	inst.AnchorPoint = Vector2.new(d.ax or 0, d.ay or 0)
	if d.fill then
		inst.Position = UDim2.fromScale(0, 0)
		inst.Size = UDim2.fromScale(1, 1)
	else
		inst.Position = UDim2.new(d.sx or 0, d.x or 0, d.sy or 0, d.y or 0)
		inst.Size = UDim2.new(d.sw or 0, d.w or 0, d.sh or 0, d.h or 0)
	end
	inst.ZIndex = z
	inst.Rotation = d.rot or 0
	if d.visible == false then inst.Visible = false end
	if d.bg then
		inst.BackgroundColor3 = c3(d.bg)
		inst.BackgroundTransparency = d.bt or 0
	else
		inst.BackgroundTransparency = 1
	end
	if d.clip then inst.ClipsDescendants = true end
	if d.c == "TextButton" then
		inst.Text = ""
		inst.AutoButtonColor = false
	end
	if d.c == "ImageLabel" or d.c == "ImageButton" then
		inst.Image = asset(assets, d.img)
		inst.ScaleType = Enum.ScaleType[d.st or "Fit"]
		if d.tile then inst.TileSize = UDim2.fromOffset(d.tile[1], d.tile[2]) end
		if d.ic then inst.ImageColor3 = c3(d.ic) end
		if d.it then inst.ImageTransparency = d.it end
	end
	if d.c == "TextLabel" then
		inst.Text = d.txt
		inst.FontFace = Font.new("rbxasset://fonts/families/" .. (d.font or "Montserrat") .. ".json",
			WEIGHT[d.wt] or Enum.FontWeight.ExtraBold)
		inst.TextSize = math.min(100, d.ts)
		inst.TextColor3 = c3(d.tc)
		inst.TextXAlignment = d.xa == "R" and Enum.TextXAlignment.Right
			or d.xa == "C" and Enum.TextXAlignment.Center or Enum.TextXAlignment.Left
		inst.TextYAlignment = Enum.TextYAlignment.Center
		inst.TextWrapped = false
		inst.RichText = false
	end
	if d.corner then
		local u = Instance.new("UICorner")
		u.CornerRadius = d.corner.s and UDim.new(d.corner.s, 0) or UDim.new(0, d.corner.o)
		u.Parent = inst
	end
	if d.stroke then
		local s = Instance.new("UIStroke")
		s.Thickness = d.stroke.t
		s.Color = c3(d.stroke.c)
		s.Transparency = d.stroke.tr or 0
		s.LineJoinMode = Enum.LineJoinMode.Round
		if d.stroke.mode == "Border" then
			s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			s.BorderStrokePosition = Enum.BorderStrokePosition[d.stroke.pos or "Inner"]
		end
		s:SetAttribute("BaseThickness", s.Thickness)
		s.Parent = inst
	end
	if d.grad then
		local g = Instance.new("UIGradient")
		g.Rotation = d.grad.rot or 90
		local kps = {}
		for _, k in d.grad.c do
			table.insert(kps, ColorSequenceKeypoint.new(k[1], Color3.fromRGB(k[2], k[3], k[4])))
		end
		g.Color = ColorSequence.new(kps)
		if d.grad.tr then
			local nps = {}
			for _, k in d.grad.tr do table.insert(nps, NumberSequenceKeypoint.new(k[1], k[2])) end
			g.Transparency = NumberSequence.new(nps)
		end
		g.Parent = inst
	end
	if d.scale then -- TextSize > 100 wrapper
		local s = Instance.new("UIScale")
		s.Name = "BigText"
		s.Scale = d.scale
		s.Parent = inst
	end
	if d.attrs then
		for k, v in d.attrs do inst:SetAttribute(k, v) end
	end
	inst.Parent = parent
	if d.cool then
		Builder.cooldown(inst, d.attrs.Frac, c3(d.cool.c), d.cool.tr)
	end
	for i, child in d.k or {} do make(child, inst, i, assets) end
	return inst
end

-- Second pass, after fonts load: nudge each label's TextSize so its rendered width matches the
-- HTML ink width (Chrome and Roblox advance widths differ by a few % on short strings/digits).
-- The gui must be Enabled while this runs or TextBounds reads 0. Run it twice.
function Builder.fit(scope: Instance?): string
	local man = decode(script.Parent:FindFirstChild("Data_Manifest"))
	local gui = scope or StarterGui:FindFirstChild(man.gui)
	assert(gui, "build first")
	local fixed, worst, n = 0, 0, 0
	for _, d in gui:GetDescendants() do
		if d:IsA("TextLabel") and d.Text ~= "" and not string.find(d.Name, "Shadow$") then
			local w = d:GetAttribute("FitW") or d.AbsoluteSize.X
			local tb = d.TextBounds.X
			if w > 0 and tb > 0 then
				n += 1
				local r = tb / w
				if math.abs(r - 1) > 0.015 then
					local ts = math.clamp(d.TextSize / r, 1, 100)
					d.TextSize = ts
					local sh = d.Parent and d.Parent:FindFirstChild(d.Name .. "Shadow")
					if sh and sh:IsA("TextLabel") then sh.TextSize = ts end
					fixed += 1
				end
				worst = math.max(worst, math.abs(r - 1))
				d:SetAttribute("FitRatio", r)
			end
		end
	end
	return string.format("fit: %d/%d labels resized (worst was %.1f%%)%s", fixed, n, worst * 100,
		n == 0 and " -- 0 measured: is the gui Enabled?" or "")
end

function Builder.build(): string
	local folder = script.Parent
	local assets = require(folder:FindFirstChild("AssetIds"))
	local man = decode(folder:FindFirstChild("Data_Manifest"))
	local W, H = man.design[1], man.design[2]

	local old = StarterGui:FindFirstChild(man.gui)
	if old then old:Destroy() end
	local gui = Instance.new("ScreenGui")
	gui.Name = man.gui
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 5
	-- Disabled in StarterGui so the design-size HUD does not sit over the edit viewport; the
	-- Controller LocalScript enables its PlayerGui copy at runtime.
	gui.Enabled = false

	local root = Instance.new("Frame")
	root.Name = "Root"
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Size = UDim2.fromOffset(W, H)
	root.BackgroundTransparency = 1
	root.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Name = "FitScale"
	scale.Parent = root

	-- scrim behind panels: the UI module fades it to each screen's Dim attribute. Active = true so a
	-- click on the scrim never reaches the world while a panel is open.
	local dim = Instance.new("Frame")
	dim.Name = "Dim"
	dim.AnchorPoint = Vector2.new(0.5, 0.5)
	dim.Position = UDim2.fromScale(0.5, 0.5)
	dim.Size = UDim2.new(1, 4000, 1, 4000)
	dim.BackgroundColor3 = Color3.fromRGB(0, 8, 12)
	dim.BackgroundTransparency = 1
	dim.BorderSizePixel = 0
	dim.Active = true
	dim.Visible = false
	dim.ZIndex = 1
	dim.Parent = root

	local count = 0
	for i, s in man.screens do
		local data = decode(folder:FindFirstChild("Data_" .. s.name))
		-- HUD-type screens sit under every panel; panels stack in manifest order above the scrim
		local z = if s.hud then 2 else i + 3
		local screen = make(data, root, z, assets)
		screen.Visible = s.visible == true
		screen:SetAttribute("Hud", s.hud == true)
		count += #screen:GetDescendants() + 1
	end

	-- ship the asset map + client scripts with the gui
	folder:FindFirstChild("AssetIds"):Clone().Parent = gui
	-- every shared runtime module in luau_out (UIKit, NumberFormat, Theme, UpdateInPlace, ...) ships inside the
	-- gui so LocalScripts can require it (clients cannot see ServerStorage). Builder/Data_* stay behind.
	for _, m in folder:GetChildren() do
		if m:IsA("ModuleScript") and m.Name ~= "Builder" and m.Name ~= "AssetIds" and not string.match(m.Name, "^Data_") then
			m:Clone().Parent = gui
		end
	end
	gui:SetAttribute("TemplatesFolder", man.templates)
	local client = folder:FindFirstChild("Client")
	if client then
		for _, s in client:GetChildren() do s:Clone().Parent = gui end
	end
	gui.Parent = StarterGui

	-- runtime templates (toasts, confirm, tutorial card, billboards ...): game code clones these and
	-- never builds UI with Instance.new.
	local ntemp = 0
	if man.templates then
		local oldT = ReplicatedStorage:FindFirstChild(man.templates)
		if oldT then oldT:Destroy() end
		local tf = make(decode(folder:FindFirstChild("Data_Templates")), ReplicatedStorage, 1, assets)
		folder:FindFirstChild("AssetIds"):Clone().Parent = tf
		ntemp = #tf:GetChildren() - 1
	end
	return string.format("built %s: %d screens, %d instances; %d templates. Now Enabled=true, fit() x2, Enabled=false.",
		man.gui, #man.screens, count, ntemp)
end

-- Update ONE screen in place (after re-exporting only that page): rebuilds StarterGui.<Gui>.Root.<name>
-- from Data_<name> at the same z, leaving every other screen and the scripts untouched.
--   return require(game.ServerStorage.<Gui>Build.Builder).buildScreen("Shop")
function Builder.buildScreen(name: string): string
	local folder = script.Parent
	local assets = require(folder:FindFirstChild("AssetIds"))
	local man = decode(folder:FindFirstChild("Data_Manifest"))
	local gui = StarterGui:FindFirstChild(man.gui)
	assert(gui, "build() first")
	local root = gui:FindFirstChild("Root")
	local z, entry = nil, nil
	for i, s in man.screens do
		if s.name == name then z, entry = if s.hud then 2 else i + 3, s end
	end
	assert(entry, "screen not in Data_Manifest: " .. name)
	local old = root:FindFirstChild(name)
	if old then old:Destroy() end
	local screen = make(decode(folder:FindFirstChild("Data_" .. name)), root, z, assets)
	screen.Visible = entry.visible == true
	screen:SetAttribute("Hud", entry.hud == true)
	return string.format("rebuilt %s (%d instances); run fit(scope) with the gui Enabled", name, #screen:GetDescendants() + 1)
end

return Builder
