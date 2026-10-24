--!strict
-- Match rules (GAME_DESIGN 2): 1v1, 3 hearts each, a roll of 3 glassies from your own collection
-- once per match, paid hand rerolls, round-only Pick Any, aim, and rewards. Pure: no Roblox APIs.
-- MatchService (server) owns the timers and calls these functions; FightRules runs each round.
--
--   local match = MatchLogic.new({ { Collection = profileA.Glassies }, { Collection = bot.Collection, IsBot = true, Skill = 0.4 } }, rng)
--   MatchLogic.startRound(match)               -- retains the match hand, rolls the sweet spot
--   MatchLogic.pick(match, 1, "pop")           -- from the remote (validated)
--   MatchLogic.reroll(match, 1)                -- after caller validates and charges rerollCost
--   MatchLogic.setAim(match, 1, 0.9, 0.2)      -- pull-back angle, sideways yaw
--   local setup = MatchLogic.fightSetup(match) -- pass to FightRules.new
--   MatchLogic.endRound(match, winnerSide)     -- returns true when the match is over
--   MatchLogic.rewards(match, side, ...)       -- coins and trophies for the results screen

local Balance = if script then require(script.Parent.Config.Balance) else require("./Config/Balance")
local Glassies = if script then require(script.Parent.Config.Glassies) else require("./Config/Glassies")
local FightRules = if script then require(script.Parent.FightRules) else require("./FightRules")
local ArenaRules = if script then require(script.Parent.ArenaRules) else require("./ArenaRules")

-- A player's collection: glassy id -> { Stars, Rainbow }. Short collections are topped up with Glassies.Fallback.
export type Owned = { Stars: number?, Rainbow: boolean? }
export type Collection = { [string]: Owned }

export type PlayerSetup = {
	Collection: Collection,
	IsBot: boolean?,
	Skill: number?, -- bots only, 0..1
	Hearts: number?, -- defaults to Balance.Match.Hearts (Crown Hill fights use 1, decision 105)
}

export type Side = {
	Collection: Collection,
	IsBot: boolean,
	Skill: number,
	Hearts: number,
	RoundsWon: number,
	RerollsUsed: number,
	PickAnyUsed: number,
	HandRevision: number,
	SelectionRevision: number,
	Offers: { string },
	Pick: string?,
	Aim: number?,
	AimYaw: number?,
	LastPick: string?,
	LastAim: number?, -- the next round's aim starts here (decision 122)
	LastYaw: number?,
	Streak: number, -- round wins in a row (On Fire)
}

export type Match = {
	Sides: { Side },
	Rng: () -> number,
	Round: number,
	SweetSpot: number?,
	Twist: string?, -- this round's arena twist (decision 122)
	Over: boolean,
	Winner: number?,
	History: { { Picks: { string }, Winner: number } },
}

local MatchLogic = {}
local B = Balance.Match

local function shuffle<T>(list: { T }, rng: () -> number)
	for i = #list, 2, -1 do
		local j = math.floor(rng() * i) + 1
		list[i], list[j] = list[j], list[i]
	end
end

-- Owned ids in a stable order (sorted) so rolls are deterministic for a given rng.
function MatchLogic.ownedIds(collection: Collection): { string }
	local ids = {}
	for id in collection do
		if Glassies.ById[id] then
			table.insert(ids, id)
		end
	end
	-- Fewer than a full roll owned (should not happen after the welcome opens): borrow the fallback hand.
	for _, id in Glassies.Fallback do
		if #ids >= Balance.Match.RollChoices then
			break
		end
		if not table.find(ids, id) then
			table.insert(ids, id)
		end
	end
	table.sort(ids)
	return ids
end

-- `count` different glassies from the collection, uniformly at random (all of them if fewer).
function MatchLogic.rollOffers(collection: Collection, count: number, rng: () -> number): { string }
	local ids = MatchLogic.ownedIds(collection)
	shuffle(ids, rng)
	local offers = {}
	for i = 1, math.min(count, #ids) do
		offers[i] = ids[i]
	end
	return offers
end

function MatchLogic.new(players: { PlayerSetup }, rng: () -> number): Match
	assert(#players == 2, "MatchLogic.new expects two players")
	local sides = {}
	for i, p in players do
		sides[i] = {
			Collection = p.Collection,
			IsBot = p.IsBot == true,
			Skill = p.Skill or 0,
			Hearts = p.Hearts or B.Hearts,
			RoundsWon = 0,
			RerollsUsed = 0,
			PickAnyUsed = 0,
			HandRevision = 0,
			SelectionRevision = 0,
			Offers = {},
			Pick = nil,
			Aim = nil,
			AimYaw = nil,
			LastPick = nil,
			Streak = 0,
		}
	end
	return { Sides = sides, Rng = rng, Round = 0, SweetSpot = nil, Over = false, Winner = nil, History = {} }
end

-- The hand survives every round; only picks/aim and the Perfect Release band reset.
function MatchLogic.startRound(match: Match)
	assert(not match.Over, "match is over")
	match.Round += 1
	for _, side in match.Sides do
		if #side.Offers == 0 then
			side.Offers = MatchLogic.rollOffers(side.Collection, B.RollChoices, match.Rng)
		end
		side.Pick = nil
		side.Aim = nil
		side.AimYaw = nil
	end
	match.SweetSpot = FightRules.rollSweetSpot(match.Rng)
	match.Twist = ArenaRules.rollTwist(match.Rng, match.Twist)
end

-- Rerolls ------------------------------------------------------------------------------------

-- Marbles the next reroll costs (0 = free).
function MatchLogic.rerollCost(rerollsUsed: number): number
	if rerollsUsed < B.FreeRerollsPerMatch then
		return 0
	end
	local paid = rerollsUsed - B.FreeRerollsPerMatch + 1
	local costs = B.RerollMarbleCosts
	return costs[math.min(paid, #costs)]
end

function MatchLogic.pickAnyCost(used: number): number
	if used < B.FreePickAnyPerMatch then
		return 0
	end
	local costs = B.PickAnyMarbleCosts
	return costs[math.min(used - B.FreePickAnyPerMatch + 1, #costs)]
end

function MatchLogic.canReroll(match: Match, sideIndex: number): (boolean, string?)
	local side = match.Sides[sideIndex]
	if not side or match.Over then
		return false, "invalid"
	end
	if side.Pick then
		return false, "picked"
	end
	if #MatchLogic.ownedIds(side.Collection) <= B.RollChoices then
		return false, "nothing_new"
	end
	return true
end

function MatchLogic.canPickAny(match: Match, sideIndex: number, id: any): (boolean, string?)
	local side = match.Sides[sideIndex]
	if not side or match.Over then
		return false, "invalid"
	end
	if side.Pick then
		return false, "picked"
	end
	if type(id) ~= "string" or side.Collection[id] == nil or not Glassies.ById[id] then
		return false, "not_owned"
	end
	return true
end

function MatchLogic.pickAny(match: Match, sideIndex: number, id: any): (boolean, string?)
	local ok, reason = MatchLogic.canPickAny(match, sideIndex, id)
	if not ok then
		return false, reason
	end
	local side = match.Sides[sideIndex]
	side.Pick = id
	side.PickAnyUsed += 1
	side.SelectionRevision += 1
	return true
end

-- Rerolls a side's offers. The caller checks and charges `cost` Marbles first (use
-- MatchLogic.rerollCost) and only calls this once the payment succeeded.
function MatchLogic.reroll(match: Match, sideIndex: number): (boolean, string?)
	local ok, reason = MatchLogic.canReroll(match, sideIndex)
	if not ok then
		return false, reason
	end
	local side = match.Sides[sideIndex]
	side.RerollsUsed += 1
	side.HandRevision += 1
	side.SelectionRevision += 1
	side.Offers = MatchLogic.rollOffers(side.Collection, B.RollChoices, match.Rng)
	return true
end

-- Picks and aim ------------------------------------------------------------------------------

function MatchLogic.pick(match: Match, sideIndex: number, id: any): (boolean, string?)
	local side = match.Sides[sideIndex]
	if not side or match.Over then
		return false, "invalid"
	end
	if side.Pick then
		return false, "picked"
	end
	if type(id) ~= "string" or not table.find(side.Offers, id) then
		return false, "not_offered"
	end
	side.Pick = id
	return true
end

-- When the roll timer runs out (or for bots). Bots with higher skill pick the offer with the
-- best type matchup against the opponent's last pick, then the strongest rarity.
function MatchLogic.autoPick(match: Match, sideIndex: number): string
	local side = match.Sides[sideIndex]
	if side.Pick then
		return side.Pick
	end
	-- A player who doesn't pick keeps last round's glassy when it is still in the hand (decision 122).
	local choice = if side.LastPick and table.find(side.Offers, side.LastPick) then side.LastPick else side.Offers[1]
	if side.IsBot and match.Rng() < side.Skill then
		local foeLast = match.Sides[3 - sideIndex].LastPick
		local foeType = if foeLast then Glassies.get(foeLast).Type else nil
		local bestScore = -math.huge
		for _, id in side.Offers do
			local def = Glassies.get(id)
			local score = Balance.Rarities[def.Rarity].StatMultiplier
			if foeType and Balance.Types.Beats[def.Type] == foeType then
				score += 0.5
			elseif foeType and Balance.Types.Beats[foeType] == def.Type then
				score -= 0.5
			end
			if score > bestScore then
				bestScore = score
				choice = id
			end
		end
	elseif side.IsBot then
		choice = side.Offers[math.floor(match.Rng() * #side.Offers) + 1]
	end
	side.Pick = choice
	return choice
end

-- aim = pull-back angle, yaw = sideways angle (both radians, clamped). Returns the clamped pair.
function MatchLogic.setAim(match: Match, sideIndex: number, aim: any, yaw: any): (number, number)
	local side = match.Sides[sideIndex]
	side.Aim = FightRules.clampAim(aim)
	side.AimYaw = FightRules.clampYaw(yaw)
	return side.Aim :: number, side.AimYaw :: number
end

-- Bots aim when the aim phase starts; players who never aimed keep last round's aim (AimDefault in round 1).
function MatchLogic.autoAim(match: Match, sideIndex: number): number
	local side = match.Sides[sideIndex]
	if side.Aim then
		return side.Aim
	end
	if side.IsBot and match.SweetSpot then
		side.Aim = FightRules.botAim(match.SweetSpot, side.Skill, match.Rng)
		side.AimYaw = FightRules.clampYaw((match.Rng() * 2 - 1) * Balance.Motion.AimYawMax)
	else
		side.Aim, side.AimYaw = MatchLogic.startAim(match, sideIndex)
	end
	return side.Aim :: number
end

-- Where a player's aim starts this round: last round's, or AimDefault.
function MatchLogic.startAim(match: Match, sideIndex: number): (number, number)
	local side = match.Sides[sideIndex]
	return side.LastAim or Balance.Motion.AimDefault, side.LastYaw or 0
end

-- Setup for FightRules.new. Both sides must have picked.
function MatchLogic.fightSetup(match: Match): FightRules.Setup
	local function fighter(i: number): FightRules.FighterSetup
		local side = match.Sides[i]
		local id = side.Pick or MatchLogic.autoPick(match, i)
		local owned = side.Collection[id] or {}
		return {
			Id = id,
			Stars = owned.Stars,
			Rainbow = owned.Rainbow,
			Aim = side.Aim or MatchLogic.autoAim(match, i),
			AimYaw = side.AimYaw or 0,
			-- Players press CAST (or it fires by itself); bots press with their skill (decision 85).
			CastPolicy = if side.IsBot then "bot" else "player",
			CastSkill = side.Skill,
			-- Decision 122: down to the last heart while the other side isn't, and two round wins in a row.
			LastGlass = side.Hearts == 1 and match.Sides[3 - i].Hearts > 1,
			OnFire = side.Streak >= Balance.Arena.OnFireStreak,
		}
	end
	return { A = fighter(1), B = fighter(2), Rng = match.Rng, SweetSpot = match.SweetSpot, Twist = match.Twist }
end

-- Round end ----------------------------------------------------------------------------------

-- The loser of the round loses a heart. Returns true when the match is over.
function MatchLogic.endRound(match: Match, winnerSide: number): boolean
	assert(winnerSide == 1 or winnerSide == 2, "winner must be 1 or 2")
	local loser = match.Sides[3 - winnerSide]
	local winner = match.Sides[winnerSide]
	loser.Hearts -= 1
	winner.RoundsWon += 1
	table.insert(match.History, {
		Picks = { match.Sides[1].Pick or "", match.Sides[2].Pick or "" },
		Winner = winnerSide,
	})
	for _, side in match.Sides do
		side.LastPick = side.Pick
		side.LastAim, side.LastYaw = side.Aim, side.AimYaw
	end
	winner.Streak += 1
	loser.Streak = 0
	if loser.Hearts <= 0 then
		match.Over = true
		match.Winner = winnerSide
	end
	return match.Over
end

-- Observed stats MatchService records per side (all optional; defaults come from `match`).
--   Hearts: hearts taken in completed fights; Chip: summed share of the winner's HP dealt in
--   rounds this side lost; Perfects: Perfect Releases; Forfeited: this side quit before the end
export type RewardStats = { Hearts: number?, Chip: number?, Perfects: number?, Forfeited: boolean? }

-- Coins for a loss, from performance only (capped well below a win).
function MatchLogic.lossCoins(hearts: number, chip: number, perfects: number): number
	local r = B.Rewards
	local coins = r.LossBaseCoins
		+ math.max(hearts, 0) * r.LossHeartCoins
		+ math.floor(math.max(chip, 0) * r.LossChipCoins + 0.5)
		+ math.max(perfects, 0) * r.LossPerfectCoins
	return math.min(r.LossMaxCoins, coins)
end

-- Rewards (GAME_DESIGN 8.1). `trophies` = the player's current trophies (never goes below 0).
function MatchLogic.rewards(
	match: Match,
	sideIndex: number,
	trophies: number?,
	eligible: boolean?,
	stats: RewardStats?
): { Coins: number, Trophies: number }
	-- MatchService supplies eligibility from observed completed fights, never forfeited hearts.
	if eligible == false then
		return { Coins = 0, Trophies = 0 }
	end
	local r = B.Rewards
	local side = match.Sides[sideIndex]
	local won = match.Winner == sideIndex
	local vsBot = match.Sides[3 - sideIndex].IsBot
	local coins = r.MatchWinCoins
	if not won then
		coins = if stats and stats.Forfeited
			then 0
			else MatchLogic.lossCoins(
				stats and stats.Hearts or side.RoundsWon,
				stats and stats.Chip or 0,
				stats and stats.Perfects or 0
			)
	end
	local delta = if won then r.WinTrophies else -r.LossTrophies
	if vsBot then
		delta = if won then r.BotWinTrophies else 0
	end
	if trophies then
		delta = math.max(delta, -trophies)
	end
	return { Coins = coins, Trophies = delta }
end

-- A bot's collection for a player: random glassies up to the player's best rarity, about the same size as the
-- player's collection (at least a full roll).
function MatchLogic.botCollection(playerCollection: Collection, rng: () -> number): Collection
	local best = 1
	local size = 0
	for id in playerCollection do
		local def = Glassies.ById[id]
		if def then
			size += 1
			best = math.max(best, Balance.Rarities[def.Rarity].Order)
		end
	end
	local pool = {}
	for _, def in Glassies.ReleaseList do
		local order = Balance.Rarities[def.Rarity].Order
		if order >= 1 and order <= best then
			table.insert(pool, def.Id)
		end
	end
	table.sort(pool)
	shuffle(pool, rng)
	local collection: Collection = {}
	for i = 1, math.min(math.max(size, Balance.Match.RollChoices), #pool) do
		collection[pool[i]] = {}
	end
	return collection
end

return MatchLogic
