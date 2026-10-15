--!nonstrict
-- TrailerDriver: plays one trailer shot in a live Studio playtest CLIENT so it looks hand-played.
-- Generic: every game-specific name (tags, paths, remotes, prompt text) comes from the shot table
-- (shots.json -> build_kit.py). Run it from eval_client_runtime; see references/luau-api.md.
--
--   local D = require(TrailerKit.TrailerDriver)
--   D.run(shot, { rig = require(TrailerKit.CameraRig), delay = 6, actor = "client-1" })
--       -> { ok, shot, startsAtMs, endsAtMs, dur }   (returns at once; the shot starts at startsAtMs)
--   D.stop()                 -- stop whatever is running and restore everything
--   D.status()               -- { running, shot, startsAtMs, endsAtMs, error, last }
--   D.calibrate(secs, rgb?)  -- full-screen flat colour so record.py can find the viewport on screen
--   D.hud(show), D.chrome(show)  -- manual HUD / Roblox top bar + CoreGui toggles (restored by stop)
--
-- Idempotent: every call first stops a previous run (found through a marker Folder on the LocalPlayer,
-- so it works across separate eval VMs) and restores camera, GUIs, CoreGui, top bar, mouse icon,
-- controls, humanoid settings and the blur it added. Nothing is left behind after a shot ends.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")
local PathfindingService = game:GetService("PathfindingService")
local Lighting = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")

local Driver = {}

local MARK = "__TrailerRig"
local BIND = "__TrailerCam"
local CALIB = "__TrailerCalib"
local BLUR = "__TrailerBlur"

local player = Players.LocalPlayer

local function nowMs(): number
	return DateTime.now().UnixTimestampMillis
end

local function v3(t: any): Vector3?
	if typeof(t) == "Vector3" then
		return t
	end
	if type(t) == "table" and type(t[1]) == "number" then
		return Vector3.new(t[1], t[2] or 0, t[3] or 0)
	end
	return nil
end

local function wrapAngle(a: number): number
	return (a + math.pi) % (2 * math.pi) - math.pi
end

local function damp(rate: number, dt: number): number
	return 1 - math.exp(-rate * dt)
end

local function character(): Model?
	return player.Character
end

local function rootPart(): BasePart?
	local c = character()
	return c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function humanoid(): Humanoid?
	local c = character()
	return c and c:FindFirstChildOfClass("Humanoid")
end

local function findPath(path: string): Instance?
	local cur: Instance? = game
	for seg in string.gmatch(path, "[^%.]+") do
		if cur == game then
			local ok, svc = pcall(function()
				return game:GetService(seg)
			end)
			cur = if ok and svc then svc else game:FindFirstChild(seg)
		else
			cur = cur and cur:FindFirstChild(seg)
		end
		if not cur then
			return nil
		end
	end
	return cur
end
Driver.findPath = findPath

local function instCFrame(inst: Instance?): CFrame?
	if not inst then
		return nil
	end
	if inst:IsA("Player") then
		inst = inst.Character
		if not inst then
			return nil
		end
	end
	if inst:IsA("BasePart") then
		return inst.CFrame
	elseif inst:IsA("Model") then
		return inst:GetPivot()
	elseif inst:IsA("Attachment") then
		return inst.WorldCFrame
	end
	local p = inst:FindFirstChildWhichIsA("BasePart", true)
	return p and p.CFrame or nil
end

local function otherPlayer(which: string): Player?
	if which == "self" then
		return player
	end
	for _, p in Players:GetPlayers() do
		if (which == "other" and p ~= player) or p.Name == which or p.DisplayName == which then
			return p
		end
	end
	return nil
end

-- Resolve a target spec to an Instance (when it names one).
local function targetInstance(target: any): Instance?
	if typeof(target) == "Instance" then
		return target
	end
	if type(target) ~= "table" then
		return nil
	end
	if target.path then
		local inst = findPath(target.path)
		if inst and target.child then
			inst = inst:FindFirstChild(target.child, true)
		end
		return inst
	elseif target.tag then
		local list = CollectionService:GetTagged(target.tag)
		if target.attrs then -- keep only tagged instances whose attributes match, e.g. { Side = "A" }
			local keep = {}
			for _, inst in list do
				local ok = true
				for k, v in target.attrs do
					local a = inst:GetAttribute(k)
					if a ~= v and tostring(a) ~= tostring(v) then
						ok = false
						break
					end
				end
				if ok then
					table.insert(keep, inst)
				end
			end
			list = keep
		end
		if target.nearest ~= false then
			local r = rootPart()
			if r and #list > 1 and not target.index then
				table.sort(list, function(a, b)
					local ca, cb = instCFrame(a), instCFrame(b)
					local da = ca and (ca.Position - r.Position).Magnitude or math.huge
					local db = cb and (cb.Position - r.Position).Magnitude or math.huge
					return da < db
				end)
			end
		end
		local inst = list[target.index or 1]
		if inst and target.child then
			inst = inst:FindFirstChild(target.child, true)
		end
		return inst
	elseif target.player then
		local p = otherPlayer(target.player)
		return p and p.Character
	end
	return nil
end

-- Target -> CFrame. Accepts {x,y,z}, Vector3, CFrame, Instance, or a table with pos/path/tag/player
-- plus optional attrs (tag filter), index, nearest=false, child (descendant name),
-- offset (world studs) / localOffset (studs in the target's own space).
local function resolve(target: any): CFrame?
	local direct = v3(target)
	if direct then
		return CFrame.new(direct)
	end
	if typeof(target) == "CFrame" then
		return target
	end
	if type(target) == "string" then
		target = { path = target }
	end
	local cf: CFrame?
	if type(target) == "table" and target.pos then
		cf = CFrame.new(v3(target.pos) :: Vector3)
	else
		cf = instCFrame(targetInstance(target))
	end
	if not cf or type(target) ~= "table" then
		return cf
	end
	local lo = v3(target.localOffset)
	if lo then
		cf = cf * CFrame.new(lo)
	end
	local wo = v3(target.offset)
	if wo then
		cf = cf + wo
	end
	return cf
end
Driver.resolve = resolve

local function resolvePos(target: any): Vector3
	local cf = resolve(target)
	if not cf then
		error("TrailerDriver: cannot resolve target " .. HttpService:JSONEncode(target))
	end
	return cf.Position
end

---------------------------------------------------------------- run state

local current: any = nil -- the run owned by THIS VM (other VMs are reached through the marker)

local function marker(): Folder?
	return player:FindFirstChild(MARK) :: Folder?
end

local function setLast(info: any)
	pcall(function()
		player:SetAttribute("TrailerLast", HttpService:JSONEncode(info))
	end)
end

-- Snapshot of everything a run may change, captured before it changes anything.
local function snapshot()
	local cam = workspace.CurrentCamera
	local s = {
		camType = cam.CameraType,
		camSubject = cam.CameraSubject,
		camFov = cam.FieldOfView,
		mouseIcon = UserInputService.MouseIconEnabled,
		guis = {},
		core = {},
		topbar = true,
	}
	local pg = player:FindFirstChildOfClass("PlayerGui")
	if pg then
		for _, g in pg:GetChildren() do
			if g:IsA("LayerCollector") and g.Name ~= CALIB then
				s.guis[g] = g.Enabled
			end
		end
	end
	for _, ct in Enum.CoreGuiType:GetEnumItems() do
		if ct ~= Enum.CoreGuiType.All then
			local ok, on = pcall(function()
				return StarterGui:GetCoreGuiEnabled(ct)
			end)
			s.core[ct] = if ok then on else true
		end
	end
	pcall(function()
		s.topbar = StarterGui:GetCore("TopbarEnabled")
	end)
	local h = humanoid()
	if h then
		s.hum = h
		s.autoRotate = h.AutoRotate
		s.walkSpeed = h.WalkSpeed
	end
	return s
end

local function setCore(name: string, value: any)
	-- SetCore can throw until the CoreScripts register; retry briefly.
	for _ = 1, 10 do
		if pcall(function()
			StarterGui:SetCore(name, value)
		end) then
			return true
		end
		task.wait(0.05)
	end
	return false
end

-- Game HUD (the place's own ScreenGuis) on/off. Only guis that were enabled at snapshot are re-enabled.
local function applyHud(run: any, show: boolean)
	local pg = player:FindFirstChildOfClass("PlayerGui")
	if not pg then
		return
	end
	for _, g in pg:GetChildren() do
		if g:IsA("LayerCollector") and g.Name ~= CALIB then
			if run.snap.guis[g] == nil then
				run.snap.guis[g] = g.Enabled -- appeared after the snapshot (e.g. a popup)
			end
			if show then
				g.Enabled = run.snap.guis[g]
			else
				g.Enabled = false
			end
		end
	end
	run.hudShown = show
end

-- Roblox chrome: CoreGui (chat, player list, backpack, health) + top bar + mouse icon.
local function applyChrome(run: any, show: boolean)
	if show then
		for ct, on in run.snap.core do
			pcall(function()
				StarterGui:SetCoreGuiEnabled(ct, on)
			end)
		end
		setCore("TopbarEnabled", run.snap.topbar ~= false)
		UserInputService.MouseIconEnabled = run.snap.mouseIcon
	else
		pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
		end)
		task.spawn(setCore, "TopbarEnabled", false)
		UserInputService.MouseIconEnabled = false
	end
end

local function controls()
	local ps = player:FindFirstChildOfClass("PlayerScripts")
	local pm = ps and ps:FindFirstChild("PlayerModule")
	if not pm then
		return nil
	end
	local ok, mod = pcall(require, pm)
	if not ok or not mod or not mod.GetControls then
		return nil
	end
	local ok2, c = pcall(function()
		return mod:GetControls()
	end)
	return if ok2 then c else nil
end

local function cleanup(run: any, reason: string?)
	if run.cleaned then
		return
	end
	run.cleaned = true
	run.alive = false
	pcall(function()
		RunService:UnbindFromRenderStep(BIND)
	end)
	for _, c in run.conns do
		pcall(function()
			c:Disconnect()
		end)
	end
	for _, f in run.cleanups do
		pcall(f)
	end
	local s = run.snap
	local cam = workspace.CurrentCamera
	if not run.passive then
		cam.CameraType = s.camType
		cam.CameraSubject = s.camSubject or humanoid()
		cam.FieldOfView = s.camFov
		applyHud(run, true)
		applyChrome(run, true)
	end
	local h = s.hum
	if h and h.Parent then
		h.AutoRotate = s.autoRotate
		h.WalkSpeed = s.walkSpeed
		local r = rootPart()
		if r then
			h:MoveTo(r.Position) -- cancel any pending MoveTo
		end
	end
	if run.controlsOff then
		local c = controls()
		if c then
			pcall(function()
				c:Enable()
			end)
		end
	end
	local blur = Lighting:FindFirstChild(BLUR)
	if blur then
		blur:Destroy()
	end
	if run.marker and run.marker.Parent then
		run.marker:Destroy()
	end
	if current == run then
		current = nil
	end
	setLast({
		shot = run.shotId,
		startsAtMs = run.startsAtMs,
		endsAtMs = run.endsAtMs,
		endedAtMs = nowMs(),
		reason = reason or "done",
		error = run.err,
		log = run.log,
	})
end

function Driver.stop()
	if current then
		cleanup(current, "stopped")
	end
	local m = marker()
	if m then
		local stop = m:FindFirstChild("Stop")
		if stop and stop:IsA("BindableEvent") then
			stop:Fire()
		end
		local t = os.clock()
		while m.Parent and os.clock() - t < 1 do
			task.wait()
		end
		if m.Parent then
			m:Destroy() -- owner VM is gone; nothing else to restore from here
		end
	end
	local calib = player:FindFirstChildOfClass("PlayerGui")
	calib = calib and calib:FindFirstChild(CALIB)
	if calib then
		calib:Destroy()
	end
	return true
end

function Driver.status()
	local m = marker()
	local last = player:GetAttribute("TrailerLast")
	return {
		running = m ~= nil,
		shot = m and m:GetAttribute("Shot"),
		startsAtMs = m and m:GetAttribute("StartsAtMs"),
		endsAtMs = m and m:GetAttribute("EndsAtMs"),
		error = m and m:GetAttribute("Error"),
		last = last and HttpService:JSONDecode(last) or nil,
	}
end

---------------------------------------------------------------- player camera ("looks hand-played")

-- Third-person follow with a lagging focus, heading-follow only while moving, slow mouse-like drift,
-- micro tremor and occasional glances. All randomness is seeded, so a retake looks the same.
local function newPlayerCam(cfg: any, seed: number)
	cfg = cfg or {}
	local pc = {
		dist = cfg.dist or 13,
		height = cfg.height or 2.4,
		pitch = cfg.pitch or -16,
		lag = cfg.lag or 7, -- focus spring rate (higher = tighter)
		yawLag = cfg.yawLag or 2.0, -- how fast the camera swings behind the walking character
		drift = cfg.drift or 1, -- scale of the slow wander (0 = robotic)
		tremor = cfg.tremor or 1,
		glances = cfg.glances ~= false,
		fov = cfg.fov or 70,
		collide = cfg.collide ~= false,
		seed = seed,
		yaw = nil,
		pitchNow = nil,
		focus = nil,
		yawOff = 0,
		pitchOff = 0,
		tweens = {},
		aim = nil,
		glanceList = {},
	}
	if cfg.yaw then
		pc.fixedYaw = math.rad(cfg.yaw)
	end
	if pc.glances then
		local rng = Random.new(seed)
		local t = rng:NextNumber(2.5, 4.5)
		for _ = 1, 20 do
			local amp = rng:NextNumber(7, 20) * (if rng:NextInteger(0, 1) == 0 then -1 else 1)
			local hold = rng:NextNumber(0.5, 1.3)
			table.insert(pc.glanceList, { t = t, amp = math.rad(amp), hold = hold })
			t += rng:NextNumber(3.5, 7)
		end
	end
	return pc
end

local function glanceAt(pc: any, t: number): number
	for _, g in pc.glanceList do
		local rel = t - g.t
		if rel >= 0 and rel <= 0.55 + g.hold + 0.8 then
			if rel < 0.55 then
				return g.amp * (1 - math.cos(math.pi * rel / 0.55)) / 2
			elseif rel < 0.55 + g.hold then
				return g.amp
			else
				local u = (rel - 0.55 - g.hold) / 0.8
				return g.amp * (1 + math.cos(math.pi * u)) / 2
			end
		end
	end
	return 0
end

local function tweenValue(pc: any, t: number, key: string): number
	local v = 0
	for _, tw in pc.tweens do
		if tw.key == key then
			local u = math.clamp((t - tw.t0) / math.max(tw.dur, 1e-3), 0, 1)
			local e = (1 - math.cos(math.pi * u)) / 2
			if tw.overshoot and u < 1 then
				e += math.sin(math.pi * u) * tw.overshoot
			end
			v = tw.from + (tw.to - tw.from) * e
		end
	end
	return v
end

local function playerCamStep(run: any, pc: any, t: number, dt: number): (CFrame?, number)
	local r = rootPart()
	if not r then
		return nil, pc.fov
	end
	local goalFocus = r.Position + Vector3.new(0, pc.height, 0)
	if not pc.focus then
		pc.focus = goalFocus
	end
	pc.focus = pc.focus:Lerp(goalFocus, damp(pc.lag, dt))

	local look = r.CFrame.LookVector
	local heading = math.atan2(-look.X, -look.Z)
	local moving = r.AssemblyLinearVelocity.Magnitude > 2
	local goalYaw: number
	if pc.aim then
		local ok, p = pcall(resolvePos, pc.aim)
		local d = if ok then p - pc.focus else look
		goalYaw = math.atan2(-d.X, -d.Z)
	elseif pc.fixedYaw then
		goalYaw = pc.fixedYaw
	elseif pc.yaw == nil or moving then
		goalYaw = heading
	else
		goalYaw = pc.baseYaw or heading -- idle: a real player doesn't re-centre the camera
	end
	pc.baseYaw = goalYaw

	local s = pc.seed
	local drift = math.rad(math.noise(t * 0.13, s, 0.5) * 6 * pc.drift)
	local tremorY = math.rad(math.noise(t * 1.9, s + 3, 0.2) * 0.35 * pc.tremor)
	local tremorP = math.rad(math.noise(s + 5, t * 1.7, 0.9) * 0.3 * pc.tremor)
	local glance = if pc.glances and not pc.aim then glanceAt(pc, t) else 0
	pc.yawOff = math.rad(tweenValue(pc, t, "yaw"))
	pc.pitchOff = tweenValue(pc, t, "pitch")

	local target = goalYaw + drift + glance + pc.yawOff
	if pc.yaw == nil then
		pc.yaw = target
	end
	pc.yaw += wrapAngle(target - pc.yaw) * damp(if moving or pc.aim then pc.yawLag else pc.yawLag * 2.5, dt)

	local goalPitch = math.rad(pc.pitch + pc.pitchOff + math.noise(t * 0.11, s + 9, 0.3) * 2.5 * pc.drift)
	if pc.pitchNow == nil then
		pc.pitchNow = goalPitch
	end
	pc.pitchNow += (goalPitch - pc.pitchNow) * damp(3, dt)

	local rot = CFrame.Angles(0, pc.yaw + tremorY, 0) * CFrame.Angles(pc.pitchNow + tremorP, 0, 0)
	local camPos = pc.focus + rot:VectorToWorldSpace(Vector3.new(0, 0, pc.dist))
	if pc.collide then
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		local ignore = { character() :: any }
		for _, p in Players:GetPlayers() do
			if p.Character then
				table.insert(ignore, p.Character)
			end
		end
		params.FilterDescendantsInstances = ignore
		local hit = workspace:Raycast(pc.focus, camPos - pc.focus, params)
		if hit then
			camPos = hit.Position + (pc.focus - camPos).Unit * 0.6
		end
	end
	return CFrame.new(camPos) * rot, pc.fov
end

---------------------------------------------------------------- actions

local Actions = {}
Driver.actions = Actions

local function log(run: any, msg: string)
	table.insert(run.log, string.format("%.2f %s", run.clock and run.clock() or 0, msg))
	if #run.log > 60 then
		table.remove(run.log, 1)
	end
end

local function flatDist(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

local function moveTo(run: any, goal: Vector3, timeout: number, reach: number)
	local h = humanoid()
	local r = rootPart()
	if not h or not r then
		return
	end
	local t0 = os.clock()
	local lastIssue = -10
	while run.alive and os.clock() - t0 < timeout do
		r = rootPart()
		if not r then
			return
		end
		if flatDist(r.Position, goal) <= reach then
			return true
		end
		if os.clock() - lastIssue > 6 then -- MoveTo times out after 8 s; keep re-issuing
			h:MoveTo(goal)
			lastIssue = os.clock()
		end
		task.wait()
	end
	return false
end

-- walk: { to = target } or { path = {target, ...} }; each path item may carry jump = true.
-- Options: speed (WalkSpeed), pathfind (use PathfindingService), jitter (studs of human wobble), timeout, reach.
function Actions.walk(run: any, ev: any)
	local h = humanoid()
	if not h then
		return
	end
	if ev.speed then
		h.WalkSpeed = ev.speed
	end
	local list = ev.path or { ev.to }
	local rng = Random.new(run.seed + (ev.t or 0) * 10)
	for _, item in list do
		if not run.alive then
			return
		end
		local goal = resolvePos(item)
		if ev.jitter then
			goal += Vector3.new(rng:NextNumber(-ev.jitter, ev.jitter), 0, rng:NextNumber(-ev.jitter, ev.jitter))
		end
		local legs = { goal }
		if ev.pathfind then
			local r = rootPart()
			local path = PathfindingService:CreatePath({ AgentCanJump = true })
			local ok = r and pcall(function()
				path:ComputeAsync(r.Position, goal)
			end)
			if ok and path.Status == Enum.PathStatus.Success then
				legs = {}
				for _, wp in path:GetWaypoints() do
					table.insert(legs, { pos = wp.Position, jump = wp.Action == Enum.PathWaypointAction.Jump })
				end
			end
		end
		for _, leg in legs do
			local p = if typeof(leg) == "Vector3" then leg else leg.pos
			if typeof(leg) ~= "Vector3" and leg.jump then
				h.Jump = true
			end
			moveTo(run, p, ev.timeout or 12, ev.reach or 1.5)
		end
		if type(item) == "table" and item.jump then
			h.Jump = true
		end
	end
	if ev.speed and run.snap.walkSpeed then
		h.WalkSpeed = run.snap.walkSpeed
	end
end

function Actions.jump(_run: any, _ev: any)
	local h = humanoid()
	if h then
		h.Jump = true
	end
end

-- face: turn the character toward a target over ev.time seconds (a human doesn't snap).
function Actions.face(run: any, ev: any)
	local h, r = humanoid(), rootPart()
	if not h or not r then
		return
	end
	local p = resolvePos(ev.target)
	local from = r.CFrame
	local flat = Vector3.new(p.X, from.Position.Y, p.Z)
	if (flat - from.Position).Magnitude < 0.1 then
		return
	end
	local to = CFrame.lookAt(from.Position, flat)
	h.AutoRotate = false
	local dur = ev.time or 0.35
	local t0 = os.clock()
	while run.alive and os.clock() - t0 < dur do
		local u = (os.clock() - t0) / dur
		local e = (1 - math.cos(math.pi * u)) / 2
		local cur = rootPart()
		if not cur then
			break
		end
		cur.CFrame = CFrame.new(cur.Position) * from.Rotation:Lerp(to.Rotation, e)
		RunService.RenderStepped:Wait()
	end
	local cur = rootPart()
	if cur then
		cur.CFrame = CFrame.new(cur.Position) * to.Rotation
	end
	h.AutoRotate = run.snap.autoRotate
end

-- look: a mouse-like camera turn in the player cam. yaw/pitch are degrees relative to the follow
-- direction; time; overshoot (0..0.15); target = keep the camera aimed at something; release = stop aiming.
function Actions.look(run: any, ev: any)
	local pc = run.pc
	if not pc then
		return
	end
	local t = run.clock()
	if ev.release then
		pc.aim = nil
	end
	if ev.target then
		pc.aim = ev.target
	end
	if ev.yaw then
		local cur = tweenValue(pc, t, "yaw")
		table.insert(pc.tweens, { key = "yaw", t0 = t, dur = ev.time or 0.6, from = cur, to = ev.yaw, overshoot = ev.overshoot })
	end
	if ev.pitch then
		local cur = tweenValue(pc, t, "pitch")
		table.insert(pc.tweens, { key = "pitch", t0 = t, dur = ev.time or 0.6, from = cur, to = ev.pitch, overshoot = ev.overshoot })
	end
	if ev.dist then
		pc.dist = ev.dist
	end
end

local function findPrompt(ev: any): ProximityPrompt?
	local roots: { Instance } = {}
	if ev.path or ev.tag or ev.player then
		local inst = targetInstance(ev)
		if inst then
			table.insert(roots, inst)
		end
	else
		table.insert(roots, workspace)
	end
	local r = rootPart()
	local near = if ev.near then resolvePos(ev.near) elseif r then r.Position else Vector3.zero
	local radius = ev.radius or 25
	local match = ev.match and string.lower(ev.match)
	local best, bestD = nil, math.huge
	for _, root in roots do
		local list = if root:IsA("ProximityPrompt") then { root } else root:GetDescendants()
		for _, d in list do
			if d:IsA("ProximityPrompt") and d.Enabled then
				local text = string.lower(d.ActionText .. " " .. d.ObjectText .. " " .. d.Name)
				if not match or string.find(text, match, 1, true) then
					local cf = instCFrame(d.Parent)
					local dist = cf and (cf.Position - near).Magnitude or math.huge
					if dist <= radius and dist < bestD then
						best, bestD = d, dist
					end
				end
			end
		end
	end
	return best
end

-- prompt: press a ProximityPrompt the way a custom prompt UI does (InputHoldBegin/End).
-- Find it by match (ActionText/ObjectText/Name substring), optionally under path/tag, within radius of near.
function Actions.prompt(run: any, ev: any)
	local pp = findPrompt(ev)
	if not pp then
		log(run, "prompt not found: " .. tostring(ev.match))
		return
	end
	pp:InputHoldBegin()
	task.wait(math.max(ev.hold or pp.HoldDuration, 0) + 0.06)
	pp:InputHoldEnd()
	log(run, "prompt " .. pp.ActionText)
end

-- Argument strings "$attr:Name" become LocalPlayer:GetAttribute("Name") at call time, so a server setup
-- snippet can hand item ids to the timeline (player:SetAttribute("TrailerItem", id) -> "$attr:TrailerItem").
local function subst(v: any): any
	if type(v) == "string" and string.sub(v, 1, 6) == "$attr:" then
		return player:GetAttribute(string.sub(v, 7))
	elseif type(v) == "table" then
		local out = {}
		for k, x in v do
			out[k] = subst(x)
		end
		return out
	end
	return v
end

local function args(ev: any): { any }
	return subst(ev.args or {})
end

-- invoke / fire: call a game remote directly (the honest fallback when a GUI click can't be simulated).
function Actions.invoke(run: any, ev: any)
	local rf = findPath(ev.remote)
	if not rf or not rf:IsA("RemoteFunction") then
		log(run, "no RemoteFunction " .. tostring(ev.remote))
		return
	end
	local res = table.pack(pcall(function()
		return rf:InvokeServer(table.unpack(args(ev)))
	end))
	if ev.save then
		run.results[ev.save] = res
	end
	log(run, "invoke " .. ev.remote .. " -> " .. tostring(res[2]))
end

function Actions.fire(run: any, ev: any)
	local re = findPath(ev.remote)
	if re and (re:IsA("RemoteEvent") or re:IsA("UnreliableRemoteEvent")) then
		re:FireServer(table.unpack(args(ev)))
	else
		log(run, "no RemoteEvent " .. tostring(ev.remote))
	end
end

function Actions.bindable(run: any, ev: any)
	local b = findPath(ev.path)
	if b and b:IsA("BindableEvent") then
		b:Fire(table.unpack(args(ev)))
	elseif b and b:IsA("BindableFunction") then
		local ok, res = pcall(function()
			return b:Invoke(table.unpack(args(ev)))
		end)
		if ev.save then
			run.results[ev.save] = { ok, res }
		end
	else
		log(run, "no bindable " .. tostring(ev.path))
	end
end

function Actions.equip(run: any, ev: any)
	local h = humanoid()
	local bp = player:FindFirstChildOfClass("Backpack")
	local tool = bp and bp:FindFirstChild(ev.tool)
	if h and tool and tool:IsA("Tool") then
		h:EquipTool(tool)
	else
		log(run, "no tool " .. tostring(ev.tool))
	end
end

function Actions.teleport(_run: any, ev: any)
	local c = character()
	local cf = resolve(ev.to)
	if c and cf then
		local face = ev.face and resolve(ev.face)
		local p = cf.Position + Vector3.new(0, ev.lift or 3, 0)
		if face then
			c:PivotTo(CFrame.lookAt(p, Vector3.new(face.Position.X, p.Y, face.Position.Z)))
		else
			c:PivotTo(CFrame.new(p) * cf.Rotation)
		end
	end
end

function Actions.hud(run: any, ev: any)
	if not run.passive then
		applyHud(run, ev.show ~= false)
	end
end

function Actions.attr(_run: any, ev: any)
	local inst = findPath(ev.path)
	if inst then
		inst:SetAttribute(ev.name, ev.value)
	end
end

function Actions.emit(run: any, ev: any)
	run.cue:Fire(ev.cue or ev.name)
end

-- camera: switch to a CameraRig preset (cinematic) or back to "player"; blend = seconds of crossfade.
function Actions.camera(run: any, ev: any)
	if run.passive then
		return
	end
	local spec = ev.spec or ev
	run.blendFrom = run.lastCF
	run.blendT0 = run.clock()
	run.blendDur = ev.blend or 0
	if spec.preset == "player" then
		run.mode = "player"
		if spec.player then
			for k, v in spec.player do
				run.pc[k] = v
			end
		end
	else
		run.mode = "rig"
		run.rigSpec = spec
		run.rigT0 = run.clock()
	end
end

---------------------------------------------------------------- triggers ("on")

-- on = { event = "ReplicatedStorage.Remotes.X", arg1 = "Roll" } | { cue = "name" }
--    | { childAdded = "Workspace.Folder", name = "pattern" } | { tagAdded = "Tag" }
--    | { attribute = { path = "...", name = "Attr" } };  plus delay, once (default true)
local function connectTrigger(run: any, ev: any, fire: () -> ())
	local on = ev.on
	local once = on.once ~= false
	local done = false
	local function go()
		if done or not run.alive then
			return
		end
		if once then
			done = true
		end
		task.delay(on.delay or 0, fire)
	end
	local conn
	if on.event then
		local re = findPath(on.event)
		if re and (re:IsA("RemoteEvent") or re:IsA("UnreliableRemoteEvent")) then
			conn = re.OnClientEvent:Connect(function(a1)
				if on.arg1 == nil or a1 == on.arg1 then
					go()
				end
			end)
		elseif re and re:IsA("BindableEvent") then
			conn = re.Event:Connect(function(a1)
				if on.arg1 == nil or a1 == on.arg1 then
					go()
				end
			end)
		end
	elseif on.cue then
		conn = run.cue.Event:Connect(function(name)
			if name == on.cue then
				go()
			end
		end)
	elseif on.childAdded then
		local parent = findPath(on.childAdded)
		if parent then
			conn = parent.ChildAdded:Connect(function(c)
				if not on.name or string.find(c.Name, on.name) then
					go()
				end
			end)
		end
	elseif on.tagAdded then
		conn = CollectionService:GetInstanceAddedSignal(on.tagAdded):Connect(go)
	elseif on.attribute then
		local inst = findPath(on.attribute.path)
		if inst then
			conn = inst:GetAttributeChangedSignal(on.attribute.name):Connect(go)
		end
	end
	if conn then
		table.insert(run.conns, conn)
	else
		log(run, "trigger target missing: " .. HttpService:JSONEncode(on))
	end
end

---------------------------------------------------------------- calibration

function Driver.calibrate(secs: number?, rgb: { number }?)
	Driver.stop()
	local pg = player:WaitForChild("PlayerGui")
	local g = Instance.new("ScreenGui")
	g.Name = CALIB
	g.IgnoreGuiInset = true
	pcall(function()
		g.ScreenInsets = Enum.ScreenInsets.None
	end)
	g.DisplayOrder = 2147483647
	g.ResetOnSpawn = false
	local f = Instance.new("Frame")
	f.Size = UDim2.fromScale(1, 1)
	f.BorderSizePixel = 0
	local c = rgb or { 0, 255, 255 }
	f.BackgroundColor3 = Color3.fromRGB(c[1], c[2], c[3])
	f.Parent = g
	local snapRun = { snap = snapshot() }
	applyChrome(snapRun, false)
	g.Parent = pg
	task.delay(secs or 8, function()
		if g.Parent then
			g:Destroy()
		end
		applyChrome(snapRun, true)
	end)
	return { ok = true, until_ms = nowMs() + (secs or 8) * 1000 }
end

function Driver.hud(show: boolean)
	local run = current or { snap = snapshot() }
	applyHud(run, show)
	return true
end

function Driver.chrome(show: boolean)
	local run = current or { snap = snapshot() }
	applyChrome(run, show)
	return true
end

---------------------------------------------------------------- run

-- shot fields used here (all optional except dur):
--   id, kind = "gameplay" | "cinematic", dur, hud (bool; default true for gameplay, false for cinematic),
--   coreGui (bool; default false = hide chat/playerlist/backpack/top bar), seed,
--   start = { at = target, face = target }, player = {player-cam cfg}, camera = {CameraRig spec | preset="player"},
--   timeline = { { t = seconds, ["do"] = action, ...args } | { on = trigger, ["do"] = action, ...args } },
--   actors = { ["client-2"] = { start = ..., timeline = ... } }   (second player, driven by its own run)
-- opts: rig (CameraRig module, required for cinematic cameras), delay (s before t=0; the first frame is held),
--   actor ("client-1" default), hold (s to keep the last frame), keep (don't clean up at the end).
function Driver.run(shot: any, opts: any?)
	opts = opts or {}
	Driver.stop()

	local actor = opts.actor or "client-1"
	local spec = shot
	local passive = false
	if shot.actors and shot.actors[actor] then
		spec = shot.actors[actor]
		passive = spec.camera == nil -- a second actor only moves its character unless it has a camera
	end
	if shot.kind == "prep" then
		passive = true -- set-up run between takes: drive the game, leave camera and HUD alone, don't record
	end
	local run = {
		shotId = shot.id or "shot",
		alive = true,
		conns = {},
		cleanups = {},
		results = {},
		log = {},
		passive = passive,
		seed = shot.seed or 7,
		mode = "player",
	}
	run.snap = snapshot()
	current = run

	local m = Instance.new("Folder")
	m.Name = MARK
	local stopEv = Instance.new("BindableEvent")
	stopEv.Name = "Stop"
	stopEv.Parent = m
	local cue = Instance.new("BindableEvent")
	cue.Name = "Cue"
	cue.Parent = m
	run.cue = cue
	run.marker = m
	m:SetAttribute("Shot", run.shotId)
	m.Parent = player
	table.insert(run.conns, stopEv.Event:Connect(function()
		cleanup(run, "stopped")
	end))
	table.insert(run.conns, player.CharacterAdded:Connect(function()
		-- a respawn would leave the camera on a dead humanoid; keep following the new one
		if run.pc then
			run.pc.focus = nil
		end
	end))

	local dur = shot.dur or spec.dur or 5
	local delay = opts.delay or 0
	run.startsAtMs = nowMs() + math.floor(delay * 1000)
	run.endsAtMs = run.startsAtMs + math.floor(dur * 1000)
	m:SetAttribute("StartsAtMs", run.startsAtMs)
	m:SetAttribute("EndsAtMs", run.endsAtMs)
	local tStart = os.clock() + delay
	run.clock = function()
		return math.max(0, os.clock() - tStart)
	end

	local ok, err = pcall(function()
		-- 1. pose: character placement, controls off (so the keyboard can't fight MoveTo)
		if spec.start and spec.start.at then
			Actions.teleport(run, { to = spec.start.at, face = spec.start.face, lift = spec.start.lift })
		end
		local c = controls()
		if c then
			pcall(function()
				c:Disable()
			end)
			run.controlsOff = true
		end
		if passive then
			return
		end
		-- 2. HUD / chrome
		local kind = shot.kind or "gameplay"
		local showHud = shot.hud
		if showHud == nil then
			showHud = kind ~= "cinematic"
		end
		applyHud(run, showHud)
		applyChrome(run, shot.coreGui == true)
		-- 3. camera
		run.pc = newPlayerCam(shot.player, run.seed)
		local cam0 = shot.camera
		if cam0 and cam0.preset and cam0.preset ~= "player" then
			if not opts.rig then
				error("cinematic camera needs opts.rig = CameraRig")
			end
			run.mode = "rig"
			run.rigSpec = cam0
			run.rigT0 = 0
		end
		local blur = Instance.new("BlurEffect")
		blur.Name = BLUR
		blur.Size = 0
		blur.Parent = Lighting
		local cam = workspace.CurrentCamera
		cam.CameraType = Enum.CameraType.Scriptable
		local lastT = os.clock()
		RunService:BindToRenderStep(BIND, Enum.RenderPriority.Camera.Value + 1, function()
			if not run.alive then
				return
			end
			local now = os.clock()
			local dt = math.min(now - lastT, 0.1)
			lastT = now
			local t = run.clock()
			local cf, fov, bl = nil, 70, 0
			if run.mode == "rig" and opts.rig then
				local okE, a, b, c2 = pcall(opts.rig.evaluate, run.rigSpec, t - (run.rigT0 or 0), resolve)
				if okE then
					cf, fov, bl = a, b, c2
				else
					run.err = tostring(a)
					m:SetAttribute("Error", run.err)
				end
			else
				cf, fov = playerCamStep(run, run.pc, t, dt)
			end
			if cf then
				if run.blendFrom and run.blendDur and run.blendDur > 0 then
					local u = math.clamp((t - run.blendT0) / run.blendDur, 0, 1)
					local e = (1 - math.cos(math.pi * u)) / 2
					cf = run.blendFrom:Lerp(cf, e)
					if u >= 1 then
						run.blendFrom = nil
					end
				end
				cam.CFrame = cf
				cam.FieldOfView = fov
				run.lastCF = cf
			end
			blur.Size = (if run.rigSpec then run.rigSpec.blurMax or 18 else 18) * (bl or 0)
		end)
	end)
	if not ok then
		run.err = tostring(err)
		cleanup(run, "setup failed")
		return { ok = false, shot = run.shotId, error = run.err }
	end

	-- 4. timeline
	local timeline = spec.timeline or {}
	for _, ev in timeline do
		local name = ev["do"]
		local fn = Actions[name]
		if not fn then
			log(run, "unknown action " .. tostring(name))
			continue
		end
		local function fire()
			if not run.alive then
				return
			end
			task.spawn(function()
				local okA, e = pcall(fn, run, ev)
				if not okA then
					log(run, name .. " failed: " .. tostring(e))
				end
			end)
		end
		if ev.on then
			connectTrigger(run, ev, fire)
		else
			task.delay(math.max(0, tStart + (ev.t or 0) - os.clock()), fire)
		end
	end

	-- 5. end of shot
	if not opts.keep then
		task.delay(math.max(0, tStart + dur + (opts.hold or 0) - os.clock()), function()
			cleanup(run, "done")
		end)
	end

	return { ok = true, shot = run.shotId, actor = actor, startsAtMs = run.startsAtMs, endsAtMs = run.endsAtMs, dur = dur }
end

return Driver
