-- First-session rules (decision 100, docs/design/ONBOARDING.md). Pure and Lune-tested: step order, the welcome and
-- first-win Kiln picks (never a glassy the player owns) and the assisted first match plan.
local Shared = if script then game.ReplicatedStorage.Shared else nil
local Balance = if Shared then require(Shared.Config.Balance) else require("../../shared/Config/Balance")
local Glassies = if Shared then require(Shared.Config.Glassies) else require("../../shared/Config/Glassies")
local Rules = {}
local O = Balance.Onboarding

-- Welcome (3 free opens) -> Daily (claim day 1) -> Arena (reach the reserved arena) -> Match (assisted first match)
-- -> Win (a claim card with the free Kiln open; picked and granted when they press OPEN) -> Done.
Rules.Steps = { "Welcome", "Daily", "Arena", "Match", "Win", "Done" }

function Rules.index(step)
	return table.find(Rules.Steps, step) or #Rules.Steps
end

-- A brand-new profile starts at Welcome; anyone who has played (or had the old welcome pull) is done.
function Rules.initial(data)
	local played = (data.Stats and (data.Stats.MatchWins or 0) + (data.Stats.MatchLosses or 0) or 0) > 0
	return if played or (data.Flags and data.Flags.WelcomePullUsed) then "Done" else "Welcome"
end

local function shuffle(list, rng)
	for i = #list, 2, -1 do
		local j = math.floor(rng() * i) + 1
		list[i], list[j] = list[j], list[i]
	end
	return list
end

-- Unowned Kiln glassies by rarity. `available` = { [id] = true } (KilnService:Pool()).
local function candidates(owned, available, rarity, exclude)
	local out = {}
	for id in available do
		local def = Glassies.ById[id]
		if def and def.Rarity == rarity and not owned[id] and not (exclude and exclude[id]) then
			table.insert(out, id)
		end
	end
	table.sort(out) -- deterministic for a given rng
	return out
end

-- The 3 welcome opens: one per rarity in O.WelcomeRarities, each a different type when the pool allows, none owned
-- and no repeats. Falls back gracefully (any type, then any unowned Kiln glassy) so it always returns up to 3.
function Rules.welcomePicks(owned, available, rng)
	local picks, chosen, types = {}, {}, {}
	for _, rarity in O.WelcomeRarities do
		local pool = shuffle(candidates(owned, available, rarity, chosen), rng)
		local pick
		for _, id in pool do
			if not types[Glassies.ById[id].Type] then
				pick = id
				break
			end
		end
		pick = pick or pool[1]
		if not pick then
			-- No unowned glassy of this rarity left: take any unowned Kiln glassy.
			local any = {}
			for id in available do
				if not owned[id] and not chosen[id] then
					table.insert(any, id)
				end
			end
			table.sort(any)
			pick = any[math.floor(rng() * #any) + 1]
		end
		if pick then
			chosen[pick] = true
			types[Glassies.ById[pick].Type] = true
			table.insert(picks, pick)
		end
	end
	return picks
end

-- The first-win open: rarity by O.WinPullOdds, never owned; if that rarity is all owned, the other one; then any.
function Rules.winPick(owned, available, rng)
	local roll, acc, order = rng(), 0, {}
	for _, rarity in { "Rare", "Epic" } do
		acc += O.WinPullOdds[rarity] or 0
		table.insert(order, { Rarity = rarity, Hit = roll < acc })
	end
	table.sort(order, function(a, b)
		return a.Hit and not b.Hit
	end)
	for _, entry in order do
		local pool = candidates(owned, available, entry.Rarity)
		if #pool > 0 then
			return pool[math.floor(rng() * #pool) + 1]
		end
	end
	local any = {}
	for id in available do
		if not owned[id] then
			table.insert(any, id)
		end
	end
	table.sort(any)
	return any[math.floor(rng() * #any) + 1]
end

-- The tutorial funnel (AnalyticsService onboarding funnel; logged on the server, once per player, in order) runs from
-- joining to the end of the second match. Every step is one all new players pass through; optional actions (a manual
-- CAST, rerolls) stay out so the drop-off between steps means friction. `Event` is what services report.
Rules.Funnel = {
	{ Name = "Joined", Event = "Joined" },
	{ Name = "Welcome Opened", Event = "WelcomeOpened" },
	{ Name = "Welcome Collected", Event = "Collected" },
	{ Name = "Daily Claimed", Event = "DailyClaimed" },
	{ Name = "First Match Started", Event = "FirstMatchStarted" },
	{ Name = "First Fight Started", Event = "FirstFightStarted" },
	{ Name = "First Round Finished", Event = "FirstRoundFinished" },
	{ Name = "First Match Won", Event = "FirstMatchWon" },
	{ Name = "Win Prize Opened", Event = "WinOpened" },
	{ Name = "Win Prize Collected", Event = "Collected" },
	{ Name = "Second Match Started", Event = "SecondMatchStarted" },
	{ Name = "Second Match Finished", Event = "SecondMatchFinished" },
}

-- The funnel step `event` completes for a player whose last logged step is `progress` (0 = none): the first later step
-- with that event, or nil (already logged, or not part of the funnel). A later step may skip a missed one (a dropped
-- client signal); Roblox then counts the skipped steps as done.
function Rules.funnelStep(progress, event)
	for index = progress + 1, #Rules.Funnel do
		if Rules.Funnel[index].Event == event then
			return index
		end
	end
	return nil
end

-- Odds shown before the opens (never the normal Kiln odds for a shaped pull).
function Rules.welcomeOddsText()
	return "1 COMMON · 1 UNCOMMON · 1 RARE (100%)"
end

function Rules.winOddsText()
	return string.format(
		"RARE %d%% · EPIC %d%%",
		math.round(O.WinPullOdds.Rare * 100),
		math.round(O.WinPullOdds.Epic * 100)
	)
end

-- The assisted first match: the player wins every round except O.BotRound (3-1). Returns the FightRules setup
-- `Assist` for `round`, where `human` is the player's side.
function Rules.assist(round, human)
	local winner = if round == O.BotRound then 3 - human else human
	local taken = { [winner] = O.WinnerTaken, [3 - winner] = O.LoserTaken }
	return { Protect = winner, Taken = taken, Winner = winner, CastSeconds = { [human] = O.CastSeconds } }
end

return Rules
