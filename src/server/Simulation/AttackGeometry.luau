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

return Geometry
