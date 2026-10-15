--!strict
-- NextGoal: config-driven "Next goal" pill. An ordered list of rules; the first rule whose goal is
-- not yet met wins. Each rule returns what the pill shows and what a tap does.
-- Put this in ReplicatedStorage next to the shared formula/config modules, so the pill is computed
-- from the same numbers the server enforces.

export type Goal = {
	id: string,
	text: string,          -- "Get 700 Iron for Tier 3"
	have: number?,         -- progress, e.g. 420
	need: number?,         -- e.g. 700 (pill shows "420/700" + bar when both are set)
	ready: boolean?,       -- green READY style
	endsAt: number?,       -- countdown (os.time() seconds) for "Researching Tier 3 2:32"
	action: string,        -- what a tap does: "openResearch", "openWar", "openSell", "pulseProducer"
	arg: any?,             -- e.g. the research node id or the producer kind
}

export type Rule = (state: any, config: any) -> Goal?

local NextGoal = {}

-- Example rules for a tier-gated game (tiers unlock by conquests, resources, cash, then a research);
-- replace them with your game's progression. Each returns a Goal when it is the current blocker, else nil.
-- Order matters: it is the order a player should solve things in.
NextGoal.rules = {
	function(s, cfg): Goal?
		if s.research.active and s.research.active.isTierGate then
			return { id = "researching", text = "Researching Tier " .. s.tier + 1,
				endsAt = s.research.active.endsAt, action = "openResearch" }
		end
		return nil
	end,
	function(s, cfg): Goal?
		local gate = cfg.tiers[s.tier + 1]
		if not gate then return nil end
		local left = gate.conquests - s.conquests
		if left > 0 then
			return { id = "conquer", text = string.format("Conquer %d more", left),
				have = s.conquests, need = gate.conquests, action = "openWar" }
		end
		return nil
	end,
	function(s, cfg): Goal?
		local gate = cfg.tiers[s.tier + 1]
		if not gate then return nil end
		for res, amount in gate.resources do
			local have = s.resources[res] or 0
			if have < amount then
				return { id = "res_" .. res,
					text = string.format("Get %d %s for Tier %d", amount, cfg.names[res], s.tier + 1),
					have = have, need = amount, action = "pulseProducer", arg = res }
			end
		end
		if s.cash < gate.cash then
			return { id = "cash", text = string.format("Save $%d for Tier %d", gate.cash, s.tier + 1),
				have = s.cash, need = gate.cash, action = "openSell" }
		end
		if s.research.active then
			return { id = "labBusy", text = "Lab busy: finishes first",
				endsAt = s.research.active.endsAt, action = "openResearch" }
		end
		return { id = "ready", text = "Research Tier " .. s.tier + 1, ready = true,
			action = "openResearch", arg = gate.researchNode }
	end,
}

function NextGoal.resolve(state: any, config: any): Goal?
	if state.tutorialActive then
		return nil -- the tutorial card is the goal while it runs
	end
	for _, rule in NextGoal.rules do
		local g = rule(state, config)
		if g then return g end
	end
	return nil
end

-- Wire-up sketch (client):
--   local last
--   local function refresh()
--       local g = NextGoal.resolve(State.get(), Config)
--       local key = g and (g.id .. tostring(g.have) .. tostring(g.need)) or ""
--       if key == last then return end      -- update in place only when something changed
--       last = key
--       renderPill(g)                       -- your function: fills GoalText/GoalCount/GoalBar (PATTERNS.md), hides the Goal group when g is nil
--   end
--   State.changed:Connect(refresh)
--   Pill.Activated:Connect(function() local g = NextGoal.resolve(State.get(), Config)
--       if g then Actions[g.action](g.arg) end end)
--   (a separate 1 s loop only re-renders the countdown text when g.endsAt is set)

return NextGoal
