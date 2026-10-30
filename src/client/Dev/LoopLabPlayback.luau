-- Pure private-lab snapshot playback. Delay events with motion so damage/shatter match the drawn contact.
local Playback = {}
Playback.__index = Playback

function Playback.new(delay, interval, capacity)
	return setmetatable(
		{ Delay = delay, Interval = interval, Capacity = capacity, Frames = {}, Events = {}, Time = 0 },
		Playback
	)
end

function Playback:push(snapshot, events, now, final)
	local frames = self.Frames
	if self.ReceivedAt and now - self.ReceivedAt > 1 then
		self.Time = math.max(0, snapshot.T - self.Delay)
		self.Frames, self.Events = {}, {}
		frames = self.Frames
	end
	self.ReceivedAt, self.Final = now, final
	local latest = frames[#frames]
	if latest and latest.T == snapshot.T then
		frames[#frames] = snapshot
	else
		table.insert(frames, snapshot)
	end
	while #frames > self.Capacity do
		table.remove(frames, 1)
	end
	for _, e in events do
		table.insert(self.Events, e)
	end
end

function Playback:sample(now)
	local frames = self.Frames
	local latest = frames[#frames]
	if not latest then
		return nil
	end
	local target = if self.Final
		then latest.T
		else math.max(0, latest.T + math.min(math.max(0, now - self.ReceivedAt), self.Interval) - self.Delay)
	self.Time = math.max(self.Time, math.min(latest.T, target))
	local left, right = frames[1], latest
	for i = 1, #frames - 1 do
		if frames[i].T <= self.Time and frames[i + 1].T >= self.Time then
			left, right = frames[i], frames[i + 1]
			break
		end
	end
	if self.Time >= latest.T then
		left = latest
	end
	local span = right.T - left.T
	local t = if span > 0 then math.clamp((self.Time - left.T) / span, 0, 1) else 0
	local result = { T = self.Time, B = {}, R = table.clone(left.R) }
	result.R.Hp, result.R.Power = {}, {}
	for side = 1, 2 do
		local a, b, body = left.B[side], right.B[side], {}
		for i = 1, #a do
			body[i] = a[i] + (b[i] - a[i]) * t
		end
		-- Hermite positions use server velocities; the caller projects back onto the string length.
		for i = 1, 3 do
			body[i] = (2 * t ^ 3 - 3 * t ^ 2 + 1) * a[i]
				+ (t ^ 3 - 2 * t ^ 2 + t) * span * a[i + 3]
				+ (-2 * t ^ 3 + 3 * t ^ 2) * b[i]
				+ (t ^ 3 - t ^ 2) * span * b[i + 3]
		end
		result.B[side] = body
		for _, key in { "Hp", "Power" } do
			result.R[key][side] = left.R[key][side] + (right.R[key][side] - left.R[key][side]) * t
		end
	end
	local due, pending = {}, {}
	for _, e in self.Events do
		table.insert(if (e.Time or latest.T) <= self.Time then due else pending, e)
	end
	self.Events = pending
	return result, due
end

return Playback
