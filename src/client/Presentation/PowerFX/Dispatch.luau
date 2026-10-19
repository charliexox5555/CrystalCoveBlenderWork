-- Routes server fight events (through Hero.state, which sees every event) to the shared states and per-kit moments,
-- and runs the per-frame step from SignaturePresentation.status.
return function(FX)
	local States = require(script.Parent.States)
	local Kits = require(script.Parent.Kits)
	local Launch = require(script.Parent.LaunchKit)
	FX.Kits, FX.States, FX.Launch = Kits, States, Launch

	local ARMS = { contact = true, slow_contact = true, mark_contact = true, armed_contact = true }
	local TYPES = {
		SignatureReady = true,
		ReadyCancel = true,
		SignatureArmed = true,
		CastStart = true,
		CastRelease = true,
		CastContact = true,
		SignatureContact = true,
		SignatureBlock = true,
		SignatureStatus = true,
	}

	local function vector(a)
		return Vector3.new(a[1], a[2], a[3])
	end

	function FX:Kit(side)
		local f = self:Fighter(side)
		return f and Kits[f.Id] or Kits.default
	end

	-- Calls kit[name] or the shape default.
	function FX:Call(side, name, ...)
		local kit = self:Kit(side)
		if kit.Skip then
			return
		end
		local fn = kit[name] or Kits.default[name]
		if fn then
			local ok, err = pcall(fn, self, side, ...)
			if not ok then
				warn("PowerFX " .. tostring(self:Fighter(side).Id) .. "." .. name .. ": " .. tostring(err))
			end
		end
	end

	function FX:Event(e)
		if not TYPES[e.Type] or not e.Side then
			return
		end
		local f = self:Fighter(e.Side)
		if not f or f.Broken or f.Finishing then
			return
		end
		local key = e.Type
			.. ":"
			.. tostring(e.CastId or e.ReadyId or e.Time)
			.. ":"
			.. e.Side
			.. ":"
			.. tostring(e.Pulse or e.Kind or "")
		if self.Seen[key] then
			return
		end
		self.Seen[key] = true
		local now = self:Time()
		local side = e.Side
		local stale = now > (e.Time or now) + self.C.Budget.StaleSeconds
		if e.Type ~= "CastRelease" and not stale and Launch.event(self, e) then
			if e.Type == "CastStart" then
				States.clearReady(self, side)
				States.flourish(self, e)
			end
			return
		end
		if e.Type == "SignatureReady" then
			States.ready(self, e)
			return
		elseif e.Type == "ReadyCancel" then
			if not self.Ready[side] or self.Ready[side].Id == e.ReadyId then
				States.clearReady(self, side)
			end
			return
		end
		if e.Type == "CastStart" or e.Type == "SignatureArmed" then
			States.clearReady(self, side)
			if not stale then
				States.flourish(self, e)
			end
		end
		if e.Type == "SignatureArmed" then
			local kit = self:Kit(side)
			States.armed(
				self,
				e,
				if kit.Armed
					then function(...)
						kit.Armed(...)
					end
					else nil
			)
			return
		end
		if e.Type == "CastStart" then
			if not stale or now < e.Time + (e.Windup or 0) then
				self:Call(side, "Windup", e)
			end
			return
		end
		if e.Type == "CastRelease" then
			local ctx = {
				Event = e,
				Shots = {},
				Origin = if e.Origin then self.Scene.Frame:PointToWorldSpace(vector(e.Origin)) else f.Body.Position,
				Direction = if e.Direction
					then self.Scene.Frame:VectorToWorldSpace(vector(e.Direction)).Unit
					else self:Toward(side),
			}
			self.Casts = self.Casts or {}
			if e.CastId then
				self.Casts[e.CastId] = ctx
			end
			local readable = math.max(e.Duration or 0, 0.5)
			if now > e.Time + readable then
				return
			end
			if e.Shape == "ray" and ctx.Origin then
				-- Rays resolve within a frame or two; a landed contact moves ctx.End.
				ctx.End = nil
			end
			if not Launch.event(self, e, ctx) then
				self:Call(side, "Release", e, ctx)
			end
			return
		end
		if e.Type == "CastContact" then
			local ctx = self.Casts and self.Casts[e.CastId]
			if ctx then
				local index = e.Pulse or 1
				local path = ctx.Event.Path
				if not (path == "return" and index == 1) then
					local shot = ctx.Shots[if path == "return" then 1 else index]
					if shot then
						shot.Done = true
					end
				end
			end
			if ctx and ctx.Zone then
				if e.Missed then
					ctx.Zone:End()
				else
					ctx.Zone:Pop(if e.Point then self.Scene.Frame:PointToWorldSpace(vector(e.Point)) else nil)
				end
			end
			if stale then
				return
			end
			if e.Missed then
				self:Call(side, "Miss", e, ctx or {})
			else
				local at = if e.Point
					then self.Scene.Frame:PointToWorldSpace(vector(e.Point))
					else (self:Body(e.Target or (3 - side)))
				if ctx then
					ctx.End = at
				end
				self:Call(side, "Hit", e, at, ctx)
			end
			return
		end
		if e.Type == "SignatureContact" then
			if e.Shape ~= "splat" then
				States.disarm(self, side, false)
			end
			if not stale then
				local at = if e.Point then self.Scene.Frame:PointToWorldSpace(vector(e.Point)) else (self:Body(side))
				self:Call(side, "Payoff", e, at)
			end
			return
		end
		if e.Type == "SignatureBlock" then
			if not stale then
				self:Call(side, "Block", e)
			end
			return
		end
		if e.Type == "SignatureStatus" then
			if e.Kind == "ArmedFade" then
				States.disarm(self, side, not stale)
				return
			end
			if e.Kind == "Slow" or e.Kind == "Mark" then
				States.disarm(self, side, false)
			end
			if e.Kind == "Boost" then
				self.BoostSeen = self.BoostSeen or {}
				self.BoostSeen[side] = e.Time
			end
			if not stale or e.Kind == "Echo" then
				self:Call(side, "Status", e)
			end
		end
		local _ = ARMS
	end

	-- Guard releases skip HeroPowers' cast path, so they arrive here as plain CastRelease events (Kit.Release).

	function FX:Update(r, time)
		local started = os.clock()
		self:UpdateInner(r, time)
		-- Cost meter, readable from any context (Studio profiling): attributes on the PowerFX folder.
		local spent = os.clock() - started
		self.Meter = self.Meter or { Sum = 0, Max = 0, Frames = 0, At = started }
		local m = self.Meter
		m.Sum, m.Max, m.Frames = m.Sum + spent, math.max(m.Max, spent), m.Frames + 1
		if started - m.At >= 1 then
			self.Root:SetAttribute("StepMs", m.Sum / m.Frames * 1000)
			self.Root:SetAttribute("StepMaxMs", m.Max * 1000)
			self.Root:SetAttribute("Active", #self.Active)
			m.Sum, m.Max, m.Frames, m.At = 0, 0, 0, started
		end
	end

	function FX:UpdateInner(r, time)
		local anyBroken = false
		for side, f in self.Scene.Fighters do
			if f.Broken or f.Finishing then
				anyBroken = true
				self:StopSide(side)
			end
		end
		if anyBroken then
			-- Round over: nothing of either side's powers hangs around through the finisher.
			self:StopAll()
		end
		-- Boost auras end when the server's boost status does (a consumed boost ends early).
		for side in self.Scene.Fighters do
			local ef = r and r.Effect and r.Effect[side]
			local boosted = ef and (ef[3] or 0) > 0
			local since = self.BoostSeen and self.BoostSeen[side]
			if not boosted and since and time > since + 0.3 then
				self:StopKey("aura:" .. side)
				self.BoostSeen[side] = nil
			end
		end
		self:Step(time)
	end
end
