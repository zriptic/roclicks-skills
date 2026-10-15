--!nocheck
-- Studify's verified voxel-blob tree, as a mesh (style-notes.md "Trees", G0ffxps / G5aS refs):
--   canopy: ~7 stacked courses whose widths follow a rounded profile (0.5 -> 1.0 -> 0.55 of a
--     ~10-12 max), each course jittered ±0.8, with 2-3 proud bump blocks (1.6-2.8), ~40% of
--     the bumps in a second patch green
--   trunk: a tall stacked coral column (~40% of tree height, 2.8 wide, 4 segments, offsets)
--   roots grow OUT of the trunk ~2 studs up and angle ~40° down to a toe block
--   branches: 3 chained tapering segments, alternating shades, joints buried 0.3, pitching up
--     ~25° more per segment so the limb curves out and dives into the canopy underside
-- Crisp edges, studs at 1 per stud like the references. lib.seed varies it. Base on Y = 0.

return function(em, lib, Shapes)
	local V3, CF, C3 = lib.Vector3, lib.CFrame, lib.Color3
	local rad = math.rad
	local P = Shapes.Props
	local rand = P.rng(lib.seed)
	local pitch = Shapes.PITCH
	Shapes.PITCH = 1.0
	Shapes.beginBake({ cell = 2.0 })
	local S = Shapes.new(em, lib)

	local greens = {
		{ C3.fromRGB(132, 214, 62), C3.fromRGB(110, 196, 52) },
		{ C3.fromRGB(120, 206, 70), C3.fromRGB(150, 222, 76) },
		{ C3.fromRGB(104, 192, 66), C3.fromRGB(128, 208, 60) },
	}
	local pal = greens[1 + math.floor(rand(0, #greens))]
	local leaf, patch = pal[1], pal[2]
	local coral, coralDark = C3.fromRGB(232, 126, 120), C3.fromRGB(218, 110, 108)
	local function block(cf, size, col)
		S:bevelBox(cf, size, col, 0)
	end

	local maxW = rand(10, 12)
	local courseH = 1.6
	local courses = 7
	local canopyH = courses * courseH
	local trunkH = canopyH * 0.8 -- trunk column: ~40% of the tree, mostly visible under the canopy
	local yaw = rad(15 * math.floor(rand(0, 6)))

	-- Trunk: 4 stacked coral segments, slight offsets, alternating shade.
	local segH = trunkH / 4
	local off = V3.new(0, 0, 0)
	for i = 0, 3 do
		block(CF.new(off.X, segH * (i + 0.5), off.Z) * CF.Angles(0, yaw, 0), V3.new(2.8, segH + 0.02, 2.8), i % 2 == 0 and coral or coralDark)
		off += V3.new(rand(-0.25, 0.25), 0, rand(-0.25, 0.25))
	end

	-- Roots: out of the trunk side ~2 up, down at ~40° to a toe block.
	local nRoots = 3 + math.floor(rand(0, 2))
	for k = 0, nRoots - 1 do
		local a = yaw + k / nRoots * math.pi * 2 + rand(-0.3, 0.3)
		local start = V3.new(math.sin(a) * 1.1, 2.0, math.cos(a) * 1.1)
		local d = P.dir(lib, a, rad(-40))
		local len = 2.0 / math.sin(rad(40)) -- reaches the ground
		local tip = P.limb(S, lib, start, d, len, 0.9, k % 2 == 0 and coralDark or coral)
		block(CF.new(tip.X, 0.25, tip.Z) * CF.Angles(0, a, 0), V3.new(1.3, 0.5, 1.5), coral)
	end

	-- Branches: arced limbs out of the upper trunk into the canopy underside.
	for k = 0, 1 do
		local a = yaw + k * math.pi + rand(-0.4, 0.4)
		local p = V3.new(off.X, trunkH * 0.72, off.Z)
		local elev = rad(15)
		for seg = 1, 3 do
			local d = P.dir(lib, a, elev)
			local len, t = ({ 1.8, 1.6, 1.4 })[seg], ({ 0.9, 0.75, 0.6 })[seg]
			local tip = P.limb(S, lib, p, d, len, t, seg % 2 == 0 and coral or coralDark)
			p = tip - d * 0.3 -- next joint buried 0.3 in this one
			elev += rad(25)
		end
	end

	-- Canopy: stepped voxel sphere.
	local profile = { 0.42, 0.75, 0.95, 1.0, 0.92, 0.75, 0.55 }
	local base = trunkH - 0.6
	local cx, cz = off.X, off.Z
	for i, f in profile do
		local w = maxW * f
		local y = base + (i - 0.5) * courseH
		local jx, jz = rand(-0.8, 0.8), rand(-0.8, 0.8)
		local cyaw = CF.Angles(0, yaw, 0) -- every course square to the tree; only offsets jitter
		local core = CF.new(cx + jx, y, cz + jz) * cyaw
		block(core, V3.new(w, courseH, w * rand(0.85, 1.0)), leaf)
		-- a cross piece rounds the square course off a little
		block(core, V3.new(w * 0.72, courseH + 0.02, w * 1.08), leaf)
		for b = 1, 2 + math.floor(rand(0, 2)) do
			local s = rand(1.6, 2.8)
			local a = rand(0, math.pi * 2)
			local r = w * 0.5 - s * 0.3
			local col = rand(0, 1) < 0.4 and patch or leaf
			block(core * CF.new(math.cos(a) * r, rand(-0.3, 0.3), math.sin(a) * r), V3.new(s, s * rand(0.7, 1.0), s), col)
		end
	end

	Shapes.finishBake(lib, { distance = 3.2, strength = 0.6, sky = 0.28 })
	Shapes.PITCH = pitch
end
