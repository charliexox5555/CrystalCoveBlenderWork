-- Client-only fight feel for one FightView: hit tiers, hitstop, camera kick/shake/FOV punch, glass reactions and the
-- Perfect / block / power land-miss / comeback / KO / victory / manual-cast beats. Never touches server state.
-- Numbers: Config/CombatFeel. Reduced motion: UI/Components/Motion.reduced() (PlayerGui attribute or Roblox setting).
local RS = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local STUDIO = game:GetService("RunService"):IsStudio()
local Balance = require(RS.Shared.Config.Balance)
local Audio = require(RS.Shared.Config.Audio)
local C = require(RS.Shared.Config.CombatFeel)
local Impact = require(script.Parent.ImpactBeat)
local Motion = require(script.Parent.Parent.UI.Components.Motion)
local LocalSettings = require(script.Parent.Parent.LocalSettings)
local Cam, R, Hold = C.Camera, C.React, C.Hitstop
local Feel = {}
Feel.__index = Feel

local E = math.exp(1)

local function assets()
	local library = RS.Assets:FindFirstChild("VFX") and RS.Assets.VFX:FindFirstChild("Combat")
	local preview = RS.Assets:FindFirstChild("CombatReleasePreview")
	return library or (preview and preview:FindFirstChild("Combat"))
end

function Feel.new(view)
	return setmetatable({
		View = view,
		Trauma = 0,
		Kick = Vector2.zero,
		KickVelocity = Vector2.zero,
		Fov = 0,
		HoldUntil = 0,
		Reacts = {},
		Ready = {},
		Manual = {},
		Grade = { Tension = 0, Pulse = 0 },
		NextPulse = 0,
		LastComeback = -math.huge,
		SettingsAt = -math.huge,
	}, Feel)
end

-- Cached once a second: reduced motion and the particle budget (touch-only or low graphics quality).
function Feel:Settings(now)
	if now - self.SettingsAt < 1 then
		return
	end
	self.SettingsAt = now
	self.Reduced = Motion.reduced()
	local scale = 1
	if UIS.TouchEnabled and not UIS.KeyboardEnabled then
		scale = C.Budget.MobileParticles
	end
	local ok, level = pcall(function()
		return UserSettings():GetService("UserGameSettings").SavedQualityLevel.Value
	end)
	if (ok and level > 0 and level <= C.Budget.LowQualityLevel) or LocalSettings.lowEffects() then
		scale = math.min(scale, C.Budget.LowParticles)
		self.LowQuality = true
	else
		self.LowQuality = false
	end
	self.Particles = scale
end

function Feel:Scale(kind)
	return if self.Reduced then C.ReducedMotion[kind] else 1
end

-- Studio-only counters on the fight folder, so MCP checks can see which beats played in a live fight.
function Feel:Note(key, value)
	local scene = STUDIO and self.View.Scene
	if scene then
		local root = scene.Root
		root:SetAttribute(key, if value ~= nil then value else (root:GetAttribute(key) or 0) + 1)
	end
end

function Feel:Viewing()
	local v = self.View
	return v.Viewing == true and v.Scene ~= nil
end

function Feel:Sounds(list, parent, glassyPitch)
	local scene = self.View.Scene
	if not scene or scene.Muted or not list then
		return
	end
	for _, layer in list do
		local id = Audio[layer.Key]
		if id then
			local pitch = layer.Pitch
				* (if layer.UseGlassyPitch then glassyPitch or 1 else 1)
				* (1 + (math.random() * 2 - 1) * (layer.Jitter or 0))
			local play = function()
				if parent.Parent and not scene.Muted then
					scene:Sound(id, parent, pitch, layer.Volume, layer.Short)
				end
			end
			if layer.Delay then
				task.delay(layer.Delay, play)
			else
				play()
			end
		end
	end
end

-- Hitstop -----------------------------------------------------------------------------------------------------------

function Feel:Hold(seconds, now)
	if seconds <= 0 then
		return
	elseif not self:Viewing() then
		self:Note("FeelHoldSkipView")
		return
	elseif self.View.FinalTime then
		self:Note("FeelHoldSkipFinal")
		return
	end
	seconds = math.min(seconds * self:Scale("Hitstop"), Hold.MaxSeconds)
	self.HoldUntil = math.max(self.HoldUntil, now + seconds)
	self:Note("FeelHolds")
	self:Note("FeelLastHoldMs", math.floor(seconds * 1000 + 0.5))
end

-- Render clock speed: near-freeze during a hold, then proportional catch-up toward the interpolation target.
function Feel:Rate(now, lag)
	if now < self.HoldUntil then
		return Hold.HoldRate
	end
	return math.max(Hold.NormalRate, math.min(Hold.CatchUpMax, 1 + math.max(0, lag) * Hold.CatchUpGain))
end

-- Camera ------------------------------------------------------------------------------------------------------------

function Feel:Shake(trauma)
	self.Trauma = math.min(1, self.Trauma + trauma)
end

function Feel:Punch(degrees)
	if degrees ~= 0 then
		self.Fov = math.max(Cam.FovMin, self.Fov + degrees * self:Scale("Fov"))
	end
end

-- Kick the shot along the hit direction as seen on screen (critically damped spring, peak ~= studs).
function Feel:KickToward(direction, studs)
	if studs <= 0 or direction.Magnitude < 1e-3 then
		return
	end
	local camera = workspace.CurrentCamera.CFrame
	local d = Vector2.new(direction:Dot(camera.RightVector), direction:Dot(camera.UpVector))
	if d.Magnitude < 1e-3 then
		d = Vector2.new(0, -1)
	end
	self.KickVelocity += d.Unit * studs * math.sqrt(Cam.KickSpring) * E * self:Scale("Shake")
end

-- Returns the camera-local offset CFrame and the FOV delta for this frame.
function Feel:Camera(now)
	local t = now * Cam.ShakeHz
	local amount = self.Trauma * self.Trauma * self:Scale("Shake")
	local shake = Vector3.new(math.noise(t, 1.7), math.noise(t, 5.3), 0) * Cam.ShakeStuds * amount
	local offset = shake + Vector3.new(self.Kick.X, self.Kick.Y, 0)
	if offset.Magnitude > Cam.MaxStuds then
		offset = offset.Unit * Cam.MaxStuds
	end
	local roll = math.noise(t, 9.1) * Cam.ShakeRoll * amount
	return CFrame.new(offset) * CFrame.Angles(0, 0, roll), self.Fov
end

-- Glass reactions ---------------------------------------------------------------------------------------------------

function Feel:React(side, spec, direction, scaleBy)
	local scene = self.View.Scene
	local f = scene and scene.Fighters[side]
	if not f or f.Broken or f.Finishing or not f.Pivot or not spec then
		return
	end
	local scale = (scaleBy or 1) * self:Scale("React")
	local state = self.Reacts[side]
	if not state then
		local offset = f.Body.PivotOffset
		state = {
			Center = offset:Inverse().Position,
			Angle = Vector3.zero,
			Velocity = Vector3.zero,
			Jolt = Vector3.zero,
		}
		self.Reacts[side] = state
	end
	local localDir = f.Pivot:VectorToObjectSpace(direction)
	if localDir.Magnitude < 1e-3 then
		localDir = Vector3.xAxis
	end
	localDir = localDir.Unit
	local axis = Vector3.yAxis:Cross(localDir)
	if axis.Magnitude < 1e-3 then
		axis = Vector3.zAxis
	end
	-- Underdamped spring: initial angular speed w * wobble peaks near `wobble` radians.
	state.Velocity += axis.Unit * (spec.Wobble or 0) * math.sqrt(R.Spring) * scale
	state.Jolt += localDir * (spec.Jolt or 0) * scale
	if state.Jolt.Magnitude > R.MaxJolt then
		state.Jolt = state.Jolt.Unit * R.MaxJolt
	end
end

function Feel:StepReacts(dt)
	local scene = self.View.Scene
	for side, state in self.Reacts do
		local f = scene.Fighters[side]
		local acc = -state.Angle * R.Spring - state.Velocity * R.Damping
		state.Velocity += acc * dt
		state.Angle += state.Velocity * dt
		if state.Angle.Magnitude > R.MaxAngle then
			state.Angle = state.Angle.Unit * R.MaxAngle
		end
		state.Jolt *= math.exp(-R.JoltDecay * dt)
		local angle = state.Angle.Magnitude
		if angle < 1e-4 and state.Velocity.Magnitude < 1e-3 and state.Jolt.Magnitude < 1e-3 then
			f.React = nil
			self.Reacts[side] = nil
		else
			local rotation = if angle > 1e-5 then CFrame.fromAxisAngle(state.Angle / angle, angle) else CFrame.identity
			f.React = CFrame.new(state.Jolt) * CFrame.new(state.Center) * rotation * CFrame.new(-state.Center)
		end
	end
end

-- A one-shot white wash over the glassy (its own Highlight, so power tints keep theirs).
function Feel:Flash(side, seconds)
	local scene = self.View.Scene
	local f = scene and scene.Fighters[side]
	if seconds <= 0 or not f or f.Broken or (f.Highlight and f.Highlight.Enabled) or self.LowQuality then
		return
	end
	local h = f.FeelFlash
	if not h or not h.Parent then
		h = Instance.new("Highlight")
		h.Name, h.Adornee, h.DepthMode = "FeelFlash", f.Model, Enum.HighlightDepthMode.Occluded
		h.FillColor, h.OutlineColor = Color3.fromHex(R.FlashColor), Color3.fromHex(R.FlashColor)
		h.Parent = scene.Root
		f.FeelFlash = h
	end
	if f.FeelFlashTween then
		f.FeelFlashTween:Cancel()
	end
	h.FillTransparency, h.OutlineTransparency, h.Enabled = 0.25, 0.1, true
	local tween = TweenService:Create(h, TweenInfo.new(seconds, Enum.EasingStyle.Quad), {
		FillTransparency = 1,
		OutlineTransparency = 1,
	})
	f.FeelFlashTween = tween
	tween.Completed:Once(function(state)
		if state == Enum.PlaybackState.Completed and h.Parent then
			h.Enabled = false
		end
	end)
	tween:Play()
end

function Feel:Burst(tier, position)
	local scene, library = self.View.Scene, assets()
	if scene and library then
		Impact.tier(scene.Root, library, position, tier, {
			Particles = self.Particles,
			Light = not self.LowQuality,
		})
	end
end

function Feel:Glint(side, seconds)
	local scene = self.View.Scene
	local f = scene and scene.Fighters[side]
	if f and seconds > 0 and scene.Shatter.GlintCracks then
		scene.Shatter:GlintCracks(f, seconds)
	end
end

-- Beats -------------------------------------------------------------------------------------------------------------

function Feel:Classify(e)
	local scene = self.View.Scene
	local d = math.max(e.Damage[1] / scene.Fighters[1].Stats.MaxHP, e.Damage[2] / scene.Fighters[2].Stats.MaxHP)
	if (e.Blocked[1] or e.Blocked[2]) and e.Damage[1] + e.Damage[2] <= 0 then
		return "Block"
	elseif e.Crit[1] or e.Crit[2] then
		return "Crit"
	end
	local speed = e.Speed / Balance.Fight.RefSpeed
	for _, name in { "Smash", "Solid" } do
		local rule = C.Classify[name]
		if speed >= rule.Speed or d >= rule.Damage then
			return name
		end
	end
	return "Glance"
end

function Feel:Hit(e, now)
	local scene = self.View.Scene
	local library = assets()
	if not scene or not library then
		return
	end
	self:Settings(now)
	local name = self:Classify(e)
	local tier = C.Tiers[name]
	local a, b = scene.Fighters[1], scene.Fighters[2]
	-- The striker dealt the bigger share (or the crit); on a full block it is the side that got blocked.
	local striker
	if name == "Block" then
		striker = if e.Blocked[2] then 1 else 2
	elseif e.Crit[1] ~= e.Crit[2] then
		striker = if e.Crit[1] then 1 else 2
	else
		striker = if e.Damage[2] / b.Stats.MaxHP >= e.Damage[1] / a.Stats.MaxHP then 1 else 2
	end
	local struck = 3 - striker
	local from, to = scene.Fighters[striker].Body.Position, scene.Fighters[struck].Body.Position
	local direction = if (to - from).Magnitude > 1e-3 then (to - from).Unit else scene.Frame.RightVector
	local point = if e.Z then scene.Frame:PointToWorldSpace(Vector3.new(e.X, e.Y, e.Z)) else (from + to) / 2
	local viewing = self:Viewing()
	self:Note("FeelHit" .. name)
	Impact.tier(scene.Root, library, point, tier, {
		LowDetail = a.LowDetail or not viewing,
		Particles = self.Particles,
		Light = viewing and not self.LowQuality,
	})
	self:Sounds(tier.Sounds, scene.Fighters[struck].Body, scene.Fighters[striker].Def.ClinkPitch)
	if viewing then
		self:Hold(tier.Hitstop, now)
		self:Shake(tier.Trauma)
		self:KickToward(direction, tier.Kick)
		self:Punch(tier.Fov)
		self:React(struck, tier.Struck, direction)
		self:React(striker, tier.Striker, -direction)
		self:Glint(struck, tier.CrackGlint)
		self:Flash(struck, tier.ImpactFlash)
		if tier.Striker.Glints > 0 and not scene.Fighters[striker].Broken then
			scene.Fighters[striker].Glints:Emit(math.floor(tier.Striker.Glints * (self.Particles or 1) + 0.5))
		end
		self:Comeback(e, now)
	end
	return name
end

function Feel:Comeback(e, now)
	local view, scene = self.View, self.View.Scene
	if not e.Hp or e.Hp[1] <= 0 or e.Hp[2] <= 0 then
		return
	end
	local lead = e.Hp[1] / scene.Fighters[1].Stats.MaxHP - e.Hp[2] / scene.Fighters[2].Stats.MaxHP
	local leader = if lead > 0.001 then 1 elseif lead < -0.001 then 2 else nil
	if not leader then
		return
	end
	if self.Leader and leader ~= self.Leader then
		local cfg = C.Comeback
		if (self.Swing or 0) >= cfg.MinLead and (view.RenderTime or 0) - self.LastComeback >= cfg.Cooldown then
			self.LastComeback = view.RenderTime or 0
			self:Note("FeelComeback")
			local f = scene.Fighters[leader]
			local color = Color3.fromHex(cfg.Color)
			self:Burst(cfg.Burst, f.Body.Position)
			if view.Hud and view.Hud.Popup and cfg.Text ~= "" then
				view.Hud:Popup(cfg.Text, f.Body.Position + Vector3.yAxis * 2.6, color, 0, "Comeback")
			end
			self:Sounds(cfg.Sounds, f.Body)
		end
		self.Swing = 0
	end
	self.Leader = leader
	self.Swing = math.max(self.Swing or 0, math.abs(lead))
end

function Feel:Perfect(e, now)
	local scene = self.View.Scene
	local f = scene and e.Side and scene.Fighters[e.Side]
	if not f or not self:Viewing() then
		return
	end
	self:Settings(now)
	local cfg = C.Perfect
	self:Note("FeelPerfect")
	self:Burst(cfg.Burst, f.Body.Position)
	if e.Side == self.View.Side then
		self:Punch(cfg.Fov)
	end
	self:Sounds(cfg.Sounds, f.Body)
end

-- A power/signature reached its target (`target` side) or went wide (`caster` side).
function Feel:PowerLand(target, now)
	local scene = self.View.Scene
	local f = scene and target and scene.Fighters[target]
	if not f or not self:Viewing() then
		return
	end
	local cfg = C.PowerLand
	self:Note("FeelPowerLand")
	local foe = scene.Fighters[3 - target]
	local direction = f.Body.Position - foe.Body.Position
	direction = if direction.Magnitude > 1e-3 then direction.Unit else scene.Frame.RightVector
	if now - (self.LastPowerLand or -math.huge) >= cfg.MinGap then
		self.LastPowerLand = now
		self:Hold(Hold.PowerLand, now)
		self:Shake(cfg.Trauma)
		self:KickToward(direction, cfg.Kick)
		self:Punch(cfg.Fov)
	end
	self:React(target, cfg.Struck, direction)
	self:Glint(target, cfg.CrackGlint)
end

function Feel:PowerMiss(caster)
	local scene = self.View.Scene
	local f = scene and caster and scene.Fighters[caster]
	if not f or not self:Viewing() then
		return
	end
	self:Note("FeelPowerMiss")
	-- A small "shrug" wobble on the caster and a soft falling whoosh; no shake for a whiff.
	self:React(caster, { Wobble = C.PowerMiss.Wobble, Jolt = 0 }, scene.Frame.LookVector)
	self:Sounds(C.PowerMiss.Sounds, f.Body)
end

function Feel:Block(side, now)
	local scene = self.View.Scene
	local f = scene and side and scene.Fighters[side]
	if not f or not self:Viewing() then
		return
	end
	local tier = C.Tiers.Block
	self:Note("FeelBlock")
	local foe = scene.Fighters[3 - side]
	local direction = foe.Body.Position - f.Body.Position
	direction = if direction.Magnitude > 1e-3 then direction.Unit else scene.Frame.RightVector
	self:Hold(tier.Hitstop, now)
	self:Shake(tier.Trauma)
	self:KickToward(-direction, tier.Kick)
	-- The attacker bounces off the guard.
	self:React(3 - side, tier.Striker, -direction)
end

-- Cast contract (workstream A): SignatureReady / ReadyCancel / CastStart { Manual } / SignatureArmed { Manual }.
function Feel:Cast(e, now)
	local view, scene = self.View, self.View.Scene
	local f = scene and e.Side and scene.Fighters[e.Side]
	if not f or f.Broken then
		return
	end
	self:Settings(now)
	if e.Type == "SignatureReady" then
		-- Ready can be re-sent (late join, state packets); ping once per ReadyId.
		local id = e.ReadyId or e.Time
		if self.Ready[e.Side] == id then
			return
		end
		self.Ready[e.Side] = id
		if e.Side == view.Side and view.Participant then
			f.Glints:Emit(C.Cast.ReadyGlints)
			self:Sounds(C.Cast.ReadySounds, f.Body)
		end
	elseif e.Type == "ReadyCancel" then
		self.Ready[e.Side] = nil
	elseif e.Type == "CastStart" or e.Type == "SignatureArmed" then
		-- Contact-payoff kits arm (SignatureArmed) instead of starting a cast; both carry Manual.
		self.Ready[e.Side] = nil
		if e.Manual ~= true then
			return
		end
		local key = e.Type .. ":" .. tostring(e.CastId or e.Time) .. ":" .. e.Side
		if self.Manual[key] then
			return
		end
		self.Manual[key] = true
		self:Note("FeelManualCast")
		local cfg = C.Cast.Manual
		local mine = e.Side == view.Side and view.Participant
		if not self:Viewing() then
			return
		end
		-- The world flourish on the glassy belongs to HeroPowers (workstream E); this is the screen layer only.
		local color = Color3.fromHex(cfg.Color)
		if mine then
			self:Note("FeelManualCastMine")
			self:Hold(cfg.Hitstop, now)
			self:Shake(cfg.Trauma)
			self:Punch(cfg.Fov)
			self:Flash(e.Side, 0.12)
			if view.Hud and view.Hud.Popup and cfg.Text ~= "" then
				view.Hud:Popup(cfg.Text, f.Body.Position + Vector3.yAxis * 2.4, color, 0, "ManualCast")
			end
			if view.Hud and view.Hud.Edge then
				view.Hud:Edge(color)
			end
			self:Sounds(cfg.Sounds, f.Body)
		end
	end
end

-- The final blow lands: returns how long to hold the frame before the shatter/finisher plays.
function Feel:KO(e, now)
	local scene = self.View.Scene
	if not scene or not self:Viewing() then
		return 0
	end
	self:Settings(now)
	local cfg = C.KO
	local f = scene.Fighters[e.Side]
	if f and not f.Broken then
		self:Flash(e.Side, cfg.ImpactFlash + cfg.HoldSeconds)
		self:Glint(e.Side, cfg.HoldSeconds + 0.1)
		self:Sounds(cfg.Sounds, f.Body)
	end
	self:Shake(cfg.Trauma)
	self:Punch(cfg.Fov)
	self.Grade.KOAt = now
	self:Note("FeelKO")
	return if self.Reduced then cfg.ReducedHoldSeconds else cfg.HoldSeconds
end

function Feel:Victory(winner, now)
	local view, scene = self.View, self.View.Scene
	local f = scene and winner and scene.Fighters[winner]
	if not f or f.Broken or not self:Viewing() then
		return
	end
	local cfg = C.Victory
	self:Note("FeelVictory")
	self:Burst(cfg.Burst, f.Body.Position)
	self:Sounds(if view.Participant and winner == view.Side then cfg.LocalWinSounds else cfg.Sounds, f.Body)
end

-- Per frame ---------------------------------------------------------------------------------------------------------

-- Authoritative HP for the low-HP tension cue (participants only, own glassy).
function Feel:Update(r, now)
	local view = self.View
	local cfg = C.Tension
	local target = 0
	local f = view.Participant and view.Scene and view.Scene.Fighters[view.Side]
	if f and not f.Broken and view.Phase == "Fighting" and not view.FinalTime then
		local hp = r.Hp[view.Side] / f.Stats.MaxHP
		if hp > 0 and hp <= cfg.Fraction then
			target = 1
			if now >= self.NextPulse then
				self.NextPulse = now + cfg.PulseEvery
				self:Glint(view.Side, cfg.PulseGlint)
				self:Sounds(cfg.Sounds, f.Body)
			end
		end
	end
	self.Grade.Target = target
end

function Feel:Step(dt, now)
	dt = math.min(dt, 1 / 20)
	self:Settings(now)
	self.Trauma = math.max(0, self.Trauma - Cam.TraumaDecay * dt)
	local k = Cam.KickSpring
	local acc = -self.Kick * k - self.KickVelocity * 2 * math.sqrt(k)
	self.KickVelocity += acc * dt
	self.Kick += self.KickVelocity * dt
	self.Fov *= math.exp(-Cam.FovRecover * dt)
	if self.View.Scene then
		self:StepReacts(dt)
	end
	self:StepGrade(dt, now)
end

function Feel:StepGrade(dt, now)
	local grade = self.Grade
	grade.Tension += ((grade.Target or 0) - grade.Tension) * (1 - math.exp(-dt / C.Tension.EaseSeconds * 3))
	local ko = 0
	if grade.KOAt then
		local age = now - grade.KOAt
		ko = if age < C.KO.HoldSeconds then 1 else math.max(0, 1 - (age - C.KO.HoldSeconds) / C.KO.GradeSeconds)
		if ko <= 0 then
			grade.KOAt = nil
		end
	end
	local scale = self:Scale("Grade")
	local saturation = (grade.Tension * C.Tension.Saturation + ko * C.KO.Saturation) * scale
	local contrast = (grade.Tension * C.Tension.Contrast + ko * C.KO.Contrast) * scale
	local brightness = ko * C.KO.Brightness * scale
	local active = self:Viewing() and (math.abs(saturation) > 0.002 or math.abs(contrast) > 0.002)
	if not active then
		if self.Effect then
			self.Effect.Enabled = false
		end
		return
	end
	if not self.Effect or not self.Effect.Parent then
		self.Effect = Instance.new("ColorCorrectionEffect")
		self.Effect.Name = "FightFeelGrade"
		self.Effect.Parent = Lighting
	end
	self.Effect.Enabled = true
	self.Effect.Saturation, self.Effect.Contrast, self.Effect.Brightness = saturation, contrast, brightness
end

function Feel:Reset()
	self.Trauma, self.Kick, self.KickVelocity, self.Fov, self.HoldUntil = 0, Vector2.zero, Vector2.zero, 0, 0
	self.Grade = { Tension = 0, Pulse = 0 }
	if self.Effect then
		self.Effect.Enabled = false
	end
end

function Feel:Destroy()
	local scene = self.View.Scene
	for side in self.Reacts do
		if scene and scene.Fighters[side] then
			scene.Fighters[side].React = nil
		end
	end
	self.Reacts = {}
	if scene then
		for _, f in scene.Fighters do
			if f.FeelFlashTween then
				f.FeelFlashTween:Cancel()
			end
			if f.FeelFlash then
				f.FeelFlash:Destroy()
			end
			f.FeelFlash, f.FeelFlashTween = nil, nil
		end
	end
	if self.Effect then
		self.Effect:Destroy()
		self.Effect = nil
	end
end

return Feel
