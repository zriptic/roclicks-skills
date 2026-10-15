--!nocheck
-- Modelling helpers for stud-style meshes on any EditableMesh (real or the Lune shim).
--
-- Stud style here follows the AnimalPack/Egg FBX bundles: low-poly, smooth-shaded geometry
-- with flat colours, and the studs are NOT geometry, they come from a tiling square-stud
-- normal map (textures/stud_normal.png). So every surface gets UVs measured in stud cells:
-- 1 UV unit = 1 stud cell = Shapes.PITCH studs, which makes the stud grid even everywhere.
--
-- Triangles wind counter-clockwise seen from outside (Roblox and glTF front face).
--
--   local S = Shapes.new(em, lib)   -- lib = { Vector3, Vector2, Color3, CFrame }
--   S:lathe(CFrame.new(), { {0,0}, {1,0}, {1,2}, {0,2} }, 12, Color3.new(1,0,0))

local Shapes = {}
Shapes.__index = Shapes

Shapes.PITCH = 0.6 -- studs per stud cell

function Shapes.new(em, lib)
	if em == nil then
		error("Shapes.new: no EditableMesh (CreateEditableMesh returned nil: memory budget full?)", 2)
	end
	return setmetatable({ em = em, V3 = lib.Vector3, V2 = lib.Vector2, C3 = lib.Color3, CF = lib.CFrame, colorIds = {} }, Shapes)
end

function Shapes:colorId(c)
	local key = string.format("%.3f,%.3f,%.3f", c.R, c.G, c.B)
	local id = self.colorIds[key]
	if not id then
		id = self.em:AddColor(c, 1)
		self.colorIds[key] = id
	end
	return id
end

-- One triangle on existing vertex ids, with a flat colour and optional per-corner UVs.
function Shapes:face(a, b, c, color, uvs)
	local em = self.em
	local f = em:AddTriangle(a, b, c)
	local cid = self:colorId(color)
	em:SetFaceColors(f, { cid, cid, cid })
	if uvs then
		em:SetFaceUVs(f, { em:AddUV(uvs[1]), em:AddUV(uvs[2]), em:AddUV(uvs[3]) })
	end
	self:_log(f)
	return f
end

-- Faceted triangle with its own corners (hard edges).
function Shapes:tri(a, b, c, color, uvs)
	local em = self.em
	return self:face(em:AddVertex(a), em:AddVertex(b), em:AddVertex(c), color, uvs)
end

-- Faceted quad, UVs in stud cells across it.
function Shapes:quad(a, b, c, d, color)
	local V2, P = self.V2, Shapes.PITCH
	local w, h = (b - a).Magnitude / P, (d - a).Magnitude / P
	local uv = { V2.new(0, 0), V2.new(w, 0), V2.new(w, h), V2.new(0, h) }
	self:tri(a, b, c, color, { uv[1], uv[2], uv[3] })
	self:tri(a, c, d, color, { uv[1], uv[3], uv[4] })
end

-- Box centred on cf (hard edges, studded on every face by the normal map).
function Shapes:box(cf, size, color)
	local h = size / 2
	local function p(x, y, z)
		return cf * self.V3.new(h.X * x, h.Y * y, h.Z * z)
	end
	self:quad(p(-1, -1, 1), p(1, -1, 1), p(1, 1, 1), p(-1, 1, 1), color) -- +Z
	self:quad(p(1, -1, -1), p(-1, -1, -1), p(-1, 1, -1), p(1, 1, -1), color) -- -Z
	self:quad(p(1, -1, 1), p(1, -1, -1), p(1, 1, -1), p(1, 1, 1), color) -- +X
	self:quad(p(-1, -1, -1), p(-1, -1, 1), p(-1, 1, 1), p(-1, 1, -1), color) -- -X
	self:quad(p(-1, 1, 1), p(1, 1, 1), p(1, 1, -1), p(-1, 1, -1), color) -- +Y
	self:quad(p(-1, -1, -1), p(1, -1, -1), p(1, -1, 1), p(-1, -1, 1), color) -- -Y
end

-- Box with the pack's soft edges: each face gets a border ring `bevel` wide whose normals
-- lean toward the neighbouring face, so edges catch light like a chamfer while the shape
-- stays an exact box (no gaps between parts). Studs are laid in stud cells from each face's
-- corner; faces thinner than ~0.8 of a cell get no studs (tiny parts read cleaner plain).
local FACES = { -- normal, u, v (u x v = normal)
	{ { 1, 0, 0 }, { 0, 1, 0 }, { 0, 0, 1 } },
	{ { -1, 0, 0 }, { 0, 0, 1 }, { 0, 1, 0 } },
	{ { 0, 1, 0 }, { 0, 0, 1 }, { 1, 0, 0 } },
	{ { 0, -1, 0 }, { 1, 0, 0 }, { 0, 0, 1 } },
	{ { 0, 0, 1 }, { 1, 0, 0 }, { 0, 1, 0 } },
	{ { 0, 0, -1 }, { 0, 1, 0 }, { 1, 0, 0 } },
}
function Shapes:bevelBox(cf, size, color, bevel)
	local em, V3, V2, P = self.em, self.V3, self.V2, Shapes.PITCH
	local cid = self:colorId(color)
	self:_occluder(cf, size)
	local h = size / 2
	local function comp(v, d)
		return math.abs(v.X * d[1] + v.Y * d[2] + v.Z * d[3])
	end
	for _, f in FACES do
		local n, u, v = V3.new(table.unpack(f[1])), V3.new(table.unpack(f[2])), V3.new(table.unpack(f[3]))
		local hn, hu, hv = comp(h, f[1]), comp(h, f[2]), comp(h, f[3])
		local b = math.min(bevel or 0.08, hu * 0.45, hv * 0.45)
		local sharp = b <= 0 -- bevel 0: a crisp box (still studded, still an AO occluder)
		local studs = hu * 2 >= P * 0.8 and hv * 2 >= P * 0.8
		-- When baking AO, split the flat middle into ~0.8-stud cells so the shading stays
		-- local instead of being interpolated across a whole panel from its corners.
		local function cuts(hh)
			local list = { -hh }
			if not sharp then
				table.insert(list, -hh + b)
			end
			local n = Shapes.bake and math.max(1, math.ceil((hh * 2 - b * 2) / Shapes.bake.cell)) or 1
			for i = 1, n - 1 do
				table.insert(list, -hh + b + (hh * 2 - b * 2) * i / n)
			end
			if not sharp then
				table.insert(list, hh - b)
			end
			table.insert(list, hh)
			return list
		end
		local us, vs = cuts(hu), cuts(hv)
		local nu, nv = #us, #vs
		local ids = {}
		for a = 1, nu do
			ids[a] = {}
			for c = 1, nv do
				local nn = n
				if not sharp then
					if a == 1 then nn -= u elseif a == nu then nn += u end
					if c == 1 then nn -= v elseif c == nv then nn += v end
				end
				local uv = studs and V2.new((us[a] + hu) / P, (vs[c] + hv) / P) or V2.new(0.03, 0.03)
				ids[a][c] = {
					v = em:AddVertex(cf * (n * hn + u * us[a] + v * vs[c])),
					n = em:AddNormal(cf:VectorToWorldSpace(nn.Unit)),
					uv = em:AddUV(uv),
				}
			end
		end
		for a = 1, nu - 1 do
			for c = 1, nv - 1 do
				local p1, p2, p3, p4 = ids[a][c], ids[a + 1][c], ids[a + 1][c + 1], ids[a][c + 1]
				for _, t in { { p1, p2, p3 }, { p1, p3, p4 } } do
					local fid = em:AddTriangle(t[1].v, t[2].v, t[3].v)
					em:SetFaceColors(fid, { cid, cid, cid })
					em:SetFaceNormals(fid, { t[1].n, t[2].n, t[3].n })
					em:SetFaceUVs(fid, { t[1].uv, t[2].uv, t[3].uv })
					self:_log(fid)
				end
			end
		end
	end
	self.owner = nil
end

-- Smooth surface from a grid of points rows[i][s] (s = 0..segs, column segs wraps to 0 when
-- closed). Vertices at the same position are shared, so poles and the seam shade smoothly.
-- UVs follow arc length in stud cells: v down the columns, u along each row measured from the
-- centre of its UV island. islandCols splits the columns into islands (e.g. one per pumpkin
-- rib) like the AnimalPack UV layouts; without islands rows of different widths shear the
-- stud grid into zigzags.
-- color: Color3 or function(i, s) -> Color3 for the face between rows i, i+1 and cols s, s+1.
function Shapes:grid(rows, segs, color, islandCols)
	islandCols = islandCols or segs
	if Shapes.bake then
		local lo, hi = rows[1][0], rows[1][0]
		for _, row in rows do
			for s = 0, segs do
				lo, hi = lo:Min(row[s]), hi:Max(row[s])
			end
		end
		-- shrunk: a round shape only fills ~80% of its box, and parts strapped onto it
		-- (hubs, tank straps) must not count as buried inside it
		self:_occluder(self.CF.new((lo + hi) / 2), ((hi - lo) * 0.8):Max(self.V3.new(0.05, 0.05, 0.05)))
	end
	local em, V2, P = self.em, self.V2, Shapes.PITCH
	local ids, byPos = {}, {}
	local function vid(p)
		local key = string.format("%.4f,%.4f,%.4f", p.X, p.Y, p.Z)
		local id = byPos[key]
		if not id then
			id = em:AddVertex(p)
			byPos[key] = id
		end
		return id
	end
	for i, row in rows do
		ids[i] = {}
		for s = 0, segs do
			ids[i][s] = vid(row[s])
		end
	end
	-- v: cumulative distance down the middle column; u: distance along each row.
	local vAt = { [1] = 0 }
	local mid = segs // 2
	for i = 2, #rows do
		vAt[i] = vAt[i - 1] + (rows[i][mid] - rows[i - 1][mid]).Magnitude / P
	end
	local uAt = {}
	for i, row in rows do
		uAt[i] = { [0] = 0 }
		for s = 1, segs do
			uAt[i][s] = uAt[i][s - 1] + (row[s] - row[s - 1]).Magnitude / P
		end
	end
	for i = 1, #rows - 1 do
		for s = 0, segs - 1 do
			-- a colour function may return a second colour for the quad's second triangle
			local col, col2 = color, color
			if type(color) == "function" then
				col, col2 = color(i, s)
				col2 = col2 or col
			end
			local a, b, c, d = ids[i][s], ids[i][s + 1], ids[i + 1][s + 1], ids[i + 1][s]
			local mc = (s // islandCols) * islandCols + islandCols / 2 -- island centre column
			local function u(r, col)
				local lo = math.floor(mc)
				local centre = uAt[r][lo] + (uAt[r][math.min(lo + 1, segs)] - uAt[r][lo]) * (mc - lo)
				return uAt[r][col] - centre
			end
			local ua, ub = V2.new(u(i, s), vAt[i]), V2.new(u(i, s + 1), vAt[i])
			local uc, ud = V2.new(u(i + 1, s + 1), vAt[i + 1]), V2.new(u(i + 1, s), vAt[i + 1])
			if a ~= b and b ~= c and a ~= c then
				self:face(a, b, c, col, { ua, ub, uc })
			end
			if a ~= c and c ~= d and a ~= d then
				self:face(a, c, d, col2, { ua, uc, ud })
			end
		end
	end
	self.owner = nil
end

-- Surface of revolution around cf's Y axis. profile = { {radius, y}, ... } bottom to top.
-- radiusFn(angle) scales the radius (pumpkin ribs, petals).
function Shapes:lathe(cf, profile, segs, color, radiusFn, islandCols)
	local V3 = self.V3
	local rows = {}
	for i, pr in profile do
		local row = {}
		for s = 0, segs do
			local a = (s % segs) / segs * math.pi * 2
			local r = pr[1] * (radiusFn and radiusFn(a) or 1)
			row[s] = cf * V3.new(math.cos(a) * r, pr[2], -math.sin(a) * r)
		end
		rows[i] = row
	end
	self:grid(rows, segs, color, islandCols)
end

-- Tube along a path of Vector3 points; radii[i] is the radius at point i. Ends are closed by
-- collapsing to the end points. color: Color3 or function(i) -> Color3, where i is the
-- segment from path[i] to path[i+1] and i = #path is the end cap.
function Shapes:tube(path, radii, segs, color)
	local V3 = self.V3
	local rows = {}
	local up = V3.new(0, 1, 0)
	local function ring(p, fwd, r)
		local side = math.abs(fwd:Dot(up)) > 0.95 and V3.new(1, 0, 0) or up
		local u = side:Cross(fwd).Unit
		local v = fwd:Cross(u).Unit
		local row = {}
		for s = 0, segs do
			local a = (s % segs) / segs * math.pi * 2
			row[s] = p + (u * math.cos(a) + v * math.sin(a)) * r
		end
		return row
	end
	local function point(p)
		local row = {}
		for s = 0, segs do
			row[s] = p
		end
		return row
	end
	table.insert(rows, point(path[1]))
	for i, p in path do
		local fwd = (path[math.min(i + 1, #path)] - path[math.max(i - 1, 1)]).Unit
		table.insert(rows, ring(p, fwd, radii[i]))
	end
	table.insert(rows, point(path[#path]))
	self:grid(rows, segs, function(i)
		local k = math.clamp(i - 1, 1, #path) -- segments 1..#path-1, end cap = #path
		return type(color) == "function" and color(k) or color
	end)
end

-- Loft: sweep cross-section rings (arrays of Vector3, same count) into a faceted surface with
-- flat-shaded quads (hard edges between facets, so it stays chunky), UVs in stud cells.
--   opts.closed   rings wrap around (default true); false for open shells like canopies
--   opts.caps     close the first and last ring with a fan (default true when closed)
--   opts.color    Color3 or function(segment, edge) -> Color3
-- Faces are wound outward automatically (checked against the ring centroids).
function Shapes:loft(rings, opts)
	opts = opts or {}
	local closed = opts.closed ~= false
	local caps = opts.caps
	if caps == nil then
		caps = closed
	end
	local color = opts.color
	local V3 = self.V3
	local function col(i, k)
		return type(color) == "function" and color(i, k) or color
	end
	local function centroid(ring)
		local c = V3.new(0, 0, 0)
		for _, p in ring do
			c += p
		end
		return c / #ring
	end
	local n = #rings[1]
	for i = 1, #rings - 1 do
		local r0, r1 = rings[i], rings[i + 1]
		if Shapes.bake then
			local lo, hi = r0[1], r0[1]
			for _, p in r0 do
				lo, hi = lo:Min(p), hi:Max(p)
			end
			for _, p in r1 do
				lo, hi = lo:Min(p), hi:Max(p)
			end
			self:_occluder(self.CF.new((lo + hi) / 2), ((hi - lo) * 0.85):Max(V3.new(0.05, 0.05, 0.05)))
		end
		local mid = (centroid(r0) + centroid(r1)) / 2
		local last = closed and n or n - 1
		for k = 1, last do
			local k2 = k % n + 1
			local a, b, c, d = r0[k], r0[k2], r1[k2], r1[k]
			local nrm = (b - a):Cross(d - a)
			if nrm.Magnitude < 1e-9 then
				nrm = (c - b):Cross(a - b)
			end
			if nrm:Dot((a + b + c + d) / 4 - mid) < 0 then
				a, b, c, d = b, a, d, c
			end
			self:quad(a, b, c, d, col(i, k))
		end
		self.owner = nil
	end
	if caps then
		for _, which in { 1, #rings } do
			local ring = rings[which]
			local other = rings[which == 1 and 2 or #rings - 1]
			local c = centroid(ring)
			local away = c - centroid(other)
			local cc = col(which == 1 and 1 or #rings - 1, 0)
			for k = 1, n do
				local a, b = ring[k], ring[k % n + 1]
				if (a - c):Cross(b - c):Dot(away) < 0 then
					a, b = b, a
				end
				self:tri(c, a, b, cc)
			end
		end
	end
end

-- Octagonal ring (a chamfered rectangle) in the plane spanned by unit vectors u (half-width a)
-- and v (half-height b) around centre o; ct/cb chamfer the top/bottom corners.
function Shapes.octRing(o, u, v, a, b, ct, cb)
	return {
		o + u * (a - ct) + v * b, o + u * a + v * (b - ct), o + u * a + v * (-b + cb), o + u * (a - cb) + v * -b,
		o + u * (-a + cb) + v * -b, o + u * -a + v * (-b + cb), o + u * -a + v * (b - ct), o + u * (-a + ct) + v * b,
	}
end

-- Hexagonal airfoil ring: chord along c (leading edge at le, length chord), thickness along t.
function Shapes.foilRing(le, c, t, chord, thick)
	return {
		le, le + c * (chord * 0.25) + t * (thick / 2), le + c * (chord * 0.85) + t * (thick * 0.3),
		le + c * chord, le + c * (chord * 0.85) - t * (thick * 0.3), le + c * (chord * 0.25) - t * (thick / 2),
	}
end

-- Baked ambient occlusion in the vertex colours, so the model has depth under Roblox's flat
-- lighting too: corners, crevices, undersides and parts near the ground get darker.
--   Shapes.beginBake()            -- before building (shapes register occluders + faces)
--   ...build...
--   Shapes.finishBake(lib)        -- after building: rays per vertex against every part's box
-- Every bevelBox is an exact occluder; lathes/tubes use their bounding box. The ground (Y = 0)
-- occludes too. A face never occludes against its own shape.
-- opts.cell: AO subdivision size for big faces (default 0.8 studs; use ~2-3 for buildings)
Shapes.AO_MAX = 0.25 -- most a face can be darkened by ambient occlusion
Shapes.SKY_MAX = 0.08 -- most the "down-facing is darker" sky term can take

function Shapes.beginBake(opts)
	Shapes.bake = { occ = {}, faces = {}, cell = opts and opts.cell or 0.8 }
end

function Shapes:_occluder(cf, size)
	local bake = Shapes.bake
	if not bake then
		return
	end
	local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
	table.insert(bake.occ, {
		x = x, y = y, z = z,
		r00 = r00, r01 = r01, r02 = r02, r10 = r10, r11 = r11, r12 = r12, r20 = r20, r21 = r21, r22 = r22,
		hx = size.X / 2, hy = size.Y / 2, hz = size.Z / 2,
		rad = size.Magnitude / 2,
	})
	self.owner = #bake.occ
end

function Shapes:_log(fid)
	if Shapes.bake then
		table.insert(Shapes.bake.faces, { self.em, fid, self.owner or 0 })
	end
end

local function hitBox(o, ox, oy, oz, dx, dy, dz, maxT)
	local px, py, pz = ox - o.x, oy - o.y, oz - o.z
	-- into the box's local space: dot with the rotation's columns
	local lx = px * o.r00 + py * o.r10 + pz * o.r20
	local ly = px * o.r01 + py * o.r11 + pz * o.r21
	local lz = px * o.r02 + py * o.r12 + pz * o.r22
	-- a ray that STARTS inside a box is a detail embedded in the surface (window frame in a wall,
	-- trim on a roof): ignore it. Counting it made the face fully occluded = near-black patches
	-- (measured 2026-10-14: FC_/BC_ models came out ~40% too dark, darkest faces at 5%).
	if math.abs(lx) <= o.hx and math.abs(ly) <= o.hy and math.abs(lz) <= o.hz then
		return nil
	end
	local ex = dx * o.r00 + dy * o.r10 + dz * o.r20
	local ey = dx * o.r01 + dy * o.r11 + dz * o.r21
	local ez = dx * o.r02 + dy * o.r12 + dz * o.r22
	local tmin, tmax = 0, maxT
	for _, axis in { { lx, ex, o.hx }, { ly, ey, o.hy }, { lz, ez, o.hz } } do
		local l, e, h = axis[1], axis[2], axis[3]
		if math.abs(e) < 1e-9 then
			if math.abs(l) > h then
				return nil
			end
		else
			local t1, t2 = (-h - l) / e, (h - l) / e
			if t1 > t2 then
				t1, t2 = t2, t1
			end
			if t1 > tmin then tmin = t1 end
			if t2 < tmax then tmax = t2 end
			if tmin > tmax then
				return nil
			end
		end
	end
	return tmin
end

function Shapes.finishBake(lib, opts)
	local bake = Shapes.bake
	Shapes.bake = nil
	if not bake then
		return
	end
	opts = opts or {}
	-- Shapes.raysOverride (e.g. a game server baking at boot) trades a little AO smoothness for speed
	local RAYS, MAXD = Shapes.raysOverride or opts.rays or 24, opts.distance or 1.8
	-- Roblox's own lighting already shades sides/undersides and casts shadows, so the bake only
	-- adds soft contact shadows: AO darkening is capped at AO_MAX and the sky term at SKY_MAX
	-- for every model (heavier AO read as dark shading artifacts in game).
	local STRENGTH, SKY = opts.strength or 0.6, math.min(opts.sky or 0.16, Shapes.SKY_MAX)
	local C3 = lib.Color3

	-- cosine-weighted hemisphere directions around +Y (golden-angle spiral)
	local dirs = {}
	for i = 1, RAYS do
		local u = (i - 0.5) / RAYS
		local phi = i * 2.399963
		local r = math.sqrt(u)
		dirs[i] = { r * math.cos(phi), math.sqrt(1 - u), r * math.sin(phi) }
	end

	local occ = bake.occ
	local cache, colorCache = {}, {}
	local function occlusion(owner, ox, oy, oz, nx, ny, nz)
		-- tangent frame around n
		local ax, ay, az = 0, 1, 0
		if math.abs(ny) > 0.9 then
			ax, ay, az = 1, 0, 0
		end
		local tx, ty, tz = ay * nz - az * ny, az * nx - ax * nz, ax * ny - ay * nx
		local tl = math.sqrt(tx * tx + ty * ty + tz * tz)
		tx, ty, tz = tx / tl, ty / tl, tz / tl
		local bx, by, bz = ny * tz - nz * ty, nz * tx - nx * tz, nx * ty - ny * tx
		-- only boxes within reach
		local near = {}
		for i, o in occ do
			if i ~= owner then
				local cx, cy, cz = o.x - ox, o.y - oy, o.z - oz
				local d = math.sqrt(cx * cx + cy * cy + cz * cz) - o.rad
				if d < MAXD then
					table.insert(near, o)
				end
			end
		end
		local total = 0
		for _, s in dirs do
			local dx = tx * s[1] + nx * s[2] + bx * s[3]
			local dy = ty * s[1] + ny * s[2] + by * s[3]
			local dz = tz * s[1] + nz * s[2] + bz * s[3]
			local best = MAXD
			if dy < 0 and oy > 0 then
				local tg = oy / -dy
				if tg < best then
					best = tg
				end
			end
			for _, o in near do
				local t = hitBox(o, ox, oy, oz, dx, dy, dz, best)
				if t and t > 0.015 and t < best then -- grazing hits on touching boxes don't count
					best = t
				end
			end
			if best < MAXD then
				total += 1 - best / MAXD
			end
		end
		return total / RAYS
	end

	for _, entry in bake.faces do
		local em, fid, owner = entry[1], entry[2], entry[3]
		local vids = em:GetFaceVertices(fid)
		local p1, p2, p3 = em:GetPosition(vids[1]), em:GetPosition(vids[2]), em:GetPosition(vids[3])
		local n = (p2 - p1):Cross(p3 - p1)
		if n.Magnitude > 1e-9 then
			n = n.Unit
			local cids = em:GetFaceColors(fid)
			local newIds = {}
			for k = 1, 3 do
				local p = em:GetPosition(vids[k])
				local key = string.format("%d|%.3f,%.3f,%.3f|%.2f,%.2f,%.2f", owner, p.X, p.Y, p.Z, n.X, n.Y, n.Z)
				local o = cache[key]
				if not o then
					o = occlusion(owner, p.X + n.X * 0.03, p.Y + n.Y * 0.03, p.Z + n.Z * 0.03, n.X, n.Y, n.Z)
					cache[key] = o
				end
				-- AO plus a soft sky term: up-facing a touch brighter, down-facing darker
				local f = (1 - math.min(STRENGTH * o, Shapes.AO_MAX)) * (1 - SKY + SKY * (n.Y * 0.5 + 0.5))
				local base = em:GetColor(cids[k])
				local c = C3.new(base.R * f, base.G * f, base.B * f)
				local ck = string.format("%.3f,%.3f,%.3f", c.R, c.G, c.B)
				colorCache[em] = colorCache[em] or {}
				local id = colorCache[em][ck]
				if not id then
					id = em:AddColor(c, 1)
					colorCache[em][ck] = id
				end
				newIds[k] = id
			end
			em:SetFaceColors(fid, newIds)
		end
	end
end

return Shapes
