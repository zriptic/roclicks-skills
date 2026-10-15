--!strict
-- CrateRoll: decide the prize on the SERVER (weights + pity), then build a cosmetic reel plan on
-- the client around that known prize. The near-miss only exists in the reel strip; it never
-- changes the odds. Share the CRATES config with the odds popup so the popup can't lie.

local CrateRoll = {}

-- Shared config (ReplicatedStorage). The odds popup renders straight from this table.
CrateRoll.CRATES = {
	Basic = {
		weights = { Common = 55, Rare = 30, Epic = 12, Legendary = 3 }, -- SAME table as the odds popup (templates/examples/build.py REWARDS)
		pity = { atLeast = "Epic", within = 20 }, -- guaranteed Epic+ within 20 opens (the popup says so)
		prizes = {
			Common = { "CoinPouch", "CoinBag" }, Rare = { "CashMedium", "Boost15" },
			Epic = { "GemSack" }, Legendary = { "GoldenTrophy" },
		},
	},
}
CrateRoll.ORDER = { "Common", "Rare", "Epic", "Legendary" }

local function rank(r: string): number
	return table.find(CrateRoll.ORDER, r) or 1
end

local function weighted(rng: Random, weights: { [string]: number }, minRank: number): string
	local total = 0
	for r, w in weights do
		if rank(r) >= minRank then total += w end
	end
	local x = rng:NextNumber() * total
	for _, r in CrateRoll.ORDER do
		local w = weights[r]
		if w and rank(r) >= minRank then
			x -= w
			if x <= 0 then return r end
		end
	end
	return CrateRoll.ORDER[#CrateRoll.ORDER]
end

-- SERVER: call after charging the price. `pityCount` is saved per player per crate and survives
-- prestige resets. Returns rarity, prize id and the new pity count. Grant through your normal paths.
function CrateRoll.roll(crateId: string, pityCount: number, rng: Random): (string, string, number)
	local c = CrateRoll.CRATES[crateId]
	local floor = 1
	if c.pity and pityCount + 1 >= c.pity.within then
		floor = rank(c.pity.atLeast) -- forced on the last open of the window
	end
	local rarity = weighted(rng, c.weights, floor)
	local pool = c.prizes[rarity]
	local prize = pool[rng:NextInteger(1, #pool)]
	local hit = c.pity and rank(rarity) >= rank(c.pity.atLeast)
	return rarity, prize, if hit then 0 else pityCount + 1
end

-- CLIENT: a reel strip with the prize at `landing` and a one-better near-miss right after it.
-- The reel eases past the prize toward the near-miss, then settles back onto the prize.
export type Tile = { rarity: string, prize: string }
function CrateRoll.reelPlan(crateId: string, rarity: string, prize: string, length: number?): ({ Tile }, number)
	local c = CrateRoll.CRATES[crateId]
	local n = length or 40
	local landing = n - 6
	local rng = Random.new()
	local strip: { Tile } = {}
	for i = 1, n do
		local r = weighted(rng, c.weights, 1) -- flavour only
		local pool = c.prizes[r]
		strip[i] = { rarity = r, prize = pool[rng:NextInteger(1, #pool)] }
	end
	strip[landing] = { rarity = rarity, prize = prize }
	-- near-miss: the next tile is one rarity better (or Epic when the prize is the top rarity)
	local better = if rank(rarity) < #CrateRoll.ORDER then CrateRoll.ORDER[rank(rarity) + 1] else CrateRoll.ORDER[#CrateRoll.ORDER - 1]
	local pool = c.prizes[better]
	strip[landing + 1] = { rarity = better, prize = pool[1] }
	return strip, landing
end

-- Reel motion: overshoot by ~0.35 tile toward the near-miss, then settle. tileW in px.
-- First spin ~5.2 s, later spins of a multi-open ~3.6 s. A tap jumps straight to the landing.
function CrateRoll.reelOffsets(landing: number, tileW: number): (number, number)
	local final = (landing - 1) * tileW
	return final + tileW * 0.35, final -- tween to the first with Quint Out, then Back Out to the second
end

-- Before sale: respect paid-random-item policy for this player.
--   local ok, info = pcall(PolicyService.GetPolicyInfoForPlayerAsync, PolicyService, player)
--   if not ok or info.ArePaidRandomItemsRestricted then -- hide paid crates / show a non-random offer
return CrateRoll
