--!nocheck
-- Shared prop builders, so models can reuse each other
-- (a pallet load is a pallet + boxes, a rack shows pallets...). Reached as Shapes.Props.
-- Sizes are set against the Forklift model: fork tines at X = ±0.9, 0.45 wide, top at 0.52.

local Props = {}

local function rgb(lib, r, g, b)
	return lib.Color3.fromRGB(r, g, b)
end

-- Cylinder standing on cf (base at cf, up along cf's Y), chamfered top and bottom rims.
function Props.cyl(S, cf, r, h, color, segs, chamfer)
	local c = math.min(chamfer or 0.08, r * 0.3, h * 0.3)
	S:lathe(cf, { { 0, 0 }, { r - c, 0 }, { r, c }, { r, h - c }, { r - c, h }, { 0, h } }, segs or 16, color)
end

-- Euro-ish pallet, 3.4 (X) x 3.0 (Z) x 0.85 tall, standing on cf. Openings face ±Z and sit
-- around X = ±0.75 (0.6 tall), so the forklift's tines slide straight in.
function Props.pallet(S, lib, cf)
	local V3, CF = lib.Vector3, lib.CFrame
	local wood = rgb(lib, 214, 168, 108)
	local woodDark = rgb(lib, 184, 134, 82)
	local woodEnd = rgb(lib, 160, 112, 66)
	local function box(x, y, z, sx, sy, sz, col)
		S:bevelBox(cf * CF.new(x, y, z), V3.new(sx, sy, sz), col, 0.04)
	end
	-- bottom boards (along X) at front, middle, back
	for _, z in { -1.3, 0, 1.3 } do
		box(0, 0.06, z, 3.4, 0.12, 0.4, woodDark)
	end
	-- three blocks per runner, three runners (the fork openings sit between them)
	for _, x in { -1.5, 0, 1.5 } do
		for _, z in { -1.3, 0, 1.3 } do
			box(x, 0.42, z, 0.4, 0.6, 0.4, woodEnd)
		end
		box(x, 0.785, 0, 0.4, 0.13, 3.0, woodDark) -- stringer board on top of the blocks
	end
	-- top deck boards (along Z), alternating shade
	for i = 0, 6 do
		local x = -1.5 + i * 0.5
		box(x, 0.915, 0, 0.42, 0.13, 3.0, i % 2 == 0 and wood or woodDark)
	end
end

-- Cardboard box with a tape strip over the top and a "this way up" label.
function Props.carton(S, lib, cf, size)
	local V3, CF = lib.Vector3, lib.CFrame
	local card = rgb(lib, 206, 160, 104)
	S:bevelBox(cf * CF.new(0, size.Y / 2, 0), size, card, 0.06)
	S:bevelBox(cf * CF.new(0, size.Y + 0.005, 0), V3.new(0.3, 0.03, size.Z + 0.02), rgb(lib, 232, 212, 160), 0.01)
	S:bevelBox(cf * CF.new(0, size.Y * 0.62, -size.Z / 2 - 0.02), V3.new(size.X * 0.4, size.Y * 0.28, 0.04), rgb(lib, 244, 244, 238), 0.02)
	S:bevelBox(cf * CF.new(0, size.Y * 0.62, -size.Z / 2 - 0.045), V3.new(0.12, size.Y * 0.18, 0.02), rgb(lib, 220, 60, 50), 0.01)
end

-- Deterministic random for seeded variations (Lune has no Random datatype):
--   local rand = Props.rng(lib.seed)   rand(a, b) -> number in [a, b)
function Props.rng(seed)
	local state = ((seed or 1) * 7919 + 13) % 2147483648
	return function(a, b)
		state = (state * 1103515245 + 12345) % 2147483648
		return a + (b - a) * (state / 2147483648)
	end
end

-- CFrame at `pos` whose LookVector is the unit direction `d`. Built from the rotation matrix
-- because Lune 0.10.5's CFrame.lookAt is wrong for any direction with a Z component (only
-- +-X comes out right); Studio's is fine, and this gives the same answer in both.
function Props.lookAt(lib, pos, d)
	local V3 = lib.Vector3
	local up = V3.new(0, 1, 0)
	if math.abs(d:Dot(up)) > 0.999 then
		up = V3.new(1, 0, 0)
	end
	local right = d:Cross(up).Unit
	local u = right:Cross(d).Unit
	local b = -d
	return lib.CFrame.new(pos.X, pos.Y, pos.Z, right.X, u.X, b.X, right.Y, u.Y, b.Y, right.Z, u.Z, b.Z)
end

-- A straight limb segment from p along direction d (unit), length len, square section t.
-- Returns the far end. Sharp box, so it reads as stacked studded blocks.
function Props.limb(S, lib, p, d, len, t, color)
	local CF, V3 = lib.CFrame, lib.Vector3
	local mid = p + d * (len / 2)
	S:bevelBox(Props.lookAt(lib, mid, d), V3.new(t, t, len), color, 0)
	return p + d * len
end

-- Unit direction from a yaw (radians, around Y) and an elevation above horizontal.
function Props.dir(lib, yaw, elev)
	return lib.Vector3.new(math.cos(elev) * math.sin(yaw), math.sin(elev), math.cos(elev) * math.cos(yaw))
end

return Props
