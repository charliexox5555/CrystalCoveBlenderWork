-- Power check (docs/testing/power_check/REPORT.md): `lune run tools/power_check [rounds=30] [ids]`.
-- For every power, real Pendulum rounds against a rotating field, side A with three cast policies:
--   auto  = a player who never taps CAST (fires when the Ready timer runs out)
--   smart = taps at a good moment (CastTiming), mash = taps as soon as it is Ready
-- Per cast it asks: did the power do anything you could measure before its window closed?
--   damage landed (CastContact), a contact payoff (SignatureContact), a block, a heal, a pierce, a slow/mark/drain.
-- "dud %" = casts with no effect at all. For contact payoffs (boosts, armed hits) it also compares the powered
-- clash with A's ordinary clashes, because a payoff that lands on a slow bump can still read as "nothing happened".
local process = require("@lune/process")
local G = require("../src/shared/Config/Glassies")
local B = require("../src/shared/Config/Balance")
local Rules = require("../src/shared/FightRules")
local Rng = require("../src/shared/Rng")
local Pendulum = require("../src/server/Simulation/Pendulum")

local rounds = tonumber(process.args[1]) or 30
local ids = {}
if process.args[2] and process.args[2] ~= "" then
	for id in string.gmatch(process.args[2], "[^,]+") do
		table.insert(ids, id)
	end
else
	for _, def in G.ReleaseList do
		table.insert(ids, def.Id)
	end
	for _, list in { G.DailyIds or {}, G.StarterPackIds or {} } do
		for _, id in list do
			table.insert(ids, id)
		end
	end
end
local foes = {}
for _, def in G.ReleaseList do
	table.insert(foes, def.Id)
end
for _, info in B.Rarities do
	info.StatMultiplier = 1 -- equal stats: we're measuring the power, not the rarity edge
end

local EFFECT_STATUS = {
	Heal = true,
	Pierce = true,
	Drain = true,
	MirrorCatch = true,
	Slow = true,
	Mark = true,
	Take = true,
	Taken = true,
	Seed = true,
}

local function run(id, policy)
	local r = {
		casts = 0,
		effect = 0,
		delay = 0,
		powered = 0,
		poweredDmg = 0,
		poweredSpeed = 0,
		plain = 0,
		plainDmg = 0,
		plainSpeed = 0,
		rangedDmg = 0,
		poweredList = {},
	}
	for n = 1, rounds do
		local foe = foes[(n * 7) % #foes + 1]
		if foe == id then
			foe = "jam"
		end
		local seed = 9000 + n * 131
		local rng = Rng.new(seed)
		local sweet = Rules.rollSweetSpot(rng)
		local sim = Pendulum.new({
			A = {
				Id = id,
				Aim = Rules.botAim(sweet, 0.45, rng),
				AimYaw = (rng() * 2 - 1) * B.Motion.AimYawMax,
				CastPolicy = policy,
				CastSkill = 0,
			},
			B = {
				Id = foe,
				Aim = Rules.botAim(sweet, 0.45, rng),
				AimYaw = (rng() * 2 - 1) * B.Motion.AimYawMax,
				CastPolicy = "bot",
				CastSkill = 0.5,
			},
			SweetSpot = sweet,
			Rng = rng,
		}, seed)
		local episodes = {}
		local function open(t, untilT)
			local ep = { Start = t, Until = untilT, Hit = false }
			table.insert(episodes, ep)
			r.casts += 1
			return ep
		end
		local function current(t)
			for i = #episodes, 1, -1 do
				local ep = episodes[i]
				if t >= ep.Start - 1e-6 and t <= ep.Until then
					return ep
				end
			end
			return nil
		end
		local function land(ep, t)
			if ep and not ep.Hit then
				ep.Hit = true
				r.effect += 1
				r.delay += t - ep.Start
			end
		end
		local kit = B.CombatRelease.Kits[id] or {}
		while not sim.Fight.Over do
			Pendulum.step(sim, 1 / B.Motion.StepRate)
			local t = sim.Fight.Time
			local poweredNext = false
			for _, e in Pendulum.events(sim) do
				if e.Type == "CastStart" and e.Side == 1 then
					local cast = nil
					for _, c in sim.Fight.PendingCasts do
						if c.Id == e.CastId then
							cast = c
						end
					end
					local p = cast and cast.Params or kit
					open(t, t + (p.Windup or 0) + (p.Hold or 0) + (p.Duration or 0) + (p.Delay or 0) + 0.3)
				elseif e.Type == "SignatureArmed" and e.Side == 1 then
					open(t, t + (e.Seconds or 3) + 0.05)
				elseif e.Type == "SignatureStatus" and e.Side == 1 and e.Kind == "Counter" then
					open(t, t + (e.Seconds or 2) + 0.05)
				elseif e.Type == "CastContact" and e.Side == 1 then
					if not e.Missed and (e.Amount or 0) > 0 then
						r.rangedDmg += e.Amount
						land(current(t), t)
					end
				elseif e.Type == "SignatureContact" and e.Side == 1 then
					local ep = current(t)
					if not ep then
						ep = open(t, t) -- a power that fires on the clash itself (Pickle Jar etc.)
					end
					land(ep, t)
					poweredNext = true
				elseif e.Type == "SignatureBlock" and e.Side == 1 then
					land(current(t), t)
				elseif
					e.Type == "SignatureStatus"
					and e.Side == 1
					and EFFECT_STATUS[e.Kind]
					and (e.Amount == nil or e.Amount > 0.01)
				then
					land(current(t), t)
				elseif e.Type == "Hit" then
					if poweredNext then
						r.powered += 1
						r.poweredDmg += e.Damage[2]
						r.poweredSpeed += e.Speed
						table.insert(r.poweredList, e.Damage[2])
						poweredNext = false
					else
						r.plain += 1
						r.plainDmg += e.Damage[2]
						r.plainSpeed += e.Speed
					end
				end
			end
		end
	end
	return r
end

print(
	string.format(
		"%-18s %-14s | %-26s | %-26s | %-26s | powered clash vs plain (smart)",
		"glassy",
		"shape",
		"auto: casts dud% delay",
		"smart: casts dud% delay",
		"mash: casts dud% delay"
	)
)
local function cell(r)
	local dud = if r.casts > 0 then 100 * (1 - r.effect / r.casts) else 0
	return string.format("%5d %5.1f%% %4.2fs", r.casts, dud, if r.effect > 0 then r.delay / r.effect else 0), dud
end
for _, id in ids do
	local kit = B.CombatRelease.Kits[id]
	if not kit then
		continue
	end
	local auto, smart, mash = run(id, "auto"), run(id, "smart"), run(id, "mash")
	local a, ad = cell(auto)
	local s, sd = cell(smart)
	local m, md = cell(mash)
	local payoff = ""
	if smart.powered > 0 then
		local plainMean = smart.plainDmg / math.max(1, smart.plain)
		local weak = 0
		for _, d in smart.poweredList do
			weak += if d < plainMean then 1 else 0
		end
		payoff = string.format(
			"%.1f dmg @ %.1f spd vs %.1f @ %.1f (n=%d, %d%% below a plain clash)",
			smart.poweredDmg / smart.powered,
			smart.poweredSpeed / smart.powered,
			smart.plainDmg / math.max(1, smart.plain),
			smart.plainSpeed / math.max(1, smart.plain),
			smart.powered,
			math.floor(100 * weak / smart.powered + 0.5)
		)
	elseif smart.rangedDmg > 0 then
		payoff = string.format("ranged %.1f dmg/landed cast", smart.rangedDmg / math.max(1, smart.effect))
	end
	local flag = if math.max(ad, sd) > 40 then "  <-- " else ""
	print(string.format("%-18s %-14s | %-26s | %-26s | %-26s | %s%s", id, kit.Shape, a, s, m, payoff, flag))
end
