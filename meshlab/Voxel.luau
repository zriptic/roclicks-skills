--!nocheck
-- Voxel shells in a toy-pack style: exposed cube faces only, one stud per voxel face
-- (UV 0..1 across each face, so the square stud of textures/stud_normal.png sits centred).
-- The pack's soft bevels are done with normals, not geometry: each face gets a border ring
-- of width `bevel` whose normals lean toward the neighbouring face on convex edges, so the
-- cubes stay exact (no seams or gaps) but edges catch light like a chamfer.
--
--   Voxel.build(S, {
--       size = {nx, ny, nz}, filled = function(i, j, k) -> bool (0-based),
--       voxel = 0.6, origin = Vector3, bevel = 0.08,
--       color = function(i, j, k, nx, ny, nz) -> Color3  (n = the face normal, ints),
--   })

local Voxel = {}

local DIRS = {
	{ 1, 0, 0 }, { -1, 0, 0 }, { 0, 1, 0 }, { 0, -1, 0 }, { 0, 0, 1 }, { 0, 0, -1 },
}
-- For each face direction: two perpendicular in-plane axes (u, v) as DIRS indices, chosen
-- so u x v = n (counter-clockwise seen from outside).
local AXES = {
	[1] = { 3, 5 }, [2] = { 5, 3 }, [3] = { 5, 1 }, [4] = { 1, 5 }, [5] = { 1, 3 }, [6] = { 3, 1 },
}

function Voxel.build(S, o)
	local V3, V2, em = S.V3, S.V2, S.em
	local V, b, origin = o.voxel, o.bevel, o.origin
	local function filled(i, j, k)
		return o.filled(i, j, k) == true
	end
	local function vec(d)
		return V3.new(d[1], d[2], d[3])
	end
	local cuts = { -V / 2, -V / 2 + b, V / 2 - b, V / 2 }

	local nx, ny, nz = o.size[1], o.size[2], o.size[3]
	for i = 0, nx - 1 do
		for j = 0, ny - 1 do
			for k = 0, nz - 1 do
				if filled(i, j, k) then
					local cv = origin + V3.new(i + 0.5, j + 0.5, k + 0.5) * V
					for di, d in DIRS do
						if not filled(i + d[1], j + d[2], k + d[3]) then
							local n = vec(d)
							local col = o.color(i, j, k, d[1], d[2], d[3])
							local cid = S:colorId(col)
							local ud, vd = DIRS[AXES[di][1]], DIRS[AXES[di][2]]
							local u, v = vec(ud), vec(vd)
							-- Convex edge toward +u / -u / +v / -v: the neighbour that way is empty.
							local cu1 = not filled(i + ud[1], j + ud[2], k + ud[3])
							local cu0 = not filled(i - ud[1], j - ud[2], k - ud[3])
							local cv1 = not filled(i + vd[1], j + vd[2], k + vd[3])
							local cv0 = not filled(i - vd[1], j - vd[2], k - vd[3])
							-- Only split the face where an edge is bevelled.
							local ul, vl = { 1 }, { 1 }
							if cu0 then table.insert(ul, 2) end
							if cu1 then table.insert(ul, 3) end
							if cv0 then table.insert(vl, 2) end
							if cv1 then table.insert(vl, 3) end
							table.insert(ul, 4)
							table.insert(vl, 4)
							local ids = {}
							for a, ui in ul do
								ids[a] = {}
								for c, vi in vl do
									local p = cv + n * (V / 2) + u * cuts[ui] + v * cuts[vi]
									local nn = n
									if ui == 1 and cu0 then nn -= u end
									if ui == 4 and cu1 then nn += u end
									if vi == 1 and cv0 then nn -= v end
									if vi == 4 and cv1 then nn += v end
									ids[a][c] = {
										v = em:AddVertex(p),
										n = em:AddNormal(nn.Unit),
										uv = em:AddUV(V2.new(0.5 + cuts[ui] / V, 0.5 + cuts[vi] / V)),
									}
								end
							end
							for a = 1, #ul - 1 do
								for c = 1, #vl - 1 do
									local p1, p2, p3, p4 = ids[a][c], ids[a + 1][c], ids[a + 1][c + 1], ids[a][c + 1]
									for _, t in { { p1, p2, p3 }, { p1, p3, p4 } } do
										local f = em:AddTriangle(t[1].v, t[2].v, t[3].v)
										em:SetFaceColors(f, { cid, cid, cid })
										em:SetFaceNormals(f, { t[1].n, t[2].n, t[3].n })
										em:SetFaceUVs(f, { t[1].uv, t[2].uv, t[3].uv })
									end
								end
							end
						end
					end
				end
			end
		end
	end
end


-- filled(i, j, k) for a layer map (a list of layers of row strings): i = X column, j = layer (Y up), k = Z row.
function Voxel.fromLayers(layers)
	return function(i, j, k)
		local layer = layers[j + 1]
		local row = layer and layer[k + 1]
		return row ~= nil and string.sub(row, i + 1, i + 1) == "#"
	end
end

return Voxel
