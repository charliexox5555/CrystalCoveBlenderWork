-- Pure signature charge/cast state. FightRules remains the sole damage/HP/round authority.
local Balance = if script then require(script.Parent.Config.Balance) else require("./Config/Balance")
local K = Balance.CombatRelease
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

local function begin(state, side, emit, overrides)
	local f = state.Fighters[side]
	local s, kit = f.Signature, f.Signature.Kit
	if overrides then
		kit = table.clone(kit)
		for key, value in overrides do
			kit[key] = value
		end
	end
	if state.Over or f.Hp <= 0 or state.Time < s.BusyUntil then
		return false
	end
	if s.HasCast and not kit.Reflection and state.Time < s.LastReady + K.MinCastSeconds then
		return false
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
	}
	s.Charge, s.LastReady = 0, state.Time
	s.HasCast = true
	s.BusyUntil = cast.Release + (kit.Hold or 0) + kit.Duration
	s.NextReady = state.Time + (kit.Interval or math.huge) + (kit.Jitter or 0) * state.Rng()
	table.insert(state.PendingCasts, cast)
	event(
		state,
		emit,
		side,
		"CastStart",
		{ CastId = cast.Id, Windup = kit.Windup + (kit.Hold or 0), Shape = kit.Shape, ReleaseAt = cast.Release }
	)
	return true
end

function Signatures.damaged(state, target, amount, kind, emit)
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
	if s.Kit.Trigger ~= "turnaround" or state.Time < s.BusyUntil then
		return
	end
	if s.Kit.Shape == "armed_contact" and s.Charge >= s.Kit.Every then
		return
	end
	s.Charge = math.min(s.Kit.Every, s.Charge + 1)
	event(state, emit, side, "Charge", { Count = s.Charge, Total = s.Kit.Every })
	if s.Charge >= s.Kit.Every then
		if s.Kit.Shape == "armed_contact" then
			s.ContactBonus = s.Kit.ContactBonus
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
		if s.Kit.Trigger == "contact" and state.Time >= s.BusyUntil and not s.EchoPoint then
			s.Charge = math.min(s.Kit.Every, s.Charge + 1)
			event(state, emit, side, "Charge", { Count = s.Charge, Total = s.Kit.Every })
			if s.Charge >= s.Kit.Every then
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

function Signatures.tick(state, emit)
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
	if s.Kit.Trigger == "timer" then
		return math.clamp((state.Time - s.LastReady) / math.max(0.01, s.NextReady - s.LastReady), 0, 1)
	end
	if s.Kit.Trigger == "threshold" then
		return if s.Used then 0 else math.clamp((1 - f.Hp / f.MaxHp) / (1 - s.Kit.Threshold), 0, 1)
	end
	return s.Charge / (s.Kit.Every or 1)
end

function Signatures.cancel(state)
	state.PendingCasts, state.CastRequests, state.AbilityResults = {}, {}, {}
end

return Signatures
