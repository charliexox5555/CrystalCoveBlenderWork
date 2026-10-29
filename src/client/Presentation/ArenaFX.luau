-- Arena layer presentation for one fight (decision 122, docs/design/ROUND_REVAMP.md): glints, what a glassy is
-- holding (Smash, Bubble), bombs, bumper posts, wind gusts, PUSH bursts, the Heat bar and the twist banner.
-- Client only: the server decides everything (ArenaRules, Pendulum); this draws its events.
-- Points arrive in the stand frame (origin between the hooks, Y up), like Hit X/Y/Z.
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Balance = require(RS.Shared.Config.Balance)
local Audio = require(RS.Shared.Config.Audio)
local Arena = require(RS.Shared.ArenaRules)
local Theme = require(script.Parent.Parent.UI.Theme)
local Kit = require(script.Parent.Parent.UI.Components.MatchKit)
local A = Balance.Arena
local FX = {}
FX.__index = FX

-- One picture and colour per glint so a young player reads it in a second (no words on the gem).
FX.Glints = {
	Smash = { Color = Color3.fromHex("#FF4D5E"), Icon = "💥", Name = "SMASH!" },
	Bubble = { Color = Color3.fromHex("#7FD8FF"), Icon = "🛡️", Name = "BUBBLE!" },
	Patch = { Color = Color3.fromHex("#5CFF8A"), Icon = "❤️", Name = "PATCH!" },
	Bomb = { Color = Color3.fromHex("#FF9B2F"), Icon = "💣", Name = "BOMB!" },
	Frost = { Color = Color3.fromHex("#BFF4FF"), Icon = "❄️", Name = "FROST!" },
	Zoom = { Color = Color3.fromHex("#FFE45C"), Icon = "⚡", Name = "ZOOM!" },
}
FX.Twists = {
	Windy = { Name = "WINDY!", Icon = "🌬️", Color = Color3.fromHex("#CDEBFF") },
	Bouncy = { Name = "BOUNCY!", Icon = "🏀", Color = Color3.fromHex("#FFB35C") },
	Magnet = { Name = "MAGNET!", Icon = "🧲", Color = Color3.fromHex("#FF6B8A") },
	GlintRain = { Name = "GLINT RAIN!", Icon = "✨", Color = Color3.fromHex("#FFE45C") },
	Bumpers = { Name = "BUMPERS!", Icon = "💎", Color = Color3.fromHex("#8FF6FF") },
}
local HEAT = { Color3.fromHex("#FFD25C"), Color3.fromHex("#FF8A2F"), Color3.fromHex("#FF3B2F") }
local POST_COLOR = Color3.fromHex("#8FF6FF")

local function part(parent, name, color, shape, size)
	local p = Instance.new("Part")
	p.Name, p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = name, true, false, false, false
	p.CastShadow, p.Material, p.Color = false, Enum.Material.Neon, color
	p.Shape, p.Size = shape or Enum.PartType.Ball, size or Vector3.one
	p.Parent = parent
	return p
end

local function sparks(parent, color)
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color, e.LightEmission, e.Rate = ColorSequence.new(color), 0.9, 0
	e.Lifetime, e.Speed, e.SpreadAngle = NumberRange.new(0.25, 0.6), NumberRange.new(4, 9), Vector2.new(180, 180)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0) })
	e.Parent = parent
	return e
end

local function icon(parent, text, size)
	local gui = Instance.new("BillboardGui")
	gui.Name, gui.Size, gui.LightInfluence, gui.AlwaysOnTop = "Icon", UDim2.fromScale(size, size), 0, false
	gui.Adornee, gui.Parent = parent, parent
	local label = Instance.new("TextLabel")
	label.Size, label.BackgroundTransparency, label.TextScaled, label.Text = UDim2.fromScale(1, 1), 1, true, text
	label.Parent = gui
	return gui
end

function FX.new(scene, data, viewing)
	local self = setmetatable({ Scene = scene, Data = data, Viewing = viewing, Glints = {}, Held = {}, Bombs = {} }, FX)
	self.Root = Instance.new("Folder")
	self.Root.Name = "ArenaFX"
	self.Root.Parent = scene.Root
	self.Twist = data.Twist or "Calm"
	if not A.Enabled then
		return self
	end
	if self.Twist == "Bumpers" then
		self:BuildPosts()
	end
	for side, setup in { data.A, data.B } do
		if setup.OnFire and scene.Fighters[side] then
			-- On Fire (two round wins in a row): cosmetic only.
			local fire = Instance.new("Fire")
			fire.Name, fire.Size, fire.Heat, fire.Color, fire.SecondaryColor = "OnFire", 2.5, 4, HEAT[2], HEAT[1]
			fire.Parent = scene.Fighters[side].Body
		end
	end
	return self
end

function FX:Point(p)
	return self.Scene.Frame:PointToWorldSpace(Vector3.new(p[1], p[2], p[3]))
end

function FX:Sound(id, at, pitch, volume)
	if self.Viewing and at then
		self.Scene:Sound(id, at, pitch, volume, 0.6)
	end
end

-- Crystal posts on thin glass rods down to the pen floor.
function FX:BuildPosts()
	local hooks = self.Data.HookPositions
	local gap = if hooks then (hooks[2] - hooks[1]).Magnitude else Balance.Motion.HookGap
	local params = RaycastParams.new()
	params.FilterType, params.FilterDescendantsInstances = Enum.RaycastFilterType.Exclude, { self.Scene.Root }
	self.Posts = {}
	local radius = A.Twists.Bumpers.Radius
	for index, p in Arena.posts(gap) do
		local at = self:Point(p)
		local shell = part(self.Root, "BumperPost" .. index, POST_COLOR, Enum.PartType.Ball, Vector3.one * radius * 2)
		shell.Material, shell.Transparency, shell.Position = Enum.Material.Glass, 0.25, at
		local core =
			part(self.Root, "BumperCore" .. index, Color3.new(1, 1, 1), Enum.PartType.Ball, Vector3.one * radius)
		core.Position, core.Transparency = at, 0.2
		local hit = workspace:Raycast(at, Vector3.new(0, -40, 0), params)
		local floor = if hit then hit.Position.Y else at.Y - 6
		local length = math.max(0.2, at.Y - radius - floor)
		local rod =
			part(self.Root, "BumperRod" .. index, POST_COLOR, Enum.PartType.Cylinder, Vector3.new(length, 0.14, 0.14))
		rod.Material, rod.Transparency = Enum.Material.Glass, 0.4
		rod.CFrame = CFrame.new(at.X, floor + length / 2, at.Z) * CFrame.Angles(0, 0, math.pi / 2)
		for _, piece in { shell, core, rod } do
			local size = piece.Size
			piece.Size = size * 0.05
			TweenService:Create(piece, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Size = size }):Play()
		end
		self.Posts[index] = { Shell = shell, Core = core, Sparks = sparks(core, POST_COLOR) }
	end
end

-- The twist banner (countdown and the first moments of the fight) and MATCH POINT on a last-heart round.
function FX:Banner(hud, show)
	if not A.Enabled then
		return false
	end
	if not hud then
		return
	end
	local twist = FX.Twists[self.Twist]
	local hearts = self.Data.Hearts
	local matchPoint = hearts and math.min(hearts[1], hearts[2]) <= 1 and math.max(hearts[1], hearts[2]) > 0
	if not twist and not matchPoint then
		return
	end
	local label = hud.Gui:FindFirstChild("TwistBanner")
	if not label then
		label = Kit.label(
			hud.Gui,
			"TwistBanner",
			"",
			UDim2.fromScale(0.6, 0.09),
			UDim2.fromScale(0.2, 0.06),
			{ MaxSize = 72, Outline = 4, RichText = true }
		)
		local scale = Instance.new("UIScale")
		scale.Parent = label
	end
	local lines = {}
	if twist then
		table.insert(
			lines,
			string.format('<font color="#%s">%s %s</font>', twist.Color:ToHex(), twist.Icon, twist.Name)
		)
	end
	if matchPoint then
		table.insert(lines, '<font color="#FFE45C">MATCH POINT</font>')
	end
	label.Text = table.concat(lines, "  •  ")
	label.Visible, label.TextTransparency = show, 0
	if show and not self.BannerShown then
		self.BannerShown = true
		label.UIScale.Scale = 0.4
		TweenService:Create(label.UIScale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		self:Sound(Audio.ChimeCluster, self.Scene.Fighters[1].Body, 1.1, 0.35)
	end
end

function FX:HideBanner(hud)
	local label = hud and hud.Gui:FindFirstChild("TwistBanner")
	if label and label.Visible then
		TweenService:Create(label, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		task.delay(0.4, function()
			if label.Parent then
				label.Visible = false
			end
		end)
	end
end

-- A short word in the middle of the screen ("HEATING UP!", "MELTDOWN!").
function FX:Shout(hud, text, color)
	if not hud then
		return
	end
	hud.Headline.Text, hud.Headline.TextColor3 = text, color
	hud:Beat()
	self.ShoutSerial = (self.ShoutSerial or 0) + 1
	local serial = self.ShoutSerial
	task.delay(1.3, function()
		if self.ShoutSerial == serial and hud.Headline.Parent and hud.Headline.Text == text then
			hud.Headline.Text, hud.Headline.TextColor3 = "", Theme.Colors.Text
		end
	end)
end

function FX:HeatBar(hud, time)
	if not hud then
		return
	end
	local bar = hud.Gui:FindFirstChild("HeatBar")
	if not bar then
		bar =
			Kit.frame(hud.Gui, "HeatBar", UDim2.fromScale(0.3, 0.018), UDim2.fromScale(0.5, 0.035), Vector2.new(0.5, 0))
		bar.BackgroundColor3, bar.BackgroundTransparency = Theme.Colors.Shadow, 0.35
		Kit.outline(bar, 1.5)
		local fill = Instance.new("Frame")
		fill.Name, fill.BorderSizePixel, fill.Size, fill.Parent = "Fill", 0, UDim2.fromScale(0, 1), bar
		local flame = Kit.label(
			bar,
			"Flame",
			"🔥",
			UDim2.fromScale(0.08, 2.2),
			UDim2.fromScale(1.02, -0.6),
			{ Outline = false }
		)
		flame.SizeConstraint = Enum.SizeConstraint.RelativeYY
	end
	local meltdown = Balance.Fight.OvertimeAt
	local stage = if time > meltdown then 3 elseif time >= A.Heat.WarmAt then 2 else 1
	bar.Fill.Size = UDim2.fromScale(math.clamp(time / meltdown, 0, 1), 1)
	bar.Fill.BackgroundColor3 = HEAT[stage]
	bar.Visible = self.Phase == "Fighting"
end

function FX:Spawn(e)
	if self.Glints[e.GlintId] or not e.Point then
		return
	end
	local look = FX.Glints[e.Kind] or FX.Glints.Smash
	local at = self:Point(e.Point)
	local radius = A.Glints.Radius
	local gem = part(self.Root, "Glint", look.Color, Enum.PartType.Ball, Vector3.one * radius * 1.4)
	gem.Material, gem.Transparency, gem.Position = Enum.Material.Glass, 0.15, at
	local core = part(gem, "Core", look.Color, Enum.PartType.Ball, Vector3.one * radius * 0.8)
	core.Position = at
	local glint =
		{ Gem = gem, Core = core, Base = at, Kind = e.Kind, Born = os.clock(), Sparks = sparks(gem, look.Color) }
	if self.Viewing then
		local light = Instance.new("PointLight")
		light.Color, light.Range, light.Brightness, light.Parent = look.Color, 7, 1.6, gem
		local gui = icon(gem, look.Icon, 1.8)
		gui.StudsOffsetWorldSpace = Vector3.yAxis * 1.3
	end
	gem.Size = Vector3.one * 0.05
	TweenService:Create(gem, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Size = Vector3.one * radius * 1.4 }):Play()
	glint.Sparks:Emit(8)
	self:Sound(Audio.ChimeCluster, gem, 1.6, 0.18)
	self.Glints[e.GlintId] = glint
end

function FX:Remove(id, into)
	local glint = self.Glints[id]
	if not glint then
		return
	end
	self.Glints[id] = nil
	glint.Sparks:Emit(14)
	local goal = { Size = Vector3.one * 0.05 }
	if into then
		goal.Position = into.Position
	end
	TweenService:Create(glint.Gem, TweenInfo.new(0.18, Enum.EasingStyle.Quad), goal):Play()
	Debris:AddItem(glint.Gem, 0.6)
end

-- Smash glows red round the glassy; Bubble wraps it. Both go when used.
function FX:Hold(side, kind, on)
	self.Held[side] = self.Held[side] or {}
	local held = self.Held[side][kind]
	if not on then
		if held then
			held:Destroy()
			self.Held[side][kind] = nil
		end
		return
	end
	local f = self.Scene.Fighters[side]
	if held or not f or f.Broken then
		return
	end
	local look = FX.Glints[kind]
	local size = f.Def.Radius * Balance.Motion.GlassyScale * (if kind == "Bubble" then 2.9 else 2.3)
	local aura = part(self.Root, "Held" .. kind, look.Color, Enum.PartType.Ball, Vector3.one * size)
	aura.Material = if kind == "Bubble" then Enum.Material.ForceField else Enum.Material.Neon
	aura.Transparency = if kind == "Bubble" then 0.1 else 0.82
	aura.CFrame = f.Body.CFrame
	self.Held[side][kind] = aura
end

function FX:Grab(e, hud)
	local f = self.Scene.Fighters[e.Side]
	if not f then
		return
	end
	self:Remove(e.GlintId, f.Body)
	local look = FX.Glints[e.Kind]
	if not look then
		return
	end
	if e.Kind == "Smash" or e.Kind == "Bubble" then
		self:Hold(e.Side, e.Kind, true)
	end
	if hud and not e.Held then
		hud:Popup(
			look.Icon
				.. " "
				.. look.Name
				.. (if e.Amount and e.Amount > 0 then " +" .. math.floor(e.Amount + 0.5) else ""),
			f.Body.Position + Vector3.yAxis * 2.4,
			look.Color,
			0,
			"Glint" .. e.Side
		)
	end
	f.Glints:Emit(16)
	if not e.Held then
		self:Sound(Audio.MagicPoof, f.Body, 1.3, 0.3)
	end
end

function FX:Bomb(e)
	local f = self.Scene.Fighters[e.Side]
	if not f then
		return
	end
	local bomb = part(self.Root, "Bomb", Color3.fromHex("#2B2233"), Enum.PartType.Ball, Vector3.one * 0.9)
	bomb.Material = Enum.Material.SmoothPlastic
	local fuse = part(bomb, "Fuse", FX.Glints.Bomb.Color, Enum.PartType.Ball, Vector3.one * 0.3)
	table.insert(self.Bombs, { Part = bomb, Fuse = fuse, Side = e.Side, Born = os.clock(), Seconds = e.Seconds or 1 })
	self:Sound(Audio.CapRattle, f.Body, 1.4, 0.3)
end

function FX:Pop(e, hud)
	local f = self.Scene.Fighters[e.Side]
	for i, bomb in self.Bombs do
		if bomb.Side == e.Side then
			table.remove(self.Bombs, i)
			bomb.Part:Destroy()
			break
		end
	end
	if not f then
		return
	end
	local at = f.Body.Position
	local blast = part(self.Root, "BombBlast", FX.Glints.Bomb.Color, Enum.PartType.Ball, Vector3.one * 0.5)
	blast.Position, blast.Transparency = at, 0.1
	TweenService:Create(blast, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { Size = Vector3.one * 6, Transparency = 1 })
		:Play()
	Debris:AddItem(blast, 0.4)
	sparks(blast, FX.Glints.Bomb.Color):Emit(24)
	self:Sound(Audio.SoftBoom, f.Body, 1.1, 0.5)
	if self.Scene.Feel and e.Amount and e.Amount > 0 then
		self.Scene.Feel:PowerLand(e.Side, os.clock())
	end
	if hud and e.Amount then
		hud:Popup(
			if e.Amount > 0 then "−" .. math.floor(e.Amount + 0.5) else "BLOCKED",
			at,
			FX.Glints.Bomb.Color,
			if e.Side == 1 then -1 else 1,
			"Bomb" .. e.Side
		)
	end
end

function FX:PushBurst(side)
	local f = self.Scene.Fighters[side]
	if not f or f.Broken then
		return
	end
	local ring =
		part(self.Root, "PushRing", Color3.fromRGB(120, 230, 255), Enum.PartType.Cylinder, Vector3.new(0.1, 1, 1))
	ring.Transparency, ring.CFrame = 0.2, f.Body.CFrame * CFrame.Angles(0, 0, math.pi / 2)
	local size = f.Def.Radius * Balance.Motion.GlassyScale * 4
	TweenService
		:Create(
			ring,
			TweenInfo.new(0.3, Enum.EasingStyle.Quad),
			{ Size = Vector3.new(0.05, size, size), Transparency = 1 }
		)
		:Play()
	Debris:AddItem(ring, 0.35)
	f.Trail.Enabled = true
	self:Sound(Audio.RisingWhoosh, f.Body, 1.5, 0.28)
end

function FX:Gust(e)
	if not self.Viewing then
		return
	end
	local direction = self.Scene.Frame:VectorToWorldSpace(Vector3.new(e.X, 0, e.Z))
	if direction.Magnitude < 0.01 then
		return
	end
	local center = self.Scene.Frame:PointToWorldSpace(Vector3.new(0, -8, 0))
	if not self.Wind then
		self.Wind = part(self.Root, "Wind", Color3.new(1, 1, 1), Enum.PartType.Block, Vector3.new(14, 8, 1))
		self.Wind.Transparency = 1
		local e2 = Instance.new("ParticleEmitter")
		e2.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		e2.Color, e2.LightEmission, e2.Rate = ColorSequence.new(Color3.fromHex("#E6F6FF")), 0.6, 0
		e2.Lifetime, e2.Speed = NumberRange.new(0.5, 0.8), NumberRange.new(26, 34)
		e2.Orientation, e2.Squash = Enum.ParticleOrientation.VelocityParallel, NumberSequence.new(-2)
		e2.Size = NumberSequence.new(0.25)
		e2.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.3, 0.3),
			NumberSequenceKeypoint.new(1, 1),
		})
		e2.EmissionDirection, e2.Parent = Enum.NormalId.Front, self.Wind
		self.WindEmitter = e2
	end
	-- Start upwind so the streaks cross the pen.
	self.Wind.CFrame = CFrame.lookAt(center - direction.Unit * 10, center)
	self.WindEmitter.Rate = 90
	self.WindUntil = os.clock() + (e.Seconds or 1)
	self:Sound(Audio.Whoosh, self.Scene.Fighters[1].Body, 0.6, 0.3)
end

function FX:Bump(e)
	local post = self.Posts and self.Posts[e.Post]
	if not post then
		return
	end
	post.Core.Transparency = 0
	TweenService:Create(post.Core, TweenInfo.new(0.25), { Transparency = 0.2 }):Play()
	post.Sparks:Emit(6)
	self:Sound(Audio.ClinkLightA, post.Shell, 2.2, 0.16)
end

-- Returns true for the arena events it drew (FightView sends everything here first).
function FX:Event(e, hud)
	if not A.Enabled then
		return false
	end
	local kind = e.Type
	if kind == "GlintSpawn" then
		self:Spawn(e)
	elseif kind == "GlintGrab" then
		self:Grab(e, hud)
	elseif kind == "GlintFade" then
		self:Remove(e.GlintId)
	elseif kind == "GlintBlock" then
		self:Hold(e.Side, "Bubble", false)
		local f = self.Scene.Fighters[e.Side]
		if hud and f then
			hud:Popup(
				"🛡️ BLOCKED",
				f.Body.Position,
				FX.Glints.Bubble.Color,
				if e.Side == 1 then -1 else 1,
				"Damage" .. e.Side
			)
		end
		self:Sound(Audio.BubblePop, f and f.Body, 1, 0.4)
	elseif kind == "BombArm" then
		self:Bomb(e)
	elseif kind == "BombPop" then
		self:Pop(e, hud)
	elseif kind == "Push" then
		self:PushBurst(e.Side)
	elseif kind == "Gust" then
		self:Gust(e)
	elseif kind == "Bump" then
		self:Bump(e)
	elseif kind == "Heat" then
		if e.Stage == 1 and not e.Bootstrap then
			self:Shout(hud, "🔥 HEATING UP!", HEAT[2])
		end
		self.Meltdown = self.Meltdown or e.Stage == 2
	elseif kind == "Twist" then
		if e.Kind ~= self.Twist then
			self.Twist = e.Kind
			if e.Kind == "Bumpers" and not self.Posts then
				self:BuildPosts()
			end
		end
	elseif kind == "PushCharge" then
		return true
	elseif kind == "Hit" then
		-- A hit uses up any held Smash (the rules consume it on contact).
		for side = 1, 2 do
			self:Hold(side, "Smash", false)
		end
		return false
	elseif kind == "Overtime" then
		self.Meltdown = true
		self:Shout(hud, "🔥 MELTDOWN!", HEAT[3])
		return false
	elseif kind == "Shatter" then
		self:EndRound()
		return false
	else
		return false
	end
	return true
end

-- The round is over: glints, bombs and auras go (the render clock stops at the shatter).
function FX:EndRound()
	for id in self.Glints do
		self:Remove(id)
	end
	for _, bomb in self.Bombs do
		bomb.Part:Destroy()
	end
	self.Bombs = {}
	for side in self.Held do
		self:Hold(side, "Smash", false)
		self:Hold(side, "Bubble", false)
	end
	for _, f in self.Scene.Fighters do
		local fire = f.Body:FindFirstChild("OnFire")
		if fire then
			fire.Enabled = false
		end
	end
end

function FX:Step(dt, time, hud, phase)
	if not A.Enabled then
		return false
	end
	self.Phase = phase
	local now = os.clock()
	for _, glint in self.Glints do
		local age = now - glint.Born
		glint.Gem.Position = glint.Base + Vector3.yAxis * math.sin(age * 4) * 0.18
		glint.Gem.CFrame = CFrame.new(glint.Gem.Position) * CFrame.Angles(0, age * 2.5, 0)
		glint.Core.CFrame = glint.Gem.CFrame
	end
	for side, held in self.Held do
		local f = self.Scene.Fighters[side]
		for _, aura in held do
			if f and not f.Broken then
				aura.CFrame = f.Body.CFrame
			end
		end
	end
	for _, bomb in self.Bombs do
		local f = self.Scene.Fighters[bomb.Side]
		if f then
			local offset = f.Def.Radius * Balance.Motion.GlassyScale * 0.9
			bomb.Part.Position = f.Body.Position + Vector3.yAxis * offset
			bomb.Fuse.Position = bomb.Part.Position + Vector3.yAxis * 0.5
			-- Blinks faster as the fuse runs out.
			local left = math.max(0.05, bomb.Seconds - (now - bomb.Born))
			bomb.Fuse.Transparency = if math.sin(now * math.pi * 2 * (2 + 6 / left)) > 0 then 0 else 0.8
		end
	end
	if self.WindUntil and now > self.WindUntil then
		self.WindUntil = nil
		self.WindEmitter.Rate = 0
	end
	if self.Meltdown and self.Viewing then
		-- Meltdown glow on both glassies.
		for _, f in self.Scene.Fighters do
			if not f.Broken and not f.HeatLight then
				f.HeatLight = Instance.new("PointLight")
				f.HeatLight.Color, f.HeatLight.Range, f.HeatLight.Brightness, f.HeatLight.Parent =
					HEAT[2], 6, 1.2, f.Body
			end
		end
	end
	if self.Viewing then
		self:HeatBar(hud, time)
	end
end

function FX:Destroy()
	for _, f in self.Scene.Fighters do
		if f.HeatLight then
			f.HeatLight:Destroy()
			f.HeatLight = nil
		end
	end
	self.Root:Destroy()
end

return FX
