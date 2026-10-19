-- Pure signature charge/cast state. FightRules remains the sole damage/HP/round authority.
local Balance = if script then require(script.Parent.Config.Balance) else require("./Config/Balance")
local K = Balance.CombatRelease
local Cast = K.Cast
local Geometry = if script then require(script.Parent.Config.ReleaseGeometry) else require("./Config/ReleaseGeometry")
local Signatures = {}
local Traits = if script then require(script.Parent.SignatureTraits) else require("./SignatureTraits")

function Signatures.new(state, fighter)
	local kit = K.Kits[fighter.Id]
	if not state.ReleaseKits or not kit then
		return
	end
	fighter.Signature = {
		Kit = kit,
		Charge = 0,
		GuardUntil = -1,
		ContactBonus = 0,
		NextReady = (kit.First or math.huge) + (kit.Jitter or 0) * state.Rng(),
		LastReady = 0,
		BusyUntil = -1,
		-- Optional cast (decision 85): "player", "bot", "smart", "auto" or "mash"; nil casts at once.
		Policy = if Cast.Enabled then fighter.CastPolicy else nil,
		Skill = fighter.CastSkill or 0,
		-- Cycle kits (Potion Flask): the brew order repeats from a random start each round.
		CycleOffset = if kit.Cycle then math.floor(state.Rng() * #kit.Cycle) else 0,
		CycleCount = 0,
	}
	fighter.Radius, fighter.BodyCenter = Geometry[fighter.Id].Radius, Geometry[fighter.Id].Center
	-- Legacy passives/specials remain available for dormant definitions and explicit legacy tests.
	fighter.Passive, fighter.NextPowerAt = "signature", math.huge
end

local function event(state, emit, side, kind, fields)
	local e = fields or {}
	e.Type, e.Side, e.Kit = kind, side, state.Fighters[side].Id
	emit(state, e)
end

local ARMS = { contact = true, slow_contact = true, mark_contact = true, armed_contact = true, drain_contact = true }

local function merged(kit, overrides)
	if not overrides then
		return kit
	end
	local out = table.clone(kit)
	for key, value in overrides do
		out[key] = value
	end
	return out
end

-- The next brew of a Cycle kit, as overrides with its index.
local function nextBrew(s)
	local cycle = s.Kit.Cycle
	local index = (s.CycleCount + s.CycleOffset) % #cycle + 1
	local brew = table.clone(cycle[index])
	brew.Brew = index
	return brew
end

-- Makes the power Ready for a side with a cast policy instead of casting it now.
local function hold(state, side, emit, overrides, arm)
	local f = state.Fighters[side]
	local s = f.Signature
	if s.Ready then
		return false
	end
	state.ReadySerial = (state.ReadySerial or 0) + 1
	local shape = overrides and overrides.Shape or s.Kit.Shape
	s.Ready = {
		Id = state.ReadySerial,
		Overrides = overrides,
		Arm = arm == true,
		Shape = shape,
		Since = state.Time,
		AutoAt = state.Time + Cast.AutoSeconds,
	}
	event(state, emit, side, "SignatureReady", {
		ReadyId = s.Ready.Id,
		AutoAt = s.Ready.AutoAt,
		Seconds = Cast.AutoSeconds,
		Shape = shape,
		Arm = arm == true,
		Brew = overrides and overrides.Brew,
		Next = overrides and overrides.Brew,
	})
	return true
end

-- release: nil = a trigger asked (hold it if this side has a policy); "manual"/"auto" = from Ready.
local function begin(state, side, emit, overrides, release)
	local f = state.Fighters[side]
	local s, kit = f.Signature, f.Signature.Kit
	if not release and s.Policy and s.Ready and not (overrides and (overrides.Instant or overrides.Reflection)) then
		return false
	end
	if overrides then
		kit = table.clone(kit)
		for key, value in overrides do
			kit[key] = value
		end
	end
	-- Instant (guard ripostes) and Priority (Phoenix rebirth) ignore busy time and cooldowns.
	local urgent = kit.Instant or kit.Priority or kit.Reflection
	if state.Over or f.Hp <= 0 or (state.Time < s.BusyUntil and not urgent) then
		return false
	end
	if kit.MaxCasts and (s.CastsStarted or 0) >= kit.MaxCasts then
		return false
	end
	if kit.HealBelow and (f.Hp / f.MaxHp > kit.HealBelow or state.Time >= Balance.Fight.OvertimeAt) then
		return false
	end
	if s.HasCast and not urgent and state.Time < s.LastReady + math.max(K.MinCastSeconds, kit.Cooldown or 0) then
		return false
	end
	if not release and s.Policy and not kit.Reflection and not kit.Instant then
		return hold(state, side, emit, overrides)
	end
	state.CastSerial += 1
	local cast = {
		Id = state.CastSerial,
		Side = side,
		Kit = f.Id,
		Shape = kit.Shape,
		Start = state.Time,
		Release = state.Time + kit.Windup,
		Params = kit,
		Manual = release == "manual",
	}
	s.Charge, s.LastReady = 0, state.Time
	s.HasCast = true
	s.CastsStarted = (s.CastsStarted or 0) + 1
	s.BusyUntil = cast.Release + (kit.Hold or 0) + kit.Duration
	s.NextReady = state.Time + (kit.Interval or math.huge) + (kit.Jitter or 0) * state.Rng()
	table.insert(state.PendingCasts, cast)
	event(state, emit, side, "CastStart", {
		CastId = cast.Id,
		Windup = kit.Windup + (kit.Hold or 0),
		Shape = kit.Shape,
		ReleaseAt = cast.Release,
		Pulses = kit.Pulses,
		Manual = cast.Manual,
		Held = release ~= nil,
		Brew = kit.Brew,
		Rebirth = kit.IsRebirth,
		Riposte = kit.IsRiposte,
	})
	if kit.Brew then
		s.CycleCount += 1
	end
	if kit.IsRebirth and s.Kit.Then then
		-- Phoenix: after the rebirth flare its normal power upgrades for the rest of the round.
		local after = merged(s.Kit, s.Kit.Then)
		after.Then = nil
		s.Kit = after
	end
	return true
end

-- Ready contact-payoff kits arm instead: the next contact within ArmedSeconds pays off.
local function arm(state, side, emit, manual, overrides)
	local f = state.Fighters[side]
	local s = f.Signature
	local kit = merged(s.Kit, overrides)
	s.HasCast, s.LastReady = true, state.Time
	s.CastsStarted = (s.CastsStarted or 0) + 1
	if kit.Brew then
		s.CycleCount += 1
	end
	if kit.Shape == "armed_contact" then
		s.ContactBonus, s.Charge = kit.ContactBonus, kit.Every or 1
		s.ArmExpiry = state.Time + Cast.ArmedSeconds
	else
		s.Armed = { Until = state.Time + Cast.ArmedSeconds, Kit = kit }
		if kit.Trigger ~= "contact" then
			s.Charge = 0
		end
	end
	event(
		state,
		emit,
		side,
		"SignatureArmed",
		{ Seconds = Cast.ArmedSeconds, Manual = manual, Shape = kit.Shape, Brew = kit.Brew }
	)
end

-- Light Bulb: the next clash steals part of the foe's charge. A foe that is Ready, winding up or
-- armed is immune, so tapping your own CAST is the counter.
local function drain(state, side, fraction, emit)
	local foe = state.Fighters[3 - side]
	local fs = foe.Signature
	if not fs or fs.Ready or fs.Armed or state.Time < fs.BusyUntil or fs.ContactBonus > 0 then
		return
	end
	local before = Signatures.progress(state, foe) or 0
	local k = fs.Kit
	if k.Trigger == "timer" then
		local span = math.max(0.01, fs.NextReady - fs.LastReady)
		local p = math.clamp((state.Time - fs.LastReady) / span, 0, 1) * (1 - fraction)
		fs.LastReady = state.Time - p * span
		fs.NextReady = fs.LastReady + span
	elseif k.Trigger == "stored" then
		fs.Stored = (fs.Stored or 0) * (1 - fraction)
		fs.Charge = math.min(1, fs.Stored / (foe.MaxHp * k.StoreCap))
	elseif k.Shape == "seed_contact" then
		fs.Seeds = math.max(0, (fs.Seeds or 0) - 1)
	elseif k.Every then
		fs.Charge = math.floor(fs.Charge * (1 - fraction))
	end
	local after = Signatures.progress(state, foe) or 0
	event(state, emit, side, "SignatureStatus", { Kind = "Drain", Target = foe.Side, Amount = before - after })
end

-- A contact-payoff power that is charged: Ready for a cast policy, armed at once otherwise.
local function chargedArm(state, side, emit, overrides)
	if state.Fighters[side].Signature.Policy then
		hold(state, side, emit, overrides, true)
	else
		arm(state, side, emit, false, overrides)
	end
end

-- Phoenix: dropping under Rebirth.Threshold makes the rebirth flare Ready (once), replacing any
-- normal Ready power.
local function rebirth(state, f, emit)
	local s = f.Signature
	s.Reborn = true
	if s.Ready then
		local id = s.Ready.Id
		s.Ready = nil
		event(state, emit, f.Side, "ReadyCancel", { ReadyId = id })
	end
	local o = table.clone(s.Kit.Rebirth)
	o.Threshold, o.Priority, o.IsRebirth = nil, true, true
	begin(state, f.Side, emit, o)
end

-- The player (or a bot/tool policy) asks to cast the Ready power. Applied on the next tick.
function Signatures.requestCast(state, side)
	local f = state.Fighters[side]
	local s = f and f.Signature
	if state.Over or not s or not s.Ready or s.Ready.Requested then
		return false
	end
	s.Ready.Requested = true
	return true
end

function Signatures.ready(f)
	return f.Signature and f.Signature.Ready
end

function Signatures.armed(state, f)
	local s = f.Signature
	return s ~= nil and s.Policy ~= nil and s.Armed ~= nil and state.Time < s.Armed.Until
end

function Signatures.damaged(state, target, amount, kind, emit)
	local s = target.Signature
	if
		s
		and s.Kit.Rebirth
		and not s.Reborn
		and target.Hp > 0
		and target.Hp / target.MaxHp <= s.Kit.Rebirth.Threshold
	then
		rebirth(state, target, emit)
	end
	if s and s.Kit.Trigger == "heavy" and (s.Policy or s.Kit.Shape ~= "armed_contact") then
		-- A big body hit: armed counters (Mason Jar) get Ready to arm; any other shape (Fishbowl) casts.
		if kind == "body" and target.Hp > 0 and amount >= target.MaxHp * s.Kit.Threshold then
			if s.Kit.Shape ~= "armed_contact" then
				begin(state, target.Side, emit)
			elseif s.ContactBonus <= 0 then
				hold(state, target.Side, emit, nil, true)
			end
		end
		return
	end
	Traits.damaged(state, target, amount, kind, emit, begin)
end

function Signatures.slow(state, source, target, kit, emit)
	Traits.slow(state, source, target, kit, emit)
end

function Signatures.turnaround(state, side, emit)
	if state.Over then
		return
	end
	local f = state.Fighters[side]
	local s = f and f.Signature
	if not s then
		return
	end
	Traits.turnaround(state, side, emit, begin)
	if s.Kit.Trigger ~= "turnaround" or state.Time < s.BusyUntil or (s.Policy and s.Ready) then
		return
	end
	if
		s.Kit.HealBelow
		and (
			f.Hp / f.MaxHp > s.Kit.HealBelow
			or state.Time >= Balance.Fight.OvertimeAt
			or (s.CastsStarted or 0) >= (s.Kit.MaxCasts or math.huge)
		)
	then
		return
	end
	if s.Kit.Shape == "armed_contact" and s.Charge >= s.Kit.Every then
		return
	end
	s.Charge = math.min(s.Kit.Every, s.Charge + 1)
	event(
		state,
		emit,
		side,
		"Charge",
		{ Count = s.Charge, Total = s.Kit.Every, Next = if s.Kit.Cycle then nextBrew(s).Brew else nil }
	)
	if s.Charge >= s.Kit.Every then
		if s.Kit.Cycle then
			local brew = nextBrew(s)
			if ARMS[brew.Shape] then
				chargedArm(state, side, emit, brew)
			else
				begin(state, side, emit, brew)
			end
		elseif s.Kit.Shape == "armed_contact" then
			if s.Policy then
				hold(state, side, emit, nil, true)
			else
				s.ContactBonus = s.Kit.ContactBonus
			end
		else
			begin(state, side, emit)
		end
	end
end

function Signatures.beforeContact(state, emit, point)
	Traits.beforeContact(state, emit, point)
	for side, f in state.Fighters do
		local s = f.Signature
		if not s then
			continue
		end
		s.Rebound = 1
		if s.Armed then
			-- Armed by a cast: this contact pays off if it came in time.
			local kit = s.Armed.Kit or s.Kit
			if state.Time < s.Armed.Until then
				if kit.Shape == "drain_contact" then
					s.ContactBonus = kit.ContactBonus or 0
					state.CastSerial += 1
					event(
						state,
						emit,
						side,
						"SignatureContact",
						{ CastId = state.CastSerial, Shape = "drain_contact", Point = point }
					)
					drain(state, side, kit.Drain, emit)
				elseif kit.Shape == "contact" then
					s.ContactBonus, s.Rebound = kit.ContactBonus, kit.Rebound
					state.CastSerial += 1
					event(
						state,
						emit,
						side,
						"SignatureContact",
						{ CastId = state.CastSerial, Shape = "contact", Point = point }
					)
					s.Charge = 0
				else
					-- Utility payoffs (slow, mark) may also carry a little contact damage.
					s.ContactBonus = kit.ContactBonus or 0
					Traits.contact(state, side, point, emit, kit)
				end
			end
			s.Armed = nil
		elseif
			s.Kit.Trigger == "contact"
			and state.Time >= s.BusyUntil
			and not s.EchoPoint
			and not (s.Policy and s.Ready)
		then
			s.Charge = math.min(s.Kit.Every, s.Charge + 1)
			event(state, emit, side, "Charge", { Count = s.Charge, Total = s.Kit.Every })
			if s.Charge >= s.Kit.Every then
				if s.Kit.Shape == "drain_contact" then
					chargedArm(state, side, emit)
				elseif s.Policy and ARMS[s.Kit.Shape] then
					hold(state, side, emit, nil, true)
				elseif s.Kit.Shape == "contact" then
					s.ContactBonus, s.Rebound = s.Kit.ContactBonus, s.Kit.Rebound
					state.CastSerial += 1
					event(
						state,
						emit,
						side,
						"SignatureContact",
						{ CastId = state.CastSerial, Shape = "contact", Point = point }
					)
					s.Charge = 0
				elseif not Traits.contact(state, side, point, emit) then
					begin(state, side, emit)
				end
			end
		elseif s.ContactBonus > 0 then
			state.CastSerial += 1
			event(
				state,
				emit,
				side,
				"SignatureContact",
				{ CastId = state.CastSerial, Shape = "armed_contact", Point = point }
			)
		end
	end
end

function Signatures.afterContact(state)
	for _, f in state.Fighters do
		local s = f.Signature
		if s and s.ContactBonus > 0 then
			s.ContactBonus, s.Charge = 0, 0
		end
	end
	Traits.afterContact(state)
end

function Signatures.mitigate(state, target, amount, kind, emit)
	amount = Traits.mirror(state, target, amount, kind, emit, begin)
	local s = target.Signature
	if s and kind == "body" and amount > 0 and state.Time < s.GuardUntil then
		local attacker = state.Fighters[3 - target.Side].Signature
		if attacker and attacker.Kit.PierceGuard and attacker.ContactBonus > 0 then
			-- Glass Unicorn's empowered clash breaks straight through a guard.
			s.GuardUntil = -1
			event(state, emit, 3 - target.Side, "SignatureStatus", { Kind = "Pierce", Target = target.Side })
			return amount
		end
		s.GuardUntil = -1
		event(state, emit, target.Side, "SignatureBlock", { Amount = amount * s.Kit.Mitigation })
		if s.Kit.Riposte then
			-- Grizzly Guardian roars back the moment its guard blocks a clash.
			local o = table.clone(s.Kit.Riposte)
			o.Instant, o.IsRiposte = true, true
			begin(state, target.Side, emit, o)
		end
		return amount * (1 - s.Kit.Mitigation)
	end
	return amount
end

local function releaseReady(state, emit)
	for side, f in state.Fighters do
		local s = f.Signature
		local r = s and s.Ready
		if not r then
			if s and s.Armed and state.Time >= s.Armed.Until then
				s.Armed, s.Charge = nil, 0
				event(state, emit, side, "SignatureStatus", { Kind = "ArmedFade" })
			end
			continue
		end
		if state.Over or f.Hp <= 0 then
			s.Ready = nil
			event(state, emit, side, "ReadyCancel", { ReadyId = r.Id })
		elseif r.Requested or state.Time >= r.AutoAt then
			local how = if r.Requested then "manual" else "auto"
			s.Ready = nil
			local overrides = r.Overrides
			if overrides and overrides.FromStored then
				-- Piggy Bank: the savings are read when you cast, so waiting lets them fill up.
				overrides = table.clone(overrides)
				overrides.Damage = math.min(s.Kit.Damage, (s.Stored or 0) / f.Power)
				s.Stored, s.Charge = 0, 0
			end
			if r.Arm then
				arm(state, side, emit, how == "manual", overrides)
			elseif not begin(state, side, emit, overrides, how) then
				event(state, emit, side, "ReadyCancel", { ReadyId = r.Id })
			end
		end
	end
end

function Signatures.tick(state, emit)
	releaseReady(state, emit)
	Traits.tick(state, emit)
	for side, f in state.Fighters do
		local s = f.Signature
		if s and s.Kit.Trigger == "timer" and state.Time >= s.NextReady then
			begin(state, side, emit)
		end
	end
	table.sort(state.PendingCasts, function(a, b)
		return if a.Release == b.Release then a.Id < b.Id else a.Release < b.Release
	end)
	local waiting = {}
	for _, cast in state.PendingCasts do
		if state.Time < cast.Release then
			table.insert(waiting, cast)
			continue
		end
		local f = state.Fighters[cast.Side]
		if
			cast.Params.Hold
			and state.CanReleaseCast
			and state.Time < cast.Release + cast.Params.Hold
			and not state.CanReleaseCast(cast)
		then
			table.insert(waiting, cast)
			continue
		end
		if state.Over or f.Hp <= 0 then
			continue
		end
		if cast.Params.HealBelow and state.Time >= Balance.Fight.OvertimeAt then
			continue
		end
		f.PowerTriggers += 1
		if cast.Params.SelfHeal and state.Time < Balance.Fight.OvertimeAt then
			local before = f.Hp
			f.Hp = math.min(f.MaxHp, f.Hp + f.MaxHp * cast.Params.SelfHeal)
			event(state, emit, cast.Side, "SignatureStatus", { Kind = "Heal", Amount = f.Hp - before })
		end
		if cast.Shape == "guard" then
			f.Signature.GuardUntil = state.Time + cast.Params.Duration
			event(state, emit, cast.Side, "CastRelease", {
				CastId = cast.Id,
				Shape = cast.Shape,
				Duration = cast.Params.Duration,
			})
		elseif Traits.selfRelease(state, cast, emit) then
			event(state, emit, cast.Side, "CastRelease", {
				CastId = cast.Id,
				Shape = cast.Shape,
				Duration = cast.Params.Duration,
				PierceGuard = cast.Params.PierceGuard, -- Glass Unicorn's dash
			})
		else
			state.AbilityResults[cast.Id] = cast
			table.insert(state.CastRequests, cast)
		end
	end
	state.PendingCasts = waiting
end

function Signatures.progress(state, f)
	local s = f.Signature
	if not s then
		return nil
	end
	if s.Ready or (s.Policy and s.Armed) then
		return 1
	end
	if s.Kit.MaxCasts and (s.CastsStarted or 0) >= s.Kit.MaxCasts then
		return 0
	end
	if s.Kit.Trigger == "timer" then
		return math.clamp((state.Time - s.LastReady) / math.max(0.01, s.NextReady - s.LastReady), 0, 1)
	end
	if s.Kit.Trigger == "threshold" then
		local list = s.Kit.Thresholds or { s.Kit.Threshold }
		local index = (s.ThresholdIndex or 0) + 1
		local next, previous = list[index], list[index - 1] or 1
		return if s.Used or not next
			then 0
			else math.clamp((previous - f.Hp / f.MaxHp) / math.max(0.01, previous - next), 0, 1)
	end
	if s.Kit.Shape == "seed_contact" then
		return (s.Seeds or 0) / s.Kit.MaxSeeds
	end
	return s.Charge / (s.Kit.Every or 1)
end

function Signatures.cancel(state)
	state.PendingCasts, state.CastRequests, state.AbilityResults = {}, {}, {}
	for _, f in state.Fighters do
		if f.Signature then
			f.Signature.Ready, f.Signature.Armed = nil, nil
		end
	end
end

return Signatures
