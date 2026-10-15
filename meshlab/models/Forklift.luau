--!nocheck
-- Two-seat forklift, stud style (pack look: soft-edged chunky blocks, square studs from
-- the normal map, flat colours), reworked from real counterbalance forklifts (TCM / Doosan /
-- CAT / Toyota photos) pushed toward the chunky cartoon game-asset look:
--   * big lugged drive tyres up front, small steer tyres at the back
--   * overhead guard with the front posts leaning back 15°, slatted roof, work lights, beacon
--   * rounded counterweight with tail lights and an LPG tank strapped across it
--   * two-stage mast (outer + inner rails, chains, lift cylinder) and tilt cylinders
--   * L-shaped forks with heels and tapered tips, barred load backrest
-- Co-op readability: blue driver (left, steering wheel), red operator (right, fork levers),
-- matching blue/red stripes on the body sides, a step + grab handle on each side to board.
-- Moving pieces are separate meshes: InnerMast, Forks, SteeringWheel, Levers, 4 wheels.
-- Forks point to -Z (Roblox front). Units are studs, wheels on Y = 0.
-- Paint schemes: lib.seed picks a row of PAINTS (nil / 1 / unknown = the yellow default).
-- Only the paintable panels change (chassis, counterweight, fenders, hood, dash cowl, side
-- panel frames) plus the wheel rims; seats + co-op side stripes stay blue/red (gameplay).

return function(em, lib, Shapes, part)
	local V3, C3, CF = lib.Vector3, lib.Color3, lib.CFrame
	local rad = math.rad

	local steel = C3.fromRGB(150, 156, 168)

	-- body = big panels, trim = darker lip / fenders / panel frames, rim = wheel hub disc.
	-- camo = { dark, light } adds small flat plates over the body panels.
	local PAINTS = {
		{ name = "Forklift Yellow", body = { 255, 196, 40 }, trim = { 236, 158, 22 }, rim = { 150, 156, 168 } },
		{ name = "Fire Red", body = { 226, 52, 44 }, trim = { 168, 30, 30 }, rim = { 196, 200, 210 } },
		{ name = "Ocean Blue", body = { 34, 128, 214 }, trim = { 22, 84, 160 }, rim = { 236, 240, 246 } },
		{ name = "Mint Green", body = { 110, 222, 170 }, trim = { 54, 172, 128 }, rim = { 236, 240, 246 } },
		{ name = "Purple Grape", body = { 142, 72, 210 }, trim = { 96, 44, 156 }, rim = { 255, 200, 70 } },
		{ name = "Cold Storage Ice", body = { 238, 244, 250 }, trim = { 140, 200, 240 }, rim = { 120, 186, 236 } },
		{ name = "VIP Gold", body = { 248, 196, 58 }, trim = { 30, 30, 34 }, rim = { 255, 214, 90 } },
		{ name = "Camo", body = { 108, 128, 66 }, trim = { 72, 88, 46 }, rim = { 96, 100, 84 },
			camo = { { 58, 72, 40 }, { 150, 146, 96 } } },
	}
	local paint = PAINTS[lib.seed or 1] or PAINTS[1]
	local function rgb(t)
		return C3.fromRGB(t[1], t[2], t[3])
	end
	local yellow = rgb(paint.body) -- names kept from the original yellow-only model
	local yellowDark = rgb(paint.trim)
	local rim = rgb(paint.rim)
	local dark = C3.fromRGB(64, 68, 80)
	local black = C3.fromRGB(36, 38, 44)
	local tyre = C3.fromRGB(44, 44, 50)
	local blue = C3.fromRGB(62, 124, 236)
	local red = C3.fromRGB(232, 72, 62)
	local lamp = C3.fromRGB(255, 244, 178)
	local tail = C3.fromRGB(220, 40, 40)
	local amber = C3.fromRGB(255, 132, 30)
	local tank = C3.fromRGB(226, 230, 236)
	local brass = C3.fromRGB(214, 170, 72)

	-- One helper set per mesh, so every moving piece can be its own MeshPart.
	local function kit(mesh)
		local S = Shapes.new(mesh, lib)
		local k = { S = S }
		function k.box(x, y, z, sx, sy, sz, col, rot, bevel)
			local cf = CF.new(x, y, z)
			if rot then
				cf = cf * rot
			end
			S:bevelBox(cf, V3.new(sx, sy, sz), col, bevel or 0.08)
		end
		-- Cylinder along X through (x, y, z): length len, radius r.
		function k.cylX(x, y, z, len, r, col, segs)
			local h = len / 2
			local c = math.min(0.08, r * 0.3)
			S:lathe(CF.new(x, y, z) * CF.Angles(0, 0, rad(90)),
				{ { 0, -h }, { r - c, -h }, { r, -h + c }, { r, h - c }, { r - c, h }, { 0, h } }, segs or 12, col)
		end
		return k
	end

	Shapes.beginBake() -- every shape below registers for the baked ambient occlusion
	local B = kit(em) -- the body

	-- Wheels: lugged tyres (alternating radius = tread blocks) with steel hubs and hub caps.
	local function wheel(partName, x, z, r, w)
		local W = kit(part(partName))
		local cf = CF.new(x, r, z) * CF.Angles(0, 0, rad(90))
		local h, c = w / 2, 0.2
		local lugs = 24
		W.S:lathe(cf, { { 0, -h }, { r - c, -h }, { r, -h + c }, { r, h - c }, { r - c, h }, { 0, h } }, lugs, tyre, function(a)
			return (math.floor(a / (math.pi * 2) * lugs + 0.5) % 2 == 0) and 1 or 0.93
		end)
		local side = x > 0 and 1 or -1
		W.cylX(x + side * (h - 0.02), r, z, 0.2, r * 0.58, rim, 10)
		W.cylX(x + side * (h + 0.08), r, z, 0.14, r * 0.26, dark, 8)
		for i = 0, 4 do
			local a = i / 5 * math.pi * 2
			W.box(x + side * (h + 0.1), r + math.cos(a) * r * 0.4, z + math.sin(a) * r * 0.4, 0.1, 0.12, 0.12, dark, nil, 0.03)
		end
	end
	wheel("WheelFL", -2.3, -2.2, 1.25, 1.0)
	wheel("WheelFR", 2.3, -2.2, 1.25, 1.0)
	wheel("WheelRL", -2.15, 2.5, 0.95, 0.85)
	wheel("WheelRR", 2.15, 2.5, 0.95, 0.85)

	-- Chassis with a dark skirt, fenders over the drive wheels.
	B.box(0, 1.75, 0.2, 3.9, 1.5, 5.6, yellow)
	B.box(0, 0.85, 0.2, 3.7, 0.4, 5.4, dark)
	B.box(0, 2.55, 0.2, 4.02, 0.14, 5.72, yellowDark) -- top lip, throws a shadow line
	for _, sx in { -1, 1 } do -- raised panel frame on each side around the stripe
		B.box(sx * 1.97, 2.32, 0.4, 0.1, 0.12, 3.3, yellowDark, nil, 0.03)
		B.box(sx * 1.97, 1.2, 0.4, 0.1, 0.12, 3.3, yellowDark, nil, 0.03)
		B.box(sx * 1.97, 1.76, -1.2, 0.1, 1.24, 0.12, yellowDark, nil, 0.03)
		B.box(sx * 1.97, 1.76, 2.0, 0.1, 1.24, 0.12, yellowDark, nil, 0.03)
	end
	for _, x in { -2.3, 2.3 } do
		B.box(x, 2.6, -2.2, 1.2, 0.28, 2.0, yellowDark)
		B.box(x, 2.25, -3.15, 1.2, 0.28, 0.6, yellowDark, CF.Angles(rad(-45), 0, 0))
		B.box(x, 2.25, -1.25, 1.2, 0.28, 0.6, yellowDark, CF.Angles(rad(45), 0, 0))
	end

	-- Rounded counterweight: a block plus a half-buried cylinder for the round back.
	B.box(0, 1.95, 3.45, 4.3, 2.5, 1.2, yellow)
	B.cylX(0, 1.95, 3.95, 4.3, 1.25, yellow, 16)
	B.box(0, 0.95, 3.95, 4.32, 0.5, 2.3, dark)
	-- Rear bumper with a tow hitch.
	B.box(0, 1.3, 5.12, 4.4, 0.5, 0.4, dark)
	B.box(0, 1.3, 5.38, 0.5, 0.3, 0.3, steel, nil, 0.05)
	-- Tail lights in the back corners.
	for _, x in { -1.75, 1.75 } do
		B.box(x, 2.55, 5.12, 0.5, 0.4, 0.2, tail)
	end
	-- LPG tank across the top of the counterweight, with straps and a brass valve.
	B.cylX(0, 3.75, 3.85, 3.0, 0.55, tank, 14)
	for _, x in { -0.9, 0.9 } do
		B.box(x, 3.75, 3.85, 0.16, 1.22, 1.22, dark, nil, 0.04)
	end
	B.cylX(1.6, 3.75, 3.85, 0.25, 0.22, brass, 8)
	B.box(0, 3.18, 3.85, 3.4, 0.14, 1.0, dark)

	-- Hood behind the seats, deck, dash cowl tilted toward the seats.
	B.box(0, 3.0, 2.25, 3.9, 1.0, 1.3, yellow)
	for _, z in { 1.85, 2.1, 2.35, 2.6 } do -- engine vents on the hood top
		B.box(0.6, 3.52, z, 2.0, 0.06, 0.12, dark, nil, 0.02)
	end
	B.box(0, 2.55, 0.35, 3.7, 0.12, 3.0, dark)
	B.box(0, 3.15, -1.85, 3.9, 1.3, 0.9, yellow, CF.Angles(rad(15), 0, 0))

	-- Seats: base, back, headrest. Blue driver left (-X), red operator right (+X).
	for _, s in { { -0.95, blue }, { 0.95, red } } do
		local back = CF.new(s[1], 3.8, 1.55) * CF.Angles(rad(12), 0, 0)
		B.box(s[1], 2.78, 0.75, 1.6, 0.3, 1.5, dark) -- seat pan
		B.box(s[1], 3.0, 0.72, 1.4, 0.26, 1.3, s[2], nil, 0.12) -- cushion, inset in the pan
		B.S:bevelBox(back, V3.new(1.6, 1.55, 0.25), dark, 0.08) -- backrest shell
		B.S:bevelBox(back * CF.new(0, 0.02, -0.2), V3.new(1.4, 1.35, 0.22), s[2], 0.1) -- cushion
		B.S:bevelBox(back * CF.new(0, 1.05, -0.05), V3.new(0.9, 0.5, 0.3), s[2], 0.1) -- headrest
		B.box(s[1] + (s[1] < 0 and -0.72 or 0.72), 3.3, 0.85, 0.18, 0.18, 1.0, dark, nil, 0.04) -- armrest
	end
	-- Co-op stripes down each side, a boarding step and a grab handle.
	for _, s in { { -1, blue }, { 1, red } } do
		B.box(s[1] * 1.96, 1.95, 0.35, 0.08, 0.36, 2.6, s[2], nil, 0.03)
		B.box(s[1] * 2.15, 1.05, 0.4, 0.55, 0.16, 1.1, dark)
		B.box(s[1] * 1.95, 5.0, -1.25, 0.14, 1.4, 0.14, black, CF.Angles(rad(15), 0, 0), 0.03)
	end

	-- Overhead guard: front posts lean back 15°, rear posts straight up off the hood.
	local postLen = 4.7
	for _, x in { -1.85, 1.85 } do
		B.box(x, 2.5 + postLen / 2, -1.65 + math.tan(rad(15)) * postLen / 2, 0.3, postLen / math.cos(rad(15)), 0.3, black, CF.Angles(rad(15), 0, 0))
		B.box(x, 5.1, 2.65, 0.3, 3.6, 0.3, black)
		B.box(x, 7.15, 1.05, 0.32, 0.3, 3.6, dark)
	end
	for _, z in { -0.45, 0.35, 1.15, 1.95, 2.65 } do
		B.box(0, 7.17, z, 3.7, 0.22, 0.3, dark)
	end
	-- Work lights on the front roof corners, headlights on the posts, beacon at the back.
	for _, x in { -1.85, 1.85 } do
		B.box(x, 7.45, -0.45, 0.45, 0.35, 0.35, dark)
		B.box(x, 7.45, -0.66, 0.36, 0.26, 0.08, lamp, nil, 0.02)
		B.box(x, 4.2, -1.55, 0.5, 0.5, 0.3, dark)
		B.box(x, 4.2, -1.71, 0.36, 0.36, 0.06, lamp, nil, 0.03)
	end
	B.box(1.35, 7.42, 2.45, 0.6, 0.28, 0.6, dark)
	B.box(1.35, 7.8, 2.45, 0.45, 0.5, 0.45, amber)
	-- Exhaust stack behind the rear post.
	B.box(-1.55, 4.0, 3.0, 0.24, 1.3, 0.24, black)

	-- Outer mast (fixed to the body), with tilt cylinders down to the chassis.
	for _, x in { -1.35, 1.35 } do
		-- channel section: two flanges and a web, so the rail has a shadowed inside
		B.box(x - 0.14, 3.95, -3.2, 0.14, 6.9, 0.5, steel, nil, 0.04)
		B.box(x + 0.14, 3.95, -3.2, 0.14, 6.9, 0.5, steel, nil, 0.04)
		B.box(x, 3.95, -2.99, 0.42, 6.9, 0.1, steel, nil, 0.03)
		B.box(x * 1.2, 2.2, -2.75, 0.22, 0.22, 1.0, dark, CF.Angles(rad(-20), 0, 0), 0.04)
	end
	B.box(0, 7.3, -3.2, 3.1, 0.35, 0.5, steel)
	B.box(0, 1.05, -3.2, 3.1, 0.4, 0.5, steel)

	-- Inner mast (slides up inside the outer one): rails, top tie, lift cylinder, chains.
	local M = kit(part("InnerMast"))
	for _, x in { -0.95, 0.95 } do
		M.box(x, 4.05, -3.32, 0.3, 6.5, 0.4, steel)
		M.box(x * 0.6, 4.0, -3.12, 0.12, 5.4, 0.1, black, nil, 0.02)
	end
	M.box(0, 7.15, -3.32, 2.2, 0.3, 0.42, steel)
	M.box(0, 3.6, -3.05, 0.34, 5.2, 0.34, dark)

	-- Carriage + forks (lift together): plate, barred backrest, L-shaped forks.
	local F = kit(part("Forks"))
	F.box(0, 1.35, -3.62, 3.0, 1.0, 0.25, dark)
	F.box(0, 3.75, -3.62, 3.0, 0.2, 0.2, dark)
	for _, x in { -1.4, -0.7, 0, 0.7, 1.4 } do
		F.box(x, 2.8, -3.62, 0.16, 1.9, 0.14, dark, nil, 0.03)
	end
	for _, x in { -0.9, 0.9 } do
		F.box(x, 1.25, -3.86, 0.45, 1.5, 0.24, black)
		F.box(x, 0.48, -3.95, 0.45, 0.4, 0.45, black, nil, 0.06)
		F.box(x, 0.42, -5.85, 0.45, 0.2, 3.6, black, nil, 0.05)
		F.box(x, 0.38, -7.85, 0.45, 0.12, 0.45, black, nil, 0.03)
	end

	-- Driver: steering column and wheel, tilted toward the driver.
	local col = CF.new(-0.95, 3.6, -1.55) * CF.Angles(rad(35), 0, 0)
	B.S:bevelBox(col * CF.new(0, 0.42, 0), V3.new(0.24, 0.84, 0.24), black, 0.05)
	local SW = kit(part("SteeringWheel"))
	local hub = col * CF.new(0, 0.92, 0)
	local ring, rr = {}, {}
	for i = 0, 18 do
		local a = i / 18 * math.pi * 2
		table.insert(ring, hub * V3.new(math.cos(a) * 0.6, 0, math.sin(a) * 0.6))
		table.insert(rr, 0.1)
	end
	SW.S:tube(ring, rr, 6, black)
	SW.S:bevelBox(hub, V3.new(1.1, 0.12, 0.18), black, 0.03)
	SW.S:bevelBox(hub * CF.new(0.42, 0.08, 0.2), V3.new(0.16, 0.2, 0.16), red, 0.04) -- spinner knob

	-- Dash gauge pod in front of the driver.
	B.box(-0.95, 3.85, -1.95, 0.9, 0.35, 0.3, dark)
	B.box(-1.15, 3.88, -1.79, 0.22, 0.22, 0.04, lamp, nil, 0.02)
	B.box(-0.75, 3.88, -1.79, 0.22, 0.22, 0.04, C3.fromRGB(110, 220, 120), nil, 0.02)

	-- Operator: lever console with three coloured knobs (lift, tilt, side-shift).
	B.box(0.95, 3.82, -1.6, 1.5, 0.3, 0.6, dark)
	local L = kit(part("Levers"))
	for i, knob in { red, C3.fromRGB(80, 200, 90), C3.fromRGB(255, 210, 60) } do
		local x = 0.5 + (i - 1) * 0.45
		local lever = CF.new(x, 3.97, -1.55) * CF.Angles(rad(i == 2 and -20 or 15), 0, 0)
		L.S:bevelBox(lever * CF.new(0, 0.35, 0), V3.new(0.12, 0.7, 0.12), black, 0.03)
		L.S:bevelBox(lever * CF.new(0, 0.78, 0), V3.new(0.28, 0.28, 0.28), knob, 0.07)
	end

	-- Camo paint: small flat plates just proud of the body panels (only for camo schemes).
	if paint.camo then
		local cd, cl = rgb(paint.camo[1]), rgb(paint.camo[2])
		for _, sx in { -1, 1 } do
			local a, b = cd, cl
			if sx > 0 then
				a, b = cl, cd
			end
			local dz = sx * 0.15
			-- chassis side, kept clear of the co-op stripe band (y 1.77..2.13)
			for _, p in { { 1.45, -0.6, 0.3, 0.7, a }, { 2.3, 0.9, 0.18, 0.9, b }, { 1.4, 1.35, 0.32, 0.6, b },
				{ 2.28, -0.4, 0.14, 0.5, a }, { 1.5, 0.4, 0.2, 0.45, a } } do
				B.S:box(CF.new(sx * 1.965, p[1], p[2] + dz), V3.new(0.04, p[3], p[4]), p[5])
			end
			-- counterweight side
			for _, p in { { 2.45, 3.35, 0.5, 0.6, a }, { 1.55, 3.75, 0.4, 0.5, b }, { 2.75, 4.35, 0.3, 0.45, b },
				{ 1.4, 3.05, 0.25, 0.35, a } } do
				B.S:box(CF.new(sx * 2.165, p[1], p[2] - dz), V3.new(0.04, p[3], p[4]), p[5])
			end
			-- hood side + fender top
			B.S:box(CF.new(sx * 1.965, 3.05, 2.2 + dz), V3.new(0.04, 0.4, 0.55), b)
			B.S:box(CF.new(sx * 2.3 + 0.15, 2.755, -2.4 + dz), V3.new(0.5, 0.03, 0.6), a)
			B.S:box(CF.new(sx * 2.3 - 0.2, 2.755, -1.85), V3.new(0.35, 0.03, 0.3), b)
		end
		-- hood top (left of the vents)
		B.S:box(CF.new(-1.25, 3.515, 2.0), V3.new(0.7, 0.03, 0.5), cd)
		B.S:box(CF.new(-0.9, 3.515, 2.6), V3.new(0.4, 0.03, 0.3), cl)
	end
	Shapes.finishBake(lib)
end
