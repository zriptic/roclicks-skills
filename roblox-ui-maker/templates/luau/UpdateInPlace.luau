--!strict
-- UpdateInPlace: refresh a list of rows without destroying them.
-- A panel that destroyed and re-cloned every row each second dropped any tap whose press and
-- release straddled the refresh (Activated needs both on the same instance), and reset hover/press
-- animations. Rows are now keyed: reused when the key set is unchanged, only labels update.

local UpdateInPlace = {}

export type Item = { key: string, locked: boolean?, [string]: any }

export type List = {
	container: GuiObject,
	template: GuiObject,
	fill: (row: GuiObject, item: Item) -> (),   -- set texts/colours/bars ONLY (no Instance.new)
	wire: (row: GuiObject, item: Item) -> (),   -- connect buttons ONCE per row; read item via row attribute
	rows: { [string]: GuiObject },
	signature: string,
}

function UpdateInPlace.new(container: GuiObject, template: GuiObject, fill, wire): List
	return { container = container, template = template, fill = fill, wire = wire, rows = {}, signature = "" }
end

local function sig(items: { Item }): string
	local parts = table.create(#items)
	for i, it in items do
		parts[i] = it.key .. (if it.locked then "#L" else "")
	end
	return table.concat(parts, "|")
end

function UpdateInPlace.render(list: List, items: { Item })
	local s = sig(items)
	if s ~= list.signature then
		-- the set changed: keep rows whose key survives, add new ones, drop the rest
		local keep = {}
		for i, it in items do
			local row = list.rows[it.key]
			if not row then
				row = list.template:Clone()
				row.Name = "Row_" .. it.key
				row:SetAttribute("Key", it.key)
				list.wire(row, it)
				row.Parent = list.container
			end
			row.LayoutOrder = i
			keep[it.key] = row
		end
		for key, row in list.rows do
			if not keep[key] then row:Destroy() end
		end
		list.rows = keep
		list.signature = s
	end
	-- every refresh: only cheap property writes
	for _, it in items do
		list.fill(list.rows[it.key], it)
	end
end

--[[ Usage
local sell = UpdateInPlace.new(panel.List, templates.SellRow,
	function(row, it)
		(row :: any).ItemName.Text = it.name
		(row :: any).Price.Text = NumberFormat.cash(it.price)
	end,
	function(row, it)
		local key = row:GetAttribute("Key")
		(row :: any).SellButton.Activated:Connect(function() Remotes.Sell:FireServer(key) end)
	end)

-- refresh only while visible, and only when state changes (plus a 1 s tick for timers)
State.changed:Connect(function()
	if panel.Visible then UpdateInPlace.render(sell, buildItems(State.get())) end
end)
]]

return UpdateInPlace
