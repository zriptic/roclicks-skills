--!nocheck
-- Stand-in for Roblox's EditableMesh so model scripts run under Lune, outside Studio.
-- Same method names and argument shapes as the real API, so a model function written
-- against this runs unchanged on AssetService:CreateEditableMesh() in Studio.

local Shim = {}
Shim.__index = Shim

function Shim.new()
	return setmetatable({
		verts = {}, normals = {}, colors = {}, alphas = {}, uvs = {},
		faces = {}, -- id -> { v = {a,b,c}, n = {..}?, c = {..}?, uv = {..}? }
		nextFace = 0,
	}, Shim)
end

function Shim:AddVertex(p)
	table.insert(self.verts, p)
	return #self.verts
end

function Shim:SetPosition(id, p)
	self.verts[id] = p
end

function Shim:GetPosition(id)
	return self.verts[id]
end

function Shim:AddNormal(n)
	table.insert(self.normals, n)
	return #self.normals
end

function Shim:AddColor(c, alpha)
	table.insert(self.colors, c)
	self.alphas[#self.colors] = alpha or 1
	return #self.colors
end

function Shim:AddUV(uv)
	table.insert(self.uvs, uv)
	return #self.uvs
end

function Shim:AddTriangle(a, b, c)
	assert(self.verts[a] and self.verts[b] and self.verts[c], "AddTriangle: bad vertex id")
	self.nextFace += 1
	self.faces[self.nextFace] = { v = { a, b, c } }
	return self.nextFace
end

function Shim:RemoveFace(id)
	self.faces[id] = nil
end

function Shim:SetFaceColors(face, ids)
	self.faces[face].c = table.clone(ids)
end

function Shim:SetFaceNormals(face, ids)
	self.faces[face].n = table.clone(ids)
end

function Shim:SetFaceUVs(face, ids)
	self.faces[face].uv = table.clone(ids)
end

function Shim:GetFaces()
	local out = {}
	for id in self.faces do
		table.insert(out, id)
	end
	table.sort(out)
	return out
end

function Shim:GetFaceColors(face)
	return table.clone(self.faces[face].c)
end

function Shim:GetColor(id)
	return self.colors[id]
end

function Shim:GetVertices()
	local out = {}
	for id in self.verts do
		table.insert(out, id)
	end
	return out
end

function Shim:GetFaceVertices(face)
	return table.clone(self.faces[face].v)
end

function Shim:Destroy() end

-- Smooth vertex normals the way EditableMesh makes them when none are set: area-weighted
-- average of the faces sharing each vertex id.
function Shim:vertexNormals()
	local acc = {}
	for _, f in self.faces do
		local a, b, c = self.verts[f.v[1]], self.verts[f.v[2]], self.verts[f.v[3]]
		local n = (b - a):Cross(c - a) -- length = 2 * area
		for k = 1, 3 do
			local id = f.v[k]
			acc[id] = acc[id] and acc[id] + n or n
		end
	end
	for id, n in acc do
		acc[id] = n.Magnitude > 1e-9 and n.Unit or n
	end
	return acc
end

-- Writes a Wavefront OBJ: per-corner positions with colours ("v x y z r g b", which Blender
-- reads), UVs (vt) and normals (vn), so per-face colours and smooth shading both survive.
-- Roblox is Y-up, -Z forward; OBJ is too.
-- offset: index offset when several meshes go into one file; also returns the corner count.
function Shim:ToOBJ(offset)
	local vn = self:vertexNormals()
	local vs, vts, vns, fs = {}, {}, {}, {}
	local n = offset or 0
	for _, id in self:GetFaces() do
		local f = self.faces[id]
		local idx = {}
		for k = 1, 3 do
			local p = self.verts[f.v[k]]
			local col = f.c and self.colors[f.c[k]]
			local r, g, b = 0.8, 0.8, 0.8
			if col then
				r, g, b = col.R, col.G, col.B
			end
			table.insert(vs, string.format("v %.5f %.5f %.5f %.4f %.4f %.4f", p.X, p.Y, p.Z, r, g, b))
			local uv = f.uv and self.uvs[f.uv[k]]
			table.insert(vts, uv and string.format("vt %.5f %.5f", uv.X, uv.Y) or "vt 0 0")
			local nn = (f.n and self.normals[f.n[k]]) or vn[f.v[k]]
			table.insert(vns, string.format("vn %.5f %.5f %.5f", nn.X, nn.Y, nn.Z))
			n += 1
			idx[k] = n
		end
		table.insert(fs, string.format("f %d/%d/%d %d/%d/%d %d/%d/%d", idx[1], idx[1], idx[1], idx[2], idx[2], idx[2], idx[3], idx[3], idx[3]))
	end
	return "# meshlab EditableMesh export\n" .. table.concat(vs, "\n") .. "\n" .. table.concat(vts, "\n") .. "\n"
		.. table.concat(vns, "\n") .. "\n" .. table.concat(fs, "\n") .. "\n", n
end

function Shim:Stats()
	return #self.verts, #self:GetFaces()
end

return Shim
