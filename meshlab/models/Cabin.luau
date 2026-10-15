--!nocheck
-- Ultra-stylized snowy log cabin. Chunky exaggerated proportions, everything a little wonky:
--   fat 8-sided logs interlocking at the corners, ends sticking out with end-grain rings;
--   steep heavy roof with crooked shingle rows under a thick snow blanket, eave lumps, icicles;
--   board gables with a glowing round attic window; glowing crooked windows with red Z-braced
--   shutters and snowy sills; arched plank door, iron hinges, lantern; leaning stone chimney with
--   snow cap and blocky smoke; firewood pile, stump + axe, log steps, lumpy snow ground.
-- Front (door) faces -Z. Ground on Y = 0. lib.seed varies the wonkiness.

return function(em, lib, Shapes, part)
	local V3, CF, C3 = lib.Vector3, lib.CFrame, lib.Color3
	local rad = math.rad
	local P = Shapes.Props
	local rand = P.rng(lib.seed)
	local pitch = Shapes.PITCH
	Shapes.PITCH = 1.0
	Shapes.beginBake({ cell = 1.6 })
	local S
	local function section(name)
		S = Shapes.new(part(name), lib)
	end
	local function box(cf, size, col)
		S:bevelBox(cf, size, col, 0)
	end
	local function at(x, y, z, sx, sy, sz, col)
		box(CF.new(x, y, z), V3.new(sx, sy, sz), col)
	end
	local function plate(a, b, w, t, col, twist)
		local d = b - a
		local cf = P.lookAt(lib, (a + b) / 2, d.Unit)
		if twist then
			cf = cf * CF.Angles(0, twist, 0)
		end
		box(cf, V3.new(w, t, d.Magnitude), col)
	end
	local X, Y, Z = V3.new(1, 0, 0), V3.new(0, 1, 0), V3.new(0, 0, 1)
	-- glowing pieces are drawn last, unshaded, in their own "Glow" part (make it Neon in Studio)
	local glowing = {}
	local function glowBox(cf, size)
		table.insert(glowing, { cf, size })
	end

	local bark, barkB = C3.fromRGB(176, 104, 56), C3.fromRGB(150, 86, 46)
	local grain, ring = C3.fromRGB(240, 196, 134), C3.fromRGB(204, 144, 86)
	local board, boardB = C3.fromRGB(200, 138, 82), C3.fromRGB(182, 120, 70)
	local shingle, shingleB = C3.fromRGB(122, 74, 56), C3.fromRGB(104, 62, 48)
	local snow, snowShade = C3.fromRGB(246, 250, 255), C3.fromRGB(218, 230, 246)
	local ice = C3.fromRGB(170, 220, 250)
	local glow = C3.fromRGB(255, 204, 104)
	local frameDark = C3.fromRGB(96, 58, 36)
	local shutter = C3.fromRGB(206, 68, 56)
	local iron = C3.fromRGB(46, 46, 52)
	local stone, stoneB, stoneC = C3.fromRGB(150, 156, 176), C3.fromRGB(126, 132, 154), C3.fromRGB(170, 174, 190)
	local door = C3.fromRGB(156, 84, 52)
	local smoke = C3.fromRGB(226, 230, 236)

	-- A log: chunky 8-sided lathe along an axis, end-grain rings on both caps.
	local function log(cf, r, len, sideCol)
		local prof = {
			{ 0, 0 }, { r * 0.4, 0 }, { r * 0.72, 0 }, { r, 0 },
			{ r, len }, { r * 0.72, len }, { r * 0.4, len }, { 0, len },
		}
		S:lathe(cf, prof, 8, function(i)
			if i == 4 then
				return sideCol
			end
			return (i == 2 or i == 6) and ring or grain
		end)
	end
	local function logX(x0, y, z, r, len, col) -- along +X from x0
		log(CF.new(x0, y, z) * CF.Angles(0, 0, rad(-90)), r, len, col)
	end
	local function logZ(x, y, z0, r, len, col) -- along +Z from z0
		log(CF.new(x, y, z0) * CF.Angles(rad(90), 0, 0), r, len, col)
	end

	local hx, hz = 7.0, 5.5 -- wall centre lines
	local R = 0.6 -- log radius (fat)
	local rows = 9
	local over = 1.0 -- how far log ends stick out past the corners
	local wallTop = R + rows - 1 + 0.5 + R

	------------------------------------------------------------------ log walls
	section("Cabin")
	for r = 0, rows - 1 do
		local y = R + r
		local j = rand(-0.12, 0.12) -- every row a touch crooked
		for _, sz in { -1, 1 } do -- front/back logs
			logX(-hx - over + j, y, sz * hz, R + rand(-0.04, 0.04), 2 * (hx + over) + rand(-0.3, 0.3), (r + (sz > 0 and 1 or 0)) % 2 == 0 and bark or barkB)
		end
		for _, sx in { -1, 1 } do -- side logs, half a log higher so the corners interlock
			logZ(sx * hx, y + 0.5, -hz - over + j, R + rand(-0.04, 0.04), 2 * (hz + over) + rand(-0.3, 0.3), (r + (sx > 0 and 0 or 1)) % 2 == 0 and barkB or bark)
		end
	end
	-- board gables on both ends, cut to the roof line, round glowing attic window
	local ridgeY, eaveY, eaveZ = 18.0, wallTop - 0.2, hz + 2.9
	local function roofY(z)
		return ridgeY - math.abs(z) * (ridgeY - eaveY) / eaveZ
	end
	for _, sx in { -1, 1 } do
		for k = -6, 6 do
			local z = k * 1.0
			local top = roofY(math.abs(z) + 0.5) - 0.3
			if top > wallTop then
				at(sx * (hx + 0.1), (wallTop + top) / 2, z, 0.3, top - wallTop, 0.96, k % 2 == 0 and board or boardB)
			end
		end
		local ac = CF.new(sx * (hx + 0.3), wallTop + 3.2, 0) * CF.Angles(0, 0, rad(sx * 90))
		table.insert(glowing, { ac, nil, { { 0, 0 }, { 1.0, 0 }, { 1.0, 0.12 }, { 0, 0.12 } } })
		S:lathe(ac, { { 0.95, -0.05 }, { 1.35, -0.05 }, { 1.35, 0.3 }, { 0.95, 0.3 } }, 10, frameDark)
		at(sx * (hx + 0.45), wallTop + 3.2, 0, 0.1, 2.0, 0.18, frameDark)
		at(sx * (hx + 0.45), wallTop + 3.2, 0, 0.1, 0.18, 2.0, frameDark)
	end
	-- stone footing under the walls
	for k = 0, 9 do
		local x = -hx + k * 1.55
		at(x, 0.15, -hz - 0.1, 1.4, 0.35, 1.3, k % 2 == 0 and stone or stoneB)
	end

	------------------------------------------------------------------ roof + snow
	section("Roof")
	local roofW = 2 * (hx + over) + 1.6
	for _, sz in { -1, 1 } do
		local E = V3.new(0, eaveY, sz * eaveZ)
		local Rg = V3.new(0, ridgeY, 0)
		local u = (Rg - E).Unit
		local n = X:Cross(u)
		if n.Y < 0 then
			n = -n
		end
		plate(E, Rg, roofW, 0.5, frameDark) -- roof deck
		local len = (Rg - E).Magnitude
		local nRows = 6
		for k = 0, nRows - 1 do -- crooked shingle rows, each overlapping the one below
			local a = E + u * (k * len / nRows) + n * 0.35
			plate(a, a + u * (len / nRows + 0.5), roofW + rand(-0.4, 0.4), 0.35, k % 2 == 0 and shingle or shingleB, rad(rand(-1.5, 1.5)))
		end
		-- snow blanket on top, lumpy eave edge and icicles
		plate(E + u * 0.6 + n * 0.85, Rg + n * 0.85, roofW - 0.4, 0.7, snow)
		for k = 0, 8 do
			local x = -roofW / 2 + 1.2 + k * (roofW - 2.4) / 8
			local s = rand(0.9, 1.4)
			box(P.lookAt(lib, E + u * 0.9 + n * 0.9 + X * x, u) * CF.Angles(0, rad(rand(-15, 15)), 0), V3.new(s * 1.3, s * 0.7, s), k % 2 == 0 and snow or snowShade)
		end
		for k = 0, 10 do
			local x = -roofW / 2 + 1.0 + k * (roofW - 2.0) / 10 + rand(-0.3, 0.3)
			local l = rand(0.5, 1.3)
			S:lathe(CF.new(V3.new(x, eaveY - 0.15, sz * (eaveZ - 0.2))) * CF.Angles(rad(180), 0, 0),
				{ { 0, 0 }, { 0.16, 0 }, { 0.1, l * 0.6 }, { 0, l } }, 5, ice)
		end
	end
	at(0, ridgeY + 1.15, 0, roofW + 0.2, 0.9, 1.8, snow) -- ridge snow cap

	------------------------------------------------------------------ windows, door, chimney
	section("Details")
	local front = -hz - R
	local function window(x, y, z, w, h, faceX)
		local tilt = CF.Angles(0, 0, rad(rand(-4, 4))) -- crooked on purpose
		local function F(u, v, d, sx, sy, sz, col)
			local cf
			if faceX then
				cf = CF.new(x, y, z) * CF.Angles(0, rad(faceX * 90), 0) * tilt * CF.new(u, v, -d)
			else
				cf = CF.new(x, y, z) * tilt * CF.new(u, v, -d)
			end
			box(cf, V3.new(sx, sy, sz), col)
		end
		do -- pane: recorded for the glow pass
			local cf = (faceX and CF.new(x, y, z) * CF.Angles(0, rad(faceX * 90), 0) or CF.new(x, y, z)) * tilt * CF.new(0, 0, -0.05)
			glowBox(cf, V3.new(w, h, 0.1))
		end
		F(0, h / 2 + 0.2, 0.2, w + 0.8, 0.4, 0.4, frameDark)
		F(0, -h / 2 - 0.2, 0.2, w + 0.8, 0.4, 0.4, frameDark)
		F(-w / 2 - 0.2, 0, 0.2, 0.4, h, 0.4, frameDark)
		F(w / 2 + 0.2, 0, 0.2, 0.4, h, 0.4, frameDark)
		F(0, 0, 0.15, 0.22, h, 0.15, frameDark)
		F(0, 0, 0.15, w, 0.22, 0.15, frameDark)
		F(0, -h / 2 - 0.55, 0.45, w + 1.1, 0.35, 0.8, snow) -- snowy sill
		for _, side in { -1, 1 } do -- red shutters with a Z brace
			local su = side * (w / 2 + 0.95)
			F(su, 0, 0.2, 1.3, h + 0.4, 0.2, shutter)
			F(su, h / 2 - 0.3, 0.32, 1.1, 0.22, 0.08, frameDark)
			F(su, -h / 2 + 0.3, 0.32, 1.1, 0.22, 0.08, frameDark)
			local d = h - 0.6
			local cf = (faceX and CF.new(x, y, z) * CF.Angles(0, rad(faceX * 90), 0) or CF.new(x, y, z)) * tilt
				* CF.new(su, 0, -0.32) * CF.Angles(0, 0, math.atan2(d, 1.0) * side - rad(90) * side)
			box(cf, V3.new(0.2, math.sqrt(d * d + 1.0), 0.08), frameDark)
		end
	end
	window(-4.3, 4.8, front, 2.6, 2.6)
	window(4.3, 4.8, front, 2.6, 2.6)
	window(-hx - R, 4.8, 0, 2.6, 2.6, 1)
	-- arched plank door, frame, iron hinges, knob
	local dz = front - 0.1
	for k = 0, 3 do
		at(-1.05 + k * 0.7, 2.6, dz, 0.68, 5.2, 0.3, k % 2 == 0 and door or door:Lerp(frameDark, 0.25))
	end
	at(0, 5.4, dz, 2.4, 0.4, 0.3, door)
	at(0, 5.75, dz, 1.7, 0.35, 0.3, door)
	at(0, 6.05, dz, 0.9, 0.3, 0.3, door)
	for _, side in { -1, 1 } do
		at(side * 1.6, 3.0, dz - 0.15, 0.45, 6.0, 0.45, frameDark)
	end
	at(0, 6.45, dz - 0.15, 3.6, 0.5, 0.45, frameDark)
	for _, hy in { 1.3, 4.0 } do
		at(-0.4, hy, dz - 0.2, 1.8, 0.25, 0.08, iron)
	end
	S:lathe(CF.new(0.9, 2.7, dz - 0.18) * CF.Angles(rad(-90), 0, 0), { { 0, 0 }, { 0.18, 0 }, { 0.2, 0.15 }, { 0, 0.25 } }, 6, C3.fromRGB(220, 180, 70))
	-- hanging lantern beside the door
	at(2.4, 6.1, dz - 0.3, 0.12, 0.12, 0.8, iron)
	at(2.4, 5.6, dz - 0.65, 0.12, 0.8, 0.12, iron)
	glowBox(CF.new(2.4, 4.95, dz - 0.65), V3.new(0.6, 0.7, 0.6))
	at(2.4, 5.4, dz - 0.65, 0.75, 0.15, 0.75, iron)
	at(2.4, 4.55, dz - 0.65, 0.75, 0.15, 0.75, iron)
	-- log steps
	logX(-1.8, 0.35, dz - 1.0, 0.35, 3.6, bark)
	logX(-1.5, 0.3, dz - 1.75, 0.3, 3.0, barkB)
	-- leaning stone chimney on the right gable, snow cap, smoke puffs
	local cx, cz = hx + R + 1.3, 0
	local courses = 21
	for k = 0, courses - 1 do
		local t = k / (courses - 1)
		local w = 2.8 - t * 0.7
		local lean = t * t * 0.9
		local y = 0.45 + k * 0.92
		local half = w / 2
		for s = -1, 1, 2 do
			local sw = half + rand(-0.15, 0.15)
			at(cx + lean + rand(-0.06, 0.06), y, cz + s * (half - sw / 2) + rand(-0.08, 0.08), w + rand(-0.1, 0.12), 0.88, sw, ({ stone, stoneB, stoneC })[1 + math.floor(rand(0, 3))])
		end
	end
	local topY = 0.45 + courses * 0.92
	local tx = cx + 0.9
	at(tx, topY, cz, 2.6, 0.5, 2.6, stoneB)
	at(tx, topY + 0.45, cz, 2.3, 0.5, 2.3, snow)
	for k, s in { 1.0, 1.35, 1.7 } do
		at(tx + k * 0.5, topY + 1.2 + k * 1.3, cz - k * 0.35, s, s, s, smoke)
	end

	------------------------------------------------------------------ yard
	section("Yard")
	-- lumpy snow ground: a big faceted slab plus a few drifts
	S:loft({ Shapes.octRing(V3.new(0, 0.0, 0), X, Z, 15, 13, 4, 4), Shapes.octRing(V3.new(0, 0.12, 0), X, Z, 15, 13, 4, 4) }, { color = snow })
	for k = 0, 6 do
		local a = rand(0, math.pi * 2)
		local x, z = math.cos(a) * rand(9, 13), math.sin(a) * rand(8, 11)
		local s = rand(1.4, 2.6)
		S:lathe(CF.new(x, 0.05, z), { { 0, 0 }, { s, 0 }, { s * 0.85, s * 0.22 }, { s * 0.5, s * 0.4 }, { 0, s * 0.46 } }, 8, k % 2 == 0 and snow or snowShade)
	end
	-- firewood pile against the left wall, with a snow cap
	local fx = -hx - R - 1.1
	for row = 0, 3 do
		local count = 5 - row
		for k = 0, count - 1 do
			local z = -2.4 + (k + row * 0.5) * 0.85
			logZ(fx + rand(-0.1, 0.1), 0.42 + row * 0.75, z - 1.2, 0.4, 2.4, k % 2 == 0 and bark or barkB)
		end
	end
	at(fx, 3.4, -1.0, 1.0, 0.35, 2.4, snow)
	-- stump with an axe stuck in it
	S:lathe(CF.new(-5.5, 0, -10.0), { { 0, 0 }, { 1.0, 0 }, { 0.9, 0.2 }, { 0.9, 1.1 }, { 0.65, 1.1 }, { 0.35, 1.1 }, { 0, 1.1 } }, 8, function(i)
		if i <= 3 then
			return bark
		end
		return i == 5 and ring or grain
	end)
	plate(V3.new(-5.4, 1.1, -10.1), V3.new(-4.4, 2.6, -10.6), 0.22, 0.22, C3.fromRGB(196, 150, 96)) -- handle
	at(-5.45, 1.2, -10.05, 0.25, 0.6, 0.7, iron) -- head
	at(-5.45, 1.2, -10.42, 0.27, 0.6, 0.12, C3.fromRGB(190, 196, 206)) -- edge

	Shapes.finishBake(lib, { distance = 2.6, strength = 0.6, sky = 0.25 })

	section("Glow") -- after the bake: full-bright, never shaded
	for _, g in glowing do
		if g[3] then
			S:lathe(g[1], g[3], 10, glow)
		else
			S:bevelBox(g[1], g[2], glow, 0)
		end
	end
	Shapes.PITCH = pitch
end
