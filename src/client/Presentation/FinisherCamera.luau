-- Reset to the normal arena shot, follow the winner's destination, then return.
local Feel = require(game.ReplicatedStorage.Shared.Config.Balance).Feel
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
	local amount = ease((age - flyAt) / Feel.FinisherFlySeconds)
	if age > impactAt + Feel.FinisherCameraHoldSeconds then
		amount = 1 - ease((age - impactAt - Feel.FinisherCameraHoldSeconds) / Feel.FinisherCameraReturnSeconds)
	end
	local focus = finisher.Target + Vector3.yAxis * Feel.FinisherCameraTargetHeight
	local offset = normal.Position - finisher.Scene.CameraFocus
	local close = CFrame.lookAt(focus + offset * Feel.FinisherCameraDistanceScale, focus)
	return normal:Lerp(close, amount)
end
return Camera
