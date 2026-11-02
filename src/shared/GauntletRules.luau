--!strict
-- Pure rules for the Gauntlet: smash a glassy to collect its shards, three hearts per run.
local G = if script then require(script.Parent.Config.Gauntlet) else require("./Config/Gauntlet")

local Rules = {}

function Rules.newCollection()
	return { Owned = { [G.Starter] = true }, Unlocked = 1, Shards = {}, Best = 0, Coins = 0, Runs = 0 }
end

function Rules.locked(collection): { string }
	local list = {}
	for _, id in G.Roster do
		if not collection.Owned[id] then
			table.insert(list, id)
		end
	end
	return list
end

function Rules.shardsNeeded(collection): number
	return G.ShardsNeeded[math.min(collection.Unlocked, #G.ShardsNeeded)]
end

function Rules.isBoss(rung: number): boolean
	return rung % G.BossEvery == 0
end

function Rules.isCounter(id: string, rival: string): boolean
	return G.Beats[G.Types[id]] == G.Types[rival]
end

-- Rivals are glassies you can still earn, so every fight visibly moves a goal. Even rungs chase the
-- closest unlock; odd rungs rotate for variety. Once everything is owned, any rival can appear.
function Rules.rivalFor(collection, rung: number, seed: number): string
	if collection.Runs <= 1 and rung == 1 and not collection.Owned[G.FirstRival] then
		return G.FirstRival
	end
	local pool = Rules.locked(collection)
	if #pool == 0 then
		pool = G.Roster
	end
	if rung % 2 == 0 then
		local best, bestShards = nil, 0
		for _, id in pool do
			local shards = collection.Shards[id] or 0
			if shards > bestShards then
				best, bestShards = id, shards
			end
		end
		if best then
			return best
		end
	end
	return pool[(seed + rung) % #pool + 1]
end

function Rules.newRun(collection, seed: number)
	collection.Runs += 1
	local run = {
		Hearts = G.Hearts,
		Rung = 1,
		Wins = 0,
		Seed = seed,
		Coins = 0,
		Unlocked = {},
		Over = false,
		Rival = "",
	}
	run.Rival = Rules.rivalFor(collection, 1, seed)
	return run
end

function Rules.rivalHpScale(collection, run, selected: string): number
	if collection.Runs == 1 and run.Rung == 1 then
		return G.FirstDuelHp
	end
	local scale = math.min(G.RivalHp + G.RivalHpPerRung * (run.Rung - 1), G.RivalHpMax)
	if Rules.isBoss(run.Rung) then
		scale *= G.BossHp
	end
	if Rules.isCounter(selected, run.Rival) then
		scale *= G.CounterHp
	end
	return scale
end

function Rules.applyResult(collection, run, won: boolean)
	assert(not run.Over, "this run has ended")
	local outcome = {
		Won = won,
		Rival = run.Rival,
		Shards = 0,
		Progress = 0,
		Needed = Rules.shardsNeeded(collection),
		Unlocked = nil :: string?,
		Coins = 0,
		Hearts = run.Hearts,
		Over = false,
	}
	if won then
		local rival, boss = run.Rival, Rules.isBoss(run.Rung)
		if not collection.Owned[rival] then
			outcome.Shards = if boss then G.BossShards else 1
			local total = (collection.Shards[rival] or 0) + outcome.Shards
			if total >= outcome.Needed then
				collection.Owned[rival], collection.Unlocked = true, collection.Unlocked + 1
				collection.Shards[rival] = nil
				outcome.Unlocked, outcome.Progress = rival, outcome.Needed
				table.insert(run.Unlocked, rival)
			else
				collection.Shards[rival], outcome.Progress = total, total
			end
		end
		outcome.Coins = G.CoinsPerWin + G.CoinsPerRung * run.Rung
		run.Coins += outcome.Coins
		collection.Coins += outcome.Coins
		run.Wins += 1
		run.Rung += 1
		collection.Best = math.max(collection.Best, run.Wins)
		run.Rival = Rules.rivalFor(collection, run.Rung, run.Seed)
	else
		-- A rematch, not a reset: lose a heart, bring a better glassy, go again.
		run.Hearts -= 1
		outcome.Hearts = run.Hearts
		outcome.Over = run.Hearts <= 0
		run.Over = outcome.Over
	end
	return outcome
end

return Rules
