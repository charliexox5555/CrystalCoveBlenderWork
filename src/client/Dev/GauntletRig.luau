-- Presentation for v5 glassies on a FightScene fighter: swap-in expressions, and HP shown as the liquid level.
local Rig = {}
Rig.__index = Rig

local BLINK_SECONDS, HURT_SECONDS = 0.12, 0.34
local MIN_LIQUID = 0.16 -- a nearly empty glass still shows a little colour

function Rig.new(fighter)
	local faces, fill = {}, nil
	for _, part in fighter.Model:GetChildren() do
		if part:IsA("BasePart") then
			local state = part:GetAttribute("BuddyFace")
			if state then
				faces[state] = part
			elseif part.Name == "Fill" then
				fill = part
			end
		end
	end
	local self = setmetatable({
		Fighter = fighter,
		Faces = faces,
		Fill = fill,
		FillSize = fill and fill.Size,
		FillOffset = fill and fighter.Model:GetPivot():ToObjectSpace(fill.CFrame),
		State = "Idle",
		HurtUntil = 0,
		NextBlink = os.clock() + math.random() * 3 + 1,
		BlinkUntil = 0,
		Liquid = 1,
	}, Rig)
	return self
end

function Rig:Hurt()
	self.HurtUntil = os.clock() + HURT_SECONDS
end

function Rig:Win()
	self.Won = true
end

function Rig:Show(state)
	if state == self.State or not self.Faces[state] then
		return
	end
	self.State = state
	for name, part in self.Faces do
		part.Transparency = if name == state then 0 else 1
	end
end

function Rig:Update(hpFraction)
	local f = self.Fighter
	if f.Broken or f.Finishing then
		for _, part in self.Faces do
			part.Transparency = 1
		end
		if self.Fill then
			self.Fill.Transparency = 1
		end
		return
	end
	local now = os.clock()
	if now >= self.NextBlink then
		self.BlinkUntil, self.NextBlink = now + BLINK_SECONDS, now + 2 + math.random() * 3.5
	end
	local state = "Idle"
	if self.Won then
		state = "Happy"
	elseif now < self.HurtUntil then
		state = "Hurt"
	elseif now < self.BlinkUntil then
		state = "Blink"
	end
	self:Show(state)
	if self.Fill and f.Pivot then
		self.Liquid += (math.clamp(hpFraction, 0, 1) - self.Liquid) * 0.14
		local level = MIN_LIQUID + (1 - MIN_LIQUID) * self.Liquid
		local size = self.FillSize
		self.Fill.Size = Vector3.new(size.X, size.Y * level, size.Z)
		-- The liquid drops from its surface; the bottom of the glass stays full.
		self.Fill.CFrame = f.Pivot * self.FillOffset * CFrame.new(0, -size.Y * (1 - level) / 2, 0)
	end
end

return Rig
