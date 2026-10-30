-- Deterministic prototype runner; contains no services, profiles, rewards or live analytics.
local C = if script
	then require(game.ReplicatedStorage.Shared.Config.LoopLab)
	else require("../../../shared/Config/LoopLab")
local B = if script
	then require(game.ReplicatedStorage.Shared.Config.Balance)
	else require("../../../shared/Config/Balance")
local Rules = if script
	then require(game.ReplicatedStorage.Shared.FightRules)
	else require("../../../shared/FightRules")
local Rng = if script then require(game.ReplicatedStorage.Shared.Rng) else require("../../../shared/Rng")
local Pendulum = if script
	then require(game.ServerScriptService.Server.Simulation.Pendulum)
	else require("../../Simulation/Pendulum")
local Session = {}
Session.__index = Session
local Turnaround = if script
	then require(game.ServerScriptService.Server.Simulation.Turnaround)
	else require("../../Simulation/Turnaround")

local function finite(n)
	return type(n) == "number" and n == n and math.abs(n) < math.huge
end

function Session.new(mode, id, seed, now)
	assert(mode == "A" or mode == "B", "unknown prototype")
	assert(table.find(C.Roster, id), "not a lab glassy")
	local rival = C.Roster[seed % #C.Roster + 1]
	local setup = {
		A = { Id = id, Aim = B.Motion.AimDefault, CastPolicy = "auto" },
		B = { Id = rival, Aim = B.Motion.AimDefault, CastPolicy = "auto" },
		SweetSpot = -10, -- no hidden gold-band damage bonus in either prototype; aiming moves the launch
		Rng = Rng.new(seed),
	}
	local sim = Pendulum.new(setup, seed)
	for _, fighter in sim.Fight.Fighters do
		fighter.MaxHp *= C.HpScale
		fighter.Hp = fighter.MaxHp
	end
	return setmetatable({
		Mode = mode,
		Id = id,
		Rival = rival,
		Seed = seed,
		Sim = sim,
		Setup = setup,
		Phase = "Aim",
		Deadline = now + C.AimSeconds,
		Started = now,
		Shots = 0,
		Contacts = 0,
		Events = {},
		Trace = {},
		Reported = false,
	}, Session)
end

function Session:launch(aim, yaw, now)
	if self.Phase ~= "Aim" or not finite(aim) or not finite(yaw) then
		return false
	end
	aim, yaw = Rules.clampAim(aim), Rules.clampYaw(yaw)
	local foeAim = B.Motion.AimDefault
	-- Reset motion, not the duel's HP, signature cooldowns or gameplay RNG.
	for side, body in self.Sim.Bodies do
		local a, y = if side == 1 then aim else foeAim, if side == 1 then yaw else 0
		body.P, body.V = Pendulum.pull(a, y, side), body.V * 0
		body.Spin, body.Twist, body.Tilt, body.Tumble = 0, 0, body.Tilt * 0, body.Tumble * 0
		body.Wander, body.NextWander = 0, self.Sim.Fight.Time
		body.Turnaround = Turnaround.new(body.P.Y)
		self.Sim.Fight.Fighters[side].Aim, self.Sim.Fight.Fighters[side].AimYaw = a, y
	end
	self.Shots += 1
	self.Phase, self.ShotStarted = "Flight", self.Sim.Fight.Time
	self.Deadline = now + C.ShotSeconds
	table.insert(self.Trace, { Shot = self.Shots, Aim = aim, Yaw = yaw, At = now - self.Started })
	return true
end

function Session:finish(now, reason)
	self.Phase = "Result"
	self.ResultAt = now
	self.Duration = now - self.Started
	self.Reason = reason or self.Sim.Fight.Reason or "Shatter"
	self.Winner = self.Sim.Fight.Winner
	if not self.Winner then
		local f = self.Sim.Fight.Fighters
		self.Winner = if f[1].Hp / f[1].MaxHp >= f[2].Hp / f[2].MaxHp then 1 else 2
	end
end

function Session:next(now, seed)
	assert(self.Phase == "Result", "finish the current duel first")
	local following = Session.new("B", self.NextId or self.Id, seed, now)
	local last = self.Trace[#self.Trace]
	following:launch(last and last.Aim or B.Motion.AimDefault, last and last.Yaw or 0, now)
	return following
end

function Session:step(dt, now)
	if self.Phase == "Result" then
		return
	end
	if self.Phase == "Aim" then
		if now >= self.Deadline then
			self:launch(B.Motion.AimDefault, 0, now)
		end
		return
	end
	Pendulum.step(self.Sim, dt)
	local hit = false
	for _, e in Pendulum.events(self.Sim) do
		table.insert(self.Events, e)
		if e.Type == "Hit" then
			self.Contacts += 1
			hit = true
		end
	end
	if self.Sim.Fight.Over then
		self:finish(now)
		return
	end
	if self.Mode == "B" then
		return
	end
	if self.Phase == "Flight" and (hit or self.Sim.Fight.Time - self.ShotStarted >= C.ShotSeconds) then
		self.Phase, self.Deadline = "Recover", now + C.RecoverySeconds
		self.LastShot = if hit then "CLASH" else "MISSED - TRY A DIFFERENT ANGLE"
		-- Show the rebound/power payoff without taking another physical hit during recovery.
		self.Sim.LastHit = self.Sim.Fight.Time + C.RecoverySeconds
	elseif self.Phase == "Recover" and now >= self.Deadline then
		if self.Shots >= C.MaxShots then
			self:finish(now, "ShotLimit")
			return
		end
		self.Phase, self.Deadline = "Aim", now + C.AimSeconds
	end
end

function Session:packet()
	local snapshot = Pendulum.snapshot(self.Sim)
	local events = self.Events
	self.Events = {}
	return {
		Mode = self.Mode,
		Id = self.Id,
		Rival = self.Rival,
		Seed = self.Seed,
		Phase = self.Phase,
		Deadline = self.Deadline,
		Shots = self.Shots,
		Contacts = self.Contacts,
		LastShot = self.LastShot,
		Winner = self.Winner,
		Reason = self.Reason,
		Duration = self.Duration,
		Snapshot = snapshot,
		Events = events,
		NextId = self.NextId,
	}
end

return Session
