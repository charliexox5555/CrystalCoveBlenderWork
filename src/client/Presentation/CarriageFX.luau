-- Moonlantern Carriage extras (docs/vfx/HOLLOWLIGHT_PREMIUM.md section 5), on top of a host's RideMotion pass.
-- Hosts (RideController in rounds, BundleStage, ShowcaseController) call, for a model with attribute CarriageFX:
--   local fx = CarriageFX.attach(model, { Effects = folder })  -- take-off flourish + loop sound start
--   motion *= fx:Offset(time)                                    -- take-off lift, before posing model and rider
--   fx:Step(time, phase, near)                                   -- after the RideMotion parts are posed
--   fx:Land() / fx:Destroy()                                     -- landing flourish on removal / silent cleanup
-- Parts opt in with attribute CarriageMotion:
--   WingTip (+ FollowPart = wing name, TipAxis0/TipAxis1 in the wing's local space): flexes after the wing beat
--   Flame: lantern flame flicker   Glow: breathing glow   Twinkle: colour twinkle (tail star, hull stars)
-- Client-only and cosmetic; every sound and part is owned by the handle and removed with it.
local RS = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local Audio = require(RS.Shared.Config.Audio)
local AudioCues = require(RS.Shared.Config.AudioCues)
local Sound = require(RS.Shared.Config.HollowlightAudio).Ride
local C = require(RS.Shared.Config.Balance).CosmeticPresentation.Carriage
local CarriageFX = {}
CarriageFX.__index = CarriageFX

local TAU = math.pi * 2
local WHITE = Color3.new(1, 1, 1)

local function trim(key)
	local id = Audio[key]
	return id, id and AudioCues[id]
end

-- One-shot sound layers ({ Key, Volume, Pitch, At }) on `parent` (3D when it is a part).
local function layers(list, parent, owner)
	for _, layer in list do
		task.delay(layer.At or 0, function()
			if not parent.Parent or (owner and owner.Stopped) then
				return
			end
			local id, cue = trim(layer.Key)
			if not id then
				return
			end
			local sound = Instance.new("Sound")
			sound.Name = "Carriage_" .. layer.Key
			sound.SoundId = id
			sound.Volume = (if cue then cue.Volume else 0.35) * layer.Volume
			sound.PlaybackSpeed = (layer.Pitch or 1) * (if cue then cue.Pitch else 1)
			sound.TimePosition = if cue then cue.Start else 0
			sound.RollOffMinDistance, sound.RollOffMaxDistance = Sound.RollOffMin, Sound.RollOffMax
			sound.Parent = parent
			sound:Play()
			local seconds = (if cue then cue.Seconds else 1.5) / sound.PlaybackSpeed
			local fade = math.min(seconds, if cue then cue.Fade else 0.1)
			task.delay(math.max(0, seconds - fade), function()
				if sound.Parent then
					TweenService:Create(sound, TweenInfo.new(fade), { Volume = 0 }):Play()
				end
			end)
			Debris:AddItem(sound, seconds + 0.1)
		end)
	end
end

local function burst(emitter, count)
	if emitter and count > 0 then
		emitter:Emit(count)
	end
end

function CarriageFX.attach(model, options)
	if not model:GetAttribute("CarriageFX") then
		return nil
	end
	local opts = options or {}
	local self = setmetatable({
		Model = model,
		Effects = opts.Effects or model,
		Born = nil,
		Tips = {},
		Flames = {},
		Glows = {},
		Twinkles = {},
		Loops = {},
		Stopped = false,
		Quiet = opts.Quiet == true,
	}, CarriageFX)
	self.Body = model:FindFirstChild("Hull", true)
		or model.PrimaryPart
		or model:FindFirstChildWhichIsA("BasePart", true)
	for _, p in model:GetDescendants() do
		if not p:IsA("BasePart") then
			continue
		end
		local kind = p:GetAttribute("CarriageMotion")
		if kind == "WingTip" then
			local wing = model:FindFirstChild(p:GetAttribute("FollowPart") or "", true)
			if wing then
				table.insert(self.Tips, {
					Part = p,
					Wing = wing,
					Offset = wing.CFrame:ToObjectSpace(p.CFrame),
					A = p:GetAttribute("TipAxis0") or Vector3.zero,
					B = p:GetAttribute("TipAxis1") or Vector3.yAxis,
					Side = p:GetAttribute("WingSide") or 1,
				})
			end
		elseif kind == "Flame" then
			table.insert(self.Flames, { Part = p, Size = p.Size })
		elseif kind == "Glow" then
			table.insert(self.Glows, { Part = p, Alpha = p.Transparency })
		elseif kind == "Twinkle" then
			table.insert(self.Twinkles, { Part = p, Color = p.Color })
		end
	end
	-- One-shot emitters (Enabled = false) authored on the model for take-off and landing.
	for _, e in model:GetDescendants() do
		if e:IsA("ParticleEmitter") and e:GetAttribute("CarriageBurst") then
			self[e:GetAttribute("CarriageBurst")] = e
		end
	end
	-- Looped bed: silent until Step says the camera is near.
	if self.Body and not self.Quiet then
		for _, layer in Sound.Loop do
			local id, cue = trim(layer.Key)
			if id then
				local s = Instance.new("Sound")
				s.Name = "CarriageLoop_" .. layer.Key
				s.SoundId, s.Looped, s.Volume = id, true, 0
				s.PlaybackSpeed = (layer.Pitch or 1) * (if cue then cue.Pitch else 1)
				s.RollOffMinDistance, s.RollOffMaxDistance = Sound.RollOffMin, Sound.RollOffMax
				s.Parent = self.Body
				table.insert(self.Loops, { Sound = s, Volume = (if cue then cue.Volume else 0.2) * layer.Volume })
			end
		end
	end
	self.TakeOff = opts.TakeOff ~= false
	return self
end

-- Take-off lift: starts below its hover point and eases up with a little overshoot.
function CarriageFX:Offset(time)
	if not self.TakeOff then
		return CFrame.identity
	end
	if not self.Born then
		self.Born = time
		self:Flourish("TakeOff")
	end
	local k = math.clamp((time - self.Born) / C.TakeOffSeconds, 0, 1)
	if k >= 1 then
		return CFrame.identity
	end
	local ease = 1 + 2.2 * (k - 1) ^ 3 + 1.2 * (k - 1) ^ 2 -- back ease-out
	return CFrame.new(0, -C.TakeOffLift * (1 - ease), 0) * CFrame.Angles(-(1 - k) * 0.12, 0, 0)
end

function CarriageFX:Flourish(kind)
	if kind == "TakeOff" then
		burst(self.TakeOffDust, C.DustBurst)
		burst(self.TakeOffWisps, C.WispBurst)
		if self.Body and not self.Quiet then
			layers(Sound.TakeOff, self.Body, self)
		end
	end
end

function CarriageFX:Step(time, phase, near)
	if self.Stopped then
		return
	end
	local born = self.Born or time
	local glowUp = math.clamp((time - born) / C.TakeOffSeconds, 0, 1)
	for _, tip in self.Tips do
		if not tip.Part.Parent or not tip.Wing.Parent then
			continue
		end
		-- The tip trails the wing beat: bend about the wrist line, lagging the stroke.
		local bend = math.sin(phase - C.TipLag) * C.TipFlex * tip.Side
		local axis = (tip.B - tip.A)
		axis = if axis.Magnitude > 1e-4 then axis.Unit else Vector3.yAxis
		local hinge = CFrame.new(tip.A) * CFrame.fromAxisAngle(axis, bend) * CFrame.new(-tip.A)
		tip.Part.CFrame = tip.Wing.CFrame * hinge * tip.Offset
	end
	for i, f in self.Flames do
		local flicker = 1 + C.FlameFlicker * math.noise(time * C.FlameHz, i)
		f.Part.Size = f.Size * Vector3.new(1, flicker * 1.08, 1) * flicker
	end
	for i, g in self.Glows do
		local breathe = 0.5 + 0.5 * math.sin(time * C.CoreHz * TAU + i)
		-- Brightest just after take-off, then a steady breathing glow.
		g.Part.Transparency = math.clamp(g.Alpha + C.CorePulse * breathe * glowUp, 0, 0.95)
	end
	for i, t in self.Twinkles do
		local tw = math.max(0, math.sin(time * C.TwinkleHz * TAU + i * 1.7)) ^ 6
		t.Part.Color = t.Color:Lerp(WHITE, tw * 0.7)
	end
	local camera = workspace.CurrentCamera
	if self.Body then
		self.LastAt = self.Body.Position
	end
	local distance = if self.Body then (camera.CFrame.Position - self.Body.Position).Magnitude else math.huge
	local loud = near and distance < Sound.LoopDistance
	for _, loop in self.Loops do
		local s = loop.Sound
		if loud and not s.IsPlaying then
			s:Play()
		end
		local target = if loud then loop.Volume else 0
		-- Fade in and out over LoopFadeSeconds (frame-rate independent enough at 30-60 fps).
		s.Volume += (target - s.Volume) * math.clamp(1 / (C.LoopFadeSeconds * 60), 0, 1)
		if not loud and s.Volume < 0.002 and s.IsPlaying then
			s:Stop()
		end
	end
end

-- Landing flourish where the carriage was: falling chime, a poof and a ring of moon dust and wisps.
function CarriageFX:Land(parent)
	if self.Stopped then
		return
	end
	-- The model may already be gone (the server removed the ride), so use the last place it was seen.
	local at = self.LastAt
	local holder = parent or workspace
	if at and holder.Parent and (workspace.CurrentCamera.CFrame.Position - at).Magnitude < Sound.RollOffMax * 2 then
		local socket = Instance.new("Part")
		socket.Name = "CarriageLanding"
		socket.Anchored, socket.CanCollide, socket.CanTouch, socket.CanQuery = true, false, false, false
		socket.Transparency, socket.Size, socket.Position = 1, Vector3.one * 0.2, at
		socket:SetAttribute("CosmeticOnly", true)
		socket.Parent = holder
		local life = 0.5
		for _, key in { "TakeOffDust", "TakeOffWisps" } do
			local source = self[key]
			if source then
				local e = source:Clone()
				e.Parent = socket
				e:Emit(if key == "TakeOffDust" then C.DustBurst else C.WispBurst)
				life = math.max(life, e.Lifetime.Max)
			end
		end
		if not self.Quiet then
			layers(Sound.Land, socket, nil)
		end
		Debris:AddItem(socket, math.max(life, 1.6))
	end
	self:Destroy()
end

function CarriageFX:Destroy()
	if self.Stopped then
		return
	end
	self.Stopped = true
	for _, loop in self.Loops do
		loop.Sound:Destroy()
	end
	self.Loops = {}
end

return CarriageFX
