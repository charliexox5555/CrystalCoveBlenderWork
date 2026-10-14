local Players = game:GetService("Players")
local SocialService = game:GetService("SocialService")
local RS = game:GetService("ReplicatedStorage")
local Glassies = require(RS.Shared.Config.Glassies)
local Powers = require(RS.Shared.Config.Powers)
local Theme = require(script.Parent.Parent.Theme)
local U = require(script.Parent.Parent.Components.Util)
local Panel = require(script.Parent.Parent.Components.Panel)
local Button = require(script.Parent.Parent.Components.Button)
local Portrait = require(script.Parent.Parent.Components.GlassyPortrait)
local Screens = {}
Screens.__index = Screens

function Screens.new(name)
	local self = setmetatable({ Connections = {}, Portraits = {} }, Screens)
	self.Gui = U.make("ScreenGui", Players.LocalPlayer.PlayerGui, {
		Name = name,
		ResetOnSpawn = false,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
		DisplayOrder = 15,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})
	return self
end

function Screens:Connect(button, callback)
	U.make("UISizeConstraint", button, { MinSize = Vector2.new(70, 44) })
	table.insert(self.Connections, button.Activated:Connect(callback))
end

function Screens.queue(data, leave)
	local self = Screens.new("QueuePanel")
	local panel = Panel.new(self.Gui, "Queue", UDim2.fromScale(0.55, 0.28), UDim2.fromScale(0.225, 0.62), true)
	self.Title = U.text(
		panel,
		"Title",
		"WAITING FOR A CHALLENGER",
		UDim2.fromScale(0.94, 0.22),
		UDim2.fromScale(0.03, 0.05),
		Theme.Fonts.Heading
	)
	self.Timer = U.text(panel, "Timer", "", UDim2.fromScale(0.94, 0.19), UDim2.fromScale(0.03, 0.3))
	local track = U.make("Frame", panel, {
		Name = "Progress",
		Size = UDim2.fromScale(0.86, 0.04),
		Position = UDim2.fromScale(0.07, 0.54),
		BackgroundColor3 = Theme.Colors.Inset,
		BorderSizePixel = 0,
	})
	self.Fill = U.make(
		"Frame",
		track,
		{ Size = UDim2.fromScale(0, 1), BackgroundColor3 = Theme.Colors.EdgeA, BorderSizePixel = 0 }
	)
	self:Connect(
		Button.new(panel, "Leave", "LEAVE", "Red", UDim2.fromScale(0.37, 0.28), UDim2.fromScale(0.08, 0.65)),
		leave
	)
	self:Connect(
		Button.new(panel, "Invite", "INVITE FRIEND", "Blue", UDim2.fromScale(0.43, 0.28), UDim2.fromScale(0.51, 0.65)),
		function()
			local ok = pcall(function()
				SocialService:PromptGameInvite(Players.LocalPlayer)
			end)
			if not ok then
				self.Timer.Text = "Invite a friend from the Roblox menu"
			end
		end
	)
	self.Data = data
	return self
end

function Screens.roll(data, pick, reroll)
	local self = Screens.new("RollScreen")
	self.Data = data
	self.Panel = Panel.new(self.Gui, "Roll", UDim2.fromScale(0.94, 0.87), UDim2.fromScale(0.03, 0.04))
	local side = table.find(data.PlayerIds, Players.LocalPlayer.UserId) or 1
	self.Title = U.text(
		self.Panel,
		"Title",
		"ROUND " .. data.Round .. " • PICK A GLASSY",
		UDim2.fromScale(0.8, 0.1),
		UDim2.fromScale(0.1, 0.03),
		Theme.Fonts.Heading
	)
	local last = data.LastPicks[3 - side]
	self.Opponent = U.text(
		self.Panel,
		"Rival",
		data.Names[3 - side] .. (if last ~= "" then " • Last: " .. Glassies.get(last).Name else ""),
		UDim2.fromScale(0.75, 0.07),
		UDim2.fromScale(0.125, 0.15),
		Theme.Fonts.Caption
	)
	self.Timer = U.text(self.Panel, "Timer", "", UDim2.fromScale(0.2, 0.08), UDim2.fromScale(0.73, 0.87))
	self.Message =
		U.text(self.Panel, "Message", "", UDim2.fromScale(0.5, 0.08), UDim2.fromScale(0.25, 0.78), Theme.Fonts.Caption)
	self.Reroll = Button.new(
		self.Panel,
		"Reroll",
		"REROLL • FREE",
		"Blue",
		UDim2.fromScale(0.35, 0.13),
		UDim2.fromScale(0.325, 0.87)
	)
	self:Connect(self.Reroll, reroll)
	self.Pick = pick
	return self
end

function Screens:Offers(data)
	if self.Cards then
		self.Cards:Destroy()
	end
	self.Portraits = {}
	self.Cards = U.make("Frame", self.Panel, {
		Name = "Cards",
		Size = UDim2.fromScale(0.94, 0.53),
		Position = UDim2.fromScale(0.03, 0.24),
		BackgroundTransparency = 1,
	})
	self.Reroll.Visible = data.CanReroll == true
	self.Message.Text = if data.Picked
		then "LOCKED • " .. string.upper(Glassies.get(data.Picked).Name)
		elseif data.Message == "free_used" then "Free reroll used"
		elseif data.Message == "nothing_new" then "You already rolled your collection"
		else "Tap a glassy to lock your pick"
	for i, id in data.Offers do
		local def = Glassies.get(id)
		local owned = data.Collection[id] or {}
		local card =
			Panel.new(self.Cards, "Card" .. i, UDim2.fromScale(0.305, 1), UDim2.fromScale((i - 1) * 0.347, 0), true)
		card.UIStroke.Color = Theme.Rarity[def.Rarity].Bottom
		local portrait = Portrait.new(card, id, UDim2.fromScale(0.9, 0.54), UDim2.fromScale(0.05, 0))
		table.insert(self.Portraits, portrait)
		U.text(card, "Name", def.Name, UDim2.fromScale(0.94, 0.12), UDim2.fromScale(0.03, 0.53), Theme.Fonts.Heading)
		local kind = U.text(
			card,
			"Type",
			def.Type .. " • " .. def.Rarity .. " • ★" .. (owned.Stars or 0),
			UDim2.fromScale(0.94, 0.08),
			UDim2.fromScale(0.03, 0.66),
			Theme.Fonts.Caption
		)
		kind.TextColor3 = Theme.Types[def.Type]
		U.text(
			card,
			"Passive",
			def.PassiveName or Powers.passive(def.Passive).Name,
			UDim2.fromScale(0.94, 0.09),
			UDim2.fromScale(0.03, 0.77),
			Theme.Fonts.Caption
		)
		U.text(
			card,
			"Power",
			def.SpecialName or Powers.special(def.Special).Name,
			UDim2.fromScale(0.94, 0.09),
			UDim2.fromScale(0.03, 0.88),
			Theme.Fonts.Caption
		)
		local select = U.make("TextButton", card, {
			Name = "Select_" .. id,
			Text = "",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ZIndex = 10,
			Selectable = true,
			Active = not data.Picked,
		})
		self:Connect(select, function()
			if not data.Picked then
				self.Pick(id)
			end
		end)
	end
end

function Screens.results(data, replay, lobby)
	local self = Screens.new("ResultsScreen")
	self.Result = data
	self.Started = os.clock()
	local panel = Panel.new(self.Gui, "Results", UDim2.fromScale(0.8, 0.8), UDim2.fromScale(0.1, 0.06))
	local title = U.text(
		panel,
		"Title",
		if data.Won then "YOU WIN!" else "GOOD CLASH!",
		UDim2.fromScale(0.9, 0.15),
		UDim2.fromScale(0.05, 0.04),
		Theme.Fonts.Heading
	)
	title.UITextSizeConstraint.MaxTextSize = Theme.TextSize.Title
	title.TextColor3 = if data.Won then Theme.Colors.Highlight else Theme.Colors.Text
	local wins = { 0, 0 }
	for _, round in data.History do
		wins[round.Winner] += 1
	end
	U.text(
		panel,
		"Score",
		wins[data.Side] .. " – " .. wins[3 - data.Side],
		UDim2.fromScale(0.8, 0.1),
		UDim2.fromScale(0.1, 0.21),
		Theme.Fonts.Heading
	)
	local history = U.make("Frame", panel, {
		Name = "History",
		Size = UDim2.fromScale(0.8, 0.19),
		Position = UDim2.fromScale(0.1, 0.34),
		BackgroundTransparency = 1,
	})
	for i, round in data.History do
		local p =
			Portrait.new(history, round.Picks[data.Side], UDim2.fromScale(0.16, 1), UDim2.fromScale((i - 1) * 0.2, 0))
		U.make("UIAspectRatioConstraint", p, { AspectRatio = 1 })
		U.text(
			p,
			"Round",
			if round.Winner == data.Side then "WIN" else "LOSS",
			UDim2.fromScale(1, 0.2),
			UDim2.fromScale(0, 0.8),
			Theme.Fonts.Caption
		)
	end
	self.Coins =
		U.text(panel, "Coins", "", UDim2.fromScale(0.42, 0.1), UDim2.fromScale(0.06, 0.56), Theme.Fonts.Heading)
	self.Trophies =
		U.text(panel, "Trophies", "", UDim2.fromScale(0.42, 0.1), UDim2.fromScale(0.52, 0.56), Theme.Fonts.Heading)
	U.text(
		panel,
		"Save",
		if data.Saved then "Rewards added!" else "Practice rewards reset when you leave",
		UDim2.fromScale(0.9, 0.07),
		UDim2.fromScale(0.05, 0.69),
		Theme.Fonts.Caption
	)
	self:Connect(
		Button.new(panel, "PlayAgain", "PLAY AGAIN", "Green", UDim2.fromScale(0.4, 0.16), UDim2.fromScale(0.07, 0.8)),
		replay
	)
	self:Connect(
		Button.new(panel, "Lobby", "LOBBY", "Blue", UDim2.fromScale(0.4, 0.16), UDim2.fromScale(0.53, 0.8)),
		lobby
	)
	return self
end

function Screens:Render(now)
	if self.Gui.Name == "QueuePanel" then
		local remaining = math.max(0, self.Data.Deadline - now)
		self.Timer.Text = "A bot joins in " .. math.ceil(remaining) .. "s"
		self.Fill.Size =
			UDim2.fromScale(1 - remaining / require(RS.Shared.Config.Balance).Match.QueueBotAfterSeconds, 1)
	elseif self.Gui.Name == "RollScreen" then
		self.Timer.Text = tostring(math.max(0, math.ceil(self.Data.Deadline - now))) .. "s"
		for _, viewport in self.Portraits do
			for _, part in viewport.WorldModel:GetChildren() do
				if part:IsA("BasePart") then
					part:PivotTo(CFrame.Angles(0, os.clock() * 0.5, math.rad(-8)))
				end
			end
		end
	elseif self.Result then
		local progress = math.clamp((os.clock() - self.Started) / 0.8, 0, 1)
		self.Coins.Text = "+" .. math.floor(self.Result.Rewards.Coins * progress) .. " COINS"
		self.Trophies.Text = string.format("%+d TROPHIES", self.Result.Rewards.Trophies * progress)
	end
end

function Screens:Destroy()
	for _, connection in self.Connections do
		connection:Disconnect()
	end
	self.Gui:Destroy()
end

return Screens
