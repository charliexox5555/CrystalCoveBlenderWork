-- Concept abilities: powers that change the fight instead of adding numbers to a hit. Each one builds up in
-- plain sight, gets bigger as the round goes on and moves the glass or the arena. Numbers: Balance.Concepts.
-- Server only; the client draws them from the "Concept" events in Presentation/ConceptFX.
local Shared = if script then game.ReplicatedStorage.Shared else nil
local Rules = if Shared then require(Shared.FightRules) else require("../../shared/FightRules")
local Balance = if Shared then require(Shared.Config.Balance) else require("../../shared/Config/Balance")
local Geometry = if script then require(script.Parent.AttackGeometry) else require("./AttackGeometry")
local V = if script then Vector3 else require("@lune/roblox").Vector3
local C, M, F = Balance.Concepts, Balance.Motion, Balance.Fight
local Kits = {}

local function array(v)
	return { v.X, v.Y, v.Z }
end

local function say(sim, side, action, fields)
	local e = fields or {}
	e.Type, e.Side, e.Action, e.Time = "Concept", side, action, sim.Fight.Time
	e.Kit = sim.Fight.Fighters[side].Id
	table.insert(sim.MotionEvents, e)
end

local function hitRadius(sim, side, extra)
	return sim.Fight.Fighters[side].Radius * M.GlassyScale + extra
end

function Kits.new(sim)
	sim.Concept = { Effect = { {}, {} }, Shots = {} }
	for side, f in sim.Fight.Fighters do
		local kit = C.Enabled and C.Kits[f.Id]
		if kit then
			sim.Concept[side] = {
				Kit = kit,
				Id = f.Id,
				Count = 0,
				Casts = 0,
				NextAt = kit.First or math.huge,
				Stacks = 0,
				Cubes = {},
				Cooldowns = {},
			}
		end
	end
end

-- What integrate applies to a body this step; written fresh by Kits.step.
function Kits.effect(sim, side)
	return sim.Concept and sim.Concept.Effect[side]
end

function Kits.turnaround(sim, side)
	local s = sim.Concept and sim.Concept[side]
	if s and s.Id == "glass_cup" and s.Stacks < s.Kit.MaxStacks then
		s.Stacks += 1
		say(sim, side, "Wind", { Stacks = s.Stacks, Max = s.Kit.MaxStacks })
	end
end

local function popBlast(sim, side, s, center, predict)
	local kit = s.Kit
	s.Casts += 1
	s.Count = 0
	local origin = center(sim, side)
	local aim = predict(sim, 3 - side, kit.ShotAimSeconds)
	local direction = (aim - origin).Unit
	s.JetUntil, s.JetDirection = sim.Fight.Time + kit.JetSeconds, direction
	table.insert(sim.Concept.Shots, {
		Side = side,
		Kind = "Cap",
		Position = origin,
		Velocity = direction * kit.ShotSpeed,
		Life = kit.ShotLife,
		Radius = kit.ShotRadius,
		Damage = kit.ShotDamage,
		Push = kit.ShotPush,
	})
	say(sim, side, "Blast", {
		Origin = array(origin),
		Direction = array(direction),
		Speed = kit.ShotSpeed,
		Life = kit.ShotLife,
		Next = kit.Pressure[math.min(s.Casts + 1, #kit.Pressure)],
	})
end

local function glue(sim, side, s)
	s.Count = 0
	s.GlueUntil = sim.Fight.Time + s.Kit.GlueSeconds
	s.NextTick = sim.Fight.Time + s.Kit.TickSeconds
	s.ReadyAt = s.GlueUntil + s.Kit.Cooldown
	say(sim, side, "Glue", { Seconds = s.Kit.GlueSeconds })
end

local function splatBurst(sim, side, s, center)
	s.Count = 0
	local target = center(sim, 3 - side)
	local dealt = Rules.conceptDamage(sim.Fight, side, s.Kit.BurstDamage)
	sim.Bodies[3 - side].V += (target - center(sim, side)).Unit * s.Kit.BurstPush
	s.SlowUntil = sim.Fight.Time + s.Kit.SlowSeconds
	say(sim, side, "Burst", { Point = array(target), Amount = dealt })
end

local function raiseTide(sim, side, s)
	if s.WaveAt then
		return
	end
	s.Count = math.min(s.Count + 1, #s.Kit.Levels)
	sim.Concept.Water = { Owner = side, Y = s.Kit.Levels[s.Count] }
	say(sim, side, "Tide", { Level = s.Count, Y = s.Kit.Levels[s.Count], Max = #s.Kit.Levels })
	if s.Count >= #s.Kit.Levels then
		s.WaveAt = sim.Fight.Time + s.Kit.WaveDelay
		say(sim, side, "WaveWarn", { Delay = s.Kit.WaveDelay })
	end
end

-- Called once per qualifying body clash. Blocked hits still build pressure: the clash happened.
function Kits.hit(sim)
	if not sim.Concept or sim.Fight.Over then
		return
	end
	for side = 1, 2 do
		local s = sim.Concept[side]
		if not s then
			continue
		end
		if s.Id == "pop" then
			s.Count += 1
			local needed = s.Kit.Pressure[math.min(s.Casts + 1, #s.Kit.Pressure)]
			say(sim, side, "Pressure", { Count = s.Count, Needed = needed })
			if s.Count >= needed then
				s.PendingBlast = true
			end
		elseif s.Id == "jam" then
			if sim.Fight.Time >= (s.ReadyAt or 0) and sim.Fight.Time >= (s.GlueUntil or 0) then
				s.Count = math.min(s.Count + 1, s.Kit.Blobs)
				say(sim, side, "Blob", { Count = s.Count, Max = s.Kit.Blobs })
				if s.Count >= s.Kit.Blobs then
					glue(sim, side, s)
				end
			end
		elseif s.Id == "water_jug" then
			raiseTide(sim, side, s)
		elseif s.Id == "mason_jar" then
			s.Count += 1
			s.PendingFlies = math.min(s.Kit.MaxPerClash, math.ceil(s.Count / s.Kit.ClashesPerFly))
		elseif s.Id == "crystal_tumbler" then
			if sim.Fight.Time >= (s.ReadyAt or 0) then
				s.ReadyAt = sim.Fight.Time + s.Kit.Cooldown
				s.PendingCube = true
			end
		elseif s.Id == "ketchup_bottle" then
			s.Count += 1
			say(sim, side, "Splat", { Count = s.Count, Max = s.Kit.Splats })
			if s.Count >= s.Kit.Splats then
				s.PendingBurst = true
			end
		end
	end
end

local function fireRays(sim, side, s, center, predict)
	local kit = s.Kit
	s.Casts += 1
	local count = kit.Rays[math.min(s.Casts, #kit.Rays)]
	local origin = center(sim, side)
	local base = (predict(sim, 3 - side, 0.05) - origin).Unit
	local radius = hitRadius(sim, 3 - side, kit.RayRadius)
	local target = center(sim, 3 - side)
	local rays, hits = {}, 0
	for i = 1, count do
		local angle = (i - (count + 1) / 2) * kit.RaySpread
		local c, n = math.cos(angle), math.sin(angle)
		-- Fan in the stand plane so every ray is visible from the fixed camera.
		local direction = V.new(base.X * c - base.Y * n, base.X * n + base.Y * c, base.Z).Unit
		local landed = Geometry.segmentSphere(origin, origin + direction * kit.Range, target, radius)
		if landed then
			hits += 1
		end
		rays[i] = { direction.X, direction.Y, direction.Z, landed == true }
	end
	say(sim, side, "Rays", { Origin = array(origin), Rays = rays, Range = kit.Range, Cast = s.Casts })
	if hits > 0 then
		local dealt = Rules.conceptDamage(sim.Fight, side, kit.RayDamage * hits)
		say(sim, side, "RaysHit", { Point = array(target), Amount = dealt, Hits = hits })
	end
end

local function squeeze(sim, side, s, center, predict)
	local kit = s.Kit
	s.Casts += 1
	local count = kit.Drops[math.min(s.Casts, #kit.Drops)]
	local origin = center(sim, side)
	local aim = predict(sim, 3 - side, kit.DropFlight)
	local drops = {}
	for i = 1, count do
		local jitter = V.new(
			(sim.Rng() * 2 - 1) * kit.DropSpread,
			(sim.Rng() * 2 - 1) * kit.DropSpread,
			(sim.Rng() * 2 - 1) * kit.DropSpread * 0.4
		)
		local velocity = (aim + jitter - origin) / kit.DropFlight - V.new(0, -kit.DropGravity, 0) * (kit.DropFlight / 2)
		local delay = (i - 1) * kit.DropGap
		table.insert(sim.Concept.Shots, {
			Side = side,
			Kind = "Drop",
			Position = origin,
			Velocity = velocity,
			Gravity = kit.DropGravity,
			Life = kit.DropFlight * 1.6,
			Radius = kit.DropRadius,
			Damage = kit.DropDamage,
			Delay = delay,
		})
		drops[i] = { velocity.X, velocity.Y, velocity.Z, delay }
	end
	say(
		sim,
		side,
		"Squeeze",
		{ Origin = array(origin), Drops = drops, Gravity = kit.DropGravity, Life = kit.DropFlight * 1.6 }
	)
end

local function stepShots(sim, dt, center)
	local kept = {}
	for _, shot in sim.Concept.Shots do
		if sim.Fight.Over then
			break
		end
		if shot.Delay and shot.Delay > 0 then
			shot.Delay -= dt
			table.insert(kept, shot)
			continue
		end
		local before = shot.Position
		if shot.Gravity then
			shot.Velocity += V.new(0, -shot.Gravity, 0) * dt
		end
		if shot.Homing then
			local toward = center(sim, 3 - shot.Side) - shot.Position
			if toward.Magnitude > 0.01 then
				shot.Velocity = shot.Velocity:Lerp(toward.Unit * shot.Homing, math.min(1, dt * shot.Turn))
			end
		end
		shot.Position += shot.Velocity * dt
		shot.Life -= dt
		local foe = 3 - shot.Side
		local target = center(sim, foe)
		local radius = hitRadius(sim, foe, shot.Radius)
		if Geometry.movingSphere(before, shot.Position, target, target, radius) then
			local dealt = Rules.conceptDamage(sim.Fight, shot.Side, shot.Damage)
			if shot.Push then
				sim.Bodies[foe].V += shot.Velocity.Unit * shot.Push
			end
			say(sim, shot.Side, shot.Kind .. "Hit", { Point = array(target), Amount = dealt })
			if shot.Kind == "Drop" then
				local s = sim.Concept[shot.Side]
				if s then
					s.Count += 1
					say(sim, shot.Side, "Splat", { Count = s.Count, Max = s.Kit.Splats })
					if s.Count >= s.Kit.Splats then
						s.PendingBurst = true
					end
				end
			end
		elseif shot.Life > 0 then
			table.insert(kept, shot)
		elseif shot.Kind == "Cap" then
			say(sim, shot.Side, "CapMiss", {})
		end
	end
	sim.Concept.Shots = if sim.Fight.Over then {} else kept
end

local function rain(sim, side, s, center, predict)
	local kit = s.Kit
	s.Casts += 1
	local count = kit.Drops[math.min(s.Casts, #kit.Drops)]
	local aim = predict(sim, 3 - side, kit.FallSeconds)
	local drops = {}
	for i = 1, count do
		local x = aim.X + (i - (count + 1) / 2) * kit.Spacing
		local origin = V.new(x, kit.StartY, aim.Z)
		local velocity = V.new(0, -kit.FallSpeed, 0)
		local delay = (i - 1) * kit.Gap
		table.insert(sim.Concept.Shots, {
			Side = side,
			Kind = "Pickle",
			Position = origin,
			Velocity = velocity,
			Gravity = kit.Gravity,
			Life = kit.FallSeconds * 1.6,
			Radius = kit.DropRadius,
			Damage = kit.DropDamage,
			Delay = delay,
		})
		drops[i] = { origin.X, origin.Y, origin.Z, velocity.X, velocity.Y, velocity.Z, delay }
	end
	say(sim, side, "Rain", { Drops = drops, Gravity = kit.Gravity, Life = kit.FallSeconds * 1.6 })
end

local function releaseFlies(sim, side, s, center)
	local kit = s.Kit
	local count = s.PendingFlies
	s.PendingFlies = nil
	local origin = center(sim, side)
	for _ = 1, count do
		local spread = V.new(sim.Rng() * 2 - 1, sim.Rng() * 2 - 1, (sim.Rng() * 2 - 1) * 0.3).Unit
		table.insert(sim.Concept.Shots, {
			Side = side,
			Kind = "Fly",
			Position = origin,
			Velocity = spread * kit.FlySpeed,
			Homing = kit.FlySpeed,
			Turn = kit.FlyTurn,
			Life = kit.FlyLife,
			Radius = kit.FlyRadius,
			Damage = kit.FlyDamage,
		})
	end
	say(sim, side, "Flies", { Origin = array(origin), Count = count, Speed = kit.FlySpeed, Life = kit.FlyLife })
end

local function placeCube(sim, side, s, center)
	local kit = s.Kit
	s.PendingCube = false
	s.Serial = (s.Serial or 0) + 1
	local mid = (center(sim, side) + center(sim, 3 - side)) / 2
	local point = mid + V.new((sim.Rng() * 2 - 1) * kit.Scatter, (sim.Rng() * 2 - 1) * kit.Scatter, 0)
	table.insert(s.Cubes, { Id = s.Serial, Point = point, ArmAt = sim.Fight.Time + kit.ArmSeconds })
	say(sim, side, "Cube", { Id = s.Serial, Point = array(point), Arm = kit.ArmSeconds })
	if #s.Cubes > kit.MaxCubes then
		say(sim, side, "CubeGone", { Id = table.remove(s.Cubes, 1).Id })
	end
end

local function stepCubes(sim, side, s, center, effect)
	local kit = s.Kit
	local foe = 3 - side
	local target = center(sim, foe)
	local radius = hitRadius(sim, foe, kit.CubeRadius)
	for i = #s.Cubes, 1, -1 do
		local cube = s.Cubes[i]
		if sim.Fight.Time >= cube.ArmAt and (cube.Point - target).Magnitude <= radius then
			table.remove(s.Cubes, i)
			local dealt = Rules.conceptDamage(sim.Fight, side, kit.CubeDamage)
			s.SlowUntil = sim.Fight.Time + kit.SlowSeconds
			say(sim, side, "CubeHit", { Id = cube.Id, Point = array(cube.Point), Amount = dealt })
		end
	end
	if sim.Fight.Time < (s.SlowUntil or -1) then
		effect[foe].Amp = kit.SlowAmp
	end
end

local function stepZest(sim, side, s, center)
	local kit = s.Kit
	if sim.Fight.Time >= s.NextAt and s.Stacks < kit.MaxSlices then
		s.Stacks += 1
		s.NextAt = sim.Fight.Time + kit.Interval
		say(sim, side, "Zest", { Count = s.Stacks, Speed = kit.OrbitSpeed, Distance = kit.OrbitDistance })
	end
	if s.Stacks == 0 then
		return
	end
	local owner, target = center(sim, side), center(sim, 3 - side)
	local radius = hitRadius(sim, 3 - side, kit.SliceRadius)
	for i = 1, s.Stacks do
		local angle = sim.Fight.Time * kit.OrbitSpeed + (i - 1) * 2 * math.pi / s.Stacks
		local point = owner + V.new(math.cos(angle), math.sin(angle), 0) * kit.OrbitDistance
		if (point - target).Magnitude <= radius and sim.Fight.Time >= (s.Cooldowns[i] or 0) then
			s.Cooldowns[i] = sim.Fight.Time + kit.SliceCooldown
			local dealt = Rules.conceptDamage(sim.Fight, side, kit.SliceDamage)
			say(sim, side, "ZestHit", { Point = array(point), Amount = dealt })
			if sim.Fight.Over then
				return
			end
		end
	end
end

local function stepHeat(sim, side, s, center)
	local kit = s.Kit
	if sim.Fight.Time >= s.NextAt and s.Stacks < kit.MaxHeat then
		s.Stacks += 1
		s.NextAt = sim.Fight.Time + kit.Interval
		s.NextTick = s.NextTick or sim.Fight.Time + kit.TickSeconds
		say(
			sim,
			side,
			"Heat",
			{ Stacks = s.Stacks, Max = kit.MaxHeat, Radius = kit.BaseRadius + kit.RadiusPerHeat * s.Stacks }
		)
	end
	if s.Stacks == 0 or sim.Fight.Time < s.NextTick then
		return
	end
	s.NextTick = sim.Fight.Time + kit.TickSeconds
	local target = center(sim, 3 - side)
	local reach = kit.BaseRadius + kit.RadiusPerHeat * s.Stacks + hitRadius(sim, 3 - side, 0)
	if (target - center(sim, side)).Magnitude <= reach then
		local dealt = Rules.conceptDamage(sim.Fight, side, kit.TickDamage * s.Stacks)
		say(sim, side, "Burn", { Point = array(target), Amount = dealt })
	end
end

local function stepTopUp(sim, side, s)
	local kit, f = s.Kit, sim.Fight.Fighters[side]
	if sim.Fight.Time < s.NextAt then
		return
	end
	-- Never during overtime, so a refill can't hold a round open forever.
	if sim.Fight.Time >= F.OvertimeAt or f.Hp / f.MaxHp > kit.HealBelow then
		s.NextAt = sim.Fight.Time + kit.RetrySeconds
		return
	end
	s.Casts += 1
	s.NextAt = sim.Fight.Time + kit.Interval
	local amount = Rules.conceptHeal(sim.Fight, side, f.MaxHp * kit.Heals[math.min(s.Casts, #kit.Heals)])
	say(sim, side, "TopUp", { Healed = amount, Cast = s.Casts })
end

function Kits.step(sim, dt, center, predict)
	local concept = sim.Concept
	if not concept then
		return
	end
	local now = sim.Fight.Time
	local effect = concept.Effect
	table.clear(effect[1])
	table.clear(effect[2])
	for side = 1, 2 do
		local s = concept[side]
		if not s or sim.Fight.Over then
			continue
		end
		local foe = 3 - side
		local kit = s.Kit
		if s.Id == "pop" then
			if s.PendingBlast then
				s.PendingBlast = false
				popBlast(sim, side, s, center, predict)
			end
			if now < (s.JetUntil or -1) then
				effect[side].Force = s.JetDirection * kit.JetForce
			end
		elseif s.Id == "jam" then
			effect[foe].Amp = 1 - kit.BlobSlow * s.Count
			if now < (s.GlueUntil or -1) then
				local pull = center(sim, side) - center(sim, foe)
				if pull.Magnitude > 0.1 then
					effect[foe].Force = pull.Unit * kit.GlueForce
					effect[side].Force = -pull.Unit * kit.GlueForce * kit.GlueSelf
				end
				if now >= s.NextTick then
					s.NextTick = now + kit.TickSeconds
					local at = center(sim, foe)
					local dealt = Rules.conceptDamage(sim.Fight, side, kit.TickDamage)
					say(sim, side, "GlueTick", { Point = array(at), Amount = dealt })
				end
			elseif s.GlueUntil then
				s.GlueUntil = nil
				effect[foe].Amp = 1
				say(sim, side, "GlueEnd", {})
			end
		elseif s.Id == "prism" then
			if now >= s.NextAt and not s.ChargingUntil then
				s.ChargingUntil = now + kit.Windup
				local count = kit.Rays[math.min(s.Casts + 1, #kit.Rays)]
				say(sim, side, "Charge", { Seconds = kit.Windup, Rays = count })
			end
			if s.ChargingUntil and now >= s.ChargingUntil then
				s.ChargingUntil, s.NextAt = nil, now + kit.Interval
				fireRays(sim, side, s, center, predict)
			end
		elseif s.Id == "glass_cup" then
			local boost = s.Stacks * kit.EnergyPerStack
			effect[side].Energy = 1 + boost
			effect[side].Drive = 1 + s.Stacks * kit.DrivePerStack
		elseif s.Id == "water_jug" then
			if s.WaveAt and now >= s.WaveAt then
				s.WaveAt = nil
				s.Wave = { Start = now, Done = false }
				say(sim, side, "Wave", { Seconds = kit.WaveSeconds, Top = kit.WaveTop })
			end
			if s.Wave then
				local t = (now - s.Wave.Start) / kit.WaveSeconds
				local here = center(sim, foe)
				local from = if side == 1 then -kit.WaveWidth else kit.WaveWidth
				local x = from + (-from * 2) * t
				local passed = if side == 1 then x >= here.X else x <= here.X
				if passed and not s.Wave.Done then
					s.Wave.Done = true
					if here.Y <= kit.WaveTop then
						local dealt = Rules.conceptDamage(sim.Fight, side, kit.WaveDamage)
						sim.Bodies[foe].V += V.new(if side == 1 then kit.WavePush else -kit.WavePush, kit.WaveLift, 0)
						say(sim, side, "WaveHit", { Point = array(here), Amount = dealt })
					else
						say(sim, side, "WaveDodge", { Point = array(here) })
					end
				end
				if t >= 1 then
					s.Wave, s.Count = nil, 1
					concept.Water = { Owner = side, Y = kit.Levels[1] }
					say(sim, side, "Tide", { Level = 1, Y = kit.Levels[1], Max = #kit.Levels })
				end
			end
			local water = concept.Water
			if water and center(sim, foe).Y < water.Y then
				effect[foe].Drag = kit.WaterDrag
				effect[foe].Amp = kit.WaterAmp
			end
		elseif s.Id == "milk_bottle" then
			stepTopUp(sim, side, s)
		elseif s.Id == "pickle_jar" then
			if now >= s.NextAt then
				s.NextAt = now + kit.Interval
				rain(sim, side, s, center, predict)
			end
		elseif s.Id == "lemonade_bottle" then
			stepZest(sim, side, s, center)
		elseif s.Id == "mason_jar" then
			if s.PendingFlies then
				releaseFlies(sim, side, s, center)
			end
		elseif s.Id == "crystal_tumbler" then
			if s.PendingCube then
				placeCube(sim, side, s, center)
			end
			stepCubes(sim, side, s, center, effect)
		elseif s.Id == "hot_sauce" then
			stepHeat(sim, side, s, center)
		elseif s.Id == "ketchup_bottle" then
			if now >= s.NextAt then
				s.NextAt = now + kit.Interval
				squeeze(sim, side, s, center, predict)
			end
			if s.PendingBurst then
				s.PendingBurst = false
				splatBurst(sim, side, s, center)
			end
			if now < (s.SlowUntil or -1) then
				effect[foe].Amp = kit.SlowAmp
			end
		end
	end
	stepShots(sim, dt, center)
end

return Kits
