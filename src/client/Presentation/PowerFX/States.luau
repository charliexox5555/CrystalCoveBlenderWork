-- Ready aura, cast flourish and armed look: the same language on every kit, tinted per kit, stronger by tier.
-- Workstream B owns the screen layer for these moments (hitstop, shake, FOV, popup, edge, sounds).
local States = {}

local function mine(fx, side)
	local view = fx.Scene.Feel and fx.Scene.Feel.View
	if not view then
		return true -- previews and harnesses
	end
	return view.Participant == true and view.Side == side
end
States.mine = mine

-- Ready -------------------------------------------------------------------------------------------------------------
function States.ready(fx, e)
	local side = e.Side
	local f = fx:Fighter(side)
	local R = fx.C.Ready
	local id = e.ReadyId or e.Time
	if fx.Ready[side] and fx.Ready[side].Id == id then
		return
	end
	local now = fx:Time()
	local autoAt = e.AutoAt or (e.Time + (e.Seconds or 2.5))
	if now > autoAt then
		return
	end
	fx:StopKey("ready:" .. side)
	fx.Ready[side] = { Id = id, AutoAt = autoAt }
	if f.Motion then
		f.Motion:SetReady(true)
	end
	local color, accent = fx:Vivid(side), select(2, fx:Colors(side))
	if color == accent then
		accent = Color3.new(1, 1, 1)
	end
	local tier = fx:Tier(side)
	local low = fx:Low(side)
	local parts = {}
	local halo = fx:Part(if tier == "Crisp" then "Ring" else "ShockCrown", color)
	local inner = fx:Part("Ring", accent)
	table.insert(parts, halo)
	table.insert(parts, inner)
	local orbiters = {}
	for i = 1, (if low then 0 else R.Orbiters[tier] or 0) do
		local p = fx:Part(if tier == "Hero" then "NovaStar" else "CrystalChip", if i % 2 == 0 then accent else color)
		fx:Fit(p, R.OrbiterSize * (if tier == "Hero" then 1.25 else 1))
		orbiters[i] = p
		table.insert(parts, p)
	end
	local ground
	if tier == "Hero" and not low then
		ground = fx:Part("ShockCrown", color)
		table.insert(parts, ground)
	end
	local phase, last, nextSparkle = 0, nil, 0
	fx:Spawn({
		Side = side,
		Key = "ready:" .. side,
		Seconds = (autoAt - now) + 0.6,
		Parts = parts,
		Stop = function()
			if not fx.Armed[side] then
				fx:OutlineOff(side)
			end
		end,
		Step = function(_, age, _, time)
			if f.Broken or f.Finishing then
				return false
			end
			local pos, size = fx:Body(side)
			local remaining = autoAt - time
			local span = math.max(0.1, e.Seconds or 2.5)
			local urgency = 1 - math.clamp(remaining / span, 0, 1)
			local dt = if last then math.max(0, time - last) else 0
			last = time
			phase += dt * (R.PulseHzStart + (R.PulseHzEnd - R.PulseHzStart) * urgency) * math.pi * 2
			local pulse = (1 + math.sin(phase)) / 2
			local tighten = fx.smooth((R.TightenSeconds - remaining) / R.TightenSeconds)
			local intro = fx.pop(age / 0.22)
			local scale = size * R.HaloScale * (1 + pulse * R.HaloPulse) * (1 - tighten * (1 - R.TightenScale)) * intro
			local camera = workspace.CurrentCamera.CFrame
			local behind = pos + camera.LookVector * size * 0.45
			fx:Fit(halo, scale)
			halo.CFrame = CFrame.new(behind) * camera.Rotation * CFrame.Angles(0, 0, age * R.SpinHz * math.pi * 2)
			halo.Transparency = R.HaloTransparency + (1 - pulse) * 0.3 - tighten * 0.15
			fx:Fit(inner, scale * 0.78)
			inner.CFrame = CFrame.new(behind) * camera.Rotation * CFrame.Angles(0, 0, -age * R.SpinHz * math.pi * 3)
			inner.Transparency = 0.45 + (1 - pulse) * 0.4
			fx:Outline(side, color, R.OutlineTransparency + (1 - pulse) * R.OutlinePulse - tighten * 0.2)
			for i, p in orbiters do
				local a = age * R.OrbitHz * math.pi * 2 * (1 + urgency) + i / #orbiters * math.pi * 2
				local r = size * R.OrbitScale * (1 - tighten * 0.25)
				local offset = camera.RightVector * math.cos(a) * r
					+ camera.UpVector * math.sin(a) * r * 0.45
					+ camera.LookVector * math.sin(a) * r * 0.5
				p.CFrame = CFrame.new(pos + offset) * camera.Rotation * CFrame.Angles(0, 0, a * 2)
				p.Transparency = 0.05 + (1 - intro) * 0.9
			end
			if ground then
				local floor = fx:Ground(pos)
				fx:Fit(ground, R.GroundRadius * 2 * (1 + pulse * 0.1) * intro)
				ground.CFrame = CFrame.new(pos.X, floor.Y, pos.Z) * CFrame.Angles(math.pi / 2, 0, age)
				ground.Transparency = 0.35 + (1 - pulse) * 0.35
			end
			if (tier == "Epic" or tier == "Hero") and not low and age >= nextSparkle then
				nextSparkle = age + R.SparkleEvery
				fx:Glints(side, pos + Vector3.new(0, -size * 0.3, 0), accent, 1, {
					Speed = NumberRange.new(1.5, 3),
					Accel = Vector3.new(0, 4, 0),
					Spread = Vector2.new(35, 35),
				})
			end
		end,
	})
end

function States.clearReady(fx, side)
	fx.Ready[side] = nil
	local f = fx:Fighter(side)
	if f and f.Motion then
		f.Motion:SetReady(false)
	end
	fx:StopKey("ready:" .. side)
end

-- Cast flourish -----------------------------------------------------------------------------------------------------
-- Manual: a kit-coloured starburst with light (the other side's at OtherScale). Auto: a plain thin ring.
function States.flourish(fx, e)
	local side = e.Side
	local caster = fx:Fighter(side)
	if caster and caster.Motion then
		caster.Motion:Cast(e.Manual == true, e.Time)
	end
	local Cc = fx.C.Cast
	local color, accent = fx:Vivid(side), select(2, fx:Colors(side))
	local pos = fx:Body(side)
	local at = function()
		return (fx:Body(side))
	end
	if e.Manual == true then
		local s = if mine(fx, side) then 1 else Cc.OtherScale
		fx:Flash(side, at, color, Cc.ManualFlash * s, Cc.ManualSeconds * 0.45)
		fx:Ring(side, at, color, 1, Cc.ManualRing * s, Cc.ManualSeconds, { Kind = "ShockCrown", Spin = 3, Alpha = 0 })
		fx:Ring(side, at, accent, 0.6, Cc.ManualRing * s * 0.6, Cc.ManualSeconds * 0.8, { Spin = -4, Delay = 0.04 })
		fx:Spokes(side, at, accent, Cc.ManualSpokes, Cc.ManualSpokeLength * s, Cc.ManualSeconds * 0.75, {
			Alternate = color,
			Width = 0.38,
		})
		fx:Glints(side, pos, accent, 16)
		fx:Light(side, at, color, Cc.ManualSeconds, fx.C.Light.Brightness * 1.4)
		-- SFX: B's manual-cast riser + chime already plays here.
	else
		fx:Ring(side, at, color, 0.8, Cc.AutoRing, Cc.AutoSeconds, { Alpha = 0.3 })
		fx:Glints(side, pos, color, Cc.AutoGlints)
	end
end

-- Armed -------------------------------------------------------------------------------------------------------------
function States.armed(fx, e, kitArmed)
	local side = e.Side
	local f = fx:Fighter(side)
	local A = fx.C.Armed
	local seconds = e.Seconds or 3
	local untilTime = e.Time + seconds
	if fx:Time() > untilTime then
		return
	end
	local color, accent = fx:Vivid(side), select(2, fx:Colors(side))
	local rank = fx:Rank(side)
	local bands = { fx:Part("Ring", color) }
	if rank >= 2 or not fx:Low(side) then
		table.insert(bands, fx:Part("Ring", accent))
	end
	local nextCrackle = 0
	fx:StopKey("armed:" .. side)
	fx.Armed[side] = { Until = untilTime }
	fx:Spawn({
		Side = side,
		Key = "armed:" .. side,
		Start = e.Time,
		Seconds = seconds,
		Parts = bands,
		Stop = function()
			fx.Armed[side] = nil
			if not fx.Ready[side] then
				fx:OutlineOff(side)
			end
		end,
		Step = function(_, age, k)
			if f.Broken or f.Finishing then
				return false
			end
			local pos, size = fx:Body(side)
			local intro = fx.pop(age / 0.2)
			local flicker = if (seconds - age) < A.FlickerSeconds then (math.sin(age * 40) > 0 and 1 or 0.35) else 1
			for i, p in bands do
				fx:Fit(p, size * A.BandScale * intro * (if i == 2 then 0.85 else 1))
				local spin = age * A.BandHz * math.pi * 2 * (if i == 2 then -1.3 else 1)
				p.CFrame = CFrame.new(pos)
					* CFrame.Angles(A.BandTilt * (if i == 2 then -1 else 1), spin, 0)
					* CFrame.Angles(math.pi / 2, 0, 0)
				p.Transparency = 1 - (if i == 1 then 0.85 else 0.6) * flicker
			end
			fx:Outline(side, color, A.OutlineTransparency + (1 - flicker) * 0.6)
			if age >= nextCrackle then
				nextCrackle = age + A.CrackleEvery
				fx:Glints(side, pos, accent, 2, { Speed = NumberRange.new(2, 4) })
			end
			if kitArmed then
				kitArmed(fx, side, age, k, pos, size)
			end
		end,
	})
end

function States.disarm(fx, side, fizzle)
	if not fx.Armed[side] and not fizzle then
		return
	end
	fx:StopKey("armed:" .. side)
	fx:StopKey("armedkit:" .. side)
	if fizzle then
		local color = fx:Colors(side)
		local pos, size = fx:Body(side)
		fx:Ring(side, pos, color, size * 1.1, size * 0.3, fx.C.Armed.FadeSeconds, { Ease = "in", Alpha = 0.4 })
		fx:Chips(
			side,
			pos,
			color,
			5,
			1.5,
			fx.C.Armed.FadeSeconds * 1.4,
			{ Kind = "CrystalChip", Size = 0.25, Up = -1, Gravity = 10 }
		)
	end
end

return States
