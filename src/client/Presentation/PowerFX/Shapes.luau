-- Power VFX v2 primitives: flash, rings, spokes, flung chips, ground ring and shadow, beams. Every primitive is one
-- pooled effect stepped from the fight clock. `opts.Delay` starts it later on the same clock.
return function(FX)
	local NEON = Enum.Material.Neon
	local WHITE = Color3.new(1, 1, 1)
	local rng = Random.new()

	local function start(self, opts)
		return self:Time() + ((opts and opts.Delay) or 0)
	end

	-- Moments sit a little toward the camera so the glass bodies never swallow them.
	local FRONT = 1
	local function front(pos, amount)
		return pos - workspace.CurrentCamera.CFrame.LookVector * (amount or FRONT)
	end
	FX.front = front

	-- A popping light ball with a white core: the "it happened here" beat.
	function FX:Flash(side, at, color, size, seconds, opts)
		opts = opts or {}
		if self.Reduced then
			size *= 0.7
		end
		local outer = self:Part("Ball", color)
		local core = self:Part("Ball", WHITE)
		local where = self:Followed(at)
		return self:Spawn({
			Side = side,
			Start = start(self, opts),
			Seconds = seconds,
			Parts = { outer, core },
			Step = function(_, age, k)
				local p = front(if type(where) == "function" then where(age) else where, opts.Front)
				local grow = FX.pop(k / 0.45)
				outer.Size = Vector3.one * size * (0.35 + 0.65 * grow)
				core.Size = outer.Size * 0.55
				outer.CFrame, core.CFrame = CFrame.new(p), CFrame.new(p)
				outer.Transparency = (opts.Alpha or 0.25) + (1 - (opts.Alpha or 0.25)) * FX.easeIn(k)
				core.Transparency = 0.05 + 0.95 * FX.smooth(k / 0.7)
			end,
		})
	end

	-- An expanding ring. opts: Kind ("Ring" | "ShockCrown" | "HalfRing"), Rotation (CFrame rotation, default camera
	-- facing), Ground (lie flat), Spin (rad/s), Alpha (start transparency), Ease ("out" | "in"), Follow (function).
	function FX:Ring(side, at, color, from, to, seconds, opts)
		opts = opts or {}
		at = self:Followed(at)
		local p = self:Part(opts.Kind or "Ring", color)
		local spin = opts.Spin or 0
		return self:Spawn({
			Side = side,
			Start = start(self, opts),
			Seconds = seconds,
			Parts = { p },
			Step = function(_, age, k)
				local pos = if type(at) == "function" then at(age) else at
				if not opts.Ground and not opts.Rotation then
					pos = front(pos, opts.Front)
				end
				local grow = if opts.Ease == "in" then FX.easeIn(k) else FX.easeOut(k)
				self:Fit(p, from + (to - from) * grow)
				if opts.Thick then
					p.Size = Vector3.new(p.Size.X, p.Size.Y, opts.Thick)
				end
				local rot = if opts.Ground
					then CFrame.Angles(math.pi / 2, 0, 0)
					elseif opts.Rotation then opts.Rotation
					else workspace.CurrentCamera.CFrame.Rotation
				p.CFrame = CFrame.new(pos) * rot * CFrame.Angles(0, 0, age * spin)
				local a = opts.Alpha or 0.05
				p.Transparency = a + (1 - a) * FX.easeIn(k)
			end,
		})
	end

	-- Crystal spokes shooting out in the camera plane (star-burst).
	function FX:Spokes(side, at, color, count, length, seconds, opts)
		opts = opts or {}
		at = self:Followed(at)
		count = self:Count(side, count)
		local parts, base = {}, rng:NextNumber(0, math.pi * 2)
		for i = 1, count do
			parts[i] =
				self:Part(opts.Kind or "CrystalShard", if opts.Alternate and i % 2 == 0 then opts.Alternate else color)
		end
		local width = opts.Width or 0.32
		return self:Spawn({
			Side = side,
			Start = start(self, opts),
			Seconds = seconds,
			Parts = parts,
			Step = function(_, age, k)
				local pos = front(if type(at) == "function" then at(age) else at, opts.Front)
				local basis = FX.face(pos)
				local travel = FX.easeOut(k)
				for i, p in parts do
					local angle = base + (i - 1) / count * math.pi * 2
					local len = length * (if i % 2 == 0 then 0.7 else 1)
					local stretch = math.max(0.05, (1 - k) * len * 0.55)
					p.Size = Vector3.new(width * (1 - k * 0.6), stretch, width * 0.6)
					p.CFrame = basis * CFrame.Angles(0, 0, angle) * CFrame.new(0, (opts.Inner or 0.4) + travel * len, 0)
					p.Transparency = 0.02 + 0.98 * FX.easeIn(k)
				end
			end,
		})
	end

	-- Mesh chips flung outward with gravity and spin. opts: Kind, Size, Gravity, Up (bias), Direction (cone axis), Cone.
	function FX:Chips(side, at, color, count, speed, seconds, opts)
		opts = opts or {}
		count = self:Count(side, count)
		local chips = {}
		local camera = workspace.CurrentCamera.CFrame
		for i = 1, count do
			local p =
				self:Part(opts.Kind or "CrystalChip", if opts.Alternate and i % 2 == 0 then opts.Alternate else color)
			self:Fit(p, (opts.Size or 0.45) * rng:NextNumber(0.75, 1.2))
			local dir
			if opts.Direction then
				local cone = opts.Cone or 0.6
				dir = (CFrame.lookAt(Vector3.zero, opts.Direction) * CFrame.Angles(
					rng:NextNumber(-cone, cone),
					rng:NextNumber(-cone, cone),
					0
				)).LookVector
			else
				local a = rng:NextNumber(0, math.pi * 2)
				dir = (
					camera.RightVector * math.cos(a)
					+ camera.UpVector * math.sin(a)
					+ camera.LookVector * rng:NextNumber(-0.3, 0.3)
				).Unit
			end
			chips[i] = {
				Part = p,
				Velocity = dir * speed * rng:NextNumber(0.7, 1.15) + Vector3.yAxis * (opts.Up or 2),
				Spin = Vector3.new(rng:NextNumber(-9, 9), rng:NextNumber(-9, 9), rng:NextNumber(-9, 9)),
				Size = p.Size,
			}
		end
		local origin = front(at, opts.Front or 0.6)
		local gravity = opts.Gravity or 18
		return self:Spawn({
			Side = side,
			Start = start(self, opts),
			Seconds = seconds,
			Parts = (function()
				local list = {}
				for _, c in chips do
					table.insert(list, c.Part)
				end
				return list
			end)(),
			Step = function(_, age, k)
				for _, c in chips do
					local pos = origin + c.Velocity * age - Vector3.yAxis * gravity * age * age * 0.5
					c.Part.CFrame = CFrame.new(pos) * CFrame.Angles(c.Spin.X * age, c.Spin.Y * age, c.Spin.Z * age)
					c.Part.Size = c.Size * (1 - FX.easeIn(k) * 0.7)
					c.Part.Transparency = (opts.Alpha or 0.05) + 0.95 * FX.easeIn(k)
				end
			end,
		})
	end

	-- A flat ring on the arena floor under `at` (depth cue from the straight-on camera).
	function FX:GroundRing(side, at, color, radius, seconds, opts)
		opts = opts or {}
		local floor = self:Ground(if type(at) == "function" then at(0) else at)
		return self:Ring(
			side,
			function(age)
				local pos = if type(at) == "function" then at(age) else at
				return Vector3.new(pos.X, floor.Y, pos.Z)
			end,
			color,
			opts.From or radius * 0.3,
			radius * 2,
			seconds,
			{
				Kind = opts.Kind or "ShockCrown",
				Ground = true,
				Alpha = opts.Alpha or 0.15,
				Spin = opts.Spin or 0.8,
				Delay = opts.Delay,
			}
		)
	end

	-- A soft dark disc on the floor that tracks a point (zone hazards, falling stars).
	function FX:Shadow(side, at, radius, seconds, opts)
		opts = opts or {}
		local p = self:Part("Disc", Color3.fromRGB(20, 24, 40), Enum.Material.SmoothPlastic)
		local floor = self:Ground(if type(at) == "function" then at(0) else at)
		return self:Spawn({
			Side = side,
			Start = start(self, opts),
			Seconds = seconds,
			Key = opts.Key,
			Parts = { p },
			Step = function(_, age, k)
				local pos = if type(at) == "function" then at(age) else at
				local grow = FX.smooth(age / 0.25) * (1 - FX.smooth((k - 0.85) / 0.15))
				p.Size = Vector3.new(0.05, radius * 2 * grow, radius * 2 * grow)
				p.CFrame = CFrame.new(pos.X, floor.Y + 0.02, pos.Z) * CFrame.Angles(0, 0, math.pi / 2)
				p.Transparency = 1 - (opts.Strength or 0.4) * grow
			end,
		})
	end

	-- A beam between two moving points (functions or Vector3). opts: Texture, Width1, Segments, Curve, Speed.
	function FX:Beam(side, a, b, color, width, seconds, opts)
		opts = opts or {}
		a, b = self:Followed(a), self:Followed(b)
		local p0, p1 = self:Part("Anchor", WHITE), self:Part("Anchor", WHITE)
		local beam = p0:FindFirstChild("FXBeam")
		if not beam then
			local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
			a0.Name, a1.Name = "FXA0", "FXA1"
			a0.Parent = p0
			beam = Instance.new("Beam")
			beam.Name, beam.Attachment0 = "FXBeam", a0
			beam.FaceCamera, beam.LightEmission, beam.LightInfluence = true, 1, 0
			beam.Parent = p0
		end
		local a1 = p1:FindFirstChild("FXA1") or Instance.new("Attachment")
		a1.Name, a1.Parent = "FXA1", p1
		beam.Attachment1 = a1
		beam.Texture = opts.Texture or ""
		beam.TextureSpeed, beam.TextureLength = opts.Speed or 0, opts.TextureLength or 1
		beam.TextureMode = Enum.TextureMode.Stretch
		beam.Segments = opts.Segments or 10
		beam.Color = if typeof(color) == "ColorSequence" then color else ColorSequence.new(color)
		-- Additive light washes colour out against the bright sky; only white cores glow fully.
		beam.LightEmission = opts.Emission or (if typeof(color) == "Color3" and color == WHITE then 1 else 0.25)
		beam.Enabled = true
		local w1 = opts.Width1 or width
		return self:Spawn({
			Side = side,
			Start = start(self, opts),
			Seconds = seconds,
			Key = opts.Key,
			Parts = { p0, p1 },
			Stop = function()
				beam.Enabled = false
			end,
			Step = function(e, age, k)
				p0.CFrame = CFrame.new(if type(a) == "function" then a(age) else a)
				p1.CFrame = CFrame.new(if type(b) == "function" then b(age) else b)
				local shape = if opts.Shape then opts.Shape(k, age) else 1 - FX.smooth((k - 0.6) / 0.4)
				beam.Width0, beam.Width1 = width * shape, w1 * shape
				beam.CurveSize0 = if opts.Curve then opts.Curve(age) else 0
				beam.CurveSize1 = if opts.Curve then -opts.Curve(age) * 0.6 else 0
				local alpha = opts.Alpha or 0
				beam.Transparency = NumberSequence.new(alpha + (1 - alpha) * FX.easeIn((k - 0.7) / 0.3))
				e.Beam = beam
			end,
		})
	end

	-- A sparkle puff from the pooled sockets (cheap glints for every moment).
	function FX:Glints(side, at, color, count, opts)
		opts = opts or {}
		self:Emit(side, opts.Kind or "Sparkle", at, count, color, {
			Speed = opts.Speed or NumberRange.new(3, 7),
			Size = opts.Size or 1,
			Accel = opts.Accel,
			Spread = opts.Spread,
			Lifetime = opts.Lifetime,
		})
	end

	-- The standard landed-hit accent for a kit: flash + shock ring + spokes + glints (+ light for Rare and up).
	function FX:Impact(side, at, color, accent, scale, opts)
		opts = opts or {}
		local I = FX.C.Impact
		scale = scale or 1
		self:Flash(side, at, color, I.Flash * scale, I.FlashSeconds * (opts.Slow or 1))
		self:Ring(
			side,
			at,
			color,
			0.6 * scale,
			I.Ring * scale,
			I.RingSeconds,
			{ Kind = opts.RingKind or "ShockCrown", Spin = 2 }
		)
		if opts.Spokes ~= 0 then
			self:Spokes(side, at, accent or color, opts.Spokes or I.Spokes, I.SpokeLength * scale, 0.26, {
				Kind = opts.SpokeKind,
				Alternate = color,
			})
		end
		self:Glints(side, at, accent or WHITE, opts.Glints or 10)
		if self:Rank(side) >= 2 then
			self:Light(side, at, color, 0.3)
		end
	end
end
