-- UI-only timeline: simultaneous reels -> ONE kiln firing -> all awarded cards.
-- No remote, grant or economy calls belong in this component.
local RS = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Glassies = require(RS.Shared.Config.Glassies)
local Audio = require(RS.Shared.Config.Audio)
local Theme = require(script.Parent.Parent.Theme)
local S = require(script.Parent.StainedGlass)
local Portrait = require(script.Parent.GlassyPortrait)
local Reels = require(script.Parent.KilnReels)
local Opening = {}
Opening.__index = Opening
local K = Theme.Kiln

function Opening.new(window, results, odds, collected)
	local self = setmetatable({
		Window = window,
		Content = window.Content,
		Results = results,
		Time = 0,
		PhaseTime = 0,
		Phase = "Reels",
		FireCount = 0,
		Cards = {},
		Dead = false,
		OnCollected = collected,
	}, Opening)
	local c = self.Content
	c.Reels.Visible, c.KilnStage.Visible, c.Rewards.Visible = true, false, false
	c.Skip.Visible, c.Collect.Visible = true, false
	c.Status.Text = if #results == 1 then "SHAPING YOUR GLASS…" else "SHAPING " .. #results .. " GLASSIES…"
	window.Title.Text = "THE KILN"
	window.Gui:SetAttribute("AwardCount", #results)
	window.Gui:SetAttribute("FireCount", 0)
	self.Sounds = Instance.new("Folder")
	self.Sounds.Name, self.Sounds.Parent = "KilnOpeningAudio", SoundService
	for name, id in { Tick = Audio.Clink, Fire = Audio.Whoosh, Reveal = Audio.Tinkle } do
		local sound = Instance.new("Sound")
		sound.Name, sound.SoundId, sound.Volume = name, id, if name == "Tick" then 0.10 else 0.35
		sound.Parent = self.Sounds
	end
	self.Reels = Reels.new(c, results, odds)
	window:Connect(c.Skip, function()
		self:Skip()
	end)
	window:Connect(c.Collect, function()
		self:Collect()
	end)
	self:SetPhase("Reels")
	return self
end

function Opening:SetPhase(phase)
	self.Phase, self.PhaseTime = phase, 0
	self.Window.Gui:SetAttribute("OpeningPhase", phase)
end

function Opening:BeginFire()
	if self.FireCount > 0 or self.Dead then
		return
	end
	self.FireCount += 1
	self.Window.Gui:SetAttribute("FireCount", self.FireCount)
	self:SetPhase("Fire")
	local c, stage = self.Content, self.Content.KilnStage
	c.Reels.Visible, stage.Visible = false, true
	c.Status.Text = "FIRING THE KILN…"
	-- Project the chamber into UI coordinates, keeping fire inside the kiln mouth.
	local viewport = stage.KilnPortrait
	local chamber = viewport:FindFirstChild("Kiln_ChamberBackGlow", true)
	local camera = viewport.CurrentCamera
	local p = camera.CFrame:PointToObjectSpace(chamber.Position)
	local tangent = math.tan(math.rad(camera.FieldOfView) / 2)
	local pixel = viewport.AbsolutePosition
		+ Vector2.new(
			viewport.AbsoluteSize.X / 2 + p.X / (-p.Z * tangent * 2) * viewport.AbsoluteSize.Y,
			viewport.AbsoluteSize.Y / 2 - p.Y / (-p.Z * tangent * 2) * viewport.AbsoluteSize.Y
		)
	self.Mouth = (pixel - stage.AbsolutePosition) / stage.AbsoluteSize
	stage.Flame.Position = UDim2.fromScale(self.Mouth.X, self.Mouth.Y)
	stage.Burst.Position = UDim2.fromScale(self.Mouth.X, self.Mouth.Y)
	stage.FlameEcho.Visible = false
	self.GlowParts = {}
	for _, part in stage.KilnPortrait:GetDescendants() do
		if part:IsA("BasePart") and (part.Name == "Kiln_ChamberBackGlow" or part.Name == "Kiln_MoltenPool") then
			table.insert(self.GlowParts, part)
			part.Material = Enum.Material.Neon
		end
	end
	for i = 1, K.SparkCount do
		local spark = Instance.new("Frame")
		spark.Name = "Ember" .. i
		spark.AnchorPoint, spark.BorderSizePixel = Vector2.new(0.5, 0.5), 0
		spark.BackgroundColor3 = if i % 3 == 0 then Theme.Palette.aquaLight else Theme.Palette.amberLight
		spark.Size, spark.Rotation = UDim2.fromOffset(4 + i % 4, 4 + i % 4), 45
		spark.Parent = stage.Sparks
	end
end

function Opening:ShowRewards(instant)
	if self.Dead or self.Phase == "Results" then
		return
	end
	self:SetPhase(if instant then "Results" else "Launch")
	local c = self.Content
	c.Reels.Visible, c.Rewards.Visible = false, true
	c.KilnStage.Visible = not instant
	c.Status.Text = if #self.Results == 1
		then "FRESH FROM THE KILN!"
		else "ALL " .. #self.Results .. " GLASSIES ARE YOURS!"
	c.Skip.Visible, c.Collect.Visible = not instant, instant
	if not instant then
		self.Sounds.Reveal:Play()
	end
	local centerY = (
		self.Window.Gui.AbsolutePosition.Y
		+ self.Window.Gui.AbsoluteSize.Y / 2
		- c.Rewards.AbsolutePosition.Y
	) / math.max(1, c.Rewards.AbsoluteSize.Y)
	for i, result in self.Results do
		local card = c.Templates.RewardCard:Clone()
		local def = Glassies.get(result.Id)
		card.Name, card.Visible = "Reward" .. i, true
		card:SetAttribute("AwardIndex", i)
		card:SetAttribute("GlassyId", result.Id)
		card:SetAttribute("Rainbow", result.Rainbow == true)
		local multi = #self.Results > 1
		local destination = if multi
			then Vector2.new(0.14 + (i - 1) % 5 * 0.18, centerY - 0.255 + math.floor((i - 1) / 5) * 0.51)
			else Vector2.new(0.5, centerY)
		card.Size = if multi then UDim2.fromScale(0.18, 0.48) else UDim2.fromScale(0.43, 0.99)
		card.Position = UDim2.fromScale(destination.X, destination.Y)
		S.setAsset(card.Artwork, "tile/tile_" .. S.rarity(def.Rarity))
		card.Rarity.Text, card.Rarity.TextColor3 = def.Rarity:upper(), Theme.Rarity[def.Rarity].Top
		card.NameLabel.Text = def.Name
		card.RewardLabel.Text = if result.Duplicate
			then "DUPLICATE • " .. (result.Stars or 0) .. " STARS"
			else "NEW GLASSY!"
		card.RewardLabel.TextColor3 = if result.Duplicate then Theme.Palette.milk else Theme.Palette.emeraldLight
		card.BonusLabel.Text = if result.Rainbow then "RAINBOW!" else ""
		if (result.BonusCoins or 0) > 0 then
			card.BonusLabel.Text ..= " +" .. result.BonusCoins .. " COINS"
		end
		card.Glow.ImageColor3 = Theme.Rarity[def.Rarity].Top
		card.Parent = c.Rewards
		Portrait.new(card, result.Id)
		table.insert(self.Cards, { Object = card, Destination = destination, Delay = (i - 1) * K.CardStagger })
	end
	S.bindSlices(c.Rewards)
	if instant then
		self:Finish()
	else
		self:LaunchStep(0)
	end
end

function Opening:LaunchStep(time)
	for _, item in self.Cards do
		local card = item.Object
		local t = math.clamp((time - item.Delay) / K.CardFlight, 0, 1)
		card.Visible = time >= item.Delay
		local ease = TweenService:GetValue(t, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
		local destination = item.Destination
		local mouth = self.Mouth and self.Mouth.Y or 0.61
		card.Position = UDim2.fromScale(
			0.5 + (destination.X - 0.5) * ease,
			mouth + (destination.Y - mouth) * ease - math.sin(t * math.pi) * 0.12
		)
		card.RevealScale.Scale = 0.08 + 0.92 * TweenService:GetValue(t, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		card.Glow.ImageTransparency = 0.45 + 0.35 * t
	end
	self.Content.KilnStage.KilnPortrait.ImageTransparency = math.clamp(time / K.CardFlight, 0, 1)
	-- Fade the viewport and its model during the card release.
	for _, part in self.Content.KilnStage.KilnPortrait:GetDescendants() do
		if part:IsA("BasePart") then
			part.LocalTransparencyModifier = math.clamp(time / K.CardFlight, 0, 1)
		end
	end
	for _, image in { self.Content.KilnStage.Flame, self.Content.KilnStage.FlameEcho, self.Content.KilnStage.Burst } do
		image.ImageTransparency = math.clamp(time / K.CardFlight, 0, 1)
	end
end

function Opening:Finish()
	self:SetPhase("Results")
	local c = self.Content
	c.KilnStage.Visible, c.Skip.Visible, c.Collect.Visible = false, false, true
	for _, item in self.Cards do
		item.Object.Visible, item.Object.RevealScale.Scale = true, 1
		item.Object.Position = UDim2.fromScale(item.Destination.X, item.Destination.Y)
		item.Object.Glow.ImageTransparency = 0.85
	end
	self.Window.Gui:SetAttribute("RevealedCount", #self.Cards)
	for _, sound in self.Sounds:GetChildren() do
		sound:Stop()
	end
end

function Opening:Skip()
	if self.Dead or self.Phase == "Collect" then
		return
	end
	if #self.Cards > 0 then
		self:Finish()
	else
		self:ShowRewards(true)
	end
end

function Opening:Collect()
	if self.Dead or self.Phase ~= "Results" then
		return
	end
	local hud = game.Players.LocalPlayer.PlayerGui:FindFirstChild("LobbyHUD")
	local button = hud and hud:FindFirstChild("InventoryButton", true)
	if not button then
		self.Collected = true
		self:SetPhase("Collected")
		self.OnCollected()
		return
	end
	self.Target = button
	self.TargetScale = button:FindFirstChild("InteractionScale")
	self.PreviousScale = self.TargetScale and self.TargetScale.Scale
	self.ArrivalCount = 0
	self:SetPhase("Collect")
	self.Content.Collect.Visible = false
	self.Window.Panel.Close.Visible = false
	self.Content.Status.Text = "ADDING TO YOUR INVENTORY…"
	self.Window.Title.Visible = false
	for _, item in self.Cards do
		item.Start = Vector2.new(item.Object.Position.X.Scale, item.Object.Position.Y.Scale)
	end
	self.Sounds.Fire.PlaybackSpeed = 1.4
	self.Sounds.Fire.Volume = 0.18
	self.Sounds.Fire:Play()
end

function Opening:CollectStep(time)
	local rewards = self.Content.Rewards
	local target = (self.Target.AbsolutePosition + self.Target.AbsoluteSize / 2 - rewards.AbsolutePosition)
		/ rewards.AbsoluteSize
	for i, item in self.Cards do
		local t = math.clamp((time - (i - 1) * K.CollectStagger) / K.CollectFlight, 0, 1)
		local u = TweenService:GetValue(t, Enum.EasingStyle.Cubic, Enum.EasingDirection.InOut)
		local control = (item.Start + target) / 2 - Vector2.new(0, 0.22)
		local position = item.Start * (1 - u) ^ 2 + control * 2 * (1 - u) * u + target * u ^ 2
		local card = item.Object
		card.Position = UDim2.fromScale(position.X, position.Y)
		card.RevealScale.Scale = 1 - 0.95 * u
		card.Artwork.ImageTransparency = math.clamp(t * 4, 0, 1)
		card.Glow.ImageTransparency = math.clamp(0.85 + t, 0, 1)
		card.Portrait.Position = UDim2.fromScale(0.5, 0.4 + 0.1 * math.min(t * 4, 1))
		for _, label in { card.Rarity, card.NameLabel, card.RewardLabel, card.BonusLabel } do
			label.TextTransparency = math.clamp(t * 5, 0, 1)
		end
		if t == 1 and not item.Arrived then
			item.Arrived = true
			card.Visible = false
			self.ArrivalCount += 1
			self.LastArrival = time
			self.Window.Gui:SetAttribute("CollectionArrivals", self.ArrivalCount)
		end
	end
	if self.TargetScale and self.LastArrival then
		local pulse = math.clamp((time - self.LastArrival) / K.CollectPulse, 0, 1)
		self.TargetScale.Scale = 1 + 0.14 * math.sin(pulse * math.pi)
	end
	if self.ArrivalCount == #self.Cards and time - self.LastArrival >= K.CollectPulse and not self.Collected then
		self.Collected = true
		self.OnCollected()
	end
end

function Opening:Step(dt)
	if self.Dead or self.Phase == "Results" then
		return
	end
	self.Time += dt
	self.PhaseTime += dt
	local t = self.PhaseTime
	if self.Phase == "Reels" then
		local done, ticked = self.Reels:Step(t)
		if ticked and self.Time - (self.LastSound or 0) > K.TickInterval then
			self.LastSound = self.Time
			self.Sounds.Tick.PlaybackSpeed = 0.9 + math.min(t / K.SpinSeconds, 1) * 0.35
			self.Sounds.Tick.TimePosition = 0
			self.Sounds.Tick:Play()
		end
		if done then
			self.Content.Status.Text = "GLASS SELECTED • HEATING UP…"
			self:SetPhase("Landed")
		end
	elseif self.Phase == "Landed" then
		if t >= K.LandHold then
			self:BeginFire()
		end
	elseif self.Phase == "Fire" then
		local stage = self.Content.KilnStage
		local charge = math.clamp(t / K.FireSeconds, 0, 1)
		local heat = math.clamp(charge / 0.72, 0, 1)
		local release = math.clamp((charge - 0.72) / 0.28, 0, 1)
		local pulse = math.sin(release * math.pi)
		-- Anticipation, a short hot pulse, then release. The furnace remains readable.
		stage.Flame.Size = UDim2.fromScale(0.075 + heat * 0.022, 0.16 + heat * 0.065 + math.sin(t * 23) * 0.008)
		stage.Flame.ImageTransparency = 0.60 - heat * 0.25 + release * 0.2
		stage.Flame.Rotation = math.sin(t * 17) * 1.5
		stage.Burst.Size = UDim2.fromScale(0.24 + heat * 0.06 + pulse * 0.07, 0.46 + heat * 0.10 + pulse * 0.13)
		stage.Burst.ImageTransparency = 0.88 - heat * 0.25 - pulse * 0.08
		stage.Burst.Rotation = 0
		stage.KilnPortrait.FireScale.Scale = 0.92
			+ 0.08 * math.min(charge / 0.22, 1)
			- math.sin(heat * math.pi) * 0.015
			+ pulse * 0.035
		for _, part in self.GlowParts do
			part.Color = Theme.Palette.amberDark
				:Lerp(Theme.Palette.amberLight, heat * 0.8)
				:Lerp(Theme.Palette.milkLight, pulse * 0.65)
		end
		for i, spark in stage.Sparks:GetChildren() do
			local age = (charge * 1.2 + i / K.SparkCount) % 1
			spark.Position = UDim2.fromScale(self.Mouth.X + math.sin(i * 2.4) * age * 0.12, self.Mouth.Y - age * 0.35)
			spark.BackgroundTransparency = 0.25 + age * 0.75
		end
		if release > 0 and not self.PlayedFire then
			self.PlayedFire = true
			self.Sounds.Fire:Play()
		end
		if t >= K.FireSeconds then
			self:ShowRewards(false)
		end
	elseif self.Phase == "Collect" then
		self:CollectStep(t)
	elseif self.Phase == "Launch" then
		self:LaunchStep(t)
		if t >= K.CardFlight + (#self.Results - 1) * K.CardStagger then
			self:Finish()
		end
	end
end

function Opening:Destroy()
	if self.Dead then
		return
	end
	self.Dead = true
	if self.TargetScale then
		self.TargetScale.Scale = self.PreviousScale or 1
	end
	self.Reels:Destroy()
	self.Sounds:Destroy()
	table.clear(self.Cards)
end
return Opening
