--!nocheck
-- Traffic cone: square black base, orange cone with two reflective white bands.
return function(em, lib, Shapes)
	local V3, CF, C3 = lib.Vector3, lib.CFrame, lib.Color3
	Shapes.beginBake()
	local S = Shapes.new(em, lib)
	local orange, white = C3.fromRGB(255, 110, 30), C3.fromRGB(240, 240, 236)
	S:bevelBox(CF.new(0, 0.1, 0), V3.new(1.6, 0.2, 1.6), C3.fromRGB(40, 40, 46), 0.06)
	local prof = { { 0, 0.2 }, { 0.62, 0.2 }, { 0.55, 0.6 }, { 0.47, 0.95 }, { 0.4, 1.3 }, { 0.32, 1.65 }, { 0.24, 2.0 }, { 0.14, 2.3 }, { 0.1, 2.38 }, { 0, 2.4 } }
	S:lathe(CF.new(), prof, 16, function(ring)
		return (ring == 3 or ring == 5) and white or orange
	end)
	Shapes.finishBake(lib)
end
