-- Shared per-player/per-action limiter. Invalid requests consume their slot too.
local Guard = {}
Guard.__index = Guard
function Guard.new(clock)
	return setmetatable({ Clock = clock or os.clock, Last = {} }, Guard)
end
function Guard:Allow(player, action, seconds)
	local now = self.Clock()
	local last = self.Last[player]
	if not last then
		last = {}
		self.Last[player] = last
	end
	if now - (last[action] or -math.huge) < seconds then
		return false
	end
	last[action] = now
	return true
end
function Guard:Remove(player)
	self.Last[player] = nil
end
function Guard.finite(n)
	return type(n) == "number" and n == n and math.abs(n) < math.huge
end
return Guard
