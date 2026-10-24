-- Round pacing on the real deterministic swing: how much of a fight is "dead air" (decision 122).
--   lune run tools/pacing_report [pairs per glassy=4] [Table.Key=value ...] [twist=Name]
-- An "event" is anything a viewer notices: a hit of at least BigHit of max HP, a power release or payoff,
-- a glint grab, a bomb, a bump, or the shatter. Small taps count as hits but not as events.
local process = require("@lune/process")
local G = require("../src/shared/Config/Glassies")
local B = require("../src/shared/Config/Balance")
local Rules = require("../src/shared/FightRules")
local Arena = require("../src/shared/ArenaRules")
local Rng = require("../src/shared/Rng")
local Pendulum = require("../src/server/Simulation/Pendulum")

local PAIRS = tonumber(process.args[1]) or 4
local ONLY: string? = nil
-- Try a tuning without editing Balance: extra args like Fight.DamageScale=0.5 Motion.Gravity=110
for i = 2, #process.args do
	local twist = string.match(process.args[i], "^twist=(%w+)$")
	if twist then
		ONLY = twist
		continue
	end
	local tbl, key, value = string.match(process.args[i], "^(%w+)%.(%w+)=([%d%.%-]+)$")
	assert(tbl and B[tbl] and B[tbl][key] ~= nil, "unknown override " .. process.args[i])
	B[tbl][key] = tonumber(value)
	print(string.format("override %s.%s = %s", tbl, key, value))
end
local BigHit = 0.06
local DeadGap = 3 -- seconds with no event counts as dead air
local NOTICED = {
	CastRelease = true,
	SignatureContact = true,
	Power = true,
	Shatter = true,
	GlintGrab = true,
	BombPop = true,
	Bump = true,
}

local function round(a, b, seed)
	local rng = Rng.new(seed)
	local sweet = Rules.rollSweetSpot(rng)
	local function setup(id)
		return { Id = id, Aim = Rules.botAim(sweet, 0.45, rng), AimYaw = (rng() * 2 - 1) * B.Motion.AimYawMax }
	end
	local twist = ONLY or Arena.rollTwist(rng)
	local sim = Pendulum.new({ A = setup(a), B = setup(b), SweetSpot = sweet, Rng = rng, Twist = twist }, seed)
	local hits, events, counts = {}, {}, {}
	while not sim.Fight.Over do
		Pendulum.step(sim, 1 / B.Motion.StepRate)
		local t = sim.Fight.Time
		for _, e in Pendulum.events(sim) do
			counts[e.Type] = (counts[e.Type] or 0) + 1
			if e.Type == "Hit" then
				table.insert(hits, t)
				local m1, m2 = sim.Fight.Fighters[1].MaxHp, sim.Fight.Fighters[2].MaxHp
				if math.max(e.Damage[1] / m1, e.Damage[2] / m2) >= BigHit then
					table.insert(events, t)
				end
			elseif NOTICED[e.Type] then
				table.insert(events, t)
			end
		end
	end
	return sim.Fight.Time, hits, events, counts, twist, sim.Fight.Winner
end

local function gaps(times, total)
	local out, last = {}, 0
	for _, t in times do
		table.insert(out, t - last)
		last = t
	end
	table.insert(out, total - last)
	return out
end

local n, secs, nHits, nEvents, dead, longest = 0, 0, 0, 0, 0, {}
local lengths, totals, byTwist = {}, {}, {}
for i, def in G.ReleaseList do
	for k = 1, PAIRS do
		local foe = G.ReleaseList[(i + k * 7 - 1) % #G.ReleaseList + 1].Id
		local t, hits, events, counts, twist = round(def.Id, foe, 9000 + i * 37 + k)
		n += 1
		secs += t
		nHits += #hits
		nEvents += #events
		table.insert(lengths, t)
		for kind, c in counts do
			totals[kind] = (totals[kind] or 0) + c
		end
		local row = byTwist[twist] or { N = 0, Seconds = 0, Hits = 0, Bumps = 0 }
		row.Hits += #hits
		row.Bumps += counts.Bump or 0
		row.N += 1
		row.Seconds += t
		byTwist[twist] = row
		local worst = 0
		for _, g in gaps(events, t) do
			if g > DeadGap then
				dead += g - DeadGap
			end
			worst = math.max(worst, g)
		end
		table.insert(longest, worst)
	end
end
table.sort(lengths)
table.sort(longest)
local function pct(list, p)
	return list[math.clamp(math.ceil(#list * p), 1, #list)]
end
local function per(kind)
	return (totals[kind] or 0) / n
end
print(string.format("Real swing pacing, %d rounds", n))
print(
	string.format(
		"  fight length  mean %.1f s, median %.1f s, p90 %.1f s",
		secs / n,
		pct(lengths, 0.5),
		pct(lengths, 0.9)
	)
)
print(string.format("  hits          %.2f / s (any contact)", nHits / secs))
print(
	string.format(
		"  events        %.2f / s (big hit >= %d%% HP, power, glint, bomb, bump, shatter)",
		nEvents / secs,
		BigHit * 100
	)
)
print(string.format("  dead air      %.0f%% of fight time is beyond %d s without an event", 100 * dead / secs, DeadGap))
print(string.format("  longest quiet median %.1f s, p90 %.1f s", pct(longest, 0.5), pct(longest, 0.9)))
print(
	string.format(
		"  per round     %.1f glints, %.1f grabbed, %.1f faded, %.1f pushes, %.1f bombs, %.1f bumps, %.0f%% timeouts",
		per("GlintSpawn"),
		per("GlintGrab"),
		per("GlintFade"),
		per("Push"),
		per("BombPop"),
		per("Bump"),
		100 * (totals.End and 0 or 0)
	)
)
local names = {}
for name in byTwist do
	table.insert(names, name)
end
table.sort(names)
for _, name in names do
	local r = byTwist[name]
	print(
		string.format(
			"  %-10s %3d rounds, mean %.1f s, %.2f hits/s, %.1f bumps",
			name,
			r.N,
			r.Seconds / r.N,
			r.Hits / r.Seconds,
			r.Bumps / r.N
		)
	)
end
