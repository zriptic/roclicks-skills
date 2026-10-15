-- Totals for a prefix: vertices / normals / uvs / faces, and vertices after welding equal positions.
--   lune run meshlab/tools/count_mesh FC_
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local Shim = require("../EditableMeshShim")
local Shapes = require("../Shapes")
Shapes.Voxel = require("../Voxel")
Shapes.Props = require("../Props")
Shapes.Organic = require("../Organic")
local prefix = process.args[1] or "FC_"
local T = { v = 0, w = 0, n = 0, uv = 0, f = 0 }
for _, f in fs.readDir("meshlab/models") do
	if string.sub(f, 1, #prefix) == prefix and string.sub(f, -5) == ".luau" then
		local name = string.sub(f, 1, -6)
		local em = Shim.new()
		local parts = {}
		require("../models/" .. name)(em, { Vector3 = roblox.Vector3, Vector2 = roblox.Vector2, Color3 = roblox.Color3, CFrame = roblox.CFrame }, Shapes, function(n)
			parts[n] = parts[n] or Shim.new()
			return parts[n]
		end)
		local all = { em }
		for _, p in parts do
			table.insert(all, p)
		end
		local v, w, n, uv, fc = 0, 0, 0, 0, 0
		for _, m in all do
			v += #m.verts
			n += #m.normals
			uv += #m.uvs
			for _ in m.faces do
				fc += 1
			end
			local seen, cnt = {}, 0
			for _, p in m.verts do
				local k = string.format("%.4f,%.4f,%.4f", p.X, p.Y, p.Z)
				if not seen[k] then
					seen[k] = true
					cnt += 1
				end
			end
			w += cnt
		end
		print(string.format("%-20s verts %6d  welded %6d  normals %6d  uvs %6d  faces %6d", name, v, w, n, uv, fc))
		T.v += v; T.w += w; T.n += n; T.uv += uv; T.f += fc
	end
end
print(string.format("TOTAL                verts %6d  welded %6d  normals %6d  uvs %6d  faces %6d", T.v, T.w, T.n, T.uv, T.f))
