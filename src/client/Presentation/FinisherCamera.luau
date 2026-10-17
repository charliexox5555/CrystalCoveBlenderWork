-- Reset to the normal arena shot, follow the winner's destination, then return. Finishers may hold
-- longer (CameraHoldSeconds) and kick the camera on their release beat (KickAt, after impact).
local RS = game:GetService("ReplicatedStorage")
local Feel = require(RS.Shared.Config.Balance).Feel
local Cosmetics = require(RS.Shared.Config.RoundCosmetics)
local Camera = {}
local function ease(t)
	local x = math.clamp(t, 0, 1)
	return x * x * (3 - 2 * x)
end
function Camera.pose(finisher, normal, from, now)
	local age = math.max(0, now - finisher.At)
	if age < Feel.FinisherCameraResetSeconds then
		return from:Lerp(normal, ease(age / Feel.FinisherCameraResetSeconds))
	end
	local flyAt = Feel.FinisherPause + Feel.FinisherRiseSeconds
	local impactAt = flyAt + Feel.FinisherFlySeconds
	local def = Cosmetics.ByCategory.Finishers[finisher:Id()] or {}
	local hold = def.CameraHoldSeconds or Feel.FinisherCameraHoldSeconds
	local amount = ease((age - flyAt) / Feel.FinisherFlySeconds)
	if age > impactAt + hold then
		amount = 1 - ease((age - impactAt - hold) / Feel.FinisherCameraReturnSeconds)
	end
	local focus = finisher.Target + Vector3.yAxis * Feel.FinisherCameraTargetHeight
	local offset = normal.Position - finisher.Scene.CameraFocus
	local close = CFrame.lookAt(focus + offset * Feel.FinisherCameraDistanceScale, focus)
	local pose = normal:Lerp(close, amount)
	local kick = def.KickAt and (age - impactAt - def.KickAt) / Feel.FinisherKickSeconds
	if kick and kick >= 0 and kick < 1 then
		local size = Feel.FinisherKickStuds * (1 - kick) ^ 2
		pose *= CFrame.new(math.noise(age * 40, 1) * size, math.noise(age * 40, 2) * size, 0)
	end
	return pose
end
return Camera
