-- Bounded UI VFX. World particles do not render inside ViewportFrames.
local RS = game.ReplicatedStorage
local K = require(script.Parent.Parent.Theme).Kiln
local Assets = require(RS.Shared.Config.KilnAssets)
local MachineConfig = require(RS.Shared.Config.CrateMachines)
local CrateMachine = require(script.Parent.Parent.Parent.Presentation.CrateMachine)
local Fire = {}
Fire.__index = Fire
local function image(parent, name, texture, color)
	local o = parent:FindFirstChild(name) or Instance.new("ImageLabel")
	o.Name, o.BackgroundTransparency, o.AnchorPoint = name, 1, Vector2.new(0.5, 0.5)
	o.Image, o.ImageColor3, o.ZIndex = texture, color, 4
	o.Parent = parent
	return o
end
function Fire.new(stage, color, category)
	local self = setmetatable({ Stage = stage, Color = color, Category = category, Objects = {}, GlowParts = {} }, Fire)
	self.View = stage.KilnPortrait
	self.View:SetAttribute("FreezePortraitCamera", true)
	-- Crate Machines v2 drive their own lid/core/contents; older capsules use the lid tween below.
	self.Machine = CrateMachine.forViewport(self.View)
	self.Timing = if self.Machine then MachineConfig.Opening else K
	self.Core = self.View:FindFirstChild("RevealCore", true) or self.View:FindFirstChild("Kiln_ChamberBackGlow", true)
	stage.Flame.Visible, stage.FlameEcho.Visible, stage.Burst.Visible = false, false, false
	self.Halo = image(stage.Sparks, "ChargeHalo", Assets.Burst, color)
	local emitter = RS.Assets.VFX:FindFirstChild("PressurePop", true)
	self.Puff = image(stage.Sparks, "PressurePuff", if emitter then emitter.Texture else Assets.Burst, color)
	self.Atlas = emitter ~= nil
	if self.Atlas then
		self.Puff.ImageRectSize = Vector2.one * K.PressureAtlasFramePixels
	end
	self.Flame = image(stage.Sparks, "ChamberFlame", Assets.Flame, Color3.new(1, 1, 1))
	self.Flame.Visible = category == "Glassies"
	for i = 1, K.SparkCount do
		local spark = Instance.new("Frame")
		spark.Name, spark.AnchorPoint, spark.BorderSizePixel = "LaunchSpark" .. i, Vector2.new(0.5, 0.5), 0
		spark.BackgroundColor3, spark.Rotation, spark.ZIndex = color, 45, 5
		spark.Size, spark.Parent = UDim2.fromOffset(3 + i % 3, 3 + i % 3), stage.Sparks
		table.insert(self.Objects, spark)
	end
	for _, p in if self.Machine then {} else self.View:GetDescendants() do
		if
			p:IsA("BasePart")
			and (p.Name == "RevealCore" or p.Name == "Kiln_ChamberBackGlow" or p.Name == "Kiln_MoltenPool")
		then
			table.insert(self.GlowParts, { Part = p, Color = p.Color })
		end
	end
	self.Lid = if self.Machine then nil else self.View:FindFirstChild("RevealLid", true)
	if self.Lid then
		self.LidPose = self.Lid.CFrame
	end
	self:Step(0)
	return self
end
function Fire:Pixel()
	local v, c = self.View, self.View.CurrentCamera
	local p = c.CFrame:PointToObjectSpace(self.Core.Position)
	local scale = v.AbsoluteSize.Y / (-p.Z * math.tan(math.rad(c.FieldOfView) / 2) * 2)
	return v.AbsolutePosition + v.AbsoluteSize / 2 + Vector2.new(p.X, -p.Y) * scale
end
function Fire:InFrame(frame)
	return (self:Pixel() - frame.AbsolutePosition) / frame.AbsoluteSize
end
function Fire:Place(o, pixel, width, height)
	o.Position = UDim2.fromOffset(pixel.X, pixel.Y)
	o.Size = UDim2.fromOffset(width, height or width)
end
function Fire:Step(time)
	local timing = self.Timing
	local heat = math.clamp(time / timing.ChargeSeconds, 0, 1)
	local release = math.clamp((time - timing.ChargeSeconds) / timing.ReleaseSeconds, 0, 1)
	if self.Machine then
		self.Machine:SetOpening(heat ^ 1.4, release)
	end
	local localPixel = self:Pixel() - self.Stage.Sparks.AbsolutePosition
	local unit = math.min(self.View.AbsoluteSize.X, self.View.AbsoluteSize.Y)
	self:Place(self.Halo, localPixel, unit * (0.10 + heat * 0.30 + release * 0.5))
	self.Halo.ImageTransparency = if release == 0 then 0.95 - heat * 0.45 else 0.5 + release * 0.5
	self.Halo.Rotation = time * 28
	self:Place(
		self.Flame,
		localPixel - Vector2.new(0, unit * 0.045),
		unit * (0.08 + heat * 0.08),
		unit * (0.12 + heat * 0.16)
	)
	self.Flame.ImageTransparency = 0.5 - heat * 0.35 + release * 0.85
	self:Place(self.Puff, localPixel, unit * (0.1 + release * 0.85))
	self.Puff.Visible = release > 0
	self.Puff.ImageTransparency = release * 0.9
	if self.Atlas then
		local frame = math.min(15, math.floor(release * 16))
		self.Puff.ImageRectOffset = Vector2.new(frame % 4, math.floor(frame / 4)) * K.PressureAtlasFramePixels
	end
	self.Stage.KilnPortrait.FireScale.Scale = 1 - heat * 0.035 + math.sin(release * math.pi) * 0.09
	if self.Lid then
		self.Lid.CFrame = self.LidPose + Vector3.yAxis * (release ^ 0.55 * 2.8)
		self.Lid.CFrame *= CFrame.Angles(0, release * 0.9, release * 0.25)
	end
	for _, v in self.GlowParts do
		v.Part.Color = v.Color:Lerp(Color3.new(1, 1, 1), heat * 0.85 * (1 - release))
	end
	for i, spark in self.Objects do
		local angle = i * 2.399
		local radius = if release == 0 then (1 - heat) * unit * 0.12 else release * unit * (0.28 + i % 4 * 0.035)
		local offset = Vector2.new(math.cos(angle), math.sin(angle)) * radius
		spark.Position = UDim2.fromOffset(localPixel.X + offset.X, localPixel.Y + offset.Y - release * unit * 0.1)
		spark.BackgroundTransparency = if release == 0 then 0.5 + heat * 0.5 else release
	end
end
function Fire:Launch(time)
	local t = math.clamp(time / K.LaunchAfterglow, 0, 1)
	self.Puff.ImageTransparency = math.clamp(0.6 + t * 0.4, 0, 1)
	self.Halo.ImageTransparency = 0.8 + t * 0.2
	self.Flame.ImageTransparency = 1
	for _, s in self.Objects do
		s.BackgroundTransparency = 1
	end
	self.View.ImageTransparency = math.clamp((time - 0.15) / 0.55, 0, 1)
end
function Fire:Destroy()
	self.View:SetAttribute("FreezePortraitCamera", nil)
	if self.Machine then
		self.Machine:Reset()
	end
	for _, s in self.Objects do
		s:Destroy()
	end
	self.Halo:Destroy()
	self.Puff:Destroy()
	self.Flame:Destroy()
end
return Fire
