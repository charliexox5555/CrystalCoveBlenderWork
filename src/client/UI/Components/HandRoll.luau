-- Three fast vertical card reels, strictly sequential, pinned to server-provided offers.
local Theme = require(script.Parent.Parent.Theme)
local Audio = require(game.ReplicatedStorage.Shared.Config.Audio)
local Glassies = require(game.ReplicatedStorage.Shared.Config.Glassies)
local Roll = {}
Roll.__index = Roll
function Roll.new(panel, offers, collection, render)
	local ids = {}
	for id in collection do
		table.insert(ids, id)
	end
	table.sort(ids)
	local self = setmetatable(
		{ Panel = panel, Offers = offers, Ids = ids, Render = render, Rows = {}, Hidden = {}, Random = Random.new() },
		Roll
	)
	self.Sounds = Instance.new("Folder")
	self.Sounds.Name = "HandRollAudio"
	self.Sounds.Parent = game:GetService("SoundService")
	for name, id in { Whoosh = Audio.Whoosh, Land = Audio.Clink, Tick = Audio.ClinkAlt } do
		local sound = Instance.new("Sound")
		sound.Name, sound.SoundId, sound.Volume = name, id, 0.14
		sound.Parent = self.Sounds
	end
	return self
end
function Roll:Build()
	local p = self.Panel
	if p.AbsoluteSize.X <= 0 then
		return false
	end
	for i in self.Offers do
		if p.Cards["Card" .. i].AbsoluteSize.Y <= 0 then
			return false
		end
	end
	for i, id in self.Offers do
		local source = p.Cards["Card" .. i]
		if source.AbsoluteSize.Y <= 0 then
			return false
		end
		local clip = Instance.new("Frame")
		clip.Name = "VerticalReel" .. i
		clip.Size = UDim2.fromScale(source.AbsoluteSize.X / p.AbsoluteSize.X, source.AbsoluteSize.Y / p.AbsoluteSize.Y)
		local pos = (source.AbsolutePosition - p.AbsolutePosition) / p.AbsoluteSize
		clip.Position = UDim2.fromScale(pos.X, pos.Y)
		clip.BackgroundTransparency, clip.ClipsDescendants = 1, true
		clip.Parent = p.ReelLayer
		local row = { Clip = clip, Cells = {}, Stream = {}, Target = Theme.Selection.RollSteps, Source = source }
		row.Scale = Instance.new("UIScale")
		row.Scale.Parent = clip
		row.Edge = Instance.new("UIStroke")
		row.Edge.Thickness, row.Edge.Transparency, row.Edge.Color = 3, 1, Color3.fromHex(Glassies.get(id).Tint)
		row.Edge.Parent = clip
		for n = 1, row.Target + 3 do
			row.Stream[n] = self.Ids[self.Random:NextInteger(1, #self.Ids)]
		end
		row.Stream[row.Target] = id
		for n = 1, 3 do
			local c = p.Cards.Templates.GlassyCard:Clone()
			c.Name, c.Visible, c.Size, c.AnchorPoint, c.Parent =
				"Cell" .. n, true, UDim2.fromScale(1, 1), Vector2.new(0.5, 0.5), clip
			c.Select.Active, c.Select.Selectable = false, false
			table.insert(row.Cells, c)
		end
		for _, o in source:GetChildren() do
			if o:IsA("GuiObject") then
				self.Hidden[o] = o.Visible
				o.Visible = false
			end
		end
		table.insert(self.Rows, row)
	end
	self.Ready = true
	return true
end
function Roll:Step(time)
	if not self.Ready and not self:Build() then
		return false
	end
	local K = Theme.Selection
	for i, row in self.Rows do
		row.Clip.Visible = time >= (i - 1) * (K.CardSeconds + K.CardGap)
		if row.Clip.Visible and not row.Started then
			row.Started = true
			self.Sounds.Whoosh.TimePosition = 0
			self.Sounds.Whoosh.PlaybackSpeed = 1.6
			self.Sounds.Whoosh:Play()
		end
		local t = math.clamp((time - (i - 1) * (K.CardSeconds + K.CardGap)) / K.CardSeconds, 0, 1)
		local offset = 2 + (row.Target - 2) * (1 - (1 - t) ^ 3)
		local step = math.floor(offset)
		if row.Clip.Visible and step ~= row.LastStep and t < 1 then
			row.LastStep = step
			self.Sounds.Tick.Volume = K.TickVolume
			self.Sounds.Tick.TimePosition, self.Sounds.Tick.PlaybackSpeed = 0, 1.4 + t * 0.4
			self.Sounds.Tick:Play()
		end
		if t == 1 and not row.Landed then
			row.Landed = true
			self.Sounds.Land.TimePosition = 0
			self.Sounds.Land.PlaybackSpeed = 1 + i * 0.12
			self.Sounds.Land:Play()
		end
		local landedAt = (i - 1) * (K.CardSeconds + K.CardGap) + K.CardSeconds
		local settle = math.clamp((time - landedAt) / K.LandPulseSeconds, 0, 1)
		row.Scale.Scale = 1 + math.sin(settle * math.pi) * K.LandPulseScale
		row.Edge.Transparency = if row.Landed then settle else 1
		row.Clip.Rotation = if row.Started and not row.Landed then (1 - t) * K.RollTilt else 0
		for n, cell in row.Cells do
			local first = math.floor(offset) - 1
			local index = first + (n - 1 - (first - 1) % 3) % 3
			cell.Position = UDim2.fromScale(0.5, 0.5 + index - offset)
			local id = row.Stream[index]
			if id and cell:GetAttribute("GlassyId") ~= id then
				cell:SetAttribute("GlassyId", id)
				self.Render(cell, id)
			end
		end
	end
	return time >= #self.Rows * K.CardSeconds + (#self.Rows - 1) * K.CardGap + K.LandHold
end
function Roll:Destroy()
	self.Sounds:Destroy()
	for o, visible in self.Hidden do
		if o.Parent then
			o.Visible = visible
		end
	end
	for _, row in self.Rows do
		row.Clip:Destroy()
	end
	table.clear(self.Rows)
end
return Roll
