--!nocheck
-- Build a model outside Studio:  lune run meshlab/run <ModelName>
-- Runs meshlab/models/<ModelName>.luau on the EditableMesh shim and writes out/<ModelName>.obj.
-- Models signature: function(em, lib, Shapes, part). Calling part("Name") returns a fresh mesh
-- for a separately moving piece (forks, wheels...); each is also written to
-- out/<ModelName>/<Name>.obj, and the combined .obj holds everything for the preview.

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local Shim = require("./EditableMeshShim")
local Shapes = require("./Shapes")
Shapes.Voxel = require("./Voxel")
Shapes.Props = require("./Props")
Shapes.Organic = require("./Organic")

local modelName = process.args[1] or error("usage: lune run meshlab/run <ModelName> [seed]")
local build = require(`./models/{modelName}`)
local seed = tonumber(process.args[2])
-- a seed (for models that vary, like trees) is passed as lib.seed and suffixes the output
local name = seed and `{modelName}_s{seed}` or modelName

local em = Shim.new()
local parts, order = {}, {}
local function part(partName)
	if not parts[partName] then
		parts[partName] = Shim.new()
		table.insert(order, partName)
	end
	return parts[partName]
end
local result = build(em, { Vector3 = roblox.Vector3, Vector2 = roblox.Vector2, Color3 = roblox.Color3, CFrame = roblox.CFrame, seed = seed }, Shapes, part)

local dir = "meshlab/out"
if not fs.isDir(dir) then
	fs.writeDir(dir)
end
local chunks, offset = {}, 0
local totalV, totalF = 0, 0
local all = { { "", em } }
for _, partName in order do
	table.insert(all, { partName, parts[partName] })
end
for _, entry in all do
	local mesh = entry[2]
	local v, f = mesh:Stats()
	if f > 0 then
		local text, n = mesh:ToOBJ(offset)
		table.insert(chunks, text)
		offset = n
		totalV += v
		totalF += f
		local label = entry[1] ~= "" and entry[1] or "(body)"
		if f > 20000 or v > 60000 then
			print(`  WARNING {label}: {f} triangles / {v} vertices is over Roblox's EditableMesh limit (20,000 / 60,000)`)
		end
		if entry[1] ~= "" or #order > 0 then
			if not fs.isDir(`{dir}/{name}`) then
				fs.writeDir(`{dir}/{name}`)
			end
			local fileName = entry[1] ~= "" and entry[1] or "Body"
			fs.writeFile(`{dir}/{name}/{fileName}.obj`, (mesh:ToOBJ()))
			print(`  part {fileName}: {f} triangles`)
		end
	end
end
fs.writeFile(`{dir}/{name}.obj`, table.concat(chunks, "\n"))
-- a model may return { bones = {...} } for the skinned-rig step (tools/rig_skinned.py)
if type(result) == "table" and result.bones then
	local serde = require("@lune/serde")
	fs.writeFile(`{dir}/{name}/rig.json`, serde.encode("json", result.bones, true))
	print(`  rig: {#result.bones} bones -> {dir}/{name}/rig.json`)
end
print(`{name}: {totalV} vertices, {totalF} triangles -> {dir}/{name}.obj`)
