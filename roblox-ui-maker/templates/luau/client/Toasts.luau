--!strict
-- Toasts: short feedback messages. Clones the approved Toast_<kind> templates (templates.html:
-- Toast_info / Toast_good / Toast_error / Toast_cash, each with Icon, Msg1 (+Msg1Shadow) and a
-- countdown bar Time with fill F). Never builds the look here.
-- Dedupes identical text (restart + pulse instead of stacking), picks a duration from length, caps
-- the stack at 4, closes the gap when one leaves, merges bursts, docks while a panel is open.
--
--   local Toasts = require(gui:WaitForChild("Toasts"))   -- lives in luau_out/client/, ships with the gui
--   Toasts.init(UIKit)                                    -- after UIKit.init(...)
--   Toasts.show("Need 950 more coins", { kind = "error", icon = "warning" })
--   Toasts.merged("coins", 25, function(n) return "+" .. NumberFormat.short(n) .. " coins" end, 2)
--   UI.PageChanged:Connect(function(name) Toasts.dock(name ~= nil) end)

local TweenService = game:GetService("TweenService")

local Toasts = {}

local MAX_STACK, MAX_DOCKED = 4, 2
local GAP = 8
local SHORT, LONG, LONG_CHARS = 3.5, 6, 50
local TOP = 120 -- design px from the top (move it under a tutorial card when one shows)

type Entry = { frame: GuiObject, text: string, token: number }
local stack: { Entry } = {}
local container: Frame
local K: any
local docked = false

function Toasts.init(uikit: any)
	K = uikit
	local c = Instance.new("Frame") -- invisible layout container (not a look)
	c.Name = "ToastStack"
	c.BackgroundTransparency = 1
	c.AnchorPoint = Vector2.new(0.5, 0)
	c.Position = UDim2.new(0.5, 0, 0, TOP)
	c.Size = UDim2.fromOffset(640, 480) -- design px; KitScale maps it to the screen
	K.scaled(c)
	c.Parent = K.overlay()
	container = c
end

local function relayout()
	local y, shown = 0, 0
	for i = #stack, 1, -1 do -- newest on top
		local e = stack[i]
		shown += 1
		e.frame.Visible = shown <= (if docked then MAX_DOCKED else MAX_STACK)
		if e.frame.Visible then
			TweenService:Create(e.frame, TweenInfo.new(0.2), { Position = UDim2.fromOffset(0, y) }):Play()
			y += e.frame.Size.Y.Offset + GAP
		end
	end
end

-- while a panel is open, toasts move out of its way: bottom-right corner at 0.6 scale, newest 2
function Toasts.dock(on: boolean)
	docked = on
	K.scaled(container, if on then 0.6 else 1)
	if on then
		container.AnchorPoint = Vector2.new(1, 1)
		container.Position = UDim2.new(1, -24, 1, -10)
	else
		container.AnchorPoint = Vector2.new(0.5, 0)
		container.Position = UDim2.new(0.5, 0, 0, TOP * K.uiScale())
	end
	relayout()
end

local function popScale(f: GuiObject): UIScale
	local s = f:FindFirstChild("PopScale") :: UIScale?
	if not s then
		local n = Instance.new("UIScale")
		n.Name = "PopScale"
		n.Parent = f
		s = n
	end
	return s :: UIScale
end

local function remove(e: Entry)
	local i = table.find(stack, e)
	if not i then return end
	table.remove(stack, i)
	local t = TweenService:Create(popScale(e.frame), TweenInfo.new(0.15), { Scale = 0 })
	t.Completed:Once(function() e.frame:Destroy() end)
	t:Play()
	relayout()
end

local function arm(e: Entry, duration: number)
	e.token += 1
	local my = e.token
	-- restart the countdown strip too, or it shows empty while the toast stays up
	local bar = K.find(e.frame, "Time")
	local strip = (bar and bar:FindFirstChild("F")) :: Frame?
	if strip then
		local full = strip:GetAttribute("FullW") :: number?
		if not full then
			full = strip.Size.X.Offset
			strip:SetAttribute("FullW", full)
		end
		local y = strip.Size.Y
		strip.Size = UDim2.new(0, full :: number, y.Scale, y.Offset)
		TweenService:Create(strip, TweenInfo.new(duration, Enum.EasingStyle.Linear),
			{ Size = UDim2.new(0, 0, y.Scale, y.Offset) }):Play()
	end
	task.delay(duration, function()
		if e.token == my then remove(e) end
	end)
end

export type Opts = { kind: string?, icon: string?, duration: number? }

function Toasts.show(text: string, opts: Opts?)
	local o: Opts = opts or {}
	local duration = o.duration or (if #text > LONG_CHARS then LONG else SHORT)
	for _, e in stack do -- dedupe: same text already up -> pulse and restart its timer
		if e.text == text then
			local s = popScale(e.frame)
			s.Scale = 1.12
			TweenService:Create(s, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
			arm(e, duration)
			return
		end
	end
	local f = K.template("Toast_" .. (o.kind or "info")) or K.template("Toast_info")
	if not f then return end
	if #stack >= MAX_STACK then remove(stack[1]) end -- oldest drops
	K.set(K.find(f, "Msg1"), text)
	if o.icon then K.icon(K.find(f, "Icon"), o.icon) end
	f.Parent = container
	local e: Entry = { frame = f, text = text, token = 0 }
	table.insert(stack, e)
	relayout()
	local s = popScale(f)
	s.Scale = 0.6
	TweenService:Create(s, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	arm(e, duration)
end

-- Burst merging for events that fire many times a second: at most one toast per `window` seconds,
-- carrying the running total; whatever arrives inside the window is flushed when it ends.
local merged: { [string]: { total: number, last: number, pending: boolean } } = {}
function Toasts.merged(key: string, amount: number, fmt: (number) -> string, window: number)
	local m = merged[key] or { total = 0, last = -math.huge, pending = false }
	merged[key] = m
	m.total += amount
	if os.clock() - m.last >= window then
		m.last = os.clock()
		Toasts.show(fmt(m.total))
		m.total = 0
	elseif not m.pending then
		m.pending = true
		task.delay(window - (os.clock() - m.last), function()
			m.pending = false
			if m.total ~= 0 then
				m.last = os.clock()
				Toasts.show(fmt(m.total))
				m.total = 0
			end
		end)
	end
end

return Toasts
