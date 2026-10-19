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

local ARMS = { contact = true, slow_contact = true, mark_contact = true, armed_contact = true }

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
	})
	return true
end

-- release: nil = a trigger asked (hold it if this side has a policy); "manual"/"auto" = from Ready.
local function begin(state, side, emit, overrides, release)
	local f = state.Fighters[side]
	local s, kit = f.Signature, f.Signature.Kit
	if not release and s.Policy and s.Ready then
		return false
	end
	if overrides then
		kit = table.clone(kit)
		for key, value in overrides do
			kit[key] = value
		end
	end
	if state.Over or f.Hp <= 0 or state.Time < s.BusyUntil then
		return false
	end
	if kit.MaxCasts and (s.CastsStarted or 0) >= kit.MaxCasts then
		return false
	end
	if kit.HealBelow and (f.Hp / f.MaxHp > kit.HealBelow or state.Time >= Balance.Fight.OvertimeAt) then
		return false
	end
	if
		s.HasCast
		and not kit.Reflection
		and state.Time < s.LastReady + math.max(K.MinCastSeconds, kit.Cooldown or 0)
	then
		return false
	end
	if not release and s.Policy and not kit.Reflection then
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
	})
	return true
end

-- Ready contact-payoff kits arm instead: the next contact within ArmedSeconds pays off.
local function arm(state, side, emit, manual)
	local f = state.Fighters[side]
	local s, kit = f.Signature, f.Signature.Kit
	s.HasCast, s.LastReady = true, state.Time
	s.CastsStarted = (s.CastsStarted or 0) + 1
	if kit.Shape == "armed_contact" then
		s.ContactBonus, s.Charge = kit.ContactBonus, 1
		s.ArmExpiry = state.Time + Cast.ArmedSeconds
	else
		s.Armed = { Until = state.Time + Cast.ArmedSeconds }
	end
	event(state, emit, side, "SignatureArmed", { Seconds = Cast.ArmedSeconds, Manual = manual, Shape = kit.Shape })
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
	if s and s.Policy and s.Kit.Trigger == "heavy" then
		-- A big body hit makes the counter Ready; the next contact after arming pays it back.
		if kind == "body" and target.Hp > 0 and amount >= target.MaxHp * s.Kit.Threshold and s.ContactBonus <= 0 then
			hold(state, target.Side, emit, nil, true)
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
	event(state, emit, side, "Charge", { Count = s.Charge, Total = s.Kit.Every })
	if s.Charge >= s.Kit.Every then
		if s.Kit.Shape == "armed_contact" then
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
		if s.Policy and s.Armed then
			-- Armed by a cast: this contact pays off if it came in time.
			if state.Time < s.Armed.Until then
				if s.Kit.Shape == "contact" then
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
				else
					Traits.contact(state, side, point, emit)
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
				if s.Policy and ARMS[s.Kit.Shape] then
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
		s.GuardUntil = -1
		event(state, emit, target.Side, "SignatureBlock", { Amount = amount * s.Kit.Mitigation })
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
			if r.Arm then
				arm(state, side, emit, how == "manual")
			elseif not begin(state, side, emit, r.Overrides, how) then
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
		if cast.Shape == "guard" then
			f.Signature.GuardUntil = state.Time + cast.Params.Duration
			event(
				state,
				emit,
				cast.Side,
				"CastRelease",
				{ CastId = cast.Id, Shape = cast.Shape, Duration = cast.Params.Duration }
			)
		elseif Traits.selfRelease(state, cast, emit) then
			event(
				state,
				emit,
				cast.Side,
				"CastRelease",
				{ CastId = cast.Id, Shape = cast.Shape, Duration = cast.Params.Duration }
			)
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
		return if s.Used then 0 else math.clamp((1 - f.Hp / f.MaxHp) / (1 - s.Kit.Threshold), 0, 1)
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
