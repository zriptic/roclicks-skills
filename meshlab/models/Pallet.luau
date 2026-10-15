--!nocheck
-- Wooden pallet sized for the Forklift's tines (openings face ±Z). Base on Y = 0.
return function(em, lib, Shapes)
	Shapes.beginBake()
	local S = Shapes.new(em, lib)
	Shapes.Props.pallet(S, lib, lib.CFrame.new())
	Shapes.finishBake(lib)
end
