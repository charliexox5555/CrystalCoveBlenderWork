--!strict
-- The loading screen's show: two glass glassies on strings under the arena swing, pulled back and smashed together,
-- with a gold burst, flying shards and a little shake on every hit. Every third strong hit one of them shatters and
-- the next glassy drops onto its string. Flat images only (no ViewportFrames), laid out in a 1920x1080 design space
-- inside `stage` (an aspect-fit Frame). The swing is a small damped-pendulum simulation, so no two hits look the same.
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Art = require(script.Parent.Art)

local Clash = {}
Clash.__index = Clash

local W, H = 1920, 1080
local FRAME_CENTER, FRAME_SCALE = Vector2.new(960, 500), 0.9
local BEAM_Y = 500 + (64 - 280) * FRAME_SCALE -- the hang line on the swing frame art
local PIVOTS = { Vector2.new(840, BEAM_Y), Vector2.new(1080, BEAM_Y) }
local STRING, GLASSY_SCALE = 250, 0.85
local BODY = STRING + (220 - 16) * GLASSY_SCALE -- pivot to the middle of the glass body
local ARM_W, ARM_HALF = 240 * GLASSY_SCALE, STRING + 340 * GLASSY_SCALE
local GRAVITY, DAMPING, BOUNCE = 20, 0.35, 0.72 -- pendulum stiffness (rad/s^2), air drag, restitution
local SWING_SECONDS, PULL_SECONDS = 3.1, 0.6
local SHATTER_EVERY = 3

local function at(x: number, y: number): UDim2
	return UDim2.fromScale(x / W, y / H)
end

local function size(w: number, h: number): UDim2
	return UDim2.fromScale(w / W, h / H)
end

local function image(parent: Instance, key: string, name: string): ImageLabel
	local label = Instance.new("ImageLabel")
	label.Name, label.BackgroundTransparency, label.Image = name, 1, Art.Images[key]
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Parent = parent
	return label
end

local function tween(
	object: Instance,
	seconds: number,
	props: { [string]: any },
	style: Enum.EasingStyle?,
	dir: Enum.EasingDirection?
)
	local t = TweenService:Create(
		object,
		TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out),
		props
	)
	t:Play()
	return t
end

function Clash.new(stage: Frame)
	local self = setmetatable({}, Clash)
	self.Stage, self.Random = stage, Random.new()
	self.Shards, self.Hits, self.Next = {}, 0, 3
	self.Shake, self.ShakeTime = 0, 0
	local frame = image(stage, "swing_frame", "SwingFrame")
	frame.Position, frame.Size = at(FRAME_CENTER.X, FRAME_CENTER.Y), size(1000 * FRAME_SCALE, 560 * FRAME_SCALE)
	frame.ZIndex = 2
	self.Sides = {}
	for i, pivot in PIVOTS do
		-- GUI rotation turns around an object's centre, so each arm is a tall frame centred on its pivot with the
		-- string and glassy in its lower half.
		local arm = Instance.new("Frame")
		arm.Name, arm.BackgroundTransparency, arm.AnchorPoint = "Arm" .. i, 1, Vector2.new(0.5, 0.5)
		arm.Position, arm.Size, arm.ZIndex = at(pivot.X, pivot.Y), size(ARM_W, ARM_HALF * 2), 3
		arm.Parent = stage
		local cord = Instance.new("Frame")
		cord.Name, cord.BorderSizePixel, cord.BackgroundColor3 = "String", 0, Art.Colors.lead
		cord.AnchorPoint, cord.Position = Vector2.new(0.5, 0), UDim2.fromScale(0.5, 0.5)
		cord.Size, cord.ZIndex = UDim2.fromScale(5 / ARM_W, STRING / (ARM_HALF * 2)), 3
		cord.Parent = arm
		local glassy = image(arm, "glassy_pop", "Glassy")
		glassy.ZIndex = 4
		local scale = Instance.new("UIScale")
		scale.Parent = glassy
		self.Sides[i] = {
			Arm = arm,
			Glassy = glassy,
			Scale = scale,
			Angle = 0,
			Speed = 0,
			Present = true,
			Def = Art.Glassies[i],
		}
		self:Dress(self.Sides[i], Art.Glassies[i])
	end
	self.Phase, self.PhaseTime = "Pull", 0
	self:BeginPull()
	self.Connection = RunService.RenderStepped:Connect(function(dt)
		self:Step(math.min(dt, 1 / 20))
	end)
	return self
end

-- Put glassy `def` on a side's string: its image, size and hang point (the ring at the top of the art).
function Clash:Dress(side, def)
	side.Def = def
	local g = side.Glassy
	g.Image = Art.Images[def.Image]
	g.Size = UDim2.fromScale(def.Size.X * GLASSY_SCALE / ARM_W, def.Size.Y * GLASSY_SCALE / (ARM_HALF * 2))
	g.AnchorPoint = Vector2.new(0.5, 16 / def.Size.Y)
	g.Position = UDim2.fromScale(0.5, 0.5 + STRING / (ARM_HALF * 2))
end

function Clash:BeginPull()
	self.Phase, self.PhaseTime = "Pull", 0
	local r = self.Random
	-- Left pulled left (positive angle swings its bottom left), right pulled right.
	self.PullFrom = { self.Sides[1].Angle, self.Sides[2].Angle }
	self.PullTo = { math.rad(r:NextNumber(46, 62)), -math.rad(r:NextNumber(46, 62)) }
	for _, side in self.Sides do
		side.Speed = 0
	end
end

-- Tap: swing again now (kids poke loading screens).
function Clash:Poke()
	if self.Phase == "Swing" and self.PhaseTime > 0.45 then
		self:BeginPull()
	end
end

function Clash:Body(i: number): Vector2
	local side = self.Sides[i]
	local p = PIVOTS[i]
	return Vector2.new(p.X - BODY * math.sin(side.Angle), p.Y + BODY * math.cos(side.Angle))
end

function Clash:Step(dt: number)
	self.PhaseTime += dt
	if self.Phase == "Pull" then
		local t = math.clamp(self.PhaseTime / PULL_SECONDS, 0, 1)
		local e = 1 - (1 - t) ^ 3
		for i, side in self.Sides do
			side.Angle = self.PullFrom[i] + (self.PullTo[i] - self.PullFrom[i]) * e
		end
		if self.PhaseTime > PULL_SECONDS + 0.12 then
			self.Phase, self.PhaseTime = "Swing", 0
		end
	else
		local steps = math.max(1, math.ceil(dt * 240))
		local h = dt / steps
		for _ = 1, steps do
			for _, side in self.Sides do
				side.Speed += (-GRAVITY * math.sin(side.Angle) - DAMPING * side.Speed) * h
				side.Angle += side.Speed * h
			end
			self:Collide()
		end
		if self.PhaseTime > SWING_SECONDS then
			self:BeginPull()
		end
	end
	for _, side in self.Sides do
		side.Arm.Rotation = math.deg(side.Angle)
	end
	self:StepShards(dt)
	-- Screen shake on hits, decaying.
	self.ShakeTime = math.max(0, self.ShakeTime - dt)
	local k = self.Shake * (self.ShakeTime / 0.25)
	self.Stage.Position = UDim2.new(0.5, self.Random:NextNumber(-k, k), 0.5, self.Random:NextNumber(-k, k))
end

function Clash:Collide()
	local a, b = self.Sides[1], self.Sides[2]
	if not (a.Present and b.Present) then
		return
	end
	local pa, pb = self:Body(1), self:Body(2)
	local gap = (pb.X - pa.X) - (a.Def.HalfWidth + b.Def.HalfWidth) * GLASSY_SCALE
	if gap >= 0 then
		return
	end
	local ca, cb = math.max(BODY * math.cos(a.Angle), 1), math.max(BODY * math.cos(b.Angle), 1)
	local va, vb = -ca * a.Speed, -cb * b.Speed -- horizontal speeds (px/s)
	-- Push apart so they never sink into each other.
	a.Angle += (-gap / 2) / ca
	b.Angle -= (-gap / 2) / cb
	if va - vb <= 0 then
		return
	end
	local na = ((1 - BOUNCE) * va + (1 + BOUNCE) * vb) / 2
	local nb = ((1 + BOUNCE) * va + (1 - BOUNCE) * vb) / 2
	a.Speed, b.Speed = -na / ca, -nb / cb
	self:Hit((pa + pb) / 2 + Vector2.new(0, 0), va - vb)
end

function Clash:Hit(point: Vector2, speed: number)
	if speed < 220 then
		return
	end
	local strength = math.clamp(speed / 2600, 0.25, 1)
	local r = self.Random
	local stage = self.Stage
	-- Glow and the gold burst.
	local glow = image(stage, "glow", "Glow")
	glow.Position, glow.Size, glow.ZIndex = at(point.X, point.Y), size(560 * strength, 560 * strength), 5
	glow.ImageColor3, glow.ImageTransparency = Art.Colors.cream, 0.25
	tween(glow, 0.45, { ImageTransparency = 1, Size = size(760 * strength, 760 * strength) })
	task.delay(0.5, glow.Destroy, glow)
	local burst = image(stage, "burst", "Burst")
	burst.Position, burst.Size, burst.ZIndex = at(point.X, point.Y), size(10, 10), 7
	burst.Rotation, burst.ImageColor3 = r:NextNumber(-30, 30), Art.Colors.amberLight
	local big = 300 * (0.55 + strength * 0.6)
	tween(burst, 0.12, { Size = size(big, big) }, Enum.EasingStyle.Back)
	task.delay(0.14, function()
		tween(
			burst,
			0.3,
			{ ImageTransparency = 1, Size = size(big * 1.25, big * 1.25), Rotation = burst.Rotation + 25 }
		)
	end)
	task.delay(0.5, burst.Destroy, burst)
	-- Shards in both glassies' colours.
	local tints = { self.Sides[1].Def.Tint, self.Sides[2].Def.Tint, Color3.new(1, 1, 1) }
	for _ = 1, 4 + math.floor(strength * 6) do
		self:Shard(point, tints[r:NextInteger(1, 3)], r:NextNumber(40, 80) * (0.7 + strength * 0.5), 1)
	end
	self.Shake, self.ShakeTime = 4 + 10 * strength, 0.25
	if strength > 0.45 then
		self:Word(point)
		self.Hits += 1
		if self.Hits >= self.Next then
			self.Hits, self.Next = 0, SHATTER_EVERY
			self:Shatter(r:NextInteger(1, 2))
		end
	end
end

-- The "CLASH!" pop above a strong hit.
function Clash:Word(point: Vector2)
	local label = Instance.new("TextLabel")
	label.Name, label.BackgroundTransparency, label.Text = "ClashWord", 1, "CLASH!"
	label.FontFace, label.TextScaled, label.TextColor3 = Art.Heading, true, Color3.new(1, 1, 1)
	label.AnchorPoint, label.Position =
		Vector2.new(0.5, 0.5), at(point.X + self.Random:NextNumber(-30, 30), point.Y - 190)
	label.Size, label.ZIndex, label.Rotation = size(330, 96), 8, self.Random:NextNumber(-10, 6)
	local stroke = Instance.new("UIStroke")
	stroke.Color, stroke.Thickness = Art.Colors.lead, 5
	stroke.Parent = label
	local scale = Instance.new("UIScale")
	scale.Scale = 0.2
	scale.Parent = label
	label.Parent = self.Stage
	tween(scale, 0.18, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(0.45, function()
		tween(label, 0.25, { TextTransparency = 1, Position = label.Position - at(0, 40) })
		tween(stroke, 0.25, { Transparency = 1 })
	end)
	task.delay(0.75, label.Destroy, label)
end

function Clash:Shard(point: Vector2, tint: Color3, px: number, power: number)
	local r = self.Random
	local keys = { "shard_a", "shard_b", "shard_c" }
	local label = image(self.Stage, keys[r:NextInteger(1, 3)], "Shard")
	label.Position, label.Size, label.ZIndex = at(point.X, point.Y), size(px, px), 6
	label.ImageColor3, label.Rotation = tint, r:NextNumber(0, 360)
	local angle = r:NextNumber(-math.pi, 0) + r:NextNumber(-0.5, 0.5) -- mostly up and out
	local speed = r:NextNumber(380, 1050) * power
	table.insert(self.Shards, {
		Label = label,
		Pos = point,
		Vel = Vector2.new(math.cos(angle), math.sin(angle)) * speed,
		Spin = r:NextNumber(-540, 540),
		Life = 0,
		Max = r:NextNumber(0.7, 1.1),
	})
end

function Clash:StepShards(dt: number)
	for i = #self.Shards, 1, -1 do
		local s = self.Shards[i]
		s.Life += dt
		s.Vel += Vector2.new(0, 2300 * dt)
		s.Pos += s.Vel * dt
		s.Label.Position = at(s.Pos.X, s.Pos.Y)
		s.Label.Rotation += s.Spin * dt
		s.Label.ImageTransparency = math.clamp((s.Life - s.Max * 0.55) / (s.Max * 0.45), 0, 1)
		if s.Life >= s.Max then
			s.Label:Destroy()
			table.remove(self.Shards, i)
		end
	end
end

-- One glassy breaks into big shards; after a beat the next glassy drops onto the empty string.
function Clash:Shatter(i: number)
	local side = self.Sides[i]
	local center = self:Body(i)
	side.Present = false
	side.Glassy.Visible = false
	for _ = 1, 11 do
		self:Shard(
			center + Vector2.new(self.Random:NextNumber(-50, 50), self.Random:NextNumber(-70, 70)),
			side.Def.Tint,
			self.Random:NextNumber(70, 120),
			0.85
		)
	end
	self.Shake, self.ShakeTime = 16, 0.3
	task.delay(0.9, function()
		if not self.Connection then
			return
		end
		local other = self.Sides[3 - i].Def
		local index = table.find(Art.Glassies, side.Def) or 1
		local def
		repeat
			index = index % #Art.Glassies + 1
			def = Art.Glassies[index]
		until def ~= other
		self:Dress(side, def)
		side.Scale.Scale = 0
		side.Glassy.Visible = true
		side.Present = true
		tween(side.Scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	end)
end

function Clash:Destroy()
	if self.Connection then
		self.Connection:Disconnect()
		self.Connection = nil
	end
	for _, s in self.Shards do
		s.Label:Destroy()
	end
	table.clear(self.Shards)
end

return Clash
