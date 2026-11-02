-- Draws concept abilities (Simulation/ConceptKits) from server events. Local parts under the fight's folder.
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local Audio = require(RS.Shared.Config.Audio)
local FX = {}
FX.__index = FX

local COLORS = {
	pop = Color3.fromHex("#2E9BFF"),
	jam = Color3.fromHex("#FF8A1F"),
	prism = Color3.fromHex("#B583FF"),
	glass_cup = Color3.fromHex("#8CF53A"),
	water_jug = Color3.fromHex("#10CFC0"),
	ketchup_bottle = Color3.fromHex("#F2212F"),
	milk_bottle = Color3.fromHex("#FFF7E6"),
	pickle_jar = Color3.fromHex("#58A92C"),
	lemonade_bottle = Color3.fromHex("#FFD21F"),
	mason_jar = Color3.fromHex("#FFF27A"),
	crystal_tumbler = Color3.fromHex("#9FE8FF"),
	hot_sauce = Color3.fromHex("#FF6A14"),
}
local RAINBOW = {
	Color3.fromHex("#FF5A7A"),
	Color3.fromHex("#FFB23C"),
	Color3.fromHex("#FFF05C"),
	Color3.fromHex("#6BFF8A"),
	Color3.fromHex("#5CD6FF"),
	Color3.fromHex("#B583FF"),
}
local QUICK = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

function FX.new(scene)
	local root = Instance.new("Folder")
	root.Name = "Concepts"
	root.Parent = scene.Root
	return setmetatable({ Scene = scene, Root = root, Sides = { {}, {} }, Connections = {} }, FX)
end

function FX:World(a)
	return self.Scene.Frame:PointToWorldSpace(Vector3.new(a[1], a[2], a[3]))
end

function FX:Part(name, size, position, color, material, shape)
	local p = Instance.new("Part")
	p.Name, p.Size, p.Color = name, size, color
	p.Position = position
	p.Material = material or Enum.Material.SmoothPlastic
	p.Shape = shape or Enum.PartType.Block
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = true, false, false, false, false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = self.Root
	return p
end

function FX:Sound(id, side, pitch, volume)
	if self.Scene.Sound then
		self.Scene:Sound(id, self.Scene.Fighters[side].Body, pitch or 1, volume or 0.6)
	end
end

function FX:Ring(position, color, size, seconds)
	local ring = self:Part("Ring", Vector3.one * 0.5, position, color, Enum.Material.Neon, Enum.PartType.Ball)
	ring.Transparency = 0.25
	TweenService:Create(
		ring,
		TweenInfo.new(seconds or 0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.one * size, Transparency = 1 }
	):Play()
	Debris:AddItem(ring, (seconds or 0.4) + 0.05)
end

function FX:Burst(position, color, count, speed)
	local at = self:Part("Burst", Vector3.one * 0.2, position, color)
	at.Transparency = 1
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(color)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 0) })
	e.Lifetime = NumberRange.new(0.35, 0.8)
	e.Speed = NumberRange.new(speed * 0.5, speed)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Acceleration = Vector3.new(0, -30, 0)
	e.LightEmission, e.Rate, e.Parent = 0.4, 0, at
	e:Emit(if self.Scene.Viewing then count else math.ceil(count / 4))
	Debris:AddItem(at, 1.2)
end

function FX:Say(hud, text, position, color)
	if hud then
		hud:Popup(text, position + Vector3.yAxis * 3.6, color, 0, "Concept" .. text, 1.5)
	end
end

function FX:Number(hud, amount, position, color)
	if hud and amount and amount > 0 then
		hud:Popup(string.format("-%d", math.ceil(amount)), position, color, 1, "ConceptNumber", 1.25)
	end
end

function FX:Shake(amount)
	local feel = self.Scene.Feel
	if feel then
		feel:Shake(amount)
	end
end

function FX:Foe(side)
	return self.Scene.Fighters[3 - side]
end

-- Blobs (jam) and splats (ketchup) stuck on the rival, drawn on its glass and following it.
function FX:Stick(side, count, color)
	local state, foe = self.Sides[side], self:Foe(side)
	state.Stuck = state.Stuck or {}
	while #state.Stuck < count do
		local i = #state.Stuck + 1
		local blob = self:Part(
			"Stuck",
			Vector3.new(1.2, 1, 0.5),
			foe.Body.Position,
			color,
			Enum.Material.SmoothPlastic,
			Enum.PartType.Ball
		)
		local a = (i * 2.4) % (math.pi * 2)
		local half = foe.Body.Size * 0.42
		table.insert(
			state.Stuck,
			{ Part = blob, Offset = CFrame.new(math.cos(a) * half.X, math.sin(a) * half.Y * 0.7, half.Z * 0.7) }
		)
		blob.Size = Vector3.one * 0.1
		TweenService:Create(blob, QUICK, { Size = Vector3.new(1.3, 1.05, 0.6) }):Play()
	end
	while #state.Stuck > count do
		table.remove(state.Stuck).Part:Destroy()
	end
end

function FX:Strand(side, on)
	local state = self.Sides[side]
	if on and not state.Strand then
		local f, foe = self.Scene.Fighters[side], self:Foe(side)
		local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
		a0.Parent, a1.Parent = f.Body, foe.Body
		local beam = Instance.new("Beam")
		beam.Attachment0, beam.Attachment1 = a0, a1
		beam.Width0, beam.Width1, beam.FaceCamera = 1.1, 0.8, true
		beam.Color = ColorSequence.new(COLORS.jam)
		beam.CurveSize0, beam.CurveSize1 = 1.4, -1.4
		beam.LightEmission, beam.Parent = 0.2, f.Body
		state.Strand = { beam, a0, a1 }
	elseif not on and state.Strand then
		for _, item in state.Strand do
			item:Destroy()
		end
		state.Strand = nil
	end
end

function FX:Water(side, y, level)
	local state = self.Sides[side]
	local floorY = self.Scene.Frame.Position.Y - 15.35
	local worldY = self.Scene.Frame.Position.Y + y
	local height = math.max(0.2, worldY - floorY)
	if not state.Pool then
		local pool = self:Part(
			"TidePool",
			Vector3.new(0.2, 26.5, 26.5),
			Vector3.new(0, floorY, 0),
			COLORS.water_jug,
			Enum.Material.SmoothPlastic,
			Enum.PartType.Cylinder
		)
		pool.Transparency = 0.42
		pool.Reflectance = 0.12
		pool.CFrame = CFrame.new(self.Scene.Frame.Position.X, floorY, self.Scene.Frame.Position.Z)
			* CFrame.Angles(0, 0, math.pi / 2)
		state.Pool = pool
	end
	local here = self.Scene.Frame.Position
	TweenService:Create(state.Pool, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
		Size = Vector3.new(height, 26.5, 26.5),
		CFrame = CFrame.new(here.X, floorY + height / 2, here.Z) * CFrame.Angles(0, 0, math.pi / 2),
	}):Play()
	state.Level = level
end

function FX:Wave(side, e)
	local here = self.Scene.Frame
	local from = if side == 1 then -13 else 13
	local bottom = here.Position.Y - 15.35
	local top = here.Position.Y + e.Top
	local height = top - bottom
	local wave = self:Part(
		"Wave",
		Vector3.new(5, height, 25),
		here:PointToWorldSpace(Vector3.new(from, -15.35 + height / 2, 0)),
		COLORS.water_jug
	)
	wave.Transparency = 0.25
	local crest = self:Part(
		"WaveCrest",
		Vector3.new(6.2, 1.3, 25.5),
		wave.Position + Vector3.yAxis * (height / 2),
		Color3.new(1, 1, 1),
		Enum.Material.Neon
	)
	crest.Transparency = 0.1
	local info = TweenInfo.new(e.Seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	local move = here.RightVector * (-from * 2)
	TweenService:Create(wave, info, { Position = wave.Position + move }):Play()
	TweenService:Create(crest, info, { Position = crest.Position + move }):Play()
	Debris:AddItem(wave, e.Seconds + 0.1)
	Debris:AddItem(crest, e.Seconds + 0.1)
end

function FX:Rays(side, e)
	local origin = self:World(e.Origin)
	for i, r in e.Rays do
		local tip = origin + self.Scene.Frame:VectorToWorldSpace(Vector3.new(r[1], r[2], r[3])) * e.Range
		local color = RAINBOW[(i - 1) % #RAINBOW + 1]
		local mid = (origin + tip) / 2
		local width = if r[4] then 0.75 else 0.45
		local beam =
			self:Part("PrismRay", Vector3.new(width, width, (tip - origin).Magnitude), mid, color, Enum.Material.Neon)
		beam.CFrame = CFrame.lookAt(mid, tip)
		beam.Transparency = 0.05
		TweenService:Create(beam, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(0.05, 0.05, beam.Size.Z),
			Transparency = 1,
		}):Play()
		Debris:AddItem(beam, 0.55)
	end
	self:Ring(origin, Color3.new(1, 1, 1), 5, 0.3)
end

-- Thrown or falling pieces follow the same arc as the server's: start, velocity, gravity.
function FX:Toss(origin, velocity, gravity, life, delay, size, color, shape)
	task.delay(delay, function()
		if not self.Root.Parent then
			return
		end
		local piece =
			self:Part("ConceptShot", size, origin, color, Enum.Material.SmoothPlastic, shape or Enum.PartType.Ball)
		local turn = if shape then CFrame.Angles(0, 0, math.pi / 2) else CFrame.identity
		local born = os.clock()
		local connection
		connection = RunService.RenderStepped:Connect(function()
			local t = os.clock() - born
			if t > life or not piece.Parent then
				connection:Disconnect()
				piece:Destroy()
				return
			end
			piece.CFrame = CFrame.new(origin + velocity * t + Vector3.new(0, -gravity / 2 * t * t, 0)) * turn
		end)
		table.insert(self.Connections, connection)
	end)
end

function FX:Drops(side, e)
	local here = self.Scene.Frame
	local origin = self:World(e.Origin)
	for _, d in e.Drops do
		local velocity = here:VectorToWorldSpace(Vector3.new(d[1], d[2], d[3]))
		self:Toss(origin, velocity, e.Gravity, e.Life, d[4], Vector3.one * 0.8, COLORS.ketchup_bottle)
	end
end

function FX:Rain(side, e)
	local here = self.Scene.Frame
	for _, d in e.Drops do
		local origin = here:PointToWorldSpace(Vector3.new(d[1], d[2], d[3]))
		local velocity = here:VectorToWorldSpace(Vector3.new(d[4], d[5], d[6]))
		self:Toss(
			origin,
			velocity,
			e.Gravity,
			e.Life,
			d[7],
			Vector3.new(1.7, 0.85, 0.85),
			COLORS.pickle_jar,
			Enum.PartType.Cylinder
		)
	end
end

-- Fireflies chase the rival's glass on screen; the server decides each sting.
function FX:Flies(side, e)
	local state = self.Sides[side]
	state.Flies = state.Flies or {}
	local foe = self:Foe(side)
	local origin = self:World(e.Origin)
	for _ = 1, e.Count do
		local fly =
			self:Part("Firefly", Vector3.one * 0.42, origin, COLORS.mason_jar, Enum.Material.Neon, Enum.PartType.Ball)
		local spin = Vector3.new(math.random() * 2 - 1, math.random() * 2 - 1, 0.01)
		table.insert(state.Flies, {
			Part = fly,
			Velocity = spin.Unit * e.Speed,
			Speed = e.Speed,
			Until = os.clock() + e.Life,
			Foe = foe,
		})
		Debris:AddItem(fly, e.Life + 0.1)
	end
end

function FX:StepFlies(state, dt)
	for i = #(state.Flies or {}), 1, -1 do
		local fly = state.Flies[i]
		if os.clock() > fly.Until or not fly.Part.Parent then
			table.remove(state.Flies, i)
		else
			local toward = fly.Foe.Body.Position - fly.Part.Position
			if toward.Magnitude > 0.01 then
				fly.Velocity = fly.Velocity:Lerp(toward.Unit * fly.Speed, math.min(1, dt * 3.5))
			end
			fly.Part.Position += fly.Velocity * dt
		end
	end
end

function FX:Cube(side, e)
	local state = self.Sides[side]
	state.Cubes = state.Cubes or {}
	local at = self:World(e.Point)
	local cube = self:Part("IceCube", Vector3.one * 0.1, at, COLORS.crystal_tumbler, Enum.Material.Glass)
	cube.Transparency = 0.25
	cube.CFrame = CFrame.new(at) * CFrame.Angles(math.random() * 3, math.random() * 3, 0)
	TweenService
		:Create(
			cube,
			TweenInfo.new(e.Arm, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Size = Vector3.one * 1.5 }
		)
		:Play()
	state.Cubes[e.Id] = cube
end

function FX:Event(e, hud)
	local side, kit = e.Side, e.Kit
	local f = self.Scene.Fighters[side]
	if not f then
		return
	end
	local color = COLORS[kit]
	local a = e.Action
	local foe = self:Foe(side)
	if e.Amount and e.Amount > 0 and foe.Buddy then
		foe.Buddy:Hurt()
	end
	if a == "Pressure" then
		-- Pop shakes harder with every clash; the bottle shows it is about to go.
		self.Sides[side].Shake = e.Count / e.Needed
		self:Burst(f.Body.Position, color, 4 + e.Count * 3, 10)
		self:Sound(Audio.CapRattle, side, 1 + e.Count * 0.08, 0.5)
	elseif a == "Blast" then
		self.Sides[side].Shake = 0
		local cap = f.Model:FindFirstChild("Cap")
		local origin, direction =
			self:World(e.Origin), self.Scene.Frame:VectorToWorldSpace(Vector3.new(table.unpack(e.Direction)))
		local rocket = self:Part(
			"CapRocket",
			Vector3.new(1.7, 0.7, 1.7),
			origin,
			Color3.fromHex("#FF3B4E"),
			Enum.Material.SmoothPlastic,
			Enum.PartType.Cylinder
		)
		rocket.CFrame = CFrame.lookAt(origin, origin + direction) * CFrame.Angles(0, math.pi / 2, 0)
		TweenService:Create(
			rocket,
			TweenInfo.new(e.Life, Enum.EasingStyle.Linear),
			{ Position = origin + direction * e.Speed * e.Life }
		):Play()
		self.Sides[side].Rocket = rocket
		Debris:AddItem(rocket, e.Life + 0.1)
		if cap then
			cap.Transparency = 1
			task.delay(1.6, function()
				if cap.Parent and not f.Broken then
					cap.Transparency = 0
				end
			end)
		end
		self:Burst(origin, Color3.new(1, 1, 1), 34, 26)
		self:Ring(origin, color, 8, 0.4)
		self:Say(hud, "CAP BLAST!", origin, color)
		self:Sound(Audio.BubblePop, side, 0.8, 1)
		self:Sound(Audio.PressureAir, side, 1, 0.8)
		self:Shake(0.6)
	elseif a == "CapHit" then
		local at = self:World(e.Point)
		if self.Sides[side].Rocket then
			self.Sides[side].Rocket:Destroy()
		end
		self:Burst(at, color, 26, 22)
		self:Ring(at, Color3.new(1, 1, 1), 9, 0.35)
		self:Number(hud, e.Amount, at, color)
		self:Sound(Audio.ClinkHeavy, side, 0.9, 1)
		self:Shake(0.8)
	elseif a == "Blob" then
		self:Stick(side, e.Count, color)
		self:Sound(Audio.WaterSlap, side, 0.7 + e.Count * 0.1, 0.55)
	elseif a == "Glue" then
		self:Strand(side, true)
		self:Say(hud, "STUCK!", self:Foe(side).Body.Position, color)
		self:Sound(Audio.SplashBloom, side, 0.7, 0.9)
		self:Shake(0.4)
	elseif a == "GlueTick" then
		local at = self:World(e.Point)
		self:Burst(at, color, 7, 9)
		self:Number(hud, e.Amount, at, color)
		self:Sound(Audio.ClinkLightA, side, 0.8, 0.5)
	elseif a == "GlueEnd" then
		self:Strand(side, false)
		self:Stick(side, 0, color)
	elseif a == "Charge" then
		self:Ring(f.Body.Position, Color3.new(1, 1, 1), 1, 0.05)
		self.Sides[side].ChargeUntil = os.clock() + e.Seconds
		self.Sides[side].ChargeRays = e.Rays
		self:Sound(Audio.ChargeGlass, side, 0.9 + e.Rays * 0.08, 0.7)
	elseif a == "Rays" then
		self:Rays(side, e)
		self:Say(hud, (#e.Rays == 1 and "RAY!") or (#e.Rays .. " RAYS!"), f.Body.Position, color)
		self:Sound(Audio.FN_GlassPing, side, 0.8 + #e.Rays * 0.08, 0.9)
		self:Shake(0.2 + #e.Rays * 0.08)
	elseif a == "RaysHit" then
		local at = self:World(e.Point)
		self:Burst(at, RAINBOW[e.Hits % #RAINBOW + 1], 10 + e.Hits * 5, 16)
		self:Number(hud, e.Amount, at, color)
	elseif a == "Wind" then
		self.Sides[side].Stacks = e.Stacks
		self.Sides[side].MaxStacks = e.Max
		if f.Trail then
			f.Trail.Enabled = e.Stacks >= 3
			f.Trail.Lifetime = 0.1 + e.Stacks * 0.05
		end
		self:Sound(Audio.RisingWhoosh, side, 0.9 + e.Stacks * 0.1, 0.25 + e.Stacks * 0.03)
		if e.Stacks == e.Max then
			self:Say(hud, "TOP SPEED!", f.Body.Position, color)
			self:Ring(f.Body.Position, color, 9, 0.45)
		end
	elseif a == "Tide" then
		self:Water(side, e.Y, e.Level)
		self:Sound(Audio.WaterSlap, side, 1.1 - e.Level * 0.07, 0.6)
	elseif a == "WaveWarn" then
		self:Say(hud, "WAVE COMING!", f.Body.Position, color)
		self:Sound(Audio.RisingWhoosh, side, 0.7, 0.8)
	elseif a == "Wave" then
		self:Wave(side, e)
		self:Sound(Audio.SplashBloom, side, 0.8, 1)
		self:Shake(0.5)
	elseif a == "WaveHit" then
		local at = self:World(e.Point)
		self:Burst(at, Color3.new(1, 1, 1), 34, 24)
		self:Say(hud, "TSUNAMI!", at, color)
		self:Number(hud, e.Amount, at, color)
		self:Shake(0.9)
	elseif a == "WaveDodge" then
		self:Say(hud, "DODGED!", self:World(e.Point), Color3.new(1, 1, 1))
	elseif a == "Squeeze" then
		self:Drops(side, e)
		self:Say(hud, "SQUEEZE!", f.Body.Position, color)
		self:Sound(Audio.WaterSlap, side, 1.3, 0.8)
	elseif a == "DropHit" then
		local at = self:World(e.Point)
		self:Burst(at, color, 6, 10)
		self:Sound(Audio.WaterSlap, side, 1.5, 0.35)
	elseif a == "Splat" then
		self:Stick(side, math.min(e.Count, e.Max), color)
	elseif a == "TopUp" then
		self:Burst(f.Body.Position, color, 26, 12)
		self:Ring(f.Body.Position, color, 8, 0.45)
		self:Say(hud, "TOP UP!", f.Body.Position, Color3.fromHex("#6FE3FF"))
		if hud and e.Healed > 0 then
			hud:Popup(
				string.format("+%d", math.ceil(e.Healed)),
				f.Body.Position,
				Color3.fromHex("#7DFF6A"),
				1,
				"ConceptHeal",
				1.25
			)
		end
		self:Sound(Audio.Bubbles, side, 1, 0.9)
	elseif a == "Rain" then
		self:Rain(side, e)
		self:Say(hud, #e.Drops .. " PICKLES!", foe.Body.Position, color)
		self:Sound(Audio.RisingWhoosh, side, 1.3, 0.5)
	elseif a == "PickleHit" then
		local at = self:World(e.Point)
		self:Burst(at, color, 12, 13)
		self:Number(hud, e.Amount, at, color)
		self:Sound(Audio.ToyBlockA, side, 1, 0.7)
		self:Shake(0.3)
	elseif a == "Zest" then
		local state = self.Sides[side]
		state.Zest = state.Zest or { Parts = {} }
		state.Zest.Speed, state.Zest.Distance = e.Speed, e.Distance
		while #state.Zest.Parts < e.Count do
			local slice = self:Part(
				"LemonSlice",
				Vector3.new(0.3, 1.5, 1.5),
				f.Body.Position,
				color,
				Enum.Material.SmoothPlastic,
				Enum.PartType.Cylinder
			)
			table.insert(state.Zest.Parts, slice)
		end
		self:Ring(f.Body.Position, color, 6, 0.3)
		if e.Count > 1 then
			self:Say(hud, e.Count .. " SLICES!", f.Body.Position, color)
		end
		self:Sound(Audio.FN_GlassPing, side, 1 + e.Count * 0.08, 0.5)
	elseif a == "ZestHit" then
		local at = self:World(e.Point)
		self:Burst(at, color, 12, 15)
		self:Number(hud, e.Amount, at, color)
		self:Sound(Audio.ClinkLightB, side, 1.3, 0.6)
	elseif a == "Flies" then
		self:Flies(side, e)
		if e.Count >= 3 then
			self:Say(hud, "SWARM!", f.Body.Position, color)
		end
		self:Sound(Audio.FN_BeeBuzz, side, 1.2, 0.35)
	elseif a == "FlyHit" then
		local at = self:World(e.Point)
		local flies = self.Sides[side].Flies
		if flies and flies[1] then
			flies[1].Part:Destroy()
			table.remove(flies, 1)
		end
		self:Burst(at, color, 6, 9)
		self:Number(hud, e.Amount, at, color)
	elseif a == "Cube" then
		self:Cube(side, e)
		self:Sound(Audio.FN_IceCrackle, side, 1.2, 0.5)
	elseif a == "CubeHit" then
		local at = self:World(e.Point)
		local cubes = self.Sides[side].Cubes
		if cubes and cubes[e.Id] then
			cubes[e.Id]:Destroy()
			cubes[e.Id] = nil
		end
		self:Burst(at, color, 24, 18)
		self:Ring(at, Color3.new(1, 1, 1), 5, 0.3)
		self:Say(hud, "FROZEN!", at, color)
		self:Number(hud, e.Amount, at, color)
		self:Sound(Audio.SafetyGlass, side, 1.2, 0.8)
		self:Shake(0.4)
	elseif a == "CubeGone" then
		local cubes = self.Sides[side].Cubes
		if cubes and cubes[e.Id] then
			cubes[e.Id]:Destroy()
			cubes[e.Id] = nil
		end
	elseif a == "Heat" then
		local state = self.Sides[side]
		if not state.Aura then
			state.Aura =
				self:Part("HeatAura", Vector3.one, f.Body.Position, color, Enum.Material.Neon, Enum.PartType.Ball)
			state.Aura.Transparency = 0.82
		end
		state.AuraSize = (e.Radius + f.Body.Size.X * 0.5) * 2
		self:Ring(f.Body.Position, color, state.AuraSize + 1, 0.3)
		if e.Stacks == e.Max then
			self:Say(hud, "MAX HEAT!", f.Body.Position, color)
		end
		self:Sound(Audio.RisingWhoosh, side, 0.8 + e.Stacks * 0.08, 0.4)
	elseif a == "Burn" then
		local at = self:World(e.Point)
		self:Burst(at, color, 7, 8)
		self:Number(hud, e.Amount, at, color)
	elseif a == "Burst" then
		local at = self:World(e.Point)
		self:Stick(side, 0, color)
		self:Burst(at, color, 44, 26)
		self:Ring(at, color, 11, 0.4)
		self:Say(hud, "SPLAT!", at, color)
		self:Number(hud, e.Amount, at, color)
		self:Sound(Audio.SoftBoom, side, 1, 0.9)
		self:Shake(0.8)
	end
end

-- Runs after Pose each frame: things that follow the glass. `time` is the fight clock, so orbits match the server.
function FX:Update(time)
	local now = os.clock()
	local dt = now - (self.LastUpdate or now)
	self.LastUpdate = now
	for side, state in self.Sides do
		local f = self.Scene.Fighters[side]
		if f.Broken then
			continue
		end
		for _, stuck in state.Stuck or {} do
			local foe = self:Foe(side)
			stuck.Part.CFrame = foe.Body.CFrame * stuck.Offset
			if foe.Broken then
				stuck.Part.Transparency = 1
			end
		end
		if (state.Shake or 0) > 0 and f.Pivot and not f.Finishing then
			local amount = state.Shake * state.Shake * 0.22
			local jolt = CFrame.new(math.sin(now * 61) * amount, 0, math.cos(now * 47) * amount)
				* CFrame.Angles(0, 0, math.sin(now * 53) * amount * 0.5)
			f.Model:PivotTo(f.Pivot * jolt)
		end
		if state.ChargeUntil and now < state.ChargeUntil and f.Glints then
			f.Glints:Emit(state.ChargeRays or 1)
		end
		if state.Zest and time then
			local count = #state.Zest.Parts
			for i, slice in state.Zest.Parts do
				local angle = time * state.Zest.Speed + (i - 1) * 2 * math.pi / count
				local offset = Vector3.new(math.cos(angle), math.sin(angle), 0) * state.Zest.Distance
				slice.CFrame = CFrame.new(f.Body.Position + self.Scene.Frame:VectorToWorldSpace(offset))
					* CFrame.Angles(0, math.pi / 2, angle * 2)
			end
		end
		if state.Aura then
			state.Aura.Position = f.Body.Position
			state.Aura.Size = Vector3.one * (state.AuraSize or 1) * (1 + math.sin(now * 9) * 0.04)
		end
		self:StepFlies(state, dt)
	end
end

-- The shatter ends every running effect but leaves the water and cubes where they are.
function FX:RoundOver()
	for side, state in self.Sides do
		self:Strand(side, false)
		for _, stuck in state.Stuck or {} do
			stuck.Part:Destroy()
		end
		state.Stuck = nil
		state.Shake = 0
		for _, slice in (state.Zest and state.Zest.Parts) or {} do
			slice:Destroy()
		end
		state.Zest = nil
		if state.Aura then
			state.Aura:Destroy()
			state.Aura = nil
		end
		for _, fly in state.Flies or {} do
			fly.Part:Destroy()
		end
		state.Flies = nil
	end
end

function FX:Destroy()
	for _, c in self.Connections do
		c:Disconnect()
	end
	self.Root:Destroy()
end

return FX
