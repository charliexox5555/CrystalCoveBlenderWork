-- Balance of the arena layer on the real swing (decision 122). Mirror rounds (each release glassy vs itself), so
-- any edge comes from glints, twists, PUSH or Last Glass, not from the kits.
--   lune run tools/arena_report <mode> [seeds per glassy=6] [Table.Key=value ...]
-- modes:
--   glints  win rate of the side that grabbed each glint kind; who grabs (by type)
--   twists  round length per twist; type vs type win rates per twist (non-mirror pairs)
--   push    side A pushes (skill 0.5) vs side B never pushes; also skill 1 vs 0
--   last    side A starts with Last Glass vs side B without
local process = require("@lune/process")
local G = require("../src/shared/Config/Glassies")
local B = require("../src/shared/Config/Balance")
local Rules = require("../src/shared/FightRules")
local Arena = require("../src/shared/ArenaRules")
local Rng = require("../src/shared/Rng")
local Pendulum = require("../src/server/Simulation/Pendulum")

local mode = process.args[1] or "glints"
local SEEDS = tonumber(process.args[2]) or 6
for i = 3, #process.args do
	local tbl, key, value = string.match(process.args[i], "^(%w+)%.(%w+)=([%d%.%-]+)$")
	assert(tbl and B[tbl] and B[tbl][key] ~= nil, "unknown override " .. process.args[i])
	B[tbl][key] = tonumber(value)
	print(string.format("override %s.%s = %s", tbl, key, value))
end
for _, info in B.Rarities do
	info.StatMultiplier = 1 -- equal stats: this measures the arena, not rarity
end

local function play(a, b, seed, opts)
	local rng = Rng.new(seed)
	local sweet = Rules.rollSweetSpot(rng)
	local function setup(id, extra)
		local s = { Id = id, Aim = Rules.botAim(sweet, 0.45, rng), AimYaw = (rng() * 2 - 1) * B.Motion.AimYawMax }
		for k, v in extra or {} do
			s[k] = v
		end
		return s
	end
	local twist = opts.Twist or Arena.rollTwist(rng)
	local sim =
		Pendulum.new({ A = setup(a, opts.A), B = setup(b, opts.B), SweetSpot = sweet, Rng = rng, Twist = twist }, seed)
	local grabs = {}
	while not sim.Fight.Over do
		Pendulum.step(sim, 1 / B.Motion.StepRate)
		for _, e in Pendulum.events(sim) do
			if e.Type == "GlintGrab" and not e.LastGlass then
				table.insert(grabs, { Kind = e.Kind, Side = e.Side })
			end
		end
	end
	return sim.Fight.Winner, sim.Fight.Time, twist, grabs, sim.Fight.Reason
end

local ids = {}
for _, def in G.ReleaseList do
	table.insert(ids, def.Id)
end

local function pct(x)
	return string.format("%5.1f%%", 100 * x)
end

if mode == "glints" then
	local kinds, types = {}, {}
	local n = 0
	for i, id in ids do
		for s = 1, SEEDS do
			local winner, _, _, grabs = play(id, id, 70000 + i * 131 + s, {})
			n += 1
			for _, g in grabs do
				local k = kinds[g.Kind] or { Grabs = 0, Wins = 0 }
				kinds[g.Kind] = k
				k.Grabs += 1
				k.Wins += if g.Side == winner then 1 else 0
			end
		end
	end
	-- Non-mirror: who grabs more, by type (heavier glass, higher swing).
	for i, id in ids do
		local foe = ids[(i + 7) % #ids + 1]
		for s = 1, 2 do
			local _, _, _, grabs = play(id, foe, 71000 + i * 17 + s, {})
			for _, g in grabs do
				local t = G.get(if g.Side == 1 then id else foe).Type
				types[t] = (types[t] or 0) + 1
			end
		end
	end
	print(string.format("Glints, %d mirror rounds (grabber's win rate; 50%% = no effect)", n))
	local names = {}
	for k in kinds do
		table.insert(names, k)
	end
	table.sort(names)
	for _, k in names do
		local r = kinds[k]
		print(
			string.format(
				"  %-7s %4d grabs (%.1f a round)  grabber wins %s",
				k,
				r.Grabs,
				r.Grabs / n,
				pct(r.Wins / r.Grabs)
			)
		)
	end
	print(
		"  grabs by type (non-mirror):",
		types.Heavy or 0,
		"Heavy,",
		types.Fizzy or 0,
		"Fizzy,",
		types.Sharp or 0,
		"Sharp"
	)
elseif mode == "twists" then
	local rows = {}
	for _, twist in { "Calm", "Windy", "Bouncy", "Magnet", "GlintRain", "Bumpers" } do
		local secs, list, timeouts, typeWins = 0, {}, 0, {}
		for i, id in ids do
			local foe = ids[(i + 7) % #ids + 1]
			for s = 1, SEEDS do
				local winner, t, _, _, reason = play(id, foe, 72000 + i * 53 + s, { Twist = twist })
				secs += t
				table.insert(list, t)
				timeouts += if reason == "Timeout" then 1 else 0
				local ta, tb = G.get(id).Type, G.get(foe).Type
				if ta ~= tb then
					local key = if ta < tb then ta .. ">" .. tb else tb .. ">" .. ta
					local first = if ta < tb then 1 else 2
					local row = typeWins[key] or { W = 0, N = 0 }
					typeWins[key] = row
					row.N += 1
					row.W += if winner == first then 1 else 0
				end
			end
		end
		table.sort(list)
		local parts = {}
		for key, row in typeWins do
			table.insert(parts, string.format("%s %s", key, pct(row.W / row.N)))
		end
		table.sort(parts)
		table.insert(
			rows,
			string.format(
				"  %-9s mean %4.1f s  p90 %4.1f s  timeouts %s  %s",
				twist,
				secs / #list,
				list[math.ceil(#list * 0.9)],
				pct(timeouts / #list),
				table.concat(parts, "  ")
			)
		)
	end
	print("Twists (non-mirror pairs, type rows read 'first type wins')")
	for _, r in rows do
		print(r)
	end
elseif mode == "push" or mode == "last" then
	local function run(optsA, optsB, label)
		local wins, n = 0, 0
		for i, id in ids do
			for s = 1, SEEDS do
				-- Alternate sides so stand side can't leak in.
				local swap = s % 2 == 0
				local winner = play(id, id, 73000 + i * 97 + s, {
					A = if swap then optsB else optsA,
					B = if swap then optsA else optsB,
				})
				n += 1
				wins += if winner == (if swap then 2 else 1) then 1 else 0
			end
		end
		print(string.format("  %-34s %s (%d rounds)", label, pct(wins / n), n))
	end
	if mode == "push" then
		print("PUSH value (mirror rounds)")
		run({ PushSkill = 0.5 }, { PushSkill = 0 }, "pushes (skill 0.5) vs never")
		run({ PushSkill = 1 }, { PushSkill = 0 }, "pushes (skill 1) vs never")
		run({ PushSkill = 1 }, { PushSkill = 0.2 }, "skill 1 vs skill 0.2")
	else
		print("Last Glass value (mirror rounds)")
		run({ LastGlass = true }, {}, "Last Glass vs none")
	end
end
