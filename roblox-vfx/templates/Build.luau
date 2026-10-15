-- roblox-vfx skill: Build. Turns a list of steps (Lua tables, or the same thing
-- as a JSON string) into instances, so effects can be written as data:
--
--   local Build = require(game.ReplicatedStorage.VFX.Build)
--   local ids, report = Build.run("game.ReplicatedStorage.VFX.Slam", {
--     { op = "create", id = "a", className = "Attachment", parent = "$part" },
--     { op = "create", className = "ParticleEmitter", name = "Flash", parent = "$a",
--       properties = { Texture = "rbxasset://...", Rate = 0, Lifetime = { 0.06, 0.1 },
--         Size = { { time = 0, value = 4 }, { time = 1, value = 18 } }, Color = { 1, 0.95, 0.85 } },
--       attributes = { EmitCount = 1, EmitDelay = 0.14 } },
--   })
--   print(report)
--
-- Root: a path ("game.ReplicatedStorage.VFX.Slam") or an Instance. A missing
-- root is created as a Model holding an invisible anchored part named "Root"
-- (its PrimaryPart). Ids "$root" (the root) and "$part" (its PrimaryPart) are
-- predefined.
--
-- Steps:
--   { op = "create", className, name?, id?, parent?, properties?, attributes?, tags?,
--     position?, rotation? }   parent: "$id", a "game.X.Y" path, or omitted (the root)
--   { op = "set", target, properties?, attributes? }
--   { op = "remove", target }
--
-- Values are coerced to the property's own type:
--   number                 -> number, NumberRange, NumberSequence
--   {a, b}                 -> NumberRange (min, max), Vector2
--   {a, b, c}              -> Color3 (0..1, may exceed 1 for a glowing Decal), Vector3,
--                             ColorSequence (one colour)
--   "#rrggbb"              -> Color3 / ColorSequence
--   {{time=, value=, envelope=?}, ...} -> NumberSequence or ColorSequence keypoints
--   "Name"                 -> EnumItem by name
--   "$id" or "game.X.Y"    -> Instance (Beam/Trail Attachment0/1, Adornee, ...)
-- position/rotation (studs, degrees) place a BasePart or Model relative to the
-- root's pivot; for an Attachment they set Position/Orientation.
-- Created BaseParts default to Anchored, no collision/query/touch/shadow.

local HttpService = game:GetService("HttpService")
local CollectionService = game:GetService("CollectionService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local Build = {}

local function resolvePath(path: string): Instance?
	local parts = string.split(path, ".")
	if parts[1] ~= "game" then
		return nil
	end
	local current: Instance = game
	for i = 2, #parts do
		local name = parts[i]
		local nextOne = current:FindFirstChild(name)
		if not nextOne and current == game then
			local ok, service = pcall(game.GetService, game, name)
			nextOne = ok and service or nil
		end
		if not nextOne then
			return nil
		end
		current = nextOne
	end
	return current
end

local function ensureRoot(path: string): Instance
	local found = resolvePath(path)
	if found then
		return found
	end
	local parts = string.split(path, ".")
	assert(parts[1] == "game" and #parts >= 3, "Build: root path must look like game.Service.Name, got " .. path)
	-- Missing containers on the way are Folders; the leaf is a Model.
	local parent: Instance = resolvePath(parts[1] .. "." .. parts[2]) :: Instance
	assert(parent, "Build: no service " .. parts[2])
	for i = 3, #parts - 1 do
		local child = parent:FindFirstChild(parts[i])
		if not child then
			child = Instance.new("Folder")
			child.Name = parts[i]
			child.Parent = parent
		end
		parent = child
	end
	local model = Instance.new("Model")
	model.Name = parts[#parts]
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(1, 1, 1)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.CastShadow = false
	root.Parent = model
	model.PrimaryPart = root
	model.Parent = parent
	return model
end

local function hexColor(s: string): Color3?
	local hex = s:match("^#(%x%x%x%x%x%x)$")
	if hex then
		return Color3.fromHex(hex)
	end
	return nil
end

local function toColor(v: any): Color3
	if typeof(v) == "Color3" then
		return v
	elseif type(v) == "string" then
		local c = hexColor(v)
		if c then
			return c
		end
	elseif type(v) == "table" and type(v[1]) == "number" then
		return Color3.new(v[1], v[2], v[3])
	end
	error("expected a colour {r, g, b} (0..1) or \"#rrggbb\", got " .. HttpService:JSONEncode(v))
end

local function isKeypoints(v: any): boolean
	return type(v) == "table" and type(v[1]) == "table" and v[1].time ~= nil
end

-- Roblox needs keypoints from time 0 to time 1; pad the ends instead of failing.
local function padded(points: { any }): { any }
	table.sort(points, function(a, b)
		return a.time < b.time
	end)
	if points[1].time > 0 then
		table.insert(points, 1, { time = 0, value = points[1].value, envelope = points[1].envelope })
	end
	if points[#points].time < 1 then
		table.insert(points, { time = 1, value = points[#points].value, envelope = points[#points].envelope })
	end
	points[1].time = 0
	points[#points].time = 1
	return points
end

local function coerce(current: any, v: any, ids: { [string]: Instance }): any
	if type(v) == "string" and v:sub(1, 1) == "$" then
		local ref = ids[v:sub(2)]
		assert(ref, "unknown id " .. v)
		return ref
	end
	if type(v) == "string" and v:sub(1, 5) == "game." and (current == nil or typeof(current) == "Instance") then
		local ref = resolvePath(v)
		assert(ref, "no instance at " .. v)
		return ref
	end
	local kind = typeof(current)
	if kind == "number" or kind == "boolean" or kind == "string" then
		return v
	elseif kind == "NumberRange" then
		if type(v) == "number" then
			return NumberRange.new(v)
		end
		return NumberRange.new(math.min(v[1], v[2]), math.max(v[1], v[2]))
	elseif kind == "NumberSequence" then
		if type(v) == "number" then
			return NumberSequence.new(v)
		end
		if isKeypoints(v) then
			local keys = {}
			for _, p in padded(v) do
				table.insert(keys, NumberSequenceKeypoint.new(p.time, p.value, p.envelope or 0))
			end
			return NumberSequence.new(keys)
		end
		return NumberSequence.new(v[1], v[2])
	elseif kind == "ColorSequence" then
		if isKeypoints(v) then
			local keys = {}
			for _, p in padded(v) do
				table.insert(keys, ColorSequenceKeypoint.new(p.time, toColor(p.value)))
			end
			return ColorSequence.new(keys)
		end
		return ColorSequence.new(toColor(v))
	elseif kind == "Color3" then
		return toColor(v)
	elseif kind == "Vector3" then
		return Vector3.new(v[1], v[2], v[3])
	elseif kind == "Vector2" then
		return Vector2.new(v[1], v[2])
	elseif kind == "UDim2" then
		return UDim2.new(v[1], v[2], v[3], v[4])
	elseif kind == "EnumItem" then
		if typeof(v) == "EnumItem" then
			return v
		end
		return (current.EnumType :: any)[v]
	elseif kind == "CFrame" then
		if typeof(v) == "CFrame" then
			return v
		end
		local cf = CFrame.new(v[1], v[2], v[3])
		if v[4] then
			cf *= CFrame.fromOrientation(math.rad(v[4]), math.rad(v[5] or 0), math.rad(v[6] or 0))
		end
		return cf
	elseif kind == "Font" and type(v) == "string" then
		return Font.fromName(v)
	end
	return v
end

local function apply(instance: Instance, properties: any?, attributes: any?, ids, errors: { string })
	if properties then
		for name, value in properties do
			local okRead, current = pcall(function()
				return (instance :: any)[name]
			end)
			if not okRead then
				table.insert(errors, `{instance.Name}.{name}: not a property of {instance.ClassName}`)
				continue
			end
			local ok, err = pcall(function()
				(instance :: any)[name] = coerce(current, value, ids)
			end)
			if not ok then
				table.insert(errors, `{instance.Name}.{name}: {err}`)
			end
		end
	end
	if attributes then
		for name, value in attributes do
			local ok, err = pcall(instance.SetAttribute, instance, name, value)
			if not ok then
				table.insert(errors, `{instance.Name}@{name}: {err}`)
			end
		end
	end
end

local function pivotOf(root: Instance): CFrame
	if root:IsA("Model") then
		return root:GetPivot()
	elseif root:IsA("BasePart") then
		return root.CFrame
	end
	return CFrame.identity
end

local function target(ref: string, ids, root: Instance): Instance?
	if ref:sub(1, 1) == "$" then
		return ids[ref:sub(2)]
	elseif ref:sub(1, 5) == "game." then
		return resolvePath(ref)
	end
	return root:FindFirstChild(ref, true)
end

function Build.resolve(path: string): Instance?
	return resolvePath(path)
end

-- Runs the steps under `root`. Returns the id table and a one-line-per-item report.
function Build.run(rootOrPath: Instance | string, steps: any): ({ [string]: Instance }, string)
	if type(steps) == "string" then
		steps = HttpService:JSONDecode(steps)
	end
	if steps.op then
		steps = { steps }
	end
	local root = if type(rootOrPath) == "string" then ensureRoot(rootOrPath) else rootOrPath
	local ids: { [string]: Instance } = { root = root }
	if root:IsA("Model") and root.PrimaryPart then
		ids.part = root.PrimaryPart
	end
	local base = pivotOf(root)
	local errors, made = {}, {}
	local recording = nil
	pcall(function()
		recording = ChangeHistoryService:TryBeginRecording("roblox-vfx build")
	end)

	for index, step in steps do
		local ok, err = pcall(function()
			if step.op == "create" then
				local instance = Instance.new(step.className)
				if instance:IsA("BasePart") then
					instance.Anchored = true
					instance.CanCollide = false
					instance.CanQuery = false
					instance.CanTouch = false
					instance.CastShadow = false
				end
				instance.Name = step.name or step.className
				local parent = if step.parent then target(step.parent, ids, root) else root
				assert(parent, "no parent " .. tostring(step.parent))
				if step.id then
					ids[step.id] = instance
				end
				apply(instance, step.properties, step.attributes, ids, errors)
				if step.position or step.rotation then
					local p = step.position or { 0, 0, 0 }
					local r = step.rotation or { 0, 0, 0 }
					if instance:IsA("Attachment") then
						instance.Position = Vector3.new(p[1], p[2], p[3])
						instance.Orientation = Vector3.new(r[1], r[2], r[3])
					else
						local cf = base * CFrame.new(p[1], p[2], p[3])
							* CFrame.fromOrientation(math.rad(r[1]), math.rad(r[2]), math.rad(r[3]))
						if instance:IsA("BasePart") then
							instance.CFrame = cf
						elseif instance:IsA("Model") then
							instance.WorldPivot = cf
						end
					end
				elseif instance:IsA("BasePart") and not (step.properties and (step.properties.CFrame or step.properties.Position)) then
					instance.CFrame = base
				end
				for _, tag in step.tags or {} do
					CollectionService:AddTag(instance, tag)
				end
				instance.Parent = parent
				table.insert(made, `+ {instance:GetFullName()} ({step.className})`)
			elseif step.op == "set" then
				local instance = target(step.target, ids, root)
				assert(instance, "no target " .. tostring(step.target))
				apply(instance, step.properties, step.attributes, ids, errors)
				table.insert(made, `~ {instance:GetFullName()}`)
			elseif step.op == "remove" then
				local instance = target(step.target, ids, root)
				if instance then
					table.insert(made, `- {instance:GetFullName()}`)
					instance:Destroy()
				end
			else
				error("unknown op " .. tostring(step.op))
			end
		end)
		if not ok then
			table.insert(errors, `step {index}: {err}`)
		end
	end

	if recording then
		pcall(ChangeHistoryService.FinishRecording, ChangeHistoryService, recording, Enum.FinishRecordingOperation.Commit)
	end
	local lines = table.clone(made)
	for _, e in errors do
		table.insert(lines, "! " .. e)
	end
	table.insert(lines, `{#made} done, {#errors} errors`)
	return ids, table.concat(lines, "\n")
end

-- Every ParticleEmitter, Beam, Trail, Decal or Texture still pointing at a
-- local preview texture (players see nothing there).
function Build.previewLeftovers(root: Instance?): { string }
	local found = {}
	for _, d in (root or game):GetDescendants() do
		local ok, texture = pcall(function()
			return (d :: any).Texture
		end)
		if ok and type(texture) == "string" and texture:find("rbxasset://textures/vfxpreview/", 1, true) then
			table.insert(found, d:GetFullName())
		end
	end
	return found
end

return Build
