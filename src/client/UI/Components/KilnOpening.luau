-- UI-only timeline: simultaneous reels -> ONE kiln firing -> all awarded cards.
-- No remote, grant or economy calls belong in this component.
local RS = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Audio = require(RS.Shared.Config.Audio)
local Theme = require(script.Parent.Parent.Theme)
local S = require(script.Parent.StainedGlass)
local Reels = require(script.Parent.KilnReels)
local Opening = {}
Opening.__index = Opening
local K = Theme.Kiln
local Item = require(script.Parent.ItemPresentation)
local titles = { Glassies = "THE KILN", Finishers = "BURST CAPSULE", Rideables = "SKY CAPSULE" }
local MachineConfig = require(RS.Shared.Config.CrateMachines)
local CrateMachine = require(script.Parent.Parent.Parent.Presentation.CrateMachine)

function Opening.new(window, results, odds, collected, category, currency)
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
		Category = category or "Glassies",
		Currency = currency or "Coins",
	}, Opening)
	self.TintDark = if self.Category == "Finishers"
		then Theme.Palette.amethystDark
		elseif self.Category == "Rideables" then Theme.Palette.aquaDark
		else Theme.Palette.amberDark
	self.TintLight = if self.Category == "Finishers"
		then Theme.Palette.amethystLight
		elseif self.Category == "Rideables" then Theme.Palette.aquaLight
		else Theme.Palette.amberLight
	local c = self.Content
	c.Reels.Visible, c.KilnStage.Visible, c.Rewards.Visible = true, false, false
	c.Skip.Visible, c.Collect.Visible = true, false
	c.Status.Text = if self.Category == "Glassies"
		then (if #results == 1 then "SHAPING YOUR GLASS…" else "SHAPING " .. #results .. " GLASSIES…")
		else "FINDING YOUR " .. (if self.Category == "Finishers" then "FINISHER" else "FLYER") .. "…"
	window.Title.Text = titles[self.Category]
	local kilns = RS.Assets:FindFirstChild("Kilns")
	if self.Category == "Glassies" and kilns and kilns:FindFirstChild(self.Currency) then
		-- The Marble Kiln opening shows the creator's Marble Kiln (Assets.Kilns), framed like the shop.
		local slot = c.KilnStage.KilnPortrait
		Item.crate(c.KilnStage, self.Category, self.Currency, slot.Size, slot.Position, "KilnPortrait", true)
	end
	if self.Category ~= "Glassies" then
		local slot = c.KilnStage.KilnPortrait
		Item.crate(c.KilnStage, self.Category, self.Currency, slot.Size, slot.Position, "KilnPortrait", true)
		if CrateMachine.template(self.Category, self.Currency) then
			window.Title.Text = MachineConfig.Names[self.Category]:upper()
		end
		local tint = if self.Category == "Finishers" then Theme.Palette.amethystLight else Theme.Palette.aquaLight
		c.KilnStage.Flame.ImageColor3, c.KilnStage.Burst.ImageColor3 = tint, tint
	end
	window.Gui:SetAttribute("AwardCount", #results)
	window.Gui:SetAttribute("FireCount", 0)
	self.Sounds = Instance.new("Folder")
	self.Sounds.Name, self.Sounds.Parent = "KilnOpeningAudio", SoundService
	for name, id in { Tick = Audio.Clink, Fire = Audio.Whoosh, Reveal = Audio.Tinkle } do
		local sound = Instance.new("Sound")
		sound.Name, sound.SoundId, sound.Volume = name, id, if name == "Tick" then 0.10 else 0.35
		sound.Parent = self.Sounds
	end
	self.Reels = Reels.new(c, results, odds, self.Category)
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
	local c = self.Content
	c.Reels.Visible, c.KilnStage.Visible = false, true
	c.Status.Text = if self.Category == "Glassies"
		then "HEAT IT UP…"
		elseif self.Category == "Rideables" then "WINDING UP…"
		else "BUILDING PRESSURE…"
	self.FireFX = require(script.Parent.KilnFire).new(c.KilnStage, self.TintLight, self.Category)
	self.Mouth = self.FireFX:InFrame(c.KilnStage)
end

function Opening:ShowRewards(instant)
	if self.Dead or self.Phase == "Results" then
		return
	end
	self:SetPhase(if instant then "Results" else "Launch")
	local c = self.Content
	c.Reels.Visible, c.Rewards.Visible = false, true
	c.KilnStage.Visible = not instant
	c.Status.Text = if #self.Results == 1 then "IT’S YOURS!" else "ALL " .. #self.Results .. " ITEMS ARE YOURS!"
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
		local def = Item.definition(self.Category, result.Id)
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
			then "ANOTHER COPY · OWNED ×" .. (result.Count or 1)
			else "NEW " .. (if self.Category == "Glassies"
				then "GLASSY"
				elseif self.Category == "Finishers" then "FINISHER"
				else "FLYER") .. "!"
		card.RewardLabel.TextColor3 = if result.Duplicate then Theme.Palette.milk else Theme.Palette.emeraldLight
		card.BonusLabel.Text = if result.Rainbow then "RAINBOW!" else ""
		if (result.BonusCoins or 0) > 0 then
			card.BonusLabel.Text ..= " +" .. result.BonusCoins .. " COINS"
		end
		card.Glow.ImageColor3 = Theme.Rarity[def.Rarity].Top
		card.Parent = c.Rewards
		Item.portrait(card, self.Category, result.Id)
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
	local origin = if self.FireFX then self.FireFX:InFrame(self.Content.Rewards) else Vector2.new(0.5, 0.65)
	for i, item in self.Cards do
		local card = item.Object
		local t = math.clamp((time - item.Delay) / K.CardFlight, 0, 1)
		card.Visible = time >= item.Delay
		local u = TweenService:GetValue(t, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)
		local side = if #self.Cards == 1 then 0.05 else (i - 5.5) * 0.015
		local control = (origin + item.Destination) / 2 + Vector2.new(side, -0.32)
		local p = origin * (1 - u) ^ 2 + control * 2 * (1 - u) * u + item.Destination * u ^ 2
		card.Position = UDim2.fromScale(p.X, p.Y)
		card.RevealScale.Scale = 0.04 + 0.96 * TweenService:GetValue(t, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		card.Rotation = math.sin(t * math.pi) * (if i % 2 == 0 then 7 else -7)
		local decoration = 1 - math.clamp((t - 0.25) / 0.45, 0, 1)
		card.Artwork.ImageTransparency = decoration
		card.Glow.ImageTransparency = 0.2 + 0.65 * t
		for _, label in { card.Rarity, card.NameLabel, card.RewardLabel, card.BonusLabel } do
			label.TextTransparency = decoration
			for _, stroke in label:GetChildren() do
				if stroke:IsA("UIStroke") then
					stroke.Transparency = decoration
				end
			end
		end
	end
	if self.FireFX then
		self.FireFX:Launch(time)
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
		item.Object.Rotation, item.Object.Artwork.ImageTransparency = 0, 0
		for _, label in { item.Object.Rarity, item.Object.NameLabel, item.Object.RewardLabel, item.Object.BonusLabel } do
			label.TextTransparency = 0
			for _, stroke in label:GetChildren() do
				if stroke:IsA("UIStroke") then
					stroke.Transparency = 0
				end
			end
		end
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
			self.Content.Status.Text = "SELECTED · HERE IT COMES…"
			self:SetPhase("Landed")
		end
	elseif self.Phase == "Landed" then
		if t >= K.LandHold then
			self:BeginFire()
		end
	elseif self.Phase == "Fire" then
		self.FireFX:Step(t)
		local timing = self.FireFX.Timing
		if t >= timing.ChargeSeconds and not self.PlayedFire then
			self.PlayedFire = true
			self.Content.Status.Text = "HERE IT COMES!"
			self.Sounds.Fire:Play()
		end
		if t >= timing.FireSeconds then
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
	if self.FireFX then
		self.FireFX:Destroy()
	end
	self.Sounds:Destroy()
	table.clear(self.Cards)
end
return Opening
