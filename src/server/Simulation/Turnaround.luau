local Balance = if script
	then require(game.ReplicatedStorage.Shared.Config.Balance)
	else require("../../shared/Config/Balance")
local K, M = Balance.CombatRelease, Balance.Motion
local Turnaround = {}

function Turnaround.new(y)
	return { Low = y, Armed = false, Last = -math.huge }
end

function Turnaround.step(detector, time, previousVy, vy, y, lastCollision)
	detector.Low = math.min(detector.Low, y)
	if vy >= K.TurnRiseSpeed then
		detector.Armed = true
	end
	if previousVy > 0 and vy <= 0 then
		local valid = detector.Armed
			and y - detector.Low >= K.TurnRiseStuds
			and math.acos(math.clamp(-y / M.StringLength, -1, 1)) >= K.TurnMinAngle
			and time - detector.Last >= K.TurnMinSeconds
			and time - lastCollision >= K.TurnCollisionQuiet
		detector.Armed, detector.Low = false, y
		if valid then
			detector.Last = time
			return true
		end
	end
	return false
end

return Turnaround
