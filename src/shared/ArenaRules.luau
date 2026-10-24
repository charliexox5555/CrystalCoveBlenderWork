--!strict
-- The arena layer of a round (decision 122, docs/design/ROUND_REVAMP.md): glints both glassies race for,
-- the Heat (HEATING UP, then MELTDOWN = overtime), one arena twist per round, PUSH charges and Last Glass.
-- Pure and deterministic like FightRules, which owns the state (`state.Arena`) and calls in. The swing
-- (Pendulum) answers the geometry: it places requested glints, reports grabs and applies the motion
-- (`drainImpulses`, `force`, `restitution`, bumpers). Without a swing (the stand-in simulator) glints are
-- grabbed by chance.
--
-- Events: Twist, Heat {Stage 1 | 2}, GlintSpawn, GlintGrab, GlintFade, GlintBlock, BombArm, BombPop, Push, Gust.

local Balance = if script then require(script.Parent.Config.Balance) else require("./Config/Balance")
local A = Balance.Arena
local G = A.Glints

local ArenaRules = {}

export type Glint = { Id: number, Kind: string, Point: { number }?, Until: number }

local function weighted(rng: () -> number, entries: { [string]: any }, skip: string?): string
	local names = {}
	for name in entries do
		if name ~= skip then
			table.insert(names, name)
		end
	end
	table.sort(names) -- table order is not deterministic
	local total = 0
	for _, name in names do
		total += entries[name].Weight
	end
	local roll = rng() * total
	for _, name in names do
		roll -= entries[name].Weight
		if roll <= 0 then
			return name
		end
	end
	return names[#names]
end

-- The twist for a new round (MatchLogic.startRound). Never the same as `last`.
function ArenaRules.rollTwist(rng: () -> number, last: string?): string
	return weighted(rng, A.Twists, last)
end

-- Bumper post centres for a stand whose hooks are `gap` apart (the outer posts follow their hook).
function ArenaRules.posts(gap: number): { { number } }
	local out = {}
	local shift = (gap - Balance.Motion.HookGap) / 2
	for _, p in A.Twists.Bumpers.Posts do
		local x = if p[1] > 0.01 then p[1] + shift elseif p[1] < -0.01 then p[1] - shift else p[1]
		table.insert(out, { x, p[2], p[3] })
	end
	return out
end

function ArenaRules.twist(state: any): string
	return state.Arena and state.Arena.Twist or "Calm"
end

local function interval(state: any): number
	local arena = state.Arena
	local span = G.IntervalMin + (G.IntervalMax - G.IntervalMin) * state.Rng()
	if arena.Twist == "GlintRain" then
		span *= A.Twists.GlintRain.IntervalMult
	end
	if arena.Heat >= 1 then
		span *= A.Heat.WarmIntervalMult
	end
	return span
end

local function maxLive(state: any): number
	return if state.Arena.Twist == "GlintRain" then A.Twists.GlintRain.MaxLive else G.MaxLive
end

-- Applies a glint's effect to `side`. `start` = Last Glass (held from the release).
local function apply(state: any, side: number, kind: string, emit: (any, any) -> ())
	local f, foe = state.Fighters[side], state.Fighters[3 - side]
	local k = G.Kinds[kind]
	if kind == "Smash" then
		f.GlintSmash = true
	elseif kind == "Bubble" then
		f.GlintBubble = true
	elseif kind == "Patch" then
		local before = f.Hp
		f.Hp = math.min(f.MaxHp, f.Hp + f.MaxHp * k.Heal)
		return f.Hp - before
	elseif kind == "Bomb" then
		table.insert(state.Arena.Bombs, { Owner = side, Target = 3 - side, At = state.Time + k.Fuse })
		emit(state, { Type = "BombArm", Side = 3 - side, Owner = side, Seconds = k.Fuse })
	elseif kind == "Frost" then
		foe.GlintSlowUntil = state.Time + k.Seconds
	elseif kind == "Zoom" then
		table.insert(state.Arena.Impulses, { Side = side, Kind = "Zoom", Speed = k.Speed })
	end
	return nil
end

function ArenaRules.new(state: any, setup: any, emit: (any, any) -> ())
	local twist = setup.Twist
	if type(twist) ~= "string" or not A.Twists[twist] then
		twist = "Calm"
	end
	state.Arena = {
		Twist = twist,
		Heat = 0,
		Glints = {} :: { Glint },
		GlintSerial = 0,
		NextGlintAt = G.FirstAt,
		Requests = {} :: { Glint }, -- waiting for the swing to place them
		Bombs = {},
		Impulses = {},
		NextGust = if twist == "Windy" then A.Twists.Windy.IntervalMin else math.huge,
		Gust = nil :: any,
		Push = {},
	}
	emit(state, { Type = "Twist", Kind = twist })
	for side, f in state.Fighters do
		state.Arena.Push[side] = { Charges = A.Push.Charges, NextCharge = math.huge, ReadyAt = 0 }
		f.GlintSlowUntil = -1
		local fighterSetup = if side == 1 then setup.A else setup.B
		if fighterSetup.LastGlass then
			local kind = A.LastGlass[math.floor(state.Rng() * #A.LastGlass) + 1]
			apply(state, side, kind, emit)
			emit(state, { Type = "GlintGrab", Side = side, Kind = kind, LastGlass = true })
		end
	end
end

-- Damage multiplier for `attacker`'s next body hit (Smash). Consumed by `afterHit`.
function ArenaRules.hitMultiplier(state: any, attacker: any): number
	return if attacker.GlintSmash then G.Kinds.Smash.DamageMult else 1
end

function ArenaRules.afterHit(state: any)
	for _, f in state.Fighters do
		f.GlintSmash = nil
	end
end

-- A Bubble eats the next damage. Returns true if it blocked `target`'s damage.
function ArenaRules.block(state: any, target: any, emit: (any, any) -> ()): boolean
	if not target.GlintBubble then
		return false
	end
	target.GlintBubble = nil
	emit(state, { Type = "GlintBlock", Side = target.Side })
	return true
end

function ArenaRules.swingMultiplier(state: any, side: number): number
	local mult = 1
	if state.Time < (state.Fighters[side].GlintSlowUntil or -1) then
		mult *= G.Kinds.Frost.SwingMult
	end
	if state.InOvertime then
		mult *= A.Heat.MeltdownSwingMult
	end
	return mult
end

-- How hard `side` gets thrown in a contact (Bouncy twist). 1 = normal.
function ArenaRules.knockback(state: any): number
	return if ArenaRules.twist(state) == "Bouncy" then A.Twists.Bouncy.Knockback else 1
end

function ArenaRules.restitution(state: any): number
	return if ArenaRules.twist(state) == "Bouncy" then A.Twists.Bouncy.Restitution else Balance.Motion.Restitution
end

-- Extra force on `side`'s glassy (studs/s^2): wind gusts and the magnet. `toFoe` = vector to the other glass.
function ArenaRules.force(state: any, side: number, tx: number, ty: number, tz: number): (number, number, number)
	local arena = state.Arena
	if not arena or state.Over then
		return 0, 0, 0
	end
	local x, y, z = 0, 0, 0
	local gust = arena.Gust
	if gust and state.Time < gust.Until then
		x += gust.X
		z += gust.Z
	end
	if arena.Twist == "Magnet" then
		local m = A.Twists.Magnet
		local d = math.sqrt(tx * tx + ty * ty + tz * tz)
		if d > 0.01 and d <= m.Range then
			x += tx / d * m.Force
			y += ty / d * m.Force
			z += tz / d * m.Force
		end
	end
	return x, y, z
end

-- PUSH (decision 122). Validated here; the swing applies the shove from `drainImpulses`.
function ArenaRules.requestPush(state: any, side: number, emit: (any, any) -> ()): boolean
	local arena = state.Arena
	if state.Over or not arena or (side ~= 1 and side ~= 2) then
		return false
	end
	local push = arena.Push[side]
	-- A frozen glass can't push itself out of it.
	if push.Charges <= 0 or state.Time < push.ReadyAt or state.Time < state.Fighters[side].FrozenUntil then
		return false
	end
	push.Charges -= 1
	push.ReadyAt = state.Time + A.Push.Cooldown
	if push.NextCharge == math.huge then
		push.NextCharge = state.Time + A.Push.RechargeSeconds
	end
	table.insert(arena.Impulses, { Side = side, Kind = "Push", Speed = A.Push.Speed })
	emit(state, { Type = "Push", Side = side, Charges = push.Charges })
	return true
end

function ArenaRules.pushCharges(state: any, side: number): number
	return state.Arena and state.Arena.Push[side].Charges or 0
end

-- Shoves (Push, Zoom) for the swing to apply this step.
function ArenaRules.drainImpulses(state: any): { any }
	local list = state.Arena.Impulses
	state.Arena.Impulses = {}
	return list
end

-- Glints the swing should place now: call `placeGlint` with a point for each.
function ArenaRules.drainRequests(state: any): { Glint }
	local list = state.Arena.Requests
	state.Arena.Requests = {}
	return list
end

function ArenaRules.placeGlint(state: any, glint: Glint, point: { number }, emit: (any, any) -> ())
	glint.Point = point
	table.insert(state.Arena.Glints, glint)
	emit(state, {
		Type = "GlintSpawn",
		GlintId = glint.Id,
		Kind = glint.Kind,
		Point = point,
		Seconds = glint.Until - state.Time,
	})
end

function ArenaRules.glints(state: any): { Glint }
	return state.Arena and state.Arena.Glints or {}
end

-- `side` touched glint `id` (the swing decides who got there first).
function ArenaRules.grab(state: any, side: number, id: number, emit: (any, any) -> ()): boolean
	if state.Over then
		return false
	end
	for i, glint in state.Arena.Glints do
		if glint.Id == id then
			table.remove(state.Arena.Glints, i)
			local healed = apply(state, side, glint.Kind, emit)
			emit(state, { Type = "GlintGrab", Side = side, GlintId = id, Kind = glint.Kind, Amount = healed })
			return true
		end
	end
	return false
end

-- Bomb damage goes through FightRules' damage path (shields, guards, Bubble).
export type DamageFn = (owner: number, target: number, maxHpFraction: number) -> number

function ArenaRules.tick(state: any, emit: (any, any) -> (), damage: DamageFn)
	local arena = state.Arena
	if not arena or state.Over then
		return
	end
	local t = state.Time
	if arena.Heat < 1 and t >= A.Heat.WarmAt then
		arena.Heat = 1
		emit(state, { Type = "Heat", Stage = 1 })
	end
	if arena.Heat < 2 and t > Balance.Fight.OvertimeAt then
		arena.Heat = 2
		emit(state, { Type = "Heat", Stage = 2 })
	end
	for side, push in arena.Push do
		if t >= push.NextCharge then
			push.Charges = math.min(A.Push.Charges, push.Charges + 1)
			push.NextCharge = if push.Charges < A.Push.Charges then t + A.Push.RechargeSeconds else math.huge
			emit(state, { Type = "PushCharge", Side = side, Charges = push.Charges })
		end
	end
	if t >= arena.NextGust then
		local w = A.Twists.Windy
		local angle = state.Rng() * math.pi * 2
		-- Mostly across the stand's plane (Z), so swings go wild in 3D.
		arena.Gust = {
			X = math.cos(angle) * 0.4 * w.Force,
			Z = math.sin(angle) * w.Force,
			Until = t + w.GustSeconds,
		}
		arena.NextGust = t + w.IntervalMin + (w.IntervalMax - w.IntervalMin) * state.Rng()
		emit(state, { Type = "Gust", X = arena.Gust.X, Z = arena.Gust.Z, Seconds = w.GustSeconds })
	end
	for i = #arena.Glints, 1, -1 do
		local glint = arena.Glints[i]
		if t >= glint.Until then
			table.remove(arena.Glints, i)
			emit(state, { Type = "GlintFade", GlintId = glint.Id })
		elseif not state.CastsManaged and t >= glint.Until - G.Lifetime + G.SimGrabSeconds then
			-- Stand-in simulator: no positions, so roll who (if anyone) gets it.
			if state.Rng() < G.SimGrabChance then
				ArenaRules.grab(state, if state.Rng() < 0.5 then 1 else 2, glint.Id, emit)
			else
				glint.Until = t
			end
		end
	end
	if t >= arena.NextGlintAt then
		arena.NextGlintAt = t + interval(state)
		if #arena.Glints + #arena.Requests < maxLive(state) then
			arena.GlintSerial += 1
			local glint = { Id = arena.GlintSerial, Kind = weighted(state.Rng, G.Kinds), Until = t + G.Lifetime }
			table.insert(if state.CastsManaged then arena.Requests else arena.Glints, glint)
		end
	end
	for i = #arena.Bombs, 1, -1 do
		local bomb = arena.Bombs[i]
		if t >= bomb.At then
			table.remove(arena.Bombs, i)
			local amount = damage(bomb.Owner, bomb.Target, G.Kinds.Bomb.Damage)
			emit(state, { Type = "BombPop", Side = bomb.Target, Owner = bomb.Owner, Amount = amount })
			if state.Over then
				return
			end
		end
	end
end

-- Late joiners: what is live right now.
function ArenaRules.presentation(state: any): { any }
	local arena = state.Arena
	if not arena then
		return {}
	end
	local out = {
		{ Type = "Twist", Kind = arena.Twist, Time = state.Time },
		{ Type = "Heat", Stage = arena.Heat, Time = state.Time },
	}
	for _, glint in arena.Glints do
		if glint.Point then
			table.insert(out, {
				Type = "GlintSpawn",
				GlintId = glint.Id,
				Kind = glint.Kind,
				Point = glint.Point,
				Seconds = glint.Until - state.Time,
				Time = state.Time,
			})
		end
	end
	for side, push in arena.Push do
		table.insert(out, { Type = "PushCharge", Side = side, Charges = push.Charges, Time = state.Time })
	end
	for side, f in state.Fighters do
		if f.GlintSmash then
			table.insert(out, { Type = "GlintGrab", Side = side, Kind = "Smash", Held = true, Time = state.Time })
		end
		if f.GlintBubble then
			table.insert(out, { Type = "GlintGrab", Side = side, Kind = "Bubble", Held = true, Time = state.Time })
		end
	end
	return out
end

return ArenaRules
