--!strict
-- Fight rules (GAME_DESIGN 3): HP, damage, crits, types, passives, powers, shatter and timeout.
-- Pure and deterministic: no Roblox APIs, all randomness from `rng`, so the server, the tests
-- and the balance simulator use the same rules.
--
-- This module does NOT move the glassies. The swing code (FightService on the server) moves
-- them and tells the rules what happened:
--
--   local fight = FightRules.new({ A = { Id = "pop", Aim = 0.9 }, B = { Id = "jam", Aim = 0.7 },
--                                  Rng = rng, SweetSpot = sweetSpot,
--                                  PowerLands = function(side, powerId) return <is the target in range/line?> end })
--   -- every server step:
--   FightRules.tick(fight, dt)                        -- bleeds, heals, powers firing by themselves, timeout
--   -- when the two glassies hit (approach speed in studs/s, how much of it came from side 1, 0..1):
--   FightRules.hit(fight, speed, shareA, x, y)
--   -- Powers fire on their own at random moments (no button). Aimed powers (Beam, Freeze) ask
--   -- PowerLands whether they reach the other glass from where it is right now; they can miss.
--   -- the swing code reads these to apply powers to the motion:
--   FightRules.swingMultiplier(fight, side), FightRules.isFrozen(fight, side), FightRules.knockbackMultiplier(fight, side)
--   -- and sends FightRules.drainEvents(fight) to clients for effects and UI.
--
-- Side 1 = A (left on the stand), side 2 = B (right).

local Balance = if script then require(script.Parent.Config.Balance) else require("./Config/Balance")
local Glassies = if script then require(script.Parent.Config.Glassies) else require("./Config/Glassies")
local Powers = if script then require(script.Parent.Config.Powers) else require("./Config/Powers")
local Formula = if script then require(script.Parent.Formula) else require("./Formula")

export type FighterSetup = {
	Id: string,
	Stars: number?,
	Rainbow: boolean?,
	Aim: number?, -- pull-back angle in radians; clamped to Motion.AimMin..AimMax
	AimYaw: number?, -- sideways aim in radians (3D swing); clamped to +-Motion.AimYawMax
}

export type Setup = {
	A: FighterSetup,
	B: FighterSetup,
	Rng: () -> number,
	SweetSpot: number?, -- centre of the Perfect Release band; nil = no band this round
	-- Optional: does an aimed power fired by `side` reach the other glass right now? The swing
	-- code answers from the 3D positions. Without it, Params.LandChance is rolled.
	PowerLands: ((side: number, powerId: string) -> boolean)?,
}

export type Event = { [string]: any }

export type Fighter = {
	Side: number,
	Id: string,
	Name: string,
	Type: string,
	Power: number,
	Swing: number,
	MaxHp: number,
	Hp: number,
	Mass: number,
	Radius: number,
	Aim: number,
	AimYaw: number,
	Amplitude: number,
	Passive: string,
	PassiveParams: { [string]: number },
	Special: string,
	SpecialParams: { [string]: number },
	NextPowerAt: number, -- fight time when this glassy's power fires next
	LastPowerAt: number,
	PowerTriggers: number,
	Perfect: boolean,
	FirstHitPending: boolean,
	HitsDealt: number,
	MomentumStacks: number,
	Bleeds: { { PerSecond: number, Remaining: number } },
	Sticky: { number }, -- seconds left on each stack
	SecondWindUsed: boolean,
	ShieldUntil: number,
	SlamUntil: number,
	PumpUntil: number,
	RageUntil: number,
	FrozenUntil: number,
	DamageDealt: number,
	Crits: number,
}

export type State = {
	Time: number,
	Fighters: { Fighter },
	Rng: () -> number,
	SweetSpot: number?,
	Events: { Event },
	Over: boolean,
	Winner: number?,
	Reason: string?,
	Hits: number,
	InOvertime: boolean,
	PowerLands: ((side: number, powerId: string) -> boolean)?,
}

local FightRules = {}
FightRules.Balance = Balance

local F = Balance.Fight
local M = Balance.Motion

local function clamp(x: number, lo: number, hi: number): number
	return math.max(lo, math.min(hi, x))
end

local function finite(x: any): boolean
	return type(x) == "number" and x == x and math.abs(x) ~= math.huge
end

local function emit(state: State, event: Event)
	event.Time = state.Time
	table.insert(state.Events, event)
end

local function other(side: number): number
	return 3 - side
end

-- Aim ----------------------------------------------------------------------------------------

function FightRules.clampAim(aim: any): number
	if not finite(aim) then
		return M.AimDefault
	end
	return clamp(aim, M.AimMin, M.AimMax)
end

function FightRules.clampYaw(yaw: any): number
	if not finite(yaw) then
		return 0
	end
	return clamp(yaw, -M.AimYawMax, M.AimYawMax)
end

-- When a glassy's power fires next: a random wait (first one of the round, or a repeat).
local function powerDelay(rng: () -> number, first: boolean): number
	local lo = if first then F.PowerFirstMin else F.PowerRepeatMin
	local hi = if first then F.PowerFirstMax else F.PowerRepeatMax
	return lo + (hi - lo) * rng()
end

function FightRules.rollSweetSpot(rng: () -> number): number
	local lo = M.AimMin + M.SweetSpotWidth
	local hi = M.AimMax - M.SweetSpotWidth
	return lo + (hi - lo) * rng()
end

function FightRules.isPerfect(aim: number, sweetSpot: number?): boolean
	return sweetSpot ~= nil and math.abs(aim - sweetSpot) <= M.SweetSpotWidth
end

-- A bot's aim: perfect at skill 1, up to BotAimErrorMax off at skill 0.
function FightRules.botAim(sweetSpot: number, skill: number, rng: () -> number): number
	local err = M.BotAimErrorMax * (1 - clamp(skill, 0, 1)) * (rng() * 2 - 1)
	return FightRules.clampAim(sweetSpot + err)
end

-- How high a glassy keeps swinging (radians) for its Swing stat, before powers.
function FightRules.targetAmplitude(swing: number): number
	return math.min(M.AmplitudeBase + M.AmplitudePerSwing * swing, M.AmplitudeMax)
end

-- Setup --------------------------------------------------------------------------------------

local function newFighter(side: number, setup: FighterSetup, sweetSpot: number?, rng: () -> number): Fighter
	local def = Glassies.get(setup.Id)
	local stats = Formula.stats(def, { Stars = setup.Stars, Rainbow = setup.Rainbow })
	local aim = FightRules.clampAim(setup.Aim)
	local perfect = FightRules.isPerfect(aim, sweetSpot)
	return {
		Side = side,
		Id = def.Id,
		Name = def.Name,
		Type = def.Type,
		Power = stats.Power,
		Swing = stats.Swing,
		MaxHp = stats.HP,
		Hp = stats.HP,
		Mass = def.Mass or M.MassByType[def.Type] or 1,
		Radius = def.Radius,
		Aim = aim,
		AimYaw = FightRules.clampYaw(setup.AimYaw),
		Amplitude = FightRules.targetAmplitude(stats.Swing),
		Passive = def.Passive,
		PassiveParams = Powers.passive(def.Passive).Params,
		Special = def.Special,
		SpecialParams = Powers.special(def.Special).Params,
		NextPowerAt = powerDelay(rng, true) - (if perfect then F.PerfectPowerAdvance else 0),
		LastPowerAt = 0,
		PowerTriggers = 0,
		Perfect = perfect,
		FirstHitPending = perfect,
		HitsDealt = 0,
		MomentumStacks = 0,
		Bleeds = {},
		Sticky = {},
		SecondWindUsed = false,
		ShieldUntil = -1,
		SlamUntil = -1,
		PumpUntil = -1,
		RageUntil = -1,
		FrozenUntil = -1,
		DamageDealt = 0,
		Crits = 0,
	}
end

function FightRules.new(setup: Setup): State
	assert(type(setup.Rng) == "function", "FightRules.new needs an Rng function")
	local state: State = {
		Time = 0,
		Fighters = {},
		Rng = setup.Rng,
		SweetSpot = setup.SweetSpot,
		Events = {},
		Over = false,
		Winner = nil,
		Reason = nil,
		Hits = 0,
		InOvertime = false,
		PowerLands = setup.PowerLands,
	}
	state.Fighters[1] = newFighter(1, setup.A, setup.SweetSpot, setup.Rng)
	state.Fighters[2] = newFighter(2, setup.B, setup.SweetSpot, setup.Rng)
	for _, f in state.Fighters do
		if f.Perfect then
			emit(state, { Type = "PerfectRelease", Side = f.Side })
		end
	end
	return state
end

-- Returns the events since the last call (send them to clients) and clears the list.
function FightRules.drainEvents(state: State): { Event }
	local events = state.Events
	state.Events = {}
	return events
end

-- Read by the swing code -----------------------------------------------------------------------

-- Multiplier on a glassy's target swing height right now (Big Swing, Sticky). 1 = normal.
function FightRules.swingMultiplier(state: State, side: number): number
	local f = state.Fighters[side]
	local mult = 1
	if state.Time < f.PumpUntil then
		mult *= f.SpecialParams.SwingMult
	end
	if #f.Sticky > 0 then
		local foe = state.Fighters[other(side)]
		mult *= 1 - (foe.PassiveParams.SwingLoss or 0) * #f.Sticky
	end
	return mult
end

-- Frozen glassies stop driving their swing and get Motion.FrozenDamping extra drag.
function FightRules.isFrozen(state: State, side: number): boolean
	return state.Time < state.Fighters[side].FrozenUntil
end

-- How hard `side` gets knocked back in a hit right now (Slam from the other side). 1 = normal.
function FightRules.knockbackMultiplier(state: State, side: number): number
	local foe = state.Fighters[other(side)]
	if state.Time < foe.SlamUntil then
		return foe.SpecialParams.KnockbackMult
	end
	return 1
end

function FightRules.isShielded(state: State, side: number): boolean
	return state.Time < state.Fighters[side].ShieldUntil
end

-- Damage -------------------------------------------------------------------------------------

local function overtimeMultiplier(state: State): number
	if state.Time <= F.OvertimeAt then
		return 1
	end
	return 1 + F.OvertimePerSecond * (state.Time - F.OvertimeAt)
end

-- Applies damage to `target`, honouring shields and Sturdy. Returns the damage actually taken.
local function takeDamage(state: State, target: Fighter, amount: number): number
	if amount <= 0 or state.Time < target.ShieldUntil then
		return 0
	end
	if target.Passive == "sturdy" then
		amount *= target.PassiveParams.DamageTaken
	end
	target.Hp -= amount
	return amount
end

-- Damage one glassy deals to the other in a hit, before the defender's Shield and Sturdy.
-- `share` = how much of the approach speed came from the attacker (0..1).
function FightRules.hitDamage(state: State, attacker: Fighter, defender: Fighter, speed: number, share: number): (number, boolean)
	local rng = state.Rng
	local critBonus = if attacker.Passive == "lucky" then attacker.PassiveParams.CritBonus else 0
	local crit = rng() < Formula.critChance(attacker.Swing, critBonus)
	local variance = F.VarianceMin + (F.VarianceMax - F.VarianceMin) * rng()

	local speedFactor = math.min((math.max(speed, 0) / F.RefSpeed) ^ F.SpeedExponent, F.SpeedFactorMax)
	local massFactor = (2 * attacker.Mass / (attacker.Mass + defender.Mass)) ^ F.MassExponent
	local amount = F.DamageScale
		* attacker.Power
		* speedFactor
		* (F.ShareBase + F.ShareWeight * clamp(share, 0, 1))
		* massFactor
		* Formula.typeMultiplier(attacker.Type, defender.Type)
		* variance
		* (if crit then F.CritMultiplier else 1)
		* overtimeMultiplier(state)

	if attacker.FirstHitPending then
		amount *= F.PerfectFirstHitMult
	end
	if attacker.Passive == "fizz_burst" and (attacker.HitsDealt + 1) % attacker.PassiveParams.Every == 0 then
		amount *= 1 + attacker.PassiveParams.DamageBonus
		emit(state, { Type = "Passive", Side = attacker.Side, Id = "fizz_burst" })
	end
	if attacker.Passive == "momentum" then
		amount *= 1 + attacker.PassiveParams.PerStack * attacker.MomentumStacks
	end
	if state.Time < attacker.SlamUntil then
		amount *= attacker.SpecialParams.DamageMult
	end
	if state.Time < attacker.PumpUntil then
		amount *= attacker.SpecialParams.DamageMult
	end
	if state.Time < attacker.RageUntil then
		amount *= attacker.SpecialParams.DamageMult
	end
	if attacker.Special == "freeze" and state.Time < defender.FrozenUntil then
		amount *= attacker.SpecialParams.Brittle -- frozen glass is brittle
	end
	return amount, crit
end

-- Second Wind, then the shatter / double-KO rules. `before` = HP fractions before this hit.
local function resolveKnockouts(state: State, before: { number }?)
	if state.Over then
		return
	end
	for _, f in state.Fighters do
		if f.Hp <= 0 and f.Passive == "second_wind" and not f.SecondWindUsed then
			f.SecondWindUsed = true
			f.Hp = math.max(1, f.MaxHp * f.PassiveParams.HealFraction)
			emit(state, { Type = "Passive", Side = f.Side, Id = "second_wind" })
		end
	end
	local down1 = state.Fighters[1].Hp <= 0
	local down2 = state.Fighters[2].Hp <= 0
	if not down1 and not down2 then
		return
	end
	local loser: number
	local reason = "Shatter"
	if down1 and down2 then
		-- Double KO: whoever had more HP left before the hit hangs on with 1 HP.
		reason = "DoubleKO"
		local b = before or { 0, 0 }
		if b[1] == b[2] then
			loser = if state.Rng() < 0.5 then 1 else 2
		else
			loser = if b[1] < b[2] then 1 else 2
		end
		state.Fighters[other(loser)].Hp = 1
	else
		loser = if down1 then 1 else 2
	end
	state.Fighters[loser].Hp = 0
	state.Over = true
	state.Winner = other(loser)
	state.Reason = reason
	emit(state, { Type = "Shatter", Side = loser })
	emit(state, { Type = "End", Winner = state.Winner, Reason = reason })
end

-- Call when the two glassies hit. `speed` = approach speed along the hit normal (studs/s);
-- `shareA` = fraction of it that came from side 1 moving into the hit (0..1); x, y = contact
-- point for effects. The swing code decides MinHitSpeed and HitCooldown before calling this.
function FightRules.hit(state: State, speed: number, shareA: number, x: number?, y: number?)
	if state.Over or not finite(speed) or not finite(shareA) then
		return
	end
	local fighters = state.Fighters
	local shares = { clamp(shareA, 0, 1), 1 - clamp(shareA, 0, 1) }
	local before = { fighters[1].Hp / fighters[1].MaxHp, fighters[2].Hp / fighters[2].MaxHp }
	local raw, crit = {}, {}
	for side = 1, 2 do
		raw[side], crit[side] = FightRules.hitDamage(state, fighters[side], fighters[other(side)], speed, shares[side])
	end
	local taken, blocked = {}, {}
	for side = 1, 2 do
		local target = other(side)
		taken[target] = takeDamage(state, fighters[target], raw[side])
		blocked[target] = raw[side] > 0 and taken[target] == 0
	end
	state.Hits += 1
	emit(state, {
		Type = "Hit",
		X = x,
		Y = y,
		Speed = speed,
		Damage = { taken[1], taken[2] }, -- damage taken by side 1, side 2
		Crit = { crit[1], crit[2] }, -- side 1 / side 2 landed a crit
		Blocked = { blocked[1], blocked[2] },
		Hp = { math.max(fighters[1].Hp, 0), math.max(fighters[2].Hp, 0) },
	})

	for side = 1, 2 do
		local attacker, defender = fighters[side], fighters[other(side)]
		local dealt = taken[other(side)]
		attacker.HitsDealt += 1
		attacker.FirstHitPending = false
		attacker.DamageDealt += dealt
		if crit[side] then
			attacker.Crits += 1
		end
		if state.Time < attacker.SlamUntil then
			attacker.SlamUntil = -1 -- Slam is used up by the hit
		end
		if attacker.Passive == "momentum" then
			attacker.MomentumStacks = math.min(attacker.MomentumStacks + 1, attacker.PassiveParams.MaxStacks)
		end
		if defender.Passive == "momentum" and crit[side] then
			defender.MomentumStacks = 0
		end
		if dealt > 0 and attacker.Passive == "sharp_edge" then
			local p = attacker.PassiveParams
			table.insert(defender.Bleeds, { PerSecond = dealt * p.BleedFraction / p.BleedSeconds, Remaining = p.BleedSeconds })
			while #defender.Bleeds > p.MaxStacks do
				table.remove(defender.Bleeds, 1)
			end
		end
		if dealt > 0 and attacker.Passive == "sticky" then
			table.insert(defender.Sticky, attacker.PassiveParams.Seconds)
			while #defender.Sticky > attacker.PassiveParams.MaxStacks do
				table.remove(defender.Sticky, 1)
			end
		end
		if dealt > 0 and defender.Passive == "thorns" then
			local reflected = takeDamage(state, attacker, dealt * defender.PassiveParams.Reflect)
			if reflected > 0 then
				emit(state, { Type = "Passive", Side = defender.Side, Id = "thorns", Amount = reflected })
			end
		end
	end
	for side = 1, 2 do
		fighters[side].NextPowerAt -= F.PowerHitAdvance -- every hit brings the next power closer
	end
	resolveKnockouts(state, before)
end

-- Powers -------------------------------------------------------------------------------------

-- Does an aimed power reach the other glass? The swing code knows (PowerLands); otherwise roll.
local function powerLands(state: State, f: Fighter): boolean
	local chance = f.SpecialParams.LandChance
	if chance == nil then
		return true -- not aimed: always happens (whether it helps is up to the swing)
	end
	if state.PowerLands then
		return state.PowerLands(f.Side, f.Special) == true
	end
	return state.Rng() < chance
end

-- Fires a side's power now. Powers fire by themselves from FightRules.tick (no button); this is
-- public for tests and debug tools. Returns false (with a reason) if it can't fire.
function FightRules.triggerPower(state: State, side: number): (boolean, string?)
	if state.Over then
		return false, "over"
	end
	local f = state.Fighters[side]
	if not f then
		return false, "side"
	end
	if f.PowerTriggers >= F.PowerMaxPerRound then
		return false, "max"
	end
	f.PowerTriggers += 1
	f.LastPowerAt = state.Time
	f.NextPowerAt = if f.PowerTriggers >= F.PowerMaxPerRound
		then math.huge
		else state.Time + powerDelay(state.Rng, false)
	local foe = state.Fighters[other(side)]
	local p = f.SpecialParams
	local event: Event = { Type = "Power", Side = side, Id = f.Special }
	if not powerLands(state, f) then
		event.Missed = true
		emit(state, event)
		return true
	end
	if f.Special == "slam" or f.Special == "shield" or f.Special == "pump" or f.Special == "rage" then
		local untilTime = state.Time + p.Seconds
		if f.Special == "slam" then
			f.SlamUntil = untilTime
		elseif f.Special == "shield" then
			f.ShieldUntil = untilTime
		elseif f.Special == "pump" then
			f.PumpUntil = untilTime
		else
			f.RageUntil = untilTime
		end
		event.Seconds = p.Seconds
	elseif f.Special == "freeze" then
		foe.FrozenUntil = state.Time + p.Seconds
		event.Seconds = p.Seconds
	elseif f.Special == "beam" then
		local before = { state.Fighters[1].Hp / state.Fighters[1].MaxHp, state.Fighters[2].Hp / state.Fighters[2].MaxHp }
		local dealt = takeDamage(state, foe, foe.MaxHp * p.MaxHpFraction * overtimeMultiplier(state))
		f.DamageDealt += dealt
		event.Amount = dealt
		event.Blocked = dealt == 0
		emit(state, event)
		resolveKnockouts(state, before)
		return true
	elseif f.Special == "glaze" then
		local heal = math.min(f.MaxHp * p.HealFraction, f.MaxHp - f.Hp)
		f.Hp += heal
		f.Bleeds = {}
		event.Amount = heal
	end
	emit(state, event)
	return true
end

-- How close a side's next power is, 0..1 (for a subtle glow in the UI, not a button).
function FightRules.powerProgress(state: State, side: number): number
	local f = state.Fighters[side]
	if f.NextPowerAt == math.huge then
		return 0
	end
	local span = f.NextPowerAt - f.LastPowerAt
	if span <= 0 then
		return 1
	end
	return clamp((state.Time - f.LastPowerAt) / span, 0, 1)
end

-- Time ---------------------------------------------------------------------------------------

local function tickFighter(state: State, f: Fighter, dt: number)
	if #f.Bleeds > 0 then
		local total = 0
		for i = #f.Bleeds, 1, -1 do
			local bleed = f.Bleeds[i]
			total += bleed.PerSecond * math.min(dt, bleed.Remaining)
			bleed.Remaining -= dt
			if bleed.Remaining <= 0 then
				table.remove(f.Bleeds, i)
			end
		end
		if state.Time >= f.ShieldUntil then
			f.Hp -= total -- cracks ignore Sturdy; they're already in the glass
		end
	end
	for i = #f.Sticky, 1, -1 do
		f.Sticky[i] -= dt
		if f.Sticky[i] <= 0 then
			table.remove(f.Sticky, i)
		end
	end
	if f.Passive == "glow_core" and f.Hp > 0 then
		f.Hp = math.min(f.MaxHp, f.Hp + f.MaxHp * f.PassiveParams.HealPerSecond * dt)
	end
	if state.Time >= f.NextPowerAt then
		FightRules.triggerPower(state, f.Side)
	end
end

local function timeout(state: State)
	local a, b = state.Fighters[1], state.Fighters[2]
	local fa, fb = a.Hp / a.MaxHp, b.Hp / b.MaxHp
	local winner: number
	if fa == fb then
		winner = if state.Rng() < 0.5 then 1 else 2
	else
		winner = if fa > fb then 1 else 2
	end
	state.Over = true
	state.Winner = winner
	state.Reason = "Timeout"
	emit(state, { Type = "Shatter", Side = other(winner) })
	emit(state, { Type = "End", Winner = winner, Reason = "Timeout" })
end

-- Advances fight time by dt (call every server step while the glassies swing).
function FightRules.tick(state: State, dt: number)
	if state.Over or not finite(dt) or dt <= 0 then
		return
	end
	state.Time += dt
	for _, f in state.Fighters do
		tickFighter(state, f, dt)
	end
	resolveKnockouts(state, nil)
	if state.Over then
		return
	end
	if not state.InOvertime and state.Time > F.OvertimeAt then
		state.InOvertime = true
		emit(state, { Type = "Overtime" })
	end
	if state.Time >= F.RoundTimeout then
		timeout(state)
	end
end

-- Compact HP / charge / effect state for clients.
function FightRules.snapshot(state: State): { [string]: any }
	local out = { T = state.Time, Hp = {}, Power = {}, Shield = {}, Frozen = {}, Rage = {} }
	for side, f in state.Fighters do
		out.Hp[side] = math.max(f.Hp, 0)
		out.Power[side] = FightRules.powerProgress(state, side)
		out.Rage[side] = state.Time < f.RageUntil
		out.Shield[side] = FightRules.isShielded(state, side)
		out.Frozen[side] = FightRules.isFrozen(state, side)
	end
	return out
end

return FightRules
