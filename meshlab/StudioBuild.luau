--!nocheck
-- Studio side: runs the same model function on real EditableMeshes and returns a Model.
-- Put this, Shapes, Voxel and the model modules in ReplicatedStorage.MeshLab, then:
--   local model = require(RS.MeshLab.StudioBuild)(require(RS.MeshLab.models.Forklift), "Forklift", seed)
--   model.Parent = workspace
-- Every part("Name") the model asks for becomes its own MeshPart (so forks, wheels, steering
-- can move); the main mesh is "Body". Each mesh is recentred on its bounds and the MeshPart
-- placed back where the model put it, so model space = world space at the origin.
-- EditableMesh content is not saved with the place: build at runtime (server), and turn on
-- Game Settings > Security > "Allow Mesh & Image APIs" for published games.
-- NOT YET RUN IN LIVE STUDIO: verify on first use.

local AssetService = game:GetService("AssetService")
local Shapes = require(script.Parent.Shapes)
Shapes.Voxel = require(script.Parent.Voxel)
Shapes.Props = require(script.Parent.Props)
Shapes.Organic = require(script.Parent.Organic)

local function toPart(em, partName)
	local ids = em:GetVertices()
	if #ids == 0 then
		return nil
	end
	local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, id in ids do
		local p = em:GetPosition(id)
		lo, hi = lo:Min(p), hi:Max(p)
	end
	local center = (lo + hi) / 2
	for _, id in ids do
		em:SetPosition(id, em:GetPosition(id) - center)
	end
	local part = AssetService:CreateMeshPartAsync(Content.fromObject(em))
	part.Name = partName
	part.Anchored = true
	part.CFrame = CFrame.new(center)
	return part
end

return function(build, name, seed)
	local model = Instance.new("Model")
	model.Name = name or "MeshLabModel"
	local body = AssetService:CreateEditableMesh()
	local parts, order = {}, {}
	local function part(partName)
		if not parts[partName] then
			parts[partName] = AssetService:CreateEditableMesh()
			table.insert(order, partName)
		end
		return parts[partName]
	end
	build(body, { Vector3 = Vector3, Vector2 = Vector2, Color3 = Color3, CFrame = CFrame, seed = seed }, Shapes, part)
	local main = toPart(body, "Body")
	if main then
		main.Parent = model
	end
	for _, partName in order do
		local p = toPart(parts[partName], partName)
		if p then
			p.Parent = model
		end
	end
	-- Pivot at the model-space origin (ground level, centre), not at the Body's bounds
	-- centre, so model:PivotTo(cf) stands the model on cf like the Lune preview.
	model.WorldPivot = CFrame.new()
	return model
end
