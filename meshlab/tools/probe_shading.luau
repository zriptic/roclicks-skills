-- Measures how much the AO bake darkens a model: average face brightness by direction, with
-- and without the bake.  lune run meshlab/tools/probe_shading <ModelName>
local roblox = require("@lune/roblox")
local process = require("@lune/process")
local root = "../"
local Shim = require(root .. "EditableMeshShim")
local Shapes = require(root .. "Shapes")
Shapes.Voxel = require(root .. "Voxel")
Shapes.Props = require(root .. "Props")
Shapes.Organic = require(root .. "Organic")
local name = process.args[1]
for _, bake in { false, true } do
	local saved = Shapes.finishBake
	if not bake then
		Shapes.finishBake = function() end
	end
	local em = Shim.new()
	local parts = {}
	require(root .. "models/" .. name)(em, { Vector3 = roblox.Vector3, Vector2 = roblox.Vector2, Color3 = roblox.Color3, CFrame = roblox.CFrame }, Shapes, function(n)
		parts[n] = parts[n] or Shim.new()
		return parts[n]
	end)
	Shapes.finishBake = saved
	-- brightness histogram of faces by direction
	local buckets = { front = { 0, 0 }, up = { 0, 0 }, side = { 0, 0 } }
	local darkest = 1
	for _, id in em:GetFaces() do
		local f = em.faces[id]
		local a, b, c = em.verts[f.v[1]], em.verts[f.v[2]], em.verts[f.v[3]]
		local n = (b - a):Cross(c - a)
		if n.Magnitude > 1e-6 and f.c then
			n = n.Unit
			local col = em.colors[f.c[1]]
			local lum = 0.3 * col.R + 0.59 * col.G + 0.11 * col.B
			darkest = math.min(darkest, lum)
			local k = n.Y > 0.7 and "up" or n.Z < -0.7 and "front" or "side"
			buckets[k][1] += lum
			buckets[k][2] += 1
		end
	end
	local s = bake and "BAKED   " or "NO BAKE "
	for k, v in buckets do
		s ..= string.format("%s %.3f (%d)  ", k, v[1] / math.max(1, v[2]), v[2])
	end
	print(s .. string.format("darkest %.3f", darkest))
end
