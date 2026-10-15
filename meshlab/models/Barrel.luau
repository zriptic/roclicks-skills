--!nocheck
-- Steel oil drum: blue body with two rolling hoops, darker lid rim, a bung cap on top.
return function(em, lib, Shapes)
	local CF, C3 = lib.CFrame, lib.Color3
	Shapes.beginBake()
	local S = Shapes.new(em, lib)
	local blue, hoop, lid = C3.fromRGB(46, 110, 200), C3.fromRGB(34, 80, 156), C3.fromRGB(150, 156, 168)
	local r = 1.0
	local prof = {
		{ 0, 0 }, { r - 0.1, 0 }, { r, 0.1 }, { r, 0.95 }, { r + 0.05, 1.0 }, { r + 0.05, 1.12 }, { r, 1.17 },
		{ r, 2.13 }, { r + 0.05, 2.18 }, { r + 0.05, 2.3 }, { r, 2.35 }, { r, 3.1 }, { r + 0.03, 3.15 }, { r - 0.08, 3.2 },
		{ r - 0.12, 3.12 }, { 0, 3.12 },
	}
	S:lathe(CF.new(), prof, 20, function(ring)
		if ring >= 13 then return lid end
		if (ring >= 4 and ring <= 6) or (ring >= 8 and ring <= 10) then return hoop end
		return blue
	end)
	Shapes.Props.cyl(S, CF.new(0.45, 3.12, 0.2), 0.16, 0.1, lid, 8)
	Shapes.finishBake(lib)
end
