-- Pre-bake meshlab models into data modules so a game never runs the model code (or the AO
-- bake) at runtime, and CLIENTS can rebuild the meshes (EditableMesh content made on the server
-- does not reach players' screens: they see plain boxes).
--   lune run meshlab/tools/bake_meshdata <outFile.rbxm> <prefix> [rays]
--   e.g. lune run meshlab/tools/bake_meshdata meshlab/out/MeshData.rbxm '' 24
-- Output: Folder "MeshData" with one ModuleScript per model. Each returns
--   { parts = { { name, nv, nn, nc, nuv, nf, chunks = {"c001", ...} }, ... } }
-- and holds its base64 data in child ModuleScripts (each returns one string; Studio refuses
-- Source over 200,000 characters). Load with meshlab/MeshDataLoader.luau.
-- Binary layout per part (little-endian): verts f32x3 | normals f32x3 | colors u8x3 |
-- uvs f32x2 | faces (v u16x3, c u16x3, n u16x3, uv u16x3; 0 = none, ids 1-based).
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local Instance = roblox.Instance

local Shim = require("../EditableMeshShim")
local Shapes = require("../Shapes")
Shapes.Voxel = require("../Voxel")
Shapes.Props = require("../Props")
Shapes.Organic = require("../Organic")

local outFile = process.args[1] or error("usage: bake_meshdata <out.rbxm> <prefix> [rays]")
local prefix = process.args[2] or ""
local rays = tonumber(process.args[3])
if rays then
	Shapes.raysOverride = rays
end

local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local function base64(b: buffer): string
	local n = buffer.len(b)
	local out = table.create(math.ceil(n / 3))
	for i = 0, n - 1, 3 do
		local a = buffer.readu8(b, i)
		local c1 = i + 1 < n and buffer.readu8(b, i + 1) or 0
		local c2 = i + 2 < n and buffer.readu8(b, i + 2) or 0
		local v = a * 65536 + c1 * 256 + c2
		local s1 = string.sub(B64, v // 262144 % 64 + 1, v // 262144 % 64 + 1)
		local s2 = string.sub(B64, v // 4096 % 64 + 1, v // 4096 % 64 + 1)
		local s3 = i + 1 < n and string.sub(B64, v // 64 % 64 + 1, v // 64 % 64 + 1) or "="
		local s4 = i + 2 < n and string.sub(B64, v % 64 + 1, v % 64 + 1) or "="
		table.insert(out, s1 .. s2 .. s3 .. s4)
	end
	return table.concat(out)
end

-- weld: one entry per distinct value (positions, normals, UVs, colours). Faces keep their own
-- per-corner normal/UV/colour ids, so sharing vertices never changes how anything looks; it cuts
-- the client's EditableMesh memory (players hit "reaching memory budget limits" before this).
local function dedupe(list, keyOf)
	local out, map, remap = {}, {}, {}
	for i, v in list do
		local k = keyOf(v)
		local id = map[k]
		if not id then
			table.insert(out, v)
			id = #out
			map[k] = id
		end
		remap[i] = id
	end
	return out, remap
end

local function weld(mesh)
	local faces = {}
	for _, id in mesh:GetFaces() do
		table.insert(faces, mesh.faces[id])
	end
	local v3 = function(p)
		return string.format("%.4f,%.4f,%.4f", p.X, p.Y, p.Z)
	end
	local verts, rv = dedupe(mesh.verts, v3)
	local normals, rn = dedupe(mesh.normals, function(n)
		return string.format("%.3f,%.3f,%.3f", n.X, n.Y, n.Z)
	end)
	local uvs, ru = dedupe(mesh.uvs, function(u)
		return string.format("%.4f,%.4f", u.X, u.Y)
	end)
	local colors, rc = dedupe(mesh.colors, function(c)
		return string.format("%d,%d,%d", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
	end)
	local function map(ids, r)
		if not ids then
			return nil
		end
		return { r[ids[1]], r[ids[2]], r[ids[3]] }
	end
	local out = {}
	for _, f in faces do
		table.insert(out, { v = map(f.v, rv), n = map(f.n, rn), uv = map(f.uv, ru), c = map(f.c, rc) })
	end
	return { verts = verts, normals = normals, uvs = uvs, colors = colors, faces = out }
end

local function packPart(raw)
	local mesh = weld(raw)
	local faces = mesh.faces
	local nv, nn, nc, nuv, nf = #mesh.verts, #mesh.normals, #mesh.colors, #mesh.uvs, #faces
	assert(nv < 65536 and nn < 65536 and nc < 65536 and nuv < 65536, "part too big for u16 ids")
	local size = nv * 12 + nn * 12 + nc * 3 + nuv * 8 + nf * 24
	local b = buffer.create(size)
	local o = 0
	for _, p in mesh.verts do
		buffer.writef32(b, o, p.X)
		buffer.writef32(b, o + 4, p.Y)
		buffer.writef32(b, o + 8, p.Z)
		o += 12
	end
	for _, p in mesh.normals do
		buffer.writef32(b, o, p.X)
		buffer.writef32(b, o + 4, p.Y)
		buffer.writef32(b, o + 8, p.Z)
		o += 12
	end
	for _, c in mesh.colors do
		buffer.writeu8(b, o, math.clamp(math.floor(c.R * 255 + 0.5), 0, 255))
		buffer.writeu8(b, o + 1, math.clamp(math.floor(c.G * 255 + 0.5), 0, 255))
		buffer.writeu8(b, o + 2, math.clamp(math.floor(c.B * 255 + 0.5), 0, 255))
		o += 3
	end
	for _, uv in mesh.uvs do
		buffer.writef32(b, o, uv.X)
		buffer.writef32(b, o + 4, uv.Y)
		o += 8
	end
	for _, f in faces do
		for k = 1, 3 do
			buffer.writeu16(b, o + (k - 1) * 2, f.v[k])
			buffer.writeu16(b, o + 6 + (k - 1) * 2, f.c and f.c[k] or 0)
			buffer.writeu16(b, o + 12 + (k - 1) * 2, f.n and f.n[k] or 0)
			buffer.writeu16(b, o + 18 + (k - 1) * 2, f.uv and f.uv[k] or 0)
		end
		o += 24
	end
	-- bounds, so a server can make a plain box of the right size without building any EditableMesh
	local lo, hi = { math.huge, math.huge, math.huge }, { -math.huge, -math.huge, -math.huge }
	for _, p in mesh.verts do
		lo = { math.min(lo[1], p.X), math.min(lo[2], p.Y), math.min(lo[3], p.Z) }
		hi = { math.max(hi[1], p.X), math.max(hi[2], p.Y), math.max(hi[3], p.Z) }
	end
	local center = { (lo[1] + hi[1]) / 2, (lo[2] + hi[2]) / 2, (lo[3] + hi[3]) / 2 }
	local size = { math.max(hi[1] - lo[1], 0.01), math.max(hi[2] - lo[2], 0.01), math.max(hi[3] - lo[3], 0.01) }
	return { nv = nv, nn = nn, nc = nc, nuv = nuv, nf = nf, data = base64(b), center = center, size = size }
end

local CHUNK = 180000
-- seeded variants baked as their own modules ("<Name>_s<seed>"), matching MeshCache.get(name, seed)
local VARIANTS = { TreeBlob = { 2, 3 } }
local folder = Instance.new("Folder")
folder.Name = "MeshData"
local total, count = 0, 0
local names = {}
for _, f in fs.readDir("meshlab/models") do
	if string.sub(f, -5) == ".luau" and string.sub(f, 1, #prefix) == prefix then
		table.insert(names, string.sub(f, 1, -6))
	end
end
table.sort(names)
local jobs = {}
for _, name in names do
	table.insert(jobs, { name = name, out = name, seed = nil })
	for _, sd in VARIANTS[name] or {} do
		table.insert(jobs, { name = name, out = name .. "_s" .. sd, seed = sd })
	end
end
for _, job in jobs do
	local name = job.out
	local build = require(`../models/{job.name}`)
	local em = Shim.new()
	local parts, order = {}, {}
	local function part(partName)
		if not parts[partName] then
			parts[partName] = Shim.new()
			table.insert(order, partName)
		end
		return parts[partName]
	end
	build(em, { Vector3 = roblox.Vector3, Vector2 = roblox.Vector2, Color3 = roblox.Color3, CFrame = roblox.CFrame, seed = job.seed }, Shapes, part)
	local mod = Instance.new("ModuleScript")
	mod.Name = name
	local lines = { "-- generated by meshlab/tools/bake_meshdata.luau; do not edit", "return { parts = {" }
	local all = { { "Body", em } }
	for _, n in order do
		table.insert(all, { n, parts[n] })
	end
	local ci = 0
	for _, entry in all do
		local mesh = entry[2]
		if next(mesh.faces) == nil or entry[1] == "PreviewFloor" then
			continue
		end
		local p = packPart(mesh)
		local chunkNames = {}
		for i = 1, #p.data, CHUNK do
			ci += 1
			local c = Instance.new("ModuleScript")
			c.Name = string.format("c%03d", ci)
			c.Source = 'return "' .. string.sub(p.data, i, i + CHUNK - 1) .. '"'
			c.Parent = mod
			table.insert(chunkNames, '"' .. c.Name .. '"')
		end
		total += #p.data
		table.insert(lines, string.format('\t{ name = "%s", nv = %d, nn = %d, nc = %d, nuv = %d, nf = %d, center = { %.4f, %.4f, %.4f }, size = { %.4f, %.4f, %.4f }, chunks = { %s } },',
			entry[1], p.nv, p.nn, p.nc, p.nuv, p.nf, p.center[1], p.center[2], p.center[3], p.size[1], p.size[2], p.size[3], table.concat(chunkNames, ", ")))
	end
	table.insert(lines, "} }")
	mod.Source = table.concat(lines, "\n")
	mod.Parent = folder
	count += 1
	print(string.format("%-22s %d part(s)", name, #all))
end
fs.writeFile(outFile, roblox.serializeModel({ folder }))
print(string.format("baked %d models, %.2f MB of base64 -> %s", count, total / 1e6, outFile))
