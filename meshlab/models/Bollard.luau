--!nocheck
-- Safety bollard: yellow steel post with black hazard bands on a bolted base plate.
return function(em, lib, Shapes)
	local V3, CF, C3 = lib.Vector3, lib.CFrame, lib.Color3
	Shapes.beginBake()
	local S = Shapes.new(em, lib)
	local yellow, black, steel = C3.fromRGB(255, 200, 40), C3.fromRGB(36, 38, 44), C3.fromRGB(150, 156, 168)
	S:bevelBox(CF.new(0, 0.08, 0), V3.new(1.3, 0.16, 1.3), steel, 0.05)
	for _, a in { { -1, -1 }, { -1, 1 }, { 1, -1 }, { 1, 1 } } do
		Shapes.Props.cyl(S, CF.new(a[1] * 0.48, 0.16, a[2] * 0.48), 0.09, 0.08, black, 6)
	end
	local r = 0.42
	local prof = { { 0, 0.16 }, { r, 0.16 } }
	for i = 1, 8 do
		table.insert(prof, { r, 0.16 + i * 0.4 })
	end
	table.insert(prof, { r - 0.1, 3.42 })
	table.insert(prof, { 0, 3.46 })
	S:lathe(CF.new(), prof, 16, function(ring)
		return (ring == 7 or ring == 8) and black or yellow
	end)
	Shapes.finishBake(lib)
end
