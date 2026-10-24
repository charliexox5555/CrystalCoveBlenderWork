-- Timer/phase orchestration. Decisions and outcomes stay in MatchLogic/FightRules.
local Shared = if script then game.ReplicatedStorage.Shared else nil
local Balance = if Shared then require(Shared.Config.Balance) else require("../../shared/Config/Balance")
local Logic = if Shared then require(Shared.MatchLogic) else require("../../shared/MatchLogic")
local Runner = {}
Runner.__index = Runner

function Runner:PhaseTo(phase, now, seconds)
	self.Phase, self.Deadline = phase, now + (seconds or 0)
	table.insert(self.Events, { Phase = phase, Deadline = self.Deadline })
end

function Runner:StartRound(now)
	Logic.startRound(self.Match)
	self.Locked = {}
	for side, state in self.Match.Sides do
		if state.IsBot then
			Logic.autoPick(self.Match, side)
		end
	end
	local default = if self.Match.Round > 1 then Balance.Match.RollSecondsLater else Balance.Match.RollSeconds
	self:PhaseTo("Rolling", now, self.RollSeconds or default)
end

-- options: { RollSeconds = n? } (the onboarding first match picks more slowly).
function Runner.new(sides, rng, now, options)
	local self = setmetatable({
		Match = Logic.new(sides, rng),
		Events = {},
		Locked = {},
		RollSeconds = options and options.RollSeconds,
	}, Runner)
	self:StartRound(now)
	return self
end

function Runner:Pick(side, id)
	if self.Phase ~= "Rolling" then
		return false, "phase"
	end
	return Logic.pick(self.Match, side, id)
end

function Runner:Reroll(side)
	if self.Phase ~= "Rolling" then
		return false, "phase"
	end
	return Logic.reroll(self.Match, side)
end

function Runner:PickAny(side, id)
	if self.Phase ~= "Rolling" then
		return false, "phase"
	end
	return Logic.pickAny(self.Match, side, id)
end

function Runner:Aim(side, aim, yaw)
	if self.Phase ~= "Aiming" or self.Locked[side] then
		return false, "phase"
	end
	Logic.setAim(self.Match, side, aim, yaw)
	self.Locked[side] = true
	return true
end

function Runner:Step(now)
	local match = self.Match
	if self.Phase == "Rolling" then
		if now < self.Deadline and not (match.Sides[1].Pick and match.Sides[2].Pick) then
			return
		end
		for side = 1, 2 do
			Logic.autoPick(match, side)
			if match.Sides[side].IsBot then
				Logic.autoAim(match, side)
				self.Locked[side] = true
			end
		end
		self:PhaseTo("Aiming", now, Balance.Match.AimSeconds)
	elseif self.Phase == "Aiming" then
		if now < self.Deadline and not (self.Locked[1] and self.Locked[2]) then
			return
		end
		for side = 1, 2 do
			Logic.autoAim(match, side)
		end
		self:PhaseTo("Countdown", now, Balance.Match.CountdownSeconds)
	elseif self.Phase == "Countdown" and now >= self.Deadline then
		self:PhaseTo("Fighting", now)
	elseif self.Phase == "RoundEnd" and now >= self.Deadline then
		if match.Over then
			self:PhaseTo("MatchEnd", now)
		else
			self:StartRound(now)
		end
	end
end

function Runner:FightEnded(winner, now)
	if self.Phase ~= "Fighting" then
		return false
	end
	Logic.endRound(self.Match, winner)
	self:PhaseTo("RoundEnd", now, Balance.Match.RoundEndSeconds)
	return true
end

function Runner:Forfeit(side, now)
	if self.Match.Over then
		return
	end
	for i = 1, 2 do
		Logic.autoPick(self.Match, i)
	end
	while not self.Match.Over do
		Logic.endRound(self.Match, 3 - side)
	end
	self:PhaseTo("MatchEnd", now)
end

function Runner:Drain()
	local events = self.Events
	self.Events = {}
	return events
end

return Runner
