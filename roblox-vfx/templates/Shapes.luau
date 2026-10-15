-- roblox-vfx skill: Shapes. Mesh-effect shapes (crescent, ring, cone, swirl,
-- shell, any surface) built in Studio with EditableMesh, so they need no
-- Blender and no mesh upload. Ported from Roqer's vfx_* Blender helpers.
--
-- EditableMesh content is NOT saved with the place, so templates store
-- "shape spots": ordinary invisible Parts carrying two attributes,
--   VFXShape  = "Arc" | "Ring" | "Cone" | "Swirl" | "Shell"
--   VFXParams = JSON of the shape's parameters (studs, degrees)
-- plus, optionally, VFXScale (a number, default 1) to size the baked mesh.
-- Everything else on the spot (Name, CFrame, Color, Material, Transparency,
-- Decals and other children, attributes) carries over to the MeshPart.
--
--   local Shapes = require(game.ReplicatedStorage.VFX.Shapes)
--   local ready = Shapes.prepare(game.ReplicatedStorage.VFX.Slash) -- baked copy, cached
--   VFX.play(ready, cframe)
--
-- prepare() bakes a clone once per template and caches it, so call it on the
-- client at load (or the first time) and play the result as often as needed.
-- Published games need "Allow Mesh & Image APIs" on in Game Settings > Security.
--
-- Orientation: Roblox space. Forward is -Z, up is +Y, built around the origin.
-- Every shape is one sheet emitted with both windings (it shows from both sides).

local AssetService = game:GetService("AssetService")
local HttpService = game:GetService("HttpService")

local Shapes = {}

local MAX_SEGMENTS = 256

-- Unit direction `angle` radians from forward (-Z), turning toward +X.
local function around(angle: number): Vector3
	return Vector3.new(math.sin(angle), 0, -math.cos(angle))
end

local function segments(value: number?, default: number, low: number): number
	local n = math.floor(value or default)
	assert(n >= low and n <= MAX_SEGMENTS, `segments must be {low}..{MAX_SEGMENTS}, got {n}`)
	return n
end

-- A columns x rows grid of quads at point(u, v), both sides. Returns verts, tris.
local function strip(columns: number, rows: number, point: (number, number) -> Vector3)
	local verts, uvs = {}, {}
	for c = 0, columns do
		for r = 0, rows do
			table.insert(verts, point(c / columns, r / rows))
			table.insert(uvs, Vector2.new(c / columns, 1 - r / rows))
		end
	end
	local function index(c, r)
		return c * (rows + 1) + r + 1
	end
	local quads = {}
	for c = 0, columns - 1 do
		for r = 0, rows - 1 do
			table.insert(quads, { index(c, r), index(c + 1, r), index(c + 1, r + 1), index(c, r + 1) })
		end
	end
	return verts, uvs, quads
end

local SHAPES = {}

-- A flat crescent card for a slash, in the horizontal plane. Sweeps `sweep`
-- degrees centred on forward, from radius - width out to radius; with taper
-- it is widest in the middle and pointed at both ends.
function SHAPES.Arc(p)
	local radius, width = p.radius or 6, p.width or 1.5
	assert(width < radius, "Arc: width must be less than radius")
	local half = math.rad(p.sweep or 160) / 2
	local taper = p.taper ~= false
	return strip(segments(p.segments, 32, 4), if taper then 2 else 1, function(u, v)
		local across = if taper then math.sin(math.pi * u) else 1
		local inner = radius - width * math.max(across, 0.02)
		return around(half - 2 * half * u) * (inner + (radius - inner) * v)
	end)
end

-- A shockwave. height 0: a flat band from radius - width to radius. With a
-- height: a wall from radius at the bottom to topRadius at the top.
function SHAPES.Ring(p)
	local radius, width, height = p.radius or 5, p.width or 0.5, p.height or 0
	local n = segments(p.segments, 48, 8)
	if height == 0 then
		assert(width < radius, "Ring: width must be less than radius")
		return strip(n, 1, function(u, v)
			return around(2 * math.pi * u) * (radius - width + width * v)
		end)
	end
	local top = p.topRadius or radius
	return strip(n, 1, function(u, v)
		return around(2 * math.pi * u) * (radius + (top - radius) * v) + Vector3.new(0, height * v, 0)
	end)
end

-- An open cone from a base of `radius` at the origin up to `tipRadius` at `height`.
function SHAPES.Cone(p)
	local radius, height, tip = p.radius or 2, p.height or 4, math.max(p.tipRadius or 0, 0.001)
	return strip(segments(p.segments, 32, 8), 4, function(u, v)
		return around(2 * math.pi * u) * (radius + (tip - radius) * v) + Vector3.new(0, height * v, 0)
	end)
end

-- A ribbon `width` tall spiralling up `turns` times to `height`, radius going
-- to topRadius: a tornado, an aura, a charge-up.
function SHAPES.Swirl(p)
	local radius, height, width = p.radius or 3, p.height or 8, p.width or 1.5
	local turns, top = p.turns or 1.5, p.topRadius or p.radius or 3
	return strip(segments(p.segments, 96, 8), 1, function(u, v)
		return around(2 * math.pi * turns * u) * (radius + (top - radius) * u)
			+ Vector3.new(0, height * u + width * (v - 0.5), 0)
	end)
end

-- A sphere, or with dome a half sphere standing on the ground.
function SHAPES.Shell(p)
	local radius, dome = p.radius or 4, p.dome == true
	return strip(segments(p.segments, 32, 8), segments(p.rings, 16, 2), function(u, v)
		local polar = if dome then (math.pi / 2) * (1 - v) else math.pi * (1 - v)
		return around(2 * math.pi * u) * (radius * math.sin(polar)) + Vector3.new(0, radius * math.cos(polar), 0)
	end)
end

-- A torn shockwave: a flat ring whose outer edge is broken into `spikes`
-- uneven points (the vfx_surface example, as a recipe).
function SHAPES.TornRing(p)
	local radius, width, count = p.radius or 4, p.width or 1.5, p.spikes or 24
	local rng = Random.new(p.seed or 4)
	local spikes = {}
	for i = 1, count do
		spikes[i] = 1 + rng:NextNumber(-0.25, 0.45)
	end
	return strip(segments(p.segments, 96, 8), 2, function(u, v)
		local i = u * count
		local a, b = spikes[math.floor(i) % count + 1], spikes[(math.floor(i) + 1) % count + 1]
		local spike = a * (1 - i % 1) + b * (i % 1)
		return around(2 * math.pi * u) * (radius + v * width * spike)
	end)
end

-- Register your own: Shapes.define("Petal", function(p) return Shapes.strip(cols, rows, fn) end)
Shapes.strip = strip
function Shapes.define(name: string, recipe)
	SHAPES[name] = recipe
end

local contentCache: { [string]: { content: Content, center: Vector3 } } = {}
local partCache: { [string]: MeshPart } = {}

local function build(shape: string, params: any): (Content, Vector3)
	local key = shape .. HttpService:JSONEncode(params)
	local hit = contentCache[key]
	if hit then
		return hit.content, hit.center
	end
	local recipe = SHAPES[shape]
	assert(recipe, "Shapes: unknown shape " .. tostring(shape))
	local verts, uvs, quads = recipe(params)
	local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, v in verts do
		lo, hi = lo:Min(v), hi:Max(v)
	end
	local center = (lo + hi) / 2
	local em = AssetService:CreateEditableMesh()
	-- Two copies of every vertex, one per side, so each side keeps its own normal.
	local front, back, frontUv, backUv = {}, {}, {}, {}
	for i, v in verts do
		front[i] = em:AddVertex(v - center)
		back[i] = em:AddVertex(v - center)
		frontUv[i] = em:AddUV(uvs[i])
		backUv[i] = em:AddUV(uvs[i])
	end
	local function face(ids, uvIds, a, b, c)
		local f = em:AddTriangle(ids[a], ids[b], ids[c])
		em:SetFaceUVs(f, { uvIds[a], uvIds[b], uvIds[c] })
	end
	for _, q in quads do
		local a, b, c, d = q[1], q[2], q[3], q[4]
		-- Skip degenerate triangles (poles, closed loops collapse corners).
		if (verts[a] - verts[b]):Cross(verts[a] - verts[c]).Magnitude > 1e-9 then
			face(front, frontUv, a, b, c)
			face(back, backUv, a, c, b)
		end
		if (verts[a] - verts[c]):Cross(verts[a] - verts[d]).Magnitude > 1e-9 then
			face(front, frontUv, a, c, d)
			face(back, backUv, a, d, c)
		end
	end
	local result, content = AssetService:CreateDataModelContentAsync(Content.fromObject(em))
	em:Destroy()
	assert(result == Enum.CreateContentResult.Success, "Shapes: content creation failed: " .. tostring(result))
	contentCache[key] = { content = content, center = center }
	return content, center
end

-- A MeshPart of the shape at its natural size, centred on its bounding box
-- (the second result is where the shape's origin sits relative to that centre).
function Shapes.meshPart(shape: string, params: any): (MeshPart, Vector3)
	local key = shape .. HttpService:JSONEncode(params or {})
	local content, center = build(shape, params or {})
	local template = partCache[key]
	if not template then
		template = AssetService:CreateMeshPartAsync(content, {
			CollisionFidelity = Enum.CollisionFidelity.Box,
			RenderFidelity = Enum.RenderFidelity.Precise,
		})
		partCache[key] = template
	end
	local part = template:Clone()
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	return part, center
end

-- Replaces one spot with its MeshPart (in place). Returns the MeshPart.
function Shapes.bake(spot: BasePart): MeshPart
	local shape = spot:GetAttribute("VFXShape")
	local params = HttpService:JSONDecode(spot:GetAttribute("VFXParams") or "{}")
	local part, center = Shapes.meshPart(shape, params)
	local scale = spot:GetAttribute("VFXScale") or 1
	part.Size *= scale
	part.Name = spot.Name
	-- The spot's CFrame is the shape's origin; the MeshPart is centred on its box.
	part.CFrame = spot.CFrame * CFrame.new(center * scale)
	part.Color = spot.Color
	part.Material = spot.Material
	part.Transparency = spot.Transparency
	for name, value in spot:GetAttributes() do
		part:SetAttribute(name, value)
	end
	for _, child in spot:GetChildren() do
		child.Parent = part
	end
	part.Parent = spot.Parent
	spot:Destroy()
	return part
end

local function isSpot(d: Instance): boolean
	return d:IsA("BasePart") and not d:IsA("MeshPart") and d:GetAttribute("VFXShape") ~= nil
end

-- Bakes every spot under root, building unique meshes in parallel. Returns the count.
function Shapes.bakeAll(root: Instance): number
	local spots = {}
	for _, d in root:GetDescendants() do
		if isSpot(d) then
			table.insert(spots, d)
		end
	end
	local pending = 0
	for _, spot in spots do
		pending += 1
		task.spawn(function()
			pcall(Shapes.meshPart, spot:GetAttribute("VFXShape"), HttpService:JSONDecode(spot:GetAttribute("VFXParams") or "{}"))
			pending -= 1
		end)
	end
	while pending > 0 do
		task.wait()
	end
	local n = 0
	for _, spot in spots do
		local ok, err = pcall(Shapes.bake, spot)
		if ok then
			n += 1
		else
			warn("Shapes: bake failed for", spot:GetFullName(), err)
		end
	end
	return n
end

local prepared: { [Instance]: Instance } = {}

-- A baked copy of an effect template (cached per template). Plays like the
-- template with VFX.play. Templates with no spots are returned as they are.
function Shapes.prepare(template: Instance): Instance
	local hit = prepared[template]
	if hit then
		return hit
	end
	local hasSpot = isSpot(template)
	for _, d in template:GetDescendants() do
		if isSpot(d) then
			hasSpot = true
			break
		end
	end
	if not hasSpot then
		prepared[template] = template
		return template
	end
	local copy = template:Clone()
	copy.Archivable = true
	Shapes.bakeAll(copy)
	prepared[template] = copy
	return copy
end

-- Drop cached copies (after editing a template in Studio).
function Shapes.clear()
	table.clear(prepared)
end

return Shapes
