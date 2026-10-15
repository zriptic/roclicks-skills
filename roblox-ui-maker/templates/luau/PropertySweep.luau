--!strict
-- PropertySweep: objective UI checks for when screenshots can't be trusted (magenta playtest
-- captures, BillboardGuis never captured). Run in the client (playtest) or in edit mode on a cloned
-- ScreenGui. Returns compact lines; parse them locally (a plugin context can't POST anywhere).
--
--   local Sweep = require(path.PropertySweep)
--   print(Sweep.run(PlayerGui.GameUI, { minTap = 48, touch = true }))
--   print(Sweep.atSizes(PlayerGui.GameUI.Root, { Vector2.new(844, 390), Vector2.new(1920, 1080) }, opts))

local PropertySweep = {}

export type Opts = { minTap: number?, touch: boolean?, ignore: { string }? }

local function visible(g: GuiObject): boolean
	local p: Instance? = g
	while p and p:IsA("GuiObject") do
		if not (p :: GuiObject).Visible then return false end
		p = p.Parent
	end
	local sg = g:FindFirstAncestorWhichIsA("LayerCollector")
	return sg == nil or sg.Enabled
end

local function rect(g: GuiObject)
	return g.AbsolutePosition, g.AbsolutePosition + g.AbsoluteSize
end

local function overlaps(a: GuiObject, b: GuiObject): boolean
	local a0, a1 = rect(a)
	local b0, b1 = rect(b)
	local ix = math.min(a1.X, b1.X) - math.max(a0.X, b0.X)
	local iy = math.min(a1.Y, b1.Y) - math.max(a0.Y, b0.Y)
	return ix > 2 and iy > 2 -- 2 px tolerance for touching outlines
end

function PropertySweep.run(root: Instance, opts: Opts?): string
	local o = opts or {}
	local minTap = o.minTap or 48
	local out = {}
	local function add(kind: string, g: Instance, extra: string)
		table.insert(out, kind .. "\t" .. g:GetFullName() .. "\t" .. extra)
	end

	for _, d in root:GetDescendants() do
		if d:IsA("GuiObject") and visible(d) then
			-- text that doesn't fit (TextScaled labels report fit by design; check them by size instead)
			if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Text ~= "" then
				if not d.TextFits then
					add("TEXT_NOFIT", d, string.format("%dx%d bounds %dx%d", d.AbsoluteSize.X, d.AbsoluteSize.Y,
						d.TextBounds.X, d.TextBounds.Y))
				end
				if string.find(d.Text, "nil", 1, true) or string.find(d.Text, "?", 1, true)
					or string.find(d.Text, "_%d") then
					add("TEXT_SUSPECT", d, d.Text) -- raw ids, "?" fallbacks, "nil"
				end
			end
			-- tap targets
			if o.touch and d:IsA("GuiButton") then
				local s = d.AbsoluteSize
				if s.X < minTap or s.Y < minTap then
					add("TAP_SMALL", d, string.format("%dx%d < %d", s.X, s.Y, minTap))
				end
			end
			-- child escaping its parent's rect
			local parent = d.Parent
			if parent and parent:IsA("GuiObject") and not parent:IsA("ScrollingFrame") then
				local c0, c1 = rect(d)
				local p0, p1 = rect(parent)
				if c0.X < p0.X - 2 or c0.Y < p0.Y - 2 or c1.X > p1.X + 2 or c1.Y > p1.Y + 2 then
					if parent.ClipsDescendants then add("CLIPPED", d, "cut by parent") end
				end
			end
			-- images: report the asset, not the instance (offscreen instances read IsLoaded=false)
			if (d:IsA("ImageLabel") or d:IsA("ImageButton")) and d.Image ~= "" and not d.IsLoaded then
				add("IMG_NOTLOADED", d, d.Image)
			end
		end
	end

	-- sibling overlap between interactive controls
	for _, d in root:GetDescendants() do
		if d:IsA("GuiObject") then
			local btns = {}
			for _, c in d:GetChildren() do
				if c:IsA("GuiButton") and visible(c) then table.insert(btns, c) end
			end
			for i = 1, #btns do
				for j = i + 1, #btns do
					if overlaps(btns[i], btns[j]) then
						add("OVERLAP", btns[i], btns[j].Name)
					end
				end
			end
		end
	end

	-- billboards (never shown by Studio captures)
	for _, d in root:GetDescendants() do
		if d:IsA("BillboardGui") then
			local a = d.Adornee or d.Parent
			if not d.Enabled or not a or not a.Parent then
				add("BILLBOARD", d, "disabled or no adornee")
			end
		end
	end

	return string.format("%d issues\n%s", #out, table.concat(out, "\n"))
end

-- Sweep several screen sizes without touching the real window: resize the design root and its
-- UIScale the way the runtime controller would, sweep, restore.
function PropertySweep.atSizes(root: Frame, sizes: { Vector2 }, opts: Opts?, designW: number?, designH: number?): string
	local dw, dh = designW or 1920, designH or 1080
	local scale = root:FindFirstChildOfClass("UIScale")
	local oldSize, oldScale = root.Size, scale and scale.Scale
	local report = {}
	for _, v in sizes do
		local f = math.min(v.X / dw, v.Y / dh)
		if scale then scale.Scale = f end
		root.Size = UDim2.fromOffset(v.X / f, v.Y / f)
		task.wait() -- let AbsoluteSize/TextFits update
		table.insert(report, string.format("== %dx%d (scale %.2f)\n%s", v.X, v.Y, f, PropertySweep.run(root, opts)))
	end
	root.Size = oldSize
	if scale and oldScale then scale.Scale = oldScale end
	return table.concat(report, "\n")
end

return PropertySweep
