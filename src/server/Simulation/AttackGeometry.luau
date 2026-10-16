-- Bounded deterministic geometry, shared by native and Lune swing checks. No physics queries.
local Geometry = {}

function Geometry.segmentSphere(a, b, center, radius)
	local delta = b - a
	local t = if delta:Dot(delta) > 1e-10 then math.clamp((center - a):Dot(delta) / delta:Dot(delta), 0, 1) else 0
	local closest = a + delta * t
	local distance = (closest - center).Magnitude
	if distance > radius then
		return false, closest
	end
	local length = delta.Magnitude
	local entry = if length > 1e-10
		then math.max(0, t - math.sqrt(math.max(0, radius * radius - distance * distance)) / length)
		else 0
	return true, a + delta * entry
end

function Geometry.movingSphere(a, b, oldTarget, target, radius)
	-- Relative motion avoids tunnelling when a target crosses a short-lived attack.
	return Geometry.segmentSphere(a - oldTarget, b - target, target - target, radius)
end

function Geometry.coneSphere(origin, direction, range, arc, center, radius)
	local delta = center - origin
	local along = delta:Dot(direction)
	if along < -radius or along > range + radius then
		return false
	end
	local radial = (delta - direction * along).Magnitude
	return radial <= math.max(0, along) * math.tan(arc / 2) + radius
end

function Geometry.fanDirection(direction, index, count, arc, up)
	local right = direction:Cross(up)
	if right.Magnitude < 0.0001 then
		return direction
	end
	local angle = if count == 1 then 0 else ((index - 1) / (count - 1) - 0.5) * arc
	return (direction * math.cos(angle) + right.Unit * math.sin(angle)).Unit
end

return Geometry
