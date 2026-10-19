-- Shared flyer motion for match rides, lobby displays and previews (docs/art/FLYERS_V3.md section 4).
-- Float (two bob waves + drift), bank into turns and slides, pitch with climb, launch with overshoot,
-- RideMotion parts, RideEmitter effects, RideLaunch bursts and the RideLoop sound. Rides without a
-- Config/RideAnimations.Motion profile (the seasonal carriage) keep the original single-wave motion.
local RS = game:GetService("ReplicatedStorage")
local T = require(RS.Shared.Config.Balance).CosmeticPresentation
local Clips = require(RS.Shared.Config.RideAnimations)
local UIMotion = require(script.Parent.Parent.UI.Components.Motion)

local TAU = math.pi * 2
local LEGACY = { BobAmp = T.RideBob, BobHz = T.RideBobHz, Bank = T.RideBank, Nod = T.RideNod }
local AXES = { X = Vector3.xAxis, Y = Vector3.yAxis, Z = Vector3.zAxis }

local Motion = {}
Motion.__index = Motion

local function isEffect(obj)
	return obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") or obj:IsA("Light")
end

local function axisAngle(name, angle)
	return CFrame.fromAxisAngle(AXES[name or "Z"] or Vector3.zAxis, angle)
end

local function backOut(x)
	local c = 1.4
	x -= 1
	return 1 + (c + 1) * x * x * x + c * x * x
end

-- model: the ride (already at `base`); options: { Id, Seed, Launch = time?, Sound = false to mute }
function Motion.new(model, base, options)
	options = options or {}
	local id = options.Id or model:GetAttribute("RideId")
	local self = setmetatable({
		Model = model,
		Base = base,
		Profile = Clips.Motion and Clips.Motion[id] or LEGACY,
		Seed = options.Seed or base.Position.X,
		Parts = {},
		Effects = {},
		Lights = {},
		Bursts = {},
		Bank = 0,
		Pitch = 0,
		Reduced = UIMotion.reduced(),
	}, Motion)
	self:Collect()
	self.WantsSound = self.Profile.Sound ~= nil and options.Sound ~= false
	self:EnsureSound()
	if options.Launch then
		self:Launch(options.Launch, true)
	end
	-- Per-ride extras module (attribute RideFX = module name under Presentation, or CarriageFX = true):
	-- attach(model, options) -> handle with Offset(time), Step(time, phase, near), Land(parent), Destroy().
	local fxName = model:GetAttribute("RideFX") or (model:GetAttribute("CarriageFX") and "CarriageFX")
	local fxModule = type(fxName) == "string" and script.Parent:FindFirstChild(fxName)
	if fxModule then
		local ok, fx = pcall(function()
			return require(fxModule).attach(model, { Effects = options.Effects, TakeOff = options.Launch ~= nil })
		end)
		if ok then
			self.FX = fx
		else
			warn("RideMotion: " .. fxName .. " attach failed: " .. tostring(fx))
		end
	end
	return self
end

-- The loop sound needs a part to live on; with streaming the ride can arrive before its parts.
function Motion:EnsureSound()
	if not self.WantsSound or self.Sound then
		return
	end
	local host = self.Model.PrimaryPart or self.Model:FindFirstChildWhichIsA("BasePart", true)
	if not host then
		return
	end
	local sound = self.Profile.Sound
	local loop = Instance.new("Sound")
	loop.Name = "RideLoop"
	loop.SoundId, loop.Looped = sound.Id, true
	loop.Volume, loop.PlaybackSpeed = 0, sound.Pitch or 1
	loop.RollOffMode = Enum.RollOffMode.InverseTapered
	loop.RollOffMinDistance, loop.RollOffMaxDistance = sound.MinDistance or 6, sound.MaxDistance or 40
	loop.Parent = host
	self.Sound = loop
end

-- (Re)scan the model; streaming can deliver parts and effects after the ride itself.
function Motion:Collect()
	self:EnsureSound()
	for _, obj in self.Model:GetDescendants() do
		if obj:IsA("BasePart") and obj:GetAttribute("RideMotion") and not self.Parts[obj] then
			self.Parts[obj] = {
				Pose = self.Base:ToObjectSpace(obj.CFrame),
				Size = obj.Size,
				Transparency = obj.Transparency,
				Kind = obj:GetAttribute("RideMotion"),
				Pivot = obj:GetAttribute("WingPivot") or obj:GetAttribute("SwingPivot") or obj:GetAttribute(
					"MotionPivot"
				) or Vector3.zero,
			}
		elseif obj:GetAttribute("RideEmitter") and isEffect(obj) and not table.find(self.Effects, obj) then
			obj.Enabled = self.EffectsOn == true
			table.insert(self.Effects, obj)
			if obj:IsA("Light") then
				self.Lights[obj] = obj:GetAttribute("BaseBrightness") or obj.Brightness
			end
		elseif obj:IsA("ParticleEmitter") and obj:GetAttribute("RideLaunch") and not table.find(self.Bursts, obj) then
			obj.Enabled = false
			table.insert(self.Bursts, obj)
		end
	end
end

-- Rise from below with an overshoot (rise = false: only the burst, for displays that animate their own arrival).
function Motion:Launch(time, rise)
	local launch = self.Profile.Launch
	if rise and launch and not self.Reduced then
		self.LaunchAt = time
	end
	self.SoundFrom = time
	self.PendingBurst = true
end

function Motion:Step(time, base, near)
	local p = self.Profile
	local dt = math.clamp(time - (self.Last or time), 0, 0.1)
	self.Last = time
	local calm = if self.Reduced then 0.4 else 1
	local phase = time * p.BobHz * TAU + self.Seed
	local wave = math.sin(phase)

	-- Drift: a slow wander so a hovering flyer turns and slides a little, which then banks it.
	local drifted = base
	if p.DriftHz then
		local d = time * p.DriftHz * TAU + self.Seed * 1.7
		drifted = base
			* CFrame.new(math.sin(d) * p.DriftX * calm, 0, math.sin(d * 0.5 + 1) * (p.DriftZ or 0) * calm)
			* CFrame.Angles(0, math.sin(d * 0.73 + 2) * (p.DriftYaw or 0) * calm, 0)
	end
	if p.TurnBank and self.Prev and dt > 0 then
		local rel = self.Prev:ToObjectSpace(drifted)
		local _, yaw = rel:ToOrientation()
		local velocity = rel.Position / dt
		local maxBank, maxPitch = p.MaxBank or 0.35, p.MaxPitch or 0.2
		local bank = math.clamp(yaw / dt * p.TurnBank - velocity.X * (p.SlideBank or 0), -maxBank, maxBank)
		local pitch = math.clamp(velocity.Y * (p.ClimbPitch or 0), -maxPitch, maxPitch)
		local k = 1 - math.exp(-(p.Smooth or 4) * dt)
		self.Bank += (bank * calm - self.Bank) * k
		self.Pitch += (pitch * calm - self.Pitch) * k
	end
	self.Prev = drifted

	local lift, launchPitch = 0, 0
	if self.LaunchAt then
		local launch = p.Launch
		local k = (time - self.LaunchAt) / launch.Seconds
		if k >= 1 then
			self.LaunchAt = nil
		else
			k = math.max(k, 0)
			lift = -launch.Drop * (1 - backOut(k))
			launchPitch = (launch.Pitch or 0) * (1 - k) ^ 2
		end
	end
	local bob = wave * p.BobAmp * calm
	if p.Bob2Amp then
		bob += math.sin(time * p.Bob2Hz * TAU + self.Seed * 2.3) * p.Bob2Amp * calm
	end
	local pose = drifted
		* CFrame.new(0, bob + lift, 0)
		* CFrame.Angles(math.cos(phase) * p.Nod * calm + self.Pitch + launchPitch, 0, wave * p.Bank * calm + self.Bank)
	if self.FX then
		pose *= self.FX:Offset(time)
	end
	self.Pose = pose

	if self.EffectsOn ~= near then
		self.EffectsOn = near
		for _, effect in self.Effects do
			effect.Enabled = near
		end
	end
	if near then
		for light, brightness in self.Lights do
			light.Brightness = brightness * (1 - T.RideLightFlicker * (0.5 + 0.5 * math.noise(time * 6, light.Range)))
		end
		if self.PendingBurst then
			self.PendingBurst = nil
			for _, burst in self.Bursts do
				burst:Emit(burst:GetAttribute("EmitCount") or 12)
			end
		end
	end
	local sound = self.Sound
	if sound then
		if near and not sound.Playing then
			sound:Play()
		elseif not near and sound.Playing then
			sound:Stop()
		end
		local fade = if self.SoundFrom then math.clamp((time - self.SoundFrom) / 0.8, 0, 1) else 1
		sound.Volume = p.Sound.Volume * fade
	end

	self.Model:PivotTo(pose)
	for part, rest in self.Parts do
		if not part.Parent then
			self.Parts[part] = nil
			continue
		end
		local kind, pivot = rest.Kind, rest.Pivot
		local cf
		if kind == "Wing" then
			-- Quick down-stroke, slower recovery reads as a real wingbeat.
			local flap = wave + T.RideFlapSharpness * 0.35 * math.sin(phase * 2)
			local angle = part:GetAttribute("WingAngle") or p.WingAngle or T.RideWingAngle
			cf = pose
				* rest.Pose
				* CFrame.new(pivot)
				* CFrame.Angles(0, 0, flap * angle * calm * (part:GetAttribute("WingSide") or 1))
				* CFrame.new(-pivot)
		elseif kind == "Swing" then
			-- The hanging lantern trails the bob and bank like a pendulum.
			local swing = math.sin(phase - T.RideSwingLag) * T.RideSwingAngle
			cf = pose * rest.Pose * CFrame.new(pivot) * CFrame.Angles(swing, 0, -swing * 0.5) * CFrame.new(-pivot)
		elseif kind == "Spin" then
			local speed = part:GetAttribute("SpinSpeed") or T.RideSpinSpeed
			cf = pose * rest.Pose * axisAngle(part:GetAttribute("SpinAxis"), time * speed)
		elseif kind == "Tail" then
			-- Sways behind the body a beat late and swings out of a bank.
			local lag = phase - (part:GetAttribute("TailLag") or 0.8)
			local angle = (part:GetAttribute("TailAngle") or 0.15) * calm
			cf = pose
				* rest.Pose
				* CFrame.new(pivot)
				* CFrame.Angles(math.cos(lag) * angle * 0.35, math.sin(lag) * angle - self.Bank * 0.8, 0)
				* CFrame.new(-pivot)
		elseif kind == "Fin" then
			local hz = part:GetAttribute("FinHz") or p.BobHz
			local flutter = math.sin(time * hz * TAU + (part:GetAttribute("FinPhase") or 0) * TAU)
			local angle = flutter * (part:GetAttribute("FinAngle") or 0.1) * calm
				+ self.Bank * (part:GetAttribute("FinBank") or 0)
			cf = pose
				* rest.Pose
				* CFrame.new(pivot)
				* axisAngle(part:GetAttribute("FinAxis") or "X", angle)
				* CFrame.new(-pivot)
		elseif kind == "Pulse" then
			local breathe = math.sin(time * T.RidePulseHz * TAU)
			part.Size = rest.Size * (1 + T.RidePulseScale * breathe)
			part.Transparency = rest.Transparency + T.RidePulseFade * (0.5 + 0.5 * breathe)
		elseif kind == "Puff" then
			local breathe = math.sin(time * (p.PuffHz or 0.7) * TAU + (part:GetAttribute("PuffPhase") or 0))
			part.Size = rest.Size * (1 + (p.PuffScale or 0.06) * breathe * calm)
		else -- Flame
			local f = math.sin(time * T.RideExhaustSpeed + (part:GetAttribute("FlamePhase") or 0))
			local g = math.noise(time * 9, rest.Size.X * 7)
			part.Size = rest.Size * Vector3.new(0.96 + 0.04 * g, 0.96 + 0.04 * g, 0.8 + f * 0.2)
		end
		if cf then
			-- Any moving part can also turn on its own axis (the ray's tail prism).
			local spin = kind ~= "Spin" and part:GetAttribute("SpinSpeed")
			part.CFrame = if spin then cf * axisAngle(part:GetAttribute("SpinAxis"), time * spin) else cf
		end
	end
	if self.FX then
		self.FX:Step(time, phase, near)
	end
	return pose
end

-- land: a parent for the ride's landing flourish (rides leaving while visible); nil = silent cleanup.
function Motion:Destroy(land)
	if self.FX then
		if land then
			self.FX:Land(land)
		else
			self.FX:Destroy()
		end
		self.FX = nil
	end
	if self.Sound then
		self.Sound:Destroy()
		self.Sound = nil
	end
	table.clear(self.Parts)
	table.clear(self.Effects)
	table.clear(self.Bursts)
end

return Motion
