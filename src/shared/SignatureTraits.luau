-- Bounded storage, one-shot thresholds and statuses. All HP changes remain in FightRules.
local Balance = if script then require(script.Parent.Config.Balance) else require("./Config/Balance")
local Traits = {}

local function status(state, emit, side, kind, fields)
	local e = fields or {}
	e.Type, e.Side, e.Kit, e.Kind = "SignatureStatus", side, state.Fighters[side].Id, kind
	emit(state, e)
end

function Traits.slow(state, source, target, kit, emit)
	local s = target.Signature
	if not s or state.Time < (s.SlowImmuneUntil or -1) then
		return
	end
	s.Slow = math.max(Balance.CombatRelease.SlowFloor, kit.Slow)
	s.SlowUntil = state.Time + kit.StatusSeconds
	s.SlowImmuneUntil = s.SlowUntil + kit.Immunity
	status(state, emit, source.Side, "Slow", { Target = target.Side, Seconds = kit.StatusSeconds })
end

function Traits.damaged(state, target, amount, kind, emit, begin)
	local s = target.Signature
	if not s or amount <= 0 or target.Hp <= 0 then
		return
	end
	local kit = s.Kit
	if kit.Trigger == "threshold" and not s.Used and target.Hp / target.MaxHp <= kit.Threshold then
		s.Used = true
		begin(state, target.Side, emit)
	elseif kit.Trigger == "heavy" and kind == "body" and amount >= target.MaxHp * kit.Threshold then
		s.NextContactBonus, s.ArmExpiry = kit.ContactBonus, state.Time + kit.Duration
		status(state, emit, target.Side, "Counter", { Seconds = kit.Duration })
	elseif kit.Trigger == "received" and kind == "body" and state.Time >= s.BusyUntil then
		s.Charge = math.min(kit.Every, s.Charge + 1)
		emit(state, { Type = "Charge", Side = target.Side, Kit = target.Id, Count = s.Charge, Total = kit.Every })
	elseif kit.Trigger == "stored" then
		s.Stored = math.min(target.MaxHp * kit.StoreCap, (s.Stored or 0) + amount * kit.StoreFraction)
		s.Charge = math.min(1, s.Stored / (target.MaxHp * kit.StoreCap))
		emit(state, { Type = "Charge", Side = target.Side, Kit = target.Id, Count = s.Charge, Total = 1 })
	end
end

function Traits.turnaround(state, side, emit, begin)
	local f = state.Fighters[side]
	local s, kit = f.Signature, f.Signature.Kit
	if state.Time < s.BusyUntil then
		return
	end
	if kit.Trigger == "received" and s.Charge >= kit.Every then
		begin(state, side, emit)
	elseif kit.Trigger == "stored" and (s.Stored or 0) > 0 then
		local stored = s.Stored
		s.Stored = 0
		begin(state, side, emit, { Damage = math.min(kit.Damage, stored / f.Power) })
	elseif kit.Shape == "echo_contact" and s.EchoPoint then
		local origin = s.EchoPoint
		s.EchoPoint = nil
		begin(state, side, emit, { Shape = "projectile", StoredOrigin = origin })
	end
end

function Traits.beforeContact(state, emit, point)
	state.ContactExtra = { 0, 0 }
	for side, f in state.Fighters do
		local s = f.Signature
		if not s then
			continue
		end
		if state.Time >= (s.ArmExpiry or math.huge) then
			s.ContactBonus, s.Charge, s.ArmExpiry = 0, 0, nil
		end
		if s.BoostUntil and state.Time < s.BoostUntil then
			s.ContactBonus = s.Kit.ContactBonus
			if not s.Kit.ContinuousBonus then
				s.BoostUntil = -1
			end
		end
		if s.Mark and state.Time < s.Mark.Until then
			local owner = state.Fighters[s.Mark.Source]
			state.ContactExtra[side] = owner.Power * s.Mark.Damage
			emit(
				state,
				{ Type = "SignatureContact", Side = owner.Side, Kit = owner.Id, Shape = "splat", Point = point }
			)
		end
		s.Mark = nil
	end
end

function Traits.contact(state, side, point, emit)
	local f, target = state.Fighters[side], state.Fighters[3 - side]
	local s, kit = f.Signature, f.Signature.Kit
	if kit.Shape == "slow_contact" then
		Traits.slow(state, f, target, kit, emit)
	elseif kit.Shape == "mark_contact" then
		if target.Signature then
			target.Signature.Mark = { Source = side, Damage = kit.MarkDamage, Until = state.Time + kit.StatusSeconds }
		end
		status(state, emit, side, "Mark", { Target = target.Side, Seconds = kit.StatusSeconds })
	elseif kit.Shape == "echo_contact" then
		if s.EchoPoint then
			return
		end
		s.EchoPoint, s.EchoUntil = point or { 0, 0, 0 }, state.Time + kit.StoreSeconds
		status(state, emit, side, "Echo", { Point = s.EchoPoint, Seconds = kit.StoreSeconds })
	else
		return false
	end
	s.Charge = 0
	return true
end

function Traits.afterContact(state)
	for _, f in state.Fighters do
		local s = f.Signature
		if s and s.NextContactBonus then
			s.ContactBonus, s.Charge, s.NextContactBonus = s.NextContactBonus, 1, nil
		end
	end
end

function Traits.mirror(state, target, amount, kind, emit, begin)
	local s = target.Signature
	if not s or kind ~= "ranged" or state.Time >= (s.MirrorUntil or -1) or amount <= 0 then
		return amount
	end
	s.MirrorUntil, s.BusyUntil = -1, state.Time
	local kit = s.Kit
	begin(state, target.Side, emit, {
		Shape = "ray",
		Reflection = true,
		Windup = kit.ReturnWindup,
		Duration = Balance.CombatRelease.ReflectionSeconds,
	})
	status(state, emit, target.Side, "MirrorCatch", { Amount = amount * kit.Mitigation })
	return amount * (1 - kit.Mitigation)
end

function Traits.selfRelease(state, cast, emit)
	local f = state.Fighters[cast.Side]
	local s, p = f.Signature, cast.Params
	if cast.Shape == "heal" then
		local before = f.Hp
		f.Hp = math.min(f.MaxHp, f.Hp + f.MaxHp * p.Heal)
		status(state, emit, cast.Side, "Heal", { Amount = f.Hp - before, Seconds = p.Duration })
	elseif cast.Shape == "boost" then
		s.BoostUntil = state.Time + p.Duration
		status(state, emit, cast.Side, "Boost", { Seconds = p.Duration })
	elseif cast.Shape == "mirror" then
		s.MirrorUntil = state.Time + p.Duration
		status(state, emit, cast.Side, "Mirror", { Seconds = p.Duration })
	else
		return false
	end
	return true
end

function Traits.tick(state, emit)
	for side, f in state.Fighters do
		local s = f.Signature
		if not s then
			continue
		end
		if s.ArmExpiry and state.Time >= s.ArmExpiry then
			s.ContactBonus, s.Charge, s.ArmExpiry = 0, 0, nil
		end
		if s.EchoUntil and state.Time >= s.EchoUntil then
			s.EchoPoint, s.EchoUntil = nil, nil
		end
		if s.Mark and state.Time >= s.Mark.Until then
			s.Mark = nil
		end
		if s.MirrorUntil and s.MirrorUntil > 0 and state.Time >= s.MirrorUntil then
			s.MirrorUntil, s.ContactBonus, s.Charge = -1, s.Kit.ContactBonus, 1
			s.ArmExpiry = state.Time + Balance.CombatRelease.CounterSeconds
			status(state, emit, side, "Counter", { Seconds = Balance.CombatRelease.CounterSeconds })
		end
	end
end

return Traits
