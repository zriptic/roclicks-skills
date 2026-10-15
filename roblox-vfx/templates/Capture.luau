-- roblox-vfx skill: Capture. Holds an effect still at a chosen moment so a
-- screenshot (robloxstudio capture_screenshot) can see it, and aims the edit
-- camera. Replaces Roqer's capture_moments, one moment per call pair:
--
--   execute_luau:  local C = require(game.ReplicatedStorage.VFX.Capture)
--                  C.aim(Vector3.new(0, 3, 0), 30, 20)              -- target, distance, angleY
--                  return C.hold(game.ReplicatedStorage.VFX.Slam, CFrame.new(0, 3, 0), 0.1)
--   capture_screenshot                       (in the NEXT turn: tool calls in one turn race)
--   execute_luau:  return C.hold(..., 0.25)  -- stops the previous hold first
--   ...
--   execute_luau:  C.release()
--
-- Works in edit mode (no playtest needed) and in a playtest client
-- (eval_client_runtime) for the player's own view.

local ContentProvider = game:GetService("ContentProvider")
local RunService = game:GetService("RunService")

local Capture = {}

local function vfx()
	return require(script.Parent.Emit)
end

local function shapes()
	local module = script.Parent:FindFirstChild("Shapes")
	return module and require(module)
end

-- Stops the effect currently held, if any.
function Capture.release()
	local handle = _G.vfxCapture
	if handle and not handle.finished then
		handle:stop()
	end
	_G.vfxCapture = nil
end

-- Points the current camera at `target` from `distance` studs away, `angleY`
-- degrees above the horizon and `around` degrees around (0 = from +Z looking
-- toward -Z). Sets Focus too: the edit camera reverts a CFrame-only change.
function Capture.aim(target: Vector3, distance: number, angleY: number?, around: number?)
	local camera = workspace.CurrentCamera
	local pitch, yaw = math.rad(angleY or 15), math.rad(around or 0)
	local offset = Vector3.new(math.sin(yaw) * math.cos(pitch), math.sin(pitch), math.cos(yaw) * math.cos(pitch)) * distance
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = CFrame.lookAt(target + offset, target)
	camera.Focus = CFrame.new(target)
	return camera.CFrame
end

-- The player's view in edit mode: a third-person camera behind a caster at
-- `caster`, looking toward `effect` (12 studs back, 5 up, like the default).
function Capture.playerView(caster: Vector3, effect: Vector3, back: number?, up: number?)
	local camera = workspace.CurrentCamera
	local flat = Vector3.new(effect.X - caster.X, 0, effect.Z - caster.Z)
	local dir = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.new(0, 0, -1)
	local eye = caster - dir * (back or 12) + Vector3.new(0, up or 5, 0)
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = CFrame.lookAt(eye, effect)
	camera.Focus = CFrame.new(effect)
	return camera.CFrame
end

-- Plays `template` at `cframe` and freezes it at `at` effect seconds.
-- Runs at full speed, slows to 0.05x for the last 0.08 s so it lands
-- precisely, then holds (time scale 0). Returns a status line.
-- options: { parent: Instance?, preload: boolean? (default true) }
function Capture.hold(template: Instance, cframe: CFrame, at: number, options: any?): string
	options = options or {}
	Capture.release()
	local S = shapes()
	if S then
		template = S.prepare(template)
	end
	if options.preload ~= false then
		-- A texture shown for the first time takes a moment; load before playing.
		ContentProvider:PreloadAsync({ template })
	end
	local handle = vfx().play(template, cframe, { parent = options.parent })
	_G.vfxCapture = handle
	local started = os.clock()
	local slowed = false
	while not handle.finished and handle.time < at do
		if not slowed and handle.time >= at - 0.08 then
			handle:setTimeScale(0.05)
			slowed = true
		end
		if os.clock() - started > 40 then
			break
		end
		RunService.Heartbeat:Wait()
	end
	if handle.finished then
		return string.format("effect ended at %.3f s, before %.3f s", handle.time, at)
	end
	handle:setTimeScale(0)
	return string.format("held at %.3f s (asked %.3f)", handle.time, at)
end

-- Slow motion instead of a hold: a held Trail loses its segments, so for
-- trails play at `scale` (0.04) and capture while it runs.
function Capture.slow(template: Instance, cframe: CFrame, scale: number?, options: any?)
	options = options or {}
	Capture.release()
	local S = shapes()
	if S then
		template = S.prepare(template)
	end
	local handle = vfx().play(template, cframe, { parent = options.parent, timeScale = scale or 0.04 })
	_G.vfxCapture = handle
	return "playing at " .. tostring(scale or 0.04) .. "x"
end

-- An anchored, transparent marker the size of the effect, to frame against.
function Capture.marker(name: string, cframe: CFrame, size: Vector3): BasePart
	local old = workspace:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = size
	part.CFrame = cframe
	part.Parent = workspace
	return part
end

return Capture
