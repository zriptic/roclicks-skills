--!strict
-- WorldHitTest: pick world things (name plates over BillboardGuis, then the world itself) by
-- hit-testing, because TextButtons inside BillboardGuis never got clicks while a full-screen HUD
-- ScreenGui sat above them. Works for mouse and touch with one code path.
--
-- All positions are GUI space (inset excluded), the same space as InputObject.Position.

local WorldHitTest = {}

export type Candidate = {
	id: any,
	anchor: BasePart | Attachment, -- what the billboard is adorned to
	pxSize: Vector2,               -- the plate's on-screen size in px (BillboardGui sized in pixels)
	studsOffset: Vector3?,         -- the billboard's StudsOffsetWorldSpace
}

local TOUCH = { minBox = 56, pad = 12, nearRadius = 34 }
local MOUSE = { minBox = 34, pad = 4, nearRadius = 16 }

local function isTouch(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.Touch
end

local function worldPos(c: Candidate): Vector3
	local p = if c.anchor:IsA("Attachment") then (c.anchor :: Attachment).WorldPosition else (c.anchor :: BasePart).Position
	return p + (c.studsOffset or Vector3.zero)
end

-- 1. plates: direct hit beats padded hit; nearest centre breaks ties
function WorldHitTest.pickPlate(pos: Vector2, candidates: { Candidate }, touch: boolean): Candidate?
	local cfg = if touch then TOUCH else MOUSE
	local cam = workspace.CurrentCamera
	local best, bestScore = nil, math.huge
	for _, c in candidates do
		local sp, onScreen = cam:WorldToScreenPoint(worldPos(c)) -- GUI space, like input.Position
		if onScreen then
			local centre = Vector2.new(sp.X, sp.Y)
			local half = Vector2.new(math.max(c.pxSize.X, cfg.minBox), math.max(c.pxSize.Y, cfg.minBox)) / 2
			local d = (pos - centre)
			local direct = math.abs(d.X) <= c.pxSize.X / 2 and math.abs(d.Y) <= c.pxSize.Y / 2
			local padded = math.abs(d.X) <= half.X + cfg.pad and math.abs(d.Y) <= half.Y + cfg.pad
			if padded then
				local score = d.Magnitude + (if direct then 0 else 10000) + sp.Z * 0.001
				if score < bestScore then
					best, bestScore = c, score
				end
			end
		end
	end
	return best
end

-- 2. the world under the point (ScreenPointToRay takes GUI-space coordinates; ViewportPointToRay
--    would be off by the 58 px inset)
function WorldHitTest.raycast(pos: Vector2, params: RaycastParams?): RaycastResult?
	local ray = workspace.CurrentCamera:ScreenPointToRay(pos.X, pos.Y)
	return workspace:Raycast(ray.Origin, ray.Direction * 5000, params)
end

-- Tap vs drag: call from InputBegan / InputEnded. Returns true when the release is a tap.
local press: { [InputObject]: { at: Vector2, t: number } } = {}
local touchesDown = 0
local multiTouch = false

function WorldHitTest.began(input: InputObject)
	if isTouch(input) then
		touchesDown += 1
		if touchesDown > 1 then multiTouch = true end
	end
	press[input] = { at = Vector2.new(input.Position.X, input.Position.Y), t = os.clock() }
end

function WorldHitTest.ended(input: InputObject, claimed: boolean): boolean
	local p = press[input]
	press[input] = nil
	local touch = isTouch(input)
	if touch then
		touchesDown = math.max(0, touchesDown - 1)
	end
	local wasMulti = multiTouch
	if touchesDown == 0 then multiTouch = false end
	if not p or claimed or wasMulti then return false end
	local cam = workspace.CurrentCamera
	local short = math.min(cam.ViewportSize.X, cam.ViewportSize.Y)
	local maxMove = if touch then math.max(14, short * 0.025) else 7
	local maxTime = if touch then 0.65 else 0.5
	local moved = (Vector2.new(input.Position.X, input.Position.Y) - p.at).Magnitude
	return moved <= maxMove and os.clock() - p.t <= maxTime
end

-- Example wiring:
--   UserInputService.InputBegan:Connect(function(i, gp) if not gp then WorldHitTest.began(i) end end)
--   UserInputService.InputEnded:Connect(function(i, gp)
--       if gp or not WorldHitTest.ended(i, CameraDrag.claimed()) then return end
--       local pos = Vector2.new(i.Position.X, i.Position.Y)
--       local plate = WorldHitTest.pickPlate(pos, Plates.visible(), i.UserInputType == Enum.UserInputType.Touch)
--       if plate then return open(plate.id) end
--       local hit = WorldHitTest.raycast(pos, worldParams)
--       if hit then return open(ownerOf(hit.Instance)) end
--   end)
-- Note: `gp` (gameProcessed) is true when a GUI button took the input, so HUD buttons still win.

return WorldHitTest
