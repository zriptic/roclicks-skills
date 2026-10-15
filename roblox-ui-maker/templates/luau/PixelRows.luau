--!strict
-- PixelRows: size ScrollingFrame rows in PIXELS worked out from the list's own height.
-- Inside a ScrollingFrame, a child's Scale size resolves against the CANVAS. With
-- AutomaticCanvasSize the canvas is measured from the children, so Scale rows and the canvas define
-- each other: rows collapse (scale*count < 1), explode (> 1, seen at 112 million px), or settle at
-- an arbitrary size. Pixel rows break the loop; AutomaticCanvasSize then just follows content.

local PixelRows = {}

-- list: the ScrollingFrame. visible: how many rows should fit in the window. gap: px between rows.
function PixelRows.bind(list: ScrollingFrame, visible: number, gap: number): () -> ()
	local layout = list:FindFirstChildOfClass("UIListLayout") or Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, gap) -- Offset, never Scale, for the same reason as the rows
	layout.Parent = list

	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new(0, 0, 0, 0)

	local function apply()
		local h = list.AbsoluteSize.Y
		if h <= 0 then return end
		local rowH = math.floor((h - gap * (visible - 1)) / visible)
		for _, row in list:GetChildren() do
			if row:IsA("GuiObject") then
				row.Size = UDim2.new(1, -list.ScrollBarThickness, 0, rowH)
			end
		end
	end

	local conns = {
		list:GetPropertyChangedSignal("AbsoluteSize"):Connect(apply), -- still adapts to screen size
		list.ChildAdded:Connect(function() task.defer(apply) end),
	}
	apply()
	return function()
		for _, c in conns do c:Disconnect() end
	end
end

-- Audit any pasted UI kit: flags Scale-sized rows inside ScrollingFrames and Scale CanvasSize.
function PixelRows.audit(root: Instance): { string }
	local out = {}
	for _, d in root:GetDescendants() do
		if d:IsA("ScrollingFrame") then
			if d.CanvasSize.Y.Scale > 1.01 then
				table.insert(out, d:GetFullName() .. ": CanvasSize.Y.Scale = " .. d.CanvasSize.Y.Scale)
			end
			for _, c in d:GetChildren() do
				if c:IsA("GuiObject") and c.Size.Y.Scale > 0 then
					table.insert(out, c:GetFullName() .. ": row height is Scale " .. c.Size.Y.Scale)
					break
				end
			end
		end
	end
	return out
end

return PixelRows
