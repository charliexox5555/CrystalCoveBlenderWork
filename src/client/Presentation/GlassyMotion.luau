-- Living glassies (workstream E): Details parts move relative to the body from Config/GlassyMotion (generated from
-- the Blender motion manifests). Idle loops, per-part hit reactions scaled by the hit tier, a livelier Ready state and
-- a cast flourish, plus a very small per-type body idle. Whole-body squash/wobble on hits belongs to CombatFeel (B).
-- Only models flagged for it run (source attribute MotionVersion >= 3, or Pivot_<Detail> markers); the installed v2
-- models and anything without a config entry are left untouched. Presentation only.
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(RS.Shared.Config.GlassyMotion)

local Reduced = require(script.Parent.Parent.UI.Components.Motion)

local Motion = {}
Motion.__index = Motion

-- Reduced motion (UI setting), cached about once a second: half amplitude, no body idle.
local reducedAt, reduced = -math.huge, false
local function isReduced()
	local now = os.clock()
	if now - reducedAt > 1 then
		reducedAt = now
		local ok, value = pcall(Reduced.reduced)
		reduced = ok and value == true
	end
	return reduced
end

local TAU = math.pi * 2
local READY_SPEED = 1.7 -- idle speed while the power is Ready
local READY_AMP = 1.35
local BODY = { -- per-type body idle, layered on the authoritative pose (rotation about the hang point)
	Heavy = { Kind = "sway", Deg = 1.4, Period = 3.2 },
	Fizzy = { Kind = "bob", Studs = 0.03, Period = 1.1 },
	Sharp = { Kind = "shimmer", Deg = 0.6, Period = 0.42 },
}
local BODY_QUIET = 0.4 -- body idle fades out for this long after a hit (CombatFeel's wobble owns that moment)

local function vec(a)
	return Vector3.new(a[1], a[2], a[3])
end

-- Is this source model a motion-ready import (v3/v4)?
function Motion.enabled(source)
	if not source then
		return false
	end
	if (source:GetAttribute("MotionVersion") or 0) >= 3 or (source:GetAttribute("ReleaseVersion") or 0) >= 3 then
		return true
	end
	for _, d in source:GetDescendants() do
		if string.sub(d.Name, 1, 6) == "Pivot_" then
			return true
		end
	end
	return false
end

function Motion.config(id)
	return Config.Glassies[id]
end

local function findPart(container, name)
	for _, d in container:GetDescendants() do
		if d:IsA("BasePart") and d.Name == name and not (d.Parent and d.Parent.Name == "Shards") then
			return d
		end
	end
	return nil
end

-- container: a Model (fights, showcase) or any Instance holding the parts (portrait WorldModel).
-- opts: { Frame = function() -> CFrame (hang frame; default container:GetPivot()), Scale = number,
--         Low = bool (only lod parts), Type = "Heavy"|"Fizzy"|"Sharp" }
function Motion.attach(container, id, opts)
	opts = opts or {}
	local config = Config.Glassies[id]
	if not config then
		return nil
	end
	local frameOf = opts.Frame or function()
		return container:GetPivot()
	end
	local frame = frameOf()
	local scale = opts.Scale or 1
	local entries, byName = {}, {}
	for _, spec in config.Parts do
		if opts.Low and not spec.Lod then
			continue
		end
		local part = findPart(container, spec.Name)
		if not part then
			continue
		end
		local marker = part:FindFirstChild("Pivot_" .. spec.Name)
			or container:FindFirstChild("Pivot_" .. spec.Name, true)
		local pivot = if marker and marker:IsA("Attachment")
			then frame:PointToObjectSpace(marker.WorldPosition)
			elseif marker and marker:IsA("BasePart") then frame:PointToObjectSpace(marker.Position)
			else vec(spec.Pivot) * scale
		local entry = {
			Spec = spec,
			Part = part,
			Rest = frame:ToObjectSpace(part.CFrame),
			Size = part.Size,
			Transparency = part.Transparency,
			Material = part.Material,
			Pivot = pivot,
			Axis = vec(spec.Axis).Unit,
			Parent = spec.Follows and byName[spec.Follows],
			Phase = (#entries * 0.37) % 1,
			Hits = {},
			Slosh = { Angle = 0, Velocity = 0 },
		}
		table.insert(entries, entry)
		byName[spec.Name] = entry
	end
	if #entries == 0 then
		return nil
	end
	return setmetatable({
		Container = container,
		FrameOf = frameOf,
		Entries = entries,
		Scale = scale,
		Type = opts.Type,
		HitScale = opts.HitScale or 1, -- fights keep per-part reactions under CombatFeel's whole-body wobble
		Speed = 1,
		Amp = 1,
		Ready = false,
		Clock = 0,
		Last = nil,
		LastHitAt = -math.huge,
		Parts = table.create(#entries),
		CFrames = table.create(#entries),
	}, Motion)
end

-- Damped spring envelope: 1 at t = 0 ringing down.
local function ring(t, freq, damping)
	return math.exp(-damping * TAU * freq * t) * math.cos(TAU * freq * t)
end

-- Local transform of one entry (model space, about its pivot) at clock t.
function Motion:Eval(e, t, dt, frame)
	local axis, pivot, spec = e.Axis, e.Pivot, e.Spec
	local angle, offset, scale, axisScale, fade = 0, Vector3.zero, 1, 1, 0
	local speed, amp = self.Speed, self.Amp * (if isReduced() then 0.5 else 1)
	for _, m in spec.Idle do
		local kind = m.Type
		if kind == "sway" then
			angle += math.rad(m.AmpDeg) * amp * math.sin(TAU * (t * speed / m.Period + (m.Phase or 0) + e.Phase))
		elseif kind == "spin" then
			angle += math.rad(m.DegPerS) * t * speed
		elseif kind == "bob" then
			offset += axis * m.AmpStuds * self.Scale * amp * math.sin(
				TAU * (t * speed / m.Period + (m.Phase or 0) + e.Phase)
			)
		elseif kind == "pulse" then
			scale *= 1 + m.Amp * amp * math.sin(TAU * (t * speed / m.Period + (m.Phase or 0)))
		elseif kind == "flicker" then
			scale *= 1 + m.Amp * (math.noise(t * m.RateHz, e.Phase * 10) * 2)
		elseif kind == "blink" then
			local cycle = m.Interval * (0.8 + 0.4 * ((math.floor(t / m.Interval) * 0.618 + e.Phase) % 1))
			if t % cycle < m.Duration then
				axisScale *= 0.1
			end
		elseif kind == "drip" then
			local c = (t % m.Period)
			if c < m.Grow then
				scale *= math.max(0.01, c / m.Grow)
			else
				local k = (c - m.Grow) / math.max(0.01, m.Period - m.Grow)
				offset -= axis * m.FallStuds * self.Scale * k * k
				fade = k
			end
		elseif kind == "slosh" then
			-- Liquid lags the swing: spring toward -gain x angular velocity about the axis (deg/s), clamped.
			local s = e.Slosh
			local target = 0
			if self.LastFrame and dt > 0 then
				local delta = self.LastFrame.Rotation:ToObjectSpace(frame.Rotation)
				local rotAxis, rotAngle = delta:ToAxisAngle()
				local omega = math.deg(rotAngle / dt) * rotAxis:Dot(axis)
				target = math.clamp(-m.Gain * omega, -m.MaxDeg, m.MaxDeg)
			end
			local w = TAU * m.FreqHz
			s.Velocity += (w * w * (target - s.Angle) - 2 * m.Damping * w * s.Velocity) * dt
			s.Angle += s.Velocity * dt
			angle += math.rad(math.clamp(s.Angle, -m.MaxDeg * 1.5, m.MaxDeg * 1.5))
		end
	end
	-- Hit / cast reactions.
	local hit = spec.Hit
	local flash = false
	for i = #e.Hits, 1, -1 do
		local h = e.Hits[i]
		local age = t - h.At
		if age < 0 then
			continue
		end
		if hit.Type == "flash" or hit.Type == "spin_boost" then
			if age > hit.Duration then
				table.remove(e.Hits, i)
				continue
			end
			if hit.Type == "flash" then
				flash = true
			else
				-- Extra spin decaying over the duration: integral of (1 - age/d).
				local d = hit.Duration
				angle += math.rad(hit.DegPerS) * h.Strength * (age - age * age / (2 * d))
			end
		else
			if age > 3 / math.max(0.1, hit.Damping * hit.FreqHz) then
				table.remove(e.Hits, i)
				continue
			end
			local env = ring(age, hit.FreqHz, hit.Damping) * h.Strength * (if isReduced() then 0.5 else 1)
			if hit.Type == "kick" then
				angle += math.rad(hit.Deg) * env * h.Sign
			elseif hit.Type == "flare" then
				angle += math.rad(hit.Deg) * env
			elseif hit.Type == "hop" then
				offset += axis * hit.Studs * self.Scale * math.abs(env)
			elseif hit.Type == "squash" then
				axisScale *= 1 + (hit.Factor - 1) * env
			end
		end
	end
	local rot = if angle ~= 0 then CFrame.fromAxisAngle(axis, angle) else CFrame.identity
	return CFrame.new(pivot + offset) * rot * CFrame.new(-pivot), scale, axisScale, fade, flash
end

-- Advance to clock `time` (fight render time, or os.clock for previews) and write every part once.
function Motion:Step(time, skip)
	if not self.Container.Parent then
		return false
	end
	self.Resting = false
	local dt = if self.Last then math.clamp(time - self.Last, 0, 0.1) else 0
	self.Last = time
	local frame = self.FrameOf()
	local n = 0
	for _, e in self.Entries do
		local part = e.Part
		if not part.Parent or (skip and skip[e.Spec.Name]) or (self.Low and not e.Spec.Lod) then
			continue
		end
		local local_, scale, axisScale, fade, flash = self:Eval(e, time, dt, frame)
		e.Local = if e.Parent and e.Parent.Local then e.Parent.Local * local_ else local_
		local cf = frame * e.Local * e.Rest
		if scale ~= 1 or axisScale ~= 1 then
			-- Scale about the pivot: move the part's centre toward the pivot and resize it.
			local pivotWorld = (frame * e.Local):PointToWorldSpace(e.Pivot)
			cf = cf - cf.Position + pivotWorld + (cf.Position - pivotWorld) * scale
			local s = e.Size * scale
			if axisScale ~= 1 then
				-- Shrink along the part-local direction that best matches the motion axis.
				local localAxis = e.Rest.Rotation:VectorToObjectSpace(e.Axis)
				local ax = Vector3.new(math.abs(localAxis.X), math.abs(localAxis.Y), math.abs(localAxis.Z))
				local pick = if ax.X >= ax.Y and ax.X >= ax.Z
					then Vector3.new(axisScale, 1, 1)
					elseif ax.Y >= ax.Z then Vector3.new(1, axisScale, 1)
					else Vector3.new(1, 1, axisScale)
				s = s * pick
			end
			part.Size = s
		elseif part.Size ~= e.Size then
			part.Size = e.Size
		end
		if fade > 0 or e.Faded then
			part.Transparency = e.Transparency + (1 - e.Transparency) * fade
			e.Faded = fade > 0
		end
		if flash ~= (e.Flashing == true) then
			part.Material = if flash then Enum.Material.Neon else e.Material
			e.Flashing = flash
		end
		n += 1
		self.Parts[n] = part
		self.CFrames[n] = cf
	end
	for i = n + 1, #self.Parts do
		self.Parts[i], self.CFrames[i] = nil, nil
	end
	if n > 0 then
		workspace:BulkMoveTo(self.Parts, self.CFrames, Enum.BulkMoveMode.FireCFrameChanged)
	end
	self.LastFrame = frame
	return true
end

-- A hit: strength ~0.4 (glance) .. 1.3 (crit); sign = which way the blow pushes (kick direction).
function Motion:Hit(strength, sign, at)
	self.LastHitAt = at or self.Last or 0
	for _, e in self.Entries do
		if e.Spec.Hit then
			table.insert(e.Hits, { At = self.LastHitAt, Strength = strength * self.HitScale, Sign = sign or 1 })
			if #e.Hits > 3 then
				table.remove(e.Hits, 1)
			end
		end
	end
end

-- Ready: livelier idle (faster, bigger) until cleared.
function Motion:SetReady(on)
	self.Ready = on == true
	self.Speed = if on then READY_SPEED else 1
	self.Amp = if on then READY_AMP else 1
end

-- Cast flourish: every reacting part fires its hit reaction (manual casts a little stronger).
function Motion:Cast(manual, at)
	self:SetReady(false)
	self:Hit(if manual then 1 else 0.6, 1, at)
end

-- Put every animated part back to its rest pose once (fights the viewer stops watching); Step resumes motion.
function Motion:Rest()
	if self.Resting or not self.Container.Parent then
		return
	end
	self.Resting = true
	local frame = self.FrameOf()
	for _, e in self.Entries do
		if e.Part.Parent then
			e.Part.CFrame = frame * e.Rest
			e.Part.Size, e.Part.Transparency, e.Part.Material = e.Size, e.Transparency, e.Material
			e.Flashing, e.Faded = false, false
		end
	end
end

-- Restore every animated part to its rest pose under the current frame.
function Motion:Destroy()
	if self.Container.Parent then
		local frame = self.FrameOf()
		for _, e in self.Entries do
			if e.Part.Parent then
				e.Part.CFrame = frame * e.Rest
				e.Part.Size, e.Part.Transparency, e.Part.Material = e.Size, e.Transparency, e.Material
			end
		end
	end
	self.Entries = {}
end

-- Body idle rotation (hang-point space) for Hero.motion; identity when this glassy has no motion or was just hit.
function Motion:Body(time)
	local b = BODY[self.Type or ""]
	if not b or self.Resting or isReduced() then
		return CFrame.identity
	end
	local quiet = math.clamp((time - self.LastHitAt) / BODY_QUIET, 0, 1)
	if quiet <= 0 then
		return CFrame.identity
	end
	local phase = TAU * time / b.Period
	if b.Kind == "sway" then
		return CFrame.Angles(0, 0, math.rad(b.Deg) * math.sin(phase) * quiet)
	elseif b.Kind == "bob" then
		return CFrame.new(0, b.Studs * self.Scale * math.sin(phase) * quiet, 0)
	end
	return CFrame.Angles(
		math.rad(b.Deg) * math.sin(phase) * quiet,
		0,
		math.rad(b.Deg) * 0.6 * math.sin(phase * 1.7) * quiet
	)
end

-- Self-driven previews (portraits, showcase): one shared 30 Hz loop; a handle drops out when its container leaves
-- the DataModel or its gui is hidden. visible: optional function() -> bool.
local playing = {}
local loop
function Motion.autoplay(container, id, opts)
	local handle = Motion.attach(container, id, opts)
	if not handle then
		return nil
	end
	handle.Visible = opts and opts.Visible
	table.insert(playing, handle)
	if not loop then
		local acc = 0
		loop = RunService.RenderStepped:Connect(function(dt)
			acc += dt
			if acc < 1 / 30 then
				return
			end
			acc = 0
			local now = os.clock()
			for i = #playing, 1, -1 do
				local h = playing[i]
				if not h.Container.Parent or not h.Container:IsDescendantOf(game) then
					table.remove(playing, i)
				elseif not h.Visible or h.Visible() then
					h:Step(now)
				end
			end
			if #playing == 0 then
				loop:Disconnect()
				loop = nil
			end
		end)
	end
	return handle
end

return Motion
