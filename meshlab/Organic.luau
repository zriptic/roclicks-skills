--!nocheck
-- Smooth, non-stud organic modelling for meshlab: creatures, bones, flesh.
--
-- Everything is collected into one buffer first (positions, triangles, a material tag per
-- vertex), then finish() works out smooth normals, ambient occlusion from a signed-distance
-- copy of the shapes, and per-vertex colour from a shader function, and only then writes the
-- EditableMesh. Per-vertex colour on a dense mesh is the "texture": no UVs, no upload, so the
-- same model script works in Lune and in Studio.
--
--   local O = Shapes.Organic.new(lib)
--   O:tube({p1, p2, p3}, {0.2, 0.15, 0.1}, { segs = 10, cap0 = "round", cap1 = "point" })
--   O:blob(center, R, U, F, function(d) return Vector3 local offset end, { lat = 14, lon = 20 })
--   O:finish(em, shadeFn)   -- shadeFn(p, n, mat, ao) -> r, g, b (0..1)
--
-- Winding is fixed automatically: every triangle is checked against a point inside its shape.

local Organic = {}
Organic.__index = Organic

-- ---------------------------------------------------------------- noise
local function hash(x, y, z)
	local h = math.sin(x * 127.1 + y * 311.7 + z * 74.7) * 43758.5453
	return h - math.floor(h)
end

function Organic.vnoise(x, y, z)
	local xi, yi, zi = math.floor(x), math.floor(y), math.floor(z)
	local xf, yf, zf = x - xi, y - yi, z - zi
	local u, v, w = xf * xf * (3 - 2 * xf), yf * yf * (3 - 2 * yf), zf * zf * (3 - 2 * zf)
	local function l(a, b, t)
		return a + (b - a) * t
	end
	local x00 = l(hash(xi, yi, zi), hash(xi + 1, yi, zi), u)
	local x10 = l(hash(xi, yi + 1, zi), hash(xi + 1, yi + 1, zi), u)
	local x01 = l(hash(xi, yi, zi + 1), hash(xi + 1, yi, zi + 1), u)
	local x11 = l(hash(xi, yi + 1, zi + 1), hash(xi + 1, yi + 1, zi + 1), u)
	return l(l(x00, x10, v), l(x01, x11, v), w)
end

-- fractal noise in 0..1
function Organic.fbm(x, y, z, oct)
	local sum, amp, norm, f = 0, 1, 0, 1
	for _ = 1, oct or 4 do
		sum += Organic.vnoise(x * f, y * f, z * f) * amp
		norm += amp
		amp *= 0.5
		f *= 2.03
	end
	return sum / norm
end

function Organic.smooth(a, b, x)
	local t = math.clamp((x - a) / (b - a), 0, 1)
	return t * t * (3 - 2 * t)
end

-- ---------------------------------------------------------------- buffer
function Organic.new(lib)
	return setmetatable({ V3 = lib.Vector3, C3 = lib.Color3, P = {}, M = {}, G = {}, T = {}, prims = {}, group = "" }, Organic)
end

function Organic:vert(p, mat)
	table.insert(self.P, p)
	table.insert(self.M, mat or 0)
	table.insert(self.G, self.group)
	return #self.P
end

-- one triangle, flipped if it faces `inside`
function Organic:tri(a, b, c, inside)
	if a == b or b == c or a == c then
		return
	end
	local P = self.P
	if inside then
		local n = (P[b] - P[a]):Cross(P[c] - P[a])
		if n:Dot((P[a] + P[b] + P[c]) / 3 - inside) < 0 then
			b, c = c, b
		end
	end
	table.insert(self.T, { a, b, c })
end

-- join two rings of vertex ids (same length, wrapping); a ring may be a single pole id
function Organic:join(r1, r2, n, inside)
	for s = 1, n do
		local s2 = s % n + 1
		local a = type(r1) == "table" and r1[s] or r1
		local b = type(r1) == "table" and r1[s2] or r1
		local c = type(r2) == "table" and r2[s2] or r2
		local d = type(r2) == "table" and r2[s] or r2
		self:tri(a, b, c, inside)
		self:tri(a, c, d, inside)
	end
end

-- ---------------------------------------------------------------- AO primitives (SDF)
function Organic:capsule(a, b, r)
	table.insert(self.prims, { k = 1, a = a, b = b, r = r })
end

function Organic:ellipsoid(c, R, U, F, sx, sy, sz)
	table.insert(self.prims, { k = 2, c = c, R = R, U = U, F = F, s = self.V3.new(sx, sy, sz) })
end

local function primSdf(pr, p, V3)
	if pr.k == 1 then
		local ab = pr.b - pr.a
		local t = math.clamp((p - pr.a):Dot(ab) / math.max(ab:Dot(ab), 1e-9), 0, 1)
		return (p - (pr.a + ab * t)).Magnitude - pr.r
	end
	local d = p - pr.c
	local s = pr.s
	local q = V3.new(d:Dot(pr.R) / s.X, d:Dot(pr.U) / s.Y, d:Dot(pr.F) / s.Z)
	return (q.Magnitude - 1) * math.min(s.X, s.Y, s.Z)
end

-- ---------------------------------------------------------------- spline helpers
local function cr(p0, p1, p2, p3, t)
	local t2, t3 = t * t, t * t * t
	return (p1 * 2 + (p2 - p0) * t + (p0 * 2 - p1 * 5 + p2 * 4 - p3) * t2 + (p1 * 3 - p0 - p2 * 3 + p3) * t3) * 0.5
end
Organic.cr = cr

-- point on a Catmull-Rom spline through ctrl at parameter s in [1, #ctrl]
function Organic.splineAt(ctrl, s)
	local n = #ctrl
	s = math.clamp(s, 1, n)
	local i = math.min(math.floor(s), n - 1)
	local t = s - i
	return cr(ctrl[math.max(i - 1, 1)], ctrl[i], ctrl[i + 1], ctrl[math.min(i + 2, n)], t)
end

-- scalar Catmull-Rom over keys { {x, value}, ... } sorted by x
function Organic.curve(keys, x)
	local n = #keys
	if x <= keys[1][1] then
		return keys[1][2]
	end
	if x >= keys[n][1] then
		return keys[n][2]
	end
	local i = 1
	while keys[i + 1][1] < x do
		i += 1
	end
	local t = (x - keys[i][1]) / (keys[i + 1][1] - keys[i][1])
	local v0, v1 = keys[math.max(i - 1, 1)][2], keys[i][2]
	local v2, v3 = keys[i + 1][2], keys[math.min(i + 2, n)][2]
	return cr(v0, v1, v2, v3, t)
end

-- ---------------------------------------------------------------- tube
-- Smooth tube through control points (Catmull-Rom), radii per control point.
-- opts: segs (10), ds (ring spacing, 0.1), cap0/cap1 ("round" | "point" | nil=flat pole),
--       mat (number or fn(s, pos) where s is the control-index parameter), knobs = { {at, amt, w} },
--       jit (radial noise amount, 0.06), freq (noise frequency, 5), sx/sy (oval section),
--       up (hint for the section frame), ao (false to skip AO capsules)
-- Returns the sample list { {p, r, s, T, N, B} } so callers can hang details on it.
function Organic:tube(ctrl, radii, opts)
	opts = opts or {}
	local V3 = self.V3
	local segs, ds = opts.segs or 10, opts.ds or 0.1
	local jit, freq = opts.jit or 0.06, opts.freq or 5
	local sx, sy = opts.sx or 1, opts.sy or 1
	local n = #ctrl
	local S = {}
	for i = 1, n - 1 do
		local len = (ctrl[i + 1] - ctrl[i]).Magnitude
		local k = math.max(1, math.ceil(len / ds))
		for j = 0, k - 1 do
			local t = j / k
			local s = i + t
			local p = Organic.splineAt(ctrl, s)
			local r = radii[i] + (radii[i + 1] - radii[i]) * t
			table.insert(S, { p = p, r = r, s = s })
		end
	end
	table.insert(S, { p = ctrl[n], r = radii[n], s = n })
	for _, smp in S do
		for _, kb in opts.knobs or {} do
			smp.r += kb[2] * math.exp(-((smp.s - kb[1]) / (kb[3] or 0.2)) ^ 2)
		end
	end
	-- parallel-transport frames
	local up = opts.up or V3.new(0, 0, -1)
	for i, smp in S do
		local a, b = S[math.max(i - 1, 1)].p, S[math.min(i + 1, #S)].p
		smp.T = (b - a).Magnitude > 1e-6 and (b - a).Unit or V3.new(0, 1, 0)
	end
	local N = up - S[1].T * up:Dot(S[1].T)
	if N.Magnitude < 1e-3 then
		N = V3.new(1, 0, 0) - S[1].T * S[1].T.X
	end
	N = N.Unit
	for _, smp in S do
		N = (N - smp.T * N:Dot(smp.T))
		N = N.Magnitude > 1e-6 and N.Unit or N
		smp.N = N
		smp.B = smp.T:Cross(N)
	end
	local function matAt(s, pos)
		return type(opts.mat) == "function" and opts.mat(s, pos) or opts.mat or 0
	end
	local function ring(c, T, Nn, Bn, r, s)
		local ids = {}
		for q = 1, segs do
			local a = (q - 1) / segs * math.pi * 2
			local dir = Nn * (math.cos(a) * sx) + Bn * (math.sin(a) * sy)
			local p0 = c + dir * r
			local k = 1 + jit * (Organic.vnoise(p0.X * freq, p0.Y * freq, p0.Z * freq) * 2 - 1)
			local pos = c + dir * (r * k)
			ids[q] = self:vert(pos, matAt(s, pos))
		end
		return ids
	end
	local rings, centers = {}, {}
	-- cap rings, ordered from the equator towards the pole
	local function cap(smp, sign, kind)
		if kind == "round" then
			local list = {}
			for _, th in { math.pi / 6, math.pi / 3 } do
				table.insert(list, { smp.p + smp.T * (sign * smp.r * math.sin(th)), smp.r * math.cos(th) })
			end
			return smp.p + smp.T * (sign * smp.r), list
		elseif kind == "point" then
			return smp.p + smp.T * (sign * smp.r * 0.5), {}
		end
		return smp.p, {}
	end
	local first, last = S[1], S[#S]
	local pole0, pre = cap(first, -1, opts.cap0)
	table.insert(rings, self:vert(pole0, matAt(first.s, pole0)))
	table.insert(centers, pole0)
	for k = #pre, 1, -1 do
		table.insert(rings, ring(pre[k][1], first.T, first.N, first.B, pre[k][2], first.s))
		table.insert(centers, pre[k][1])
	end
	for _, smp in S do
		table.insert(rings, ring(smp.p, smp.T, smp.N, smp.B, smp.r, smp.s))
		table.insert(centers, smp.p)
	end
	local pole1, post = cap(last, 1, opts.cap1)
	for k = 1, #post do
		table.insert(rings, ring(post[k][1], last.T, last.N, last.B, post[k][2], last.s))
		table.insert(centers, post[k][1])
	end
	table.insert(rings, self:vert(pole1, matAt(last.s, pole1)))
	table.insert(centers, pole1)
	for i = 1, #rings - 1 do
		self:join(rings[i], rings[i + 1], segs, (centers[i] + centers[i + 1]) / 2)
	end
	if opts.ao ~= false then
		local step = 3
		for i = 1, #S - 1, step do
			local j = math.min(i + step, #S)
			self:capsule(S[i].p, S[j].p, math.min(S[i].r, S[j].r) * 0.92)
		end
	end
	return S
end

-- ---------------------------------------------------------------- blob
-- Star-shaped sculpted surface around c. shape(d) gets a unit direction in local space
-- (x along R, y along U, z along F) and returns the local offset of the surface point plus an
-- optional material. Rings run from the -F pole to the +F pole.
-- opts: lat (rings, 12), lon (segments, 16), aoSize = Vector3 half sizes for the AO ellipsoid
function Organic:blob(c, R, U, F, shape, opts)
	opts = opts or {}
	local V3 = self.V3
	local lat, lon = opts.lat or 12, opts.lon or 16
	local function world(o)
		return c + R * o.X + U * o.Y + F * o.Z
	end
	local function at(d)
		local o, mat = shape(d)
		return world(o), mat
	end
	local rings = {}
	local p0, m0 = at(V3.new(0, 0, -1))
	table.insert(rings, self:vert(p0, m0))
	for i = 1, lat - 1 do
		local phi = -math.pi / 2 + i / lat * math.pi
		local ids = {}
		for q = 1, lon do
			local a = (q - 1) / lon * math.pi * 2
			local d = V3.new(math.cos(phi) * math.cos(a), math.cos(phi) * math.sin(a), math.sin(phi))
			local p, m = at(d)
			ids[q] = self:vert(p, m)
		end
		table.insert(rings, ids)
	end
	local p1, m1 = at(V3.new(0, 0, 1))
	table.insert(rings, self:vert(p1, m1))
	local inside = opts.inside or c
	for i = 1, #rings - 1 do
		self:join(rings[i], rings[i + 1], lon, inside)
	end
	if opts.aoSize ~= false then
		local s = opts.aoSize or V3.new(1, 1, 1) * 0.1
		self:ellipsoid(c, R, U, F, s.X, s.Y, s.Z)
	end
	return world
end

-- plain ellipsoid blob with optional radial noise
function Organic:ellipsoidBlob(c, R, U, F, sx, sy, sz, mat, opts)
	opts = opts or {}
	local V3 = self.V3
	local jit, freq = opts.jit or 0, opts.freq or 6
	return self:blob(c, R, U, F, function(d)
		local k = 1
		if jit > 0 then
			local w = c + R * (d.X * sx) + U * (d.Y * sy) + F * (d.Z * sz)
			k = 1 + jit * (Organic.vnoise(w.X * freq, w.Y * freq, w.Z * freq) * 2 - 1)
		end
		return V3.new(d.X * sx * k, d.Y * sy * k, d.Z * sz * k), mat
	end, { lat = opts.lat or 8, lon = opts.lon or 10, aoSize = opts.ao == false and false or V3.new(sx, sy, sz) * 0.9 })
end

-- rounded, lumpy box (a superquadric blob): cf = centre + orientation, size = full size,
-- opts.p (squareness, 8), opts.jit / opts.freq (surface lumps), opts.mat = number or
-- fn(localPoint, unitDir) -> material
function Organic:roundBox(cf, size, opts)
	opts = opts or {}
	local V3 = self.V3
	local hx, hy, hz = size.X / 2, size.Y / 2, size.Z / 2
	local pw = opts.p or 8
	local jit, freq = opts.jit or 0.04, opts.freq or 3
	local R, U, F = cf.RightVector, cf.UpVector, -cf.LookVector
	local c = cf.Position
	return self:blob(c, R, U, F, function(d)
		-- point on |x/hx|^p + |y/hy|^p + |z/hz|^p = 1 along d
		local sum = (math.abs(d.X) / hx) ^ pw + (math.abs(d.Y) / hy) ^ pw + (math.abs(d.Z) / hz) ^ pw
		local r = sum ^ (-1 / pw)
		local lp = V3.new(d.X * r, d.Y * r, d.Z * r)
		local w = c + R * lp.X + U * lp.Y + F * lp.Z
		local k = 1 + jit * (Organic.vnoise(w.X * freq, w.Y * freq, w.Z * freq) * 2 - 1)
			+ jit * 0.5 * (Organic.vnoise(w.X * freq * 2.7 + 9, w.Y * freq * 2.7, w.Z * freq * 2.7) * 2 - 1)
		lp = lp * k
		local mat = opts.mat
		if type(mat) == "function" then
			mat = mat(lp, d)
		end
		return lp, mat or 0
	end, { lat = opts.lat or 18, lon = opts.lon or 24, aoSize = V3.new(hx, hy, hz) * 0.92 })
end

-- surface of revolution round cf's up axis: profile = { {radius, y}, ... } bottom to top,
-- matFn(profileIndex, angle) -> material. Radius 0 rows collapse to a pole.
function Organic:lathe(cf, profile, segs, matFn, opts)
	opts = opts or {}
	local jit, freq = opts.jit or 0, opts.freq or 5
	local rings, centers = {}, {}
	for i, pr in profile do
		local r, y = pr[1], pr[2]
		local cen = cf * self.V3.new(0, y, 0)
		if r <= 1e-4 then
			table.insert(rings, self:vert(cen, matFn and matFn(i, 0) or 0))
		else
			local ids = {}
			for q = 1, segs do
				local a = (q - 1) / segs * math.pi * 2
				local p = cf * self.V3.new(math.cos(a) * r, y, -math.sin(a) * r)
				if jit > 0 then
					local k = 1 + jit * (Organic.vnoise(p.X * freq, p.Y * freq, p.Z * freq) * 2 - 1)
					p = cen + (p - cen) * k
				end
				ids[q] = self:vert(p, matFn and matFn(i, a) or 0)
			end
			table.insert(rings, ids)
		end
		table.insert(centers, cen)
	end
	local inside = opts.inside or (centers[1] + centers[#centers]) / 2
	for i = 1, #rings - 1 do
		self:join(rings[i], rings[i + 1], segs, opts.insideFn and opts.insideFn(i) or inside)
	end
	if opts.aoRadius then
		self:capsule(centers[1], centers[#centers], opts.aoRadius)
	end
end

-- ---------------------------------------------------------------- finish
-- target: an EditableMesh, or fn(groupName) -> EditableMesh (set B.group before building a
-- piece to split the model into parts, e.g. for a Motor6D rig; "" = the main mesh).
-- opts: aoSteps (distances), aoStrength, ground (true: the Y=0 plane occludes)
-- Returns { [group] = triangleCount }.
function Organic:finish(target, shade, opts)
	opts = opts or {}
	local V3, C3 = self.V3, self.C3
	local P, T, M = self.P, self.T, self.M
	-- smooth normals
	local acc = {}
	for i = 1, #P do
		acc[i] = V3.new(0, 0, 0)
	end
	for _, t in T do
		local n = (P[t[2]] - P[t[1]]):Cross(P[t[3]] - P[t[1]])
		acc[t[1]] += n
		acc[t[2]] += n
		acc[t[3]] += n
	end
	-- spatial hash of SDF primitives for AO lookups
	local CELL, REACH = 0.5, 0.45
	local grid = {}
	local function key(x, y, z)
		return x .. "," .. y .. "," .. z
	end
	for _, pr in self.prims do
		local lo, hi
		if pr.k == 1 then
			lo, hi = pr.a:Min(pr.b) - V3.one * (pr.r + REACH), pr.a:Max(pr.b) + V3.one * (pr.r + REACH)
		else
			local m = math.max(pr.s.X, pr.s.Y, pr.s.Z) + REACH
			lo, hi = pr.c - V3.one * m, pr.c + V3.one * m
		end
		for x = math.floor(lo.X / CELL), math.floor(hi.X / CELL) do
			for y = math.floor(lo.Y / CELL), math.floor(hi.Y / CELL) do
				for z = math.floor(lo.Z / CELL), math.floor(hi.Z / CELL) do
					local k = key(x, y, z)
					grid[k] = grid[k] or {}
					table.insert(grid[k], pr)
				end
			end
		end
	end
	local ground = opts.ground ~= false
	local function sdf(p)
		local list = grid[key(math.floor(p.X / CELL), math.floor(p.Y / CELL), math.floor(p.Z / CELL))]
		local d = ground and p.Y or 1e9
		if list then
			for _, pr in list do
				local v = primSdf(pr, p, V3)
				if v < d then
					d = v
				end
			end
		end
		return d
	end
	local steps = opts.aoSteps or { 0.04, 0.09, 0.16, 0.26, 0.4 }
	local strength = opts.aoStrength or 1.0
	local colorIds = {}
	local vids, cids = {}, {}
	local meshes = {}
	local function meshOf(grp)
		if type(target) ~= "function" then
			return target
		end
		meshes[grp] = meshes[grp] or target(grp)
		return meshes[grp]
	end
	for i, p in P do
		local n = acc[i].Magnitude > 1e-12 and acc[i].Unit or V3.new(0, 1, 0)
		local occ, wsum, w = 0, 0, 1
		for _, h in steps do
			occ += w * math.max(0, h - sdf(p + n * h)) / h
			wsum += w
			w *= 0.6
		end
		local ao = math.clamp(occ / wsum * strength, 0, 1)
		local r, g, b = shade(p, n, M[i], ao)
		-- 6 bits per channel keeps the colour table small
		r, g, b = math.floor(math.clamp(r, 0, 1) * 63 + 0.5), math.floor(math.clamp(g, 0, 1) * 63 + 0.5), math.floor(math.clamp(b, 0, 1) * 63 + 0.5)
		local ck = r * 4096 + g * 64 + b
		local em = meshOf(self.G[i])
		colorIds[em] = colorIds[em] or {}
		local cid = colorIds[em][ck]
		if not cid then
			cid = em:AddColor(C3.new(r / 63, g / 63, b / 63), 1)
			colorIds[em][ck] = cid
		end
		vids[i] = em:AddVertex(p)
		cids[i] = cid
	end
	local counts = {}
	for _, t in T do
		local grp = self.G[t[1]]
		local em = meshOf(grp)
		local f = em:AddTriangle(vids[t[1]], vids[t[2]], vids[t[3]])
		em:SetFaceColors(f, { cids[t[1]], cids[t[2]], cids[t[3]] })
		counts[grp] = (counts[grp] or 0) + 1
	end
	return counts
end

return Organic
