-- Shared by authoritative collision and client animation; progress is normalized cast time.
local Path = {}
function Path.distance(progress, kind)
	local t = math.clamp(progress, 0, 1)
	return if kind == "return" then 1 - math.abs(2 * t - 1) else t
end
return Path
