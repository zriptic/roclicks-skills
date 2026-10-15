--!nonstrict
-- CameraRig: cinematic camera moves for trailer shots (generic; no game-specific names).
--
-- Pure evaluation:
--   CameraRig.evaluate(spec, t, resolve?) -> (CFrame, fov, blur01)
--     spec.preset: "dolly" | "spline" | "flyover" | "bezier" | "orbit" | "crane" | "pushin" | "whip" | "static"
--     spec.dur (s), spec.ease ("sineInOut" default; any TweenService style+direction such as "quintOut", "linear")
--     spec.fov or spec.fov0/fov1, spec.roll (deg), spec.shake = { amp = 0.12, freq = 0.5 } (handheld noise)
--   Targets (anywhere a position is wanted): {x,y,z} | {pos={x,y,z}} | {path="Workspace.A.B"} | {tag="T"}
--     | {player="self"|"other"|"Name"}; plus optional offset={x,y,z} (world) or localOffset={x,y,z}.
--     `resolve` is supplied by TrailerDriver (it knows the character); CameraRig.resolve is the fallback.
--
-- Standalone playback (no driver):
--   local h = CameraRig.play(spec, { onDone = fn, resolve = fn })  -- h:Stop()
--   CameraRig.playOn(signal, spec, opts) -- start the move when a RBXScriptSignal fires (game-event sync)
-- Everything it creates is cleaned up by Stop() or on completion; calling play twice stops the first.

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local CameraRig = {}

local BIND = "__TrailerCameraRig"

---------------------------------------------------------------- helpers

local STYLES = {
	linear = "Linear", sine = "Sine", quad = "Quad", cubic = "Cubic", quart = "Quart",
	quint = "Quint", expo = "Exponential", exponential = "Exponential", circ = "Circular",
	circular = "Circular", back = "Back", elastic = "Elastic", bounce = "Bounce",
}

function CameraRig.ease(alpha: number, name: string?): number
	alpha = math.clamp(alpha, 0, 1)
	local n = name or "sineInOut"
	if n == "linear" then
		return alpha
	end
	local base, dir = string.match(n, "^(%a-)(InOut)$")
	if not base then
		base, dir = string.match(n, "^(%a-)(In)$")
	end
	if not base then
		base, dir = string.match(n, "^(%a-)(Out)$")
	end
	if not base then
		base, dir = n, "InOut"
	end
	local style = STYLES[string.lower(base)] or "Sine"
	return TweenService:GetValue(alpha, Enum.EasingStyle[style], Enum.EasingDirection[dir])
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
CameraRig.v3 = v3

-- Dot path from game: "Workspace.Map.Lever" or "ReplicatedStorage.Remotes.Action".
function CameraRig.findPath(path: string): Instance?
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
CameraRig.instCFrame = instCFrame

-- Fallback resolver (TrailerDriver passes a richer one that also knows "nearest").
function CameraRig.resolve(target: any): CFrame?
	local direct = v3(target)
	if direct then
		return CFrame.new(direct)
	end
	if typeof(target) == "CFrame" then
		return target
	end
	if typeof(target) == "Instance" then
		return instCFrame(target)
	end
	if type(target) ~= "table" then
		return nil
	end
	local cf: CFrame? = nil
	if target.pos then
		cf = CFrame.new(v3(target.pos) :: Vector3)
	elseif target.path then
		cf = instCFrame(CameraRig.findPath(target.path))
	elseif target.tag then
		local list = CollectionService:GetTagged(target.tag)
		cf = instCFrame(list[target.index or 1])
	elseif target.player then
		local me = Players.LocalPlayer
		local who: Player? = nil
		if target.player == "self" then
			who = me
		else
			for _, p in Players:GetPlayers() do
				if (target.player == "other" and p ~= me) or p.Name == target.player then
					who = p
					break
				end
			end
		end
		cf = instCFrame(who)
	end
	if not cf then
		return nil
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

local function pos(resolve, target: any, fallback: Vector3?): Vector3
	local cf = resolve(target)
	if cf then
		return cf.Position
	end
	if fallback then
		return fallback
	end
	error("CameraRig: cannot resolve target " .. tostring(target and (target.tag or target.path or target.player)))
end

local function catmull(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: number): Vector3
	local t2, t3 = t * t, t * t * t
	return 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3)
end

-- Uniform-speed position along a Catmull-Rom spline through pts at u in [0,1].
local function spanPoint(pts: { Vector3 }, seg: number, s: number): Vector3
	local n = #pts
	local p0 = pts[math.max(1, seg - 1)]
	local p1, p2 = pts[seg], pts[seg + 1]
	local p3 = pts[math.min(n, seg + 2)]
	return catmull(p0, p1, p2, p3, s)
end

local function splineAt(pts: { Vector3 }, u: number): Vector3
	local n = #pts
	if n == 1 then
		return pts[1]
	end
	if n == 2 then
		return pts[1]:Lerp(pts[2], u)
	end
	-- arc-length table, 16 samples per span; each sample is (seg, s, cumulative distance)
	local samples = { { seg = 1, s = 0, d = 0 } }
	local prev, total = pts[1], 0
	for i = 1, n - 1 do
		for k = 1, 16 do
			local q = spanPoint(pts, i, k / 16)
			total += (q - prev).Magnitude
			table.insert(samples, { seg = i, s = k / 16, d = total })
			prev = q
		end
	end
	local want = math.clamp(u, 0, 1) * total
	for idx = 2, #samples do
		local b = samples[idx]
		if b.d >= want then
			local a = samples[idx - 1]
			local f = if b.d > a.d then (want - a.d) / (b.d - a.d) else 0
			local s0 = if a.seg == b.seg then a.s else 0
			return spanPoint(pts, b.seg, s0 + (b.s - s0) * f)
		end
	end
	return pts[n]
end

local function bezier(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: number): Vector3
	local u = 1 - t
	return u * u * u * p0 + 3 * u * u * t * p1 + 3 * u * t * t * p2 + t * t * t * p3
end

local function lookAt(from: Vector3, at: Vector3): CFrame
	if (at - from).Magnitude < 1e-3 then
		return CFrame.new(from)
	end
	return CFrame.lookAt(from, at)
end

local function shakeOffset(spec: any, t: number): CFrame
	local sh = spec.shake
	if not sh then
		return CFrame.identity
	end
	local amp = sh.amp or 0.12
	local f = sh.freq or 0.5
	local seed = sh.seed or 3.7
	local rx = math.noise(t * f, seed, 0.1) * amp
	local ry = math.noise(seed, t * f, 0.7) * amp
	local rz = math.noise(0.3, seed, t * f) * amp * 0.4
	return CFrame.Angles(math.rad(rx * 4), math.rad(ry * 4), math.rad(rz * 2))
end

---------------------------------------------------------------- evaluate

function CameraRig.evaluate(spec: any, t: number, resolve: any?): (CFrame, number, number)
	resolve = resolve or CameraRig.resolve
	local dur = math.max(spec.dur or 3, 1e-3)
	local a = CameraRig.ease(t / dur, spec.ease)
	local preset = spec.preset or "static"
	local fov = spec.fov or 70
	if spec.fov0 or spec.fov1 then
		fov = (spec.fov0 or fov) + ((spec.fov1 or fov) - (spec.fov0 or fov)) * a
	end
	local blur = 0
	local cf: CFrame

	if preset == "dolly" or preset == "spline" or preset == "flyover" then
		local pts = {}
		for _, p in spec.points do
			table.insert(pts, pos(resolve, p))
		end
		local at = splineAt(pts, a)
		local look: Vector3
		if spec.look == nil or spec.look == "ahead" then
			local ahead = splineAt(pts, math.min(1, a + 0.02))
			look = if (ahead - at).Magnitude > 1e-3 then ahead else at + (pts[#pts] - pts[1])
		else
			look = pos(resolve, spec.look)
		end
		cf = lookAt(at, look)
	elseif preset == "bezier" then
		local p = spec.points
		local at = bezier(pos(resolve, p[1]), pos(resolve, p[2]), pos(resolve, p[3]), pos(resolve, p[4]), a)
		local look = if spec.look and spec.look ~= "ahead"
			then pos(resolve, spec.look)
			else bezier(pos(resolve, p[1]), pos(resolve, p[2]), pos(resolve, p[3]), pos(resolve, p[4]), math.min(1, a + 0.02))
		cf = lookAt(at, look)
	elseif preset == "orbit" then
		local c = pos(resolve, spec.center)
		local ang = math.rad((spec.from or 0) + (spec.sweep or 90) * a)
		local r = (spec.radius or 20) + ((spec.radius1 or spec.radius or 20) - (spec.radius or 20)) * a
		local h = (spec.height or 8) + ((spec.height1 or spec.height or 8) - (spec.height or 8)) * a
		local at = c + Vector3.new(math.sin(ang) * r, h, math.cos(ang) * r)
		local lookH = spec.lookHeight or 2
		cf = lookAt(at, c + Vector3.new(0, lookH, 0))
	elseif preset == "crane" then
		-- Starts low and close, rises and pulls back to reveal.
		local c = pos(resolve, spec.center)
		local ang = math.rad(spec.angle or 0)
		local d = (spec.dist0 or 10) + ((spec.dist1 or 30) - (spec.dist0 or 10)) * a
		local h = (spec.h0 or 1.5) + ((spec.h1 or 25) - (spec.h0 or 1.5)) * a
		local lh = (spec.lookH0 or 3) + ((spec.lookH1 or 0) - (spec.lookH0 or 3)) * a
		local at = c + Vector3.new(math.sin(ang) * d, h, math.cos(ang) * d)
		cf = lookAt(at, c + Vector3.new(0, lh, 0))
	elseif preset == "pushin" then
		local c = pos(resolve, spec.center) + Vector3.new(0, spec.lookHeight or 0, 0)
		local dir: Vector3
		if spec.from then
			dir = (pos(resolve, spec.from) - c)
		else
			local ang = math.rad(spec.angle or 0)
			dir = Vector3.new(math.sin(ang), spec.rise or 0.35, math.cos(ang))
		end
		if dir.Magnitude < 1e-3 then
			dir = Vector3.new(0, 0.3, 1)
		end
		dir = dir.Unit
		local d = (spec.dist0 or 20) + ((spec.dist1 or 8) - (spec.dist0 or 20)) * a
		cf = lookAt(c + dir * d, c)
	elseif preset == "whip" then
		-- Fixed position; the look snaps from `fromLook` to `toLook` around the middle of the shot.
		local at = pos(resolve, spec.pos)
		local f = pos(resolve, spec.fromLook)
		local to = pos(resolve, spec.toLook)
		local whipStart = spec.whipAt or 0.35
		local whipLen = spec.whipLen or 0.3
		local u = math.clamp((t - whipStart * dur) / whipLen, 0, 1)
		local eu = CameraRig.ease(u, spec.whipEase or "quintInOut")
		local c0, c1 = lookAt(at, f), lookAt(at, to)
		cf = c0:Lerp(c1, eu)
		-- blur peaks mid-whip
		blur = math.sin(math.pi * u)
	else -- static
		local at = pos(resolve, spec.pos)
		local look = pos(resolve, spec.look or spec.pos, at + Vector3.new(0, 0, -1))
		cf = lookAt(at, look)
	end

	if spec.roll then
		cf = cf * CFrame.Angles(0, 0, math.rad(spec.roll))
	end
	cf = cf * shakeOffset(spec, t)
	return cf, fov, blur
end

---------------------------------------------------------------- standalone playback

local active: any = nil

function CameraRig.stop()
	if active then
		active:Stop()
	end
end

function CameraRig.play(spec: any, opts: any?)
	opts = opts or {}
	CameraRig.stop()
	local cam = workspace.CurrentCamera
	local saved = { type = cam.CameraType, subject = cam.CameraSubject, fov = cam.FieldOfView }
	local blurFx = Instance.new("BlurEffect")
	blurFx.Name = "__TrailerRigBlur"
	blurFx.Size = 0
	blurFx.Parent = game:GetService("Lighting")
	local t0 = os.clock()
	local handle = {}
	local stopped = false
	function handle:Stop()
		if stopped then
			return
		end
		stopped = true
		pcall(function()
			RunService:UnbindFromRenderStep(BIND)
		end)
		blurFx:Destroy()
		if not opts.keepCamera then
			cam.CameraType = saved.type
			cam.CameraSubject = saved.subject
			cam.FieldOfView = saved.fov
		end
		if active == handle then
			active = nil
		end
		if opts.onDone then
			task.spawn(opts.onDone)
		end
	end
	active = handle
	cam.CameraType = Enum.CameraType.Scriptable
	RunService:BindToRenderStep(BIND, Enum.RenderPriority.Camera.Value + 2, function()
		local t = os.clock() - t0
		local ok, cf, fov, blur = pcall(CameraRig.evaluate, spec, math.min(t, spec.dur or 3), opts.resolve)
		if ok then
			cam.CFrame = cf
			cam.FieldOfView = fov
			blurFx.Size = (spec.blurMax or 18) * blur
		else
			warn("[CameraRig] " .. tostring(cf))
			handle:Stop()
			return
		end
		if t >= (spec.dur or 3) + (spec.hold or 0) then
			handle:Stop()
		end
	end)
	return handle
end

-- Start `spec` the next time `signal` fires (optionally only when its first argument equals opts.arg1).
function CameraRig.playOn(signal: RBXScriptSignal, spec: any, opts: any?)
	opts = opts or {}
	local conn
	conn = signal:Connect(function(first, ...)
		if opts.arg1 ~= nil and first ~= opts.arg1 then
			return
		end
		conn:Disconnect()
		task.delay(opts.delay or 0, function()
			CameraRig.play(spec, opts)
		end)
	end)
	return conn
end

return CameraRig
