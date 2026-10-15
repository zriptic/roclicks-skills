-- Export every model part (and seeded variants) as a CENTRED OBJ for uploading as real mesh
-- assets (Studio Import 3D). Runtime EditableMesh hit the client memory budget for a whole city.
--   lune run meshlab/tools/export_parts <PREFIX> <outDir>
--   -> <outDir>/<Key>__<Part>.obj  +  <outDir>/manifest.json  { "<Key>__<Part>": { center, size } }
-- Key = model name, or "<Name>_s<seed>" for variants (same keys as bake_meshdata / MeshCache).
local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")
local roblox = require("@lune/roblox")
local Shim = require("../EditableMeshShim")
local Shapes = require("../Shapes")
Shapes.Voxel = require("../Voxel")
Shapes.Props = require("../Props")
Shapes.Organic = require("../Organic")

local prefix = process.args[1] or error("usage: export_parts <PREFIX> <outDir>")
local outDir = process.args[2] or error("usage: export_parts <PREFIX> <outDir>")
local VARIANTS = { TreeBlob = { 2, 3 } }
if not fs.isDir(outDir) then
	fs.writeDir(outDir)
end

local manifest, count = {}, 0
local names = {}
for _, f in fs.readDir("meshlab/models") do
	if string.sub(f, -5) == ".luau" and string.sub(f, 1, #prefix) == prefix then
		table.insert(names, string.sub(f, 1, -6))
	end
end
table.sort(names)
for _, name in names do
	local jobs = { { key = name } }
	for _, sd in VARIANTS[name] or {} do
		table.insert(jobs, { key = name .. "_s" .. sd, seed = sd })
	end
	for _, job in jobs do
		local em = Shim.new()
		local parts, order = {}, {}
		require("../models/" .. name)(em, { Vector3 = roblox.Vector3, Vector2 = roblox.Vector2, Color3 = roblox.Color3, CFrame = roblox.CFrame, seed = job.seed }, Shapes, function(n)
			if not parts[n] then
				parts[n] = Shim.new()
				table.insert(order, n)
			end
			return parts[n]
		end)
		local all = { { "Body", em } }
		for _, n in order do
			table.insert(all, { n, parts[n] })
		end
		for _, e in all do
			local mesh = e[2]
			if next(mesh.faces) ~= nil and e[1] ~= "PreviewFloor" then -- preview-only parts never ship
				local lo, hi = roblox.Vector3.one * math.huge, -roblox.Vector3.one * math.huge
				for _, p in mesh.verts do
					lo, hi = lo:Min(p), hi:Max(p)
				end
				local c = (lo + hi) / 2
				for i, p in mesh.verts do
					mesh.verts[i] = p - c
				end
				local id = job.key .. "__" .. e[1]
				fs.writeFile(outDir .. "/" .. id .. ".obj", (mesh:ToOBJ()))
				manifest[id] = { center = { c.X, c.Y, c.Z }, size = { hi.X - lo.X, hi.Y - lo.Y, hi.Z - lo.Z } }
				count += 1
			end
		end
	end
end
fs.writeFile(outDir .. "/manifest.json", serde.encode("json", manifest, true))
print(string.format("exported %d parts -> %s", count, outDir))
