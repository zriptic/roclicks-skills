--!nocheck
-- Builds a Model of MeshParts from a pre-baked meshlab data module (tools/bake_meshdata.luau).
-- Works on the server AND on clients (EditableMesh content made on the server never reaches
-- players' screens, so clients rebuild their own copy and MeshPart:ApplyMesh it onto the
-- server's parts). Same output as StudioBuild: one MeshPart per part, each recentred on its
-- bounds and placed back, model pivot at the model-space origin.
-- Published games need Game Settings > Security > "Allow Mesh & Image APIs".
--   local Loader = require(ReplicatedStorage.MeshLab.MeshDataLoader)
--   local model = Loader.build(ReplicatedStorage.MeshData.Crate)   -- yields briefly
local AssetService = game:GetService("AssetService")

local Loader = {}

local DEC = {}
do
	local s = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
	for i = 1, 64 do
		DEC[string.byte(s, i)] = i - 1
	end
end

local function decode(str: string): buffer
	local n = #str
	local pad = 0
	if string.sub(str, -2) == "==" then
		pad = 2
	elseif string.sub(str, -1) == "=" then
		pad = 1
	end
	local b = buffer.create(n // 4 * 3 - pad)
	local o = 0
	local len = buffer.len(b)
	for i = 1, n, 4 do
		local a, c, d, e = string.byte(str, i, i + 3)
		local v = DEC[a] * 262144 + DEC[c] * 4096 + (DEC[d] or 0) * 64 + (DEC[e] or 0)
		buffer.writeu8(b, o, v // 65536 % 256)
		if o + 1 < len then
			buffer.writeu8(b, o + 1, v // 256 % 256)
		end
		if o + 2 < len then
			buffer.writeu8(b, o + 2, v % 256)
		end
		o += 3
		if i % 40000 == 1 then
			task.wait() -- keep big decodes from freezing a frame
		end
	end
	return b
end

local function buildPart(module: ModuleScript, info): EditableMesh
	local strs = {}
	for _, cname in info.chunks do
		table.insert(strs, require(module:FindFirstChild(cname)))
	end
	local b = decode(table.concat(strs))
	local em = AssetService:CreateEditableMesh()
	local o = 0
	local v, nrm, col, uv = table.create(info.nv), table.create(info.nn), table.create(info.nc), table.create(info.nuv)
	for i = 1, info.nv do
		v[i] = em:AddVertex(Vector3.new(buffer.readf32(b, o), buffer.readf32(b, o + 4), buffer.readf32(b, o + 8)))
		o += 12
	end
	for i = 1, info.nn do
		nrm[i] = em:AddNormal(Vector3.new(buffer.readf32(b, o), buffer.readf32(b, o + 4), buffer.readf32(b, o + 8)))
		o += 12
	end
	for i = 1, info.nc do
		col[i] = em:AddColor(Color3.fromRGB(buffer.readu8(b, o), buffer.readu8(b, o + 1), buffer.readu8(b, o + 2)), 1)
		o += 3
	end
	for i = 1, info.nuv do
		uv[i] = em:AddUV(Vector2.new(buffer.readf32(b, o), buffer.readf32(b, o + 4)))
		o += 8
	end
	for _ = 1, info.nf do
		local a, bb, c = buffer.readu16(b, o), buffer.readu16(b, o + 2), buffer.readu16(b, o + 4)
		local f = em:AddTriangle(v[a], v[bb], v[c])
		local c1 = buffer.readu16(b, o + 6)
		if c1 > 0 then
			em:SetFaceColors(f, { col[c1], col[buffer.readu16(b, o + 8)], col[buffer.readu16(b, o + 10)] })
		end
		local n1 = buffer.readu16(b, o + 12)
		if n1 > 0 then
			em:SetFaceNormals(f, { nrm[n1], nrm[buffer.readu16(b, o + 14)], nrm[buffer.readu16(b, o + 16)] })
		end
		local u1 = buffer.readu16(b, o + 18)
		if u1 > 0 then
			em:SetFaceUVs(f, { uv[u1], uv[buffer.readu16(b, o + 20)], uv[buffer.readu16(b, o + 22)] })
		end
		o += 24
	end
	return em
end

local function toPart(em: EditableMesh, partName: string): MeshPart?
	local ids = em:GetVertices()
	if #ids == 0 then
		return nil
	end
	local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, id in ids do
		local p = em:GetPosition(id)
		lo, hi = lo:Min(p), hi:Max(p)
	end
	local center = (lo + hi) / 2
	for _, id in ids do
		em:SetPosition(id, em:GetPosition(id) - center)
	end
	local part = AssetService:CreateMeshPartAsync(Content.fromObject(em))
	part.Name = partName
	part.Anchored = true
	part.CFrame = CFrame.new(center)
	return part
end

-- SERVER side: a Model of plain anchored Parts with each mesh part's baked bounds (no EditableMesh,
-- so no memory budget). Clients draw the real meshes on top (Meshes.client). In a Studio playtest
-- the server and client share ONE EditableMesh budget, so a server that built meshes starved the
-- client (players saw boxes).
function Loader.boxes(module: ModuleScript, name: string?): Model
	local data = require(module)
	local model = Instance.new("Model")
	model.Name = name or module.Name
	for _, info in data.parts do
		if info.center and info.size then
			local p = Instance.new("Part")
			p.Name = info.name
			p.Anchored = true
			p.Size = Vector3.new(info.size[1], info.size[2], info.size[3])
			p.CFrame = CFrame.new(info.center[1], info.center[2], info.center[3])
			p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
			p.Color = Color3.fromRGB(200, 200, 205)
			p.Parent = model
		end
	end
	model.WorldPivot = CFrame.new()
	return model
end

-- for uploading: { { name = partName, em = EditableMesh (recentred), center = Vector3 }, ... }
-- (Studio plugin context: AssetService:CreateAssetAsync(em, Enum.AssetType.Mesh, ...))
function Loader.buildEditables(module: ModuleScript)
	local data = require(module)
	local out = {}
	for _, info in data.parts do
		local em = buildPart(module, info)
		local ids = em:GetVertices()
		if #ids > 0 then
			local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
			for _, id in ids do
				local p = em:GetPosition(id)
				lo, hi = lo:Min(p), hi:Max(p)
			end
			local center = (lo + hi) / 2
			for _, id in ids do
				em:SetPosition(id, em:GetPosition(id) - center)
			end
			table.insert(out, { name = info.name, em = em, center = center, size = hi - lo })
		end
	end
	return out
end

-- returns a Model named after the module, or errors (callers pcall)
function Loader.build(module: ModuleScript, name: string?): Model
	local data = require(module)
	local model = Instance.new("Model")
	model.Name = name or module.Name
	for _, info in data.parts do
		local p = toPart(buildPart(module, info), info.name)
		if p then
			p.Parent = model
		end
	end
	model.WorldPivot = CFrame.new()
	return model
end

return Loader
