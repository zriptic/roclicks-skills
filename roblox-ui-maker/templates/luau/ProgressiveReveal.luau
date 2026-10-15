--!strict
-- ProgressiveReveal: the HUD starts as cash + next goal and grows as the player meets each system.
-- ONE function decides visibility from state, so every screen agrees. Pieces that "stay once seen"
-- are remembered in the save (state.revealed), so a returning player isn't re-taught.

local ProgressiveReveal = {}

export type Rule = {
	name: string,              -- HUD element name
	sticky: boolean,           -- true: once shown, stays shown (saved); false: live condition
	when: (state: any) -> boolean,
}

-- Example rules. Replace the conditions with your game's state.
local RULES: { Rule } = {
-- Names are exported element names (name= in build.py). Example HUD: GemsIcon/GemsText, CratesButton, Goal.
	{ name = "GemsIcon", sticky = true, when = function(s) return (s.gems or 0) > 0 end },
	{ name = "GemsText", sticky = true, when = function(s) return (s.gems or 0) > 0 end },
	{ name = "CratesButton", sticky = true, when = function(s) return s.tutorialDone end },
	{ name = "BackpackFull", sticky = false, when = function(s) return s.items >= s.itemCap end },
	{ name = "EventTimer", sticky = false, when = function(s) return s.event ~= nil end },
}
ProgressiveReveal.rules = RULES

-- Returns { [name] = visible } and the list of names newly revealed (to save + celebrate).
function ProgressiveReveal.decide(state: any): ({ [string]: boolean }, { string })
	state.revealed = state.revealed or {}
	local out, newly = {}, {}
	for _, r in ProgressiveReveal.rules do
		local on = r.when(state)
		if r.sticky then
			if on and not state.revealed[r.name] then
				state.revealed[r.name] = true
				table.insert(newly, r.name)
			end
			on = state.revealed[r.name] == true
		end
		out[r.name] = on
	end
	return out, newly
end

-- Apply to a column/row of HUD pieces. Put a UIListLayout in the column so hidden rows
-- close up automatically (Visible=false children take no space in a UIListLayout).
function ProgressiveReveal.apply(hud: Instance, visible: { [string]: boolean })
	for name, on in visible do
		local el = hud:FindFirstChild(name, true) :: GuiObject?
		if el and el.Visible ~= on then
			el.Visible = on
		end
	end
end

return ProgressiveReveal
