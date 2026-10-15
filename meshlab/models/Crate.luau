--!nocheck
-- Wooden shipping crate: plank panels, a darker frame on every edge, a diagonal brace per side.
return function(em, lib, Shapes)
	local V3, CF, C3 = lib.Vector3, lib.CFrame, lib.Color3
	Shapes.beginBake()
	local S = Shapes.new(em, lib)
	local s = 2.4
	local wood, frame, stencil = C3.fromRGB(206, 160, 98), C3.fromRGB(150, 104, 58), C3.fromRGB(60, 50, 40)
	local h = s / 2
	-- planked core: horizontal planks with alternating shade
	for i = 0, 5 do
		local y = 0.2 + i * 0.4
		S:bevelBox(CF.new(0, y, 0), V3.new(s - 0.1, 0.38, s - 0.1), i % 2 == 0 and wood or C3.fromRGB(196, 150, 90), 0.05)
	end
	-- frame on all 12 edges, proud of the planks
	local t = 0.3
	for _, a in { -1, 1 } do
		for _, b in { -1, 1 } do
			S:bevelBox(CF.new(a * (h - t / 2 + 0.02), h, b * (h - t / 2 + 0.02)), V3.new(t, s, t), frame, 0.05)
			S:bevelBox(CF.new(0, h + a * (h - t / 2 + 0.02), b * (h - t / 2 + 0.02)), V3.new(s, t, t), frame, 0.05)
			S:bevelBox(CF.new(a * (h - t / 2 + 0.02), h + b * (h - t / 2 + 0.02), 0), V3.new(t, t, s), frame, 0.05)
		end
	end
	-- diagonal brace on the four sides
	local len = math.sqrt(2) * (s - 2 * t)
	for i = 0, 3 do
		local yaw = CF.Angles(0, i * math.pi / 2, 0)
		S:bevelBox(yaw * CF.new(0, h, -(h - 0.02)) * CF.Angles(0, 0, math.rad(45)), V3.new(len, 0.28, 0.12), frame, 0.04)
	end
	-- "this side up" stencil arrows on the front
	S:bevelBox(CF.new(-0.55, h + 0.55, -h - 0.06), V3.new(0.12, 0.45, 0.03), stencil, 0.01)
	S:bevelBox(CF.new(-0.55, h + 0.82, -h - 0.06) * CF.Angles(0, 0, math.rad(45)), V3.new(0.26, 0.26, 0.03), stencil, 0.01)
	Shapes.finishBake(lib)
end
