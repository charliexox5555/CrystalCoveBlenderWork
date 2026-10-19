-- Real-swing round-robin over the release roster, one shard of the pair list per process.
--   lune run tools/release_matrix <shard> <shards> <rounds per pair> <mode> <out.json> [ids]
-- mode: <base>[:<policy A>[:<policy B>]]
--   base: equal (rarity multipliers = 1), rarity (real multipliers), stars5 (side A 5 stars vs 0),
--         mirror (each glassy vs itself; use with two policies to measure the cast skill edge)
--   policy: smart, auto, mash, bot<skill 0-1> (CastBrain); omitted = cast at once (no CAST step)
-- Run all shards in parallel and print the report with tools/release_matrix.sh.
local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")
local Balance = require("../src/shared/Config/Balance")
local Glassies = require("../src/shared/Config/Glassies")
local Rng = require("../src/shared/Rng")
local Rules = require("../src/shared/FightRules")
local Pendulum = require("../src/server/Simulation/Pendulum")

local shard, shards = tonumber(process.args[1]) or 0, tonumber(process.args[2]) or 1
local rounds = tonumber(process.args[3]) or 8
local mode = process.args[4] or "equal"
local base, policyA, policyB = string.match(mode, "^([^:]+):?([^:]*):?([^:]*)$")
policyA = if policyA ~= "" then policyA else nil
policyB = if policyB ~= "" then policyB else policyA
local function policy(name)
	if not name then
		return nil, nil
	end
	local skill = string.match(name, "^bot([%d%.]+)$")
	if skill then
		return "bot", tonumber(skill)
	end
	return name, 0
end
local outPath = process.args[5] or "release_matrix.json"
local M = Balance.Motion

local ids = {}
if process.args[6] and process.args[6] ~= "" then
	for id in string.gmatch(process.args[6], "[^,]+") do
		table.insert(ids, id)
	end
else
	for _, def in Glassies.ReleaseList do
		table.insert(ids, def.Id)
	end
	if Glassies.ById.hollowlight then
		table.insert(ids, "hollowlight")
	end
end
if base ~= "rarity" then
	for _, info in Balance.Rarities do
		info.StatMultiplier = 1
	end
end

local pairs = {}
if base == "stars5" or base == "mirror" then
	for _, id in ids do
		table.insert(pairs, { id, id })
	end
else
	for i = 1, #ids do
		for j = i + 1, #ids do
			table.insert(pairs, { ids[i], ids[j] })
		end
	end
end

local function play(a, b, seed, swap)
	local rng = Rng.new(seed)
	local sweet = Rules.rollSweetSpot(rng)
	local function setup(id, isA)
		local castPolicy, castSkill = policy(if isA then policyA else policyB)
		return {
			Id = id,
			Aim = Rules.botAim(sweet, 0.45, rng),
			AimYaw = (rng() * 2 - 1) * M.AimYawMax,
			Stars = if base == "stars5" and isA then Balance.Growth.MaxStars else 0,
			CastPolicy = castPolicy,
			CastSkill = castSkill,
		}
	end
	local first, second = setup(a, true), setup(b, false)
	if swap then
		first, second = second, first
	end
	local sim = Pendulum.new({ A = first, B = second, SweetSpot = sweet, Rng = rng }, seed)
	while not sim.Fight.Over do
		Pendulum.step(sim, 1 / M.StepRate)
		Pendulum.events(sim)
	end
	local aWon = sim.Fight.Winner == (if swap then 2 else 1)
	return aWon, sim.Fight.Time, sim.Fight.Hits, sim.Fight.Reason == "Timeout"
end

local out = { Mode = mode, Rounds = rounds, Pairs = {} }
for index, pair in pairs do
	if (index - 1) % shards == shard then
		local row = { A = pair[1], B = pair[2], WinsA = 0, N = 0, Seconds = 0, Hits = 0, Timeouts = 0 }
		for r = 1, rounds do
			local seed = 50000 + index * 7919 + r * 104729
			local won, seconds, hits, timeout = play(pair[1], pair[2], seed, r % 2 == 0)
			row.N += 1
			row.WinsA += if won then 1 else 0
			row.Seconds += seconds
			row.Hits += hits
			row.Timeouts += if timeout then 1 else 0
		end
		table.insert(out.Pairs, row)
	end
end
fs.writeFile(outPath, serde.encode("json", out))
