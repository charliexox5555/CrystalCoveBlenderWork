local Players = game:GetService("Players")
local SocialService = game:GetService("SocialService")
local RS = game:GetService("ReplicatedStorage")
local Glassies = require(RS.Shared.Config.Glassies)
local Powers = require(RS.Shared.CombatText)
local Theme = require(script.Parent.Parent.Theme)
local U = require(script.Parent.Parent.Components.Util)
local Panel = require(script.Parent.Parent.Components.Panel)
local Button = require(script.Parent.Parent.Components.Button)
local Portrait = require(script.Parent.Parent.Components.GlassyPortrait)
local Window = require(script.Parent.Parent.Components.Window)
local Screens = {}
Screens.__index = Screens

function Screens.new(name)
	local self = setmetatable({ Connections = {}, Portraits = {} }, Screens)
	self.Gui = U.screen(name, 15)
	return self
end

function Screens:Connect(button, callback, compact)
	U.make("UISizeConstraint", button, {
		MinSize = Vector2.new(if compact then 44 else 70, 44),
		MaxSize = if compact then Vector2.new(56, 56) else Vector2.new(math.huge, math.huge),
	})
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
		{ Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = Theme.Colors.EdgeA, BorderSizePixel = 0 }
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

function Screens.roll(data, pick, reroll, pickAny)
	return require(script.Parent.MatchSelection).new(data, pick, reroll, pickAny)
end

function Screens:PowerInfo(id)
	if self.Info then
		self.Info:Destroy()
	end
	local def = Glassies.get(id)
	self.Info = Window.new("RollInfoScreen", def.Name, function()
		self.Info:Destroy()
		self.Info = nil
	end)
	local passive, power = Powers.passive(def), Powers.special(def)
	local copy = U.text(
		self.Info.Content,
		"Description",
		passive.Name .. ": " .. passive.Description .. "\n\n" .. power.Name .. ": " .. power.Description,
		UDim2.fromScale(0.94, 0.9),
		UDim2.fromScale(0.03, 0.03),
		Theme.Fonts.Body
	)
	copy.TextWrapped, copy.TextXAlignment = true, Enum.TextXAlignment.Left
end

local function hearts(count)
	local total = require(RS.Shared.Config.Balance).Match.Hearts
	count = math.clamp(count or 0, 0, total)
	return string.rep("♥", count) .. string.rep("♡", total - count)
end

-- Round result banner. Hidden until the fight view has actually played the shatter.
function Screens.roundEnd(data, side)
	local self = Screens.new("RoundEnd")
	self.Gui.Enabled = false
	local rival = data.Names and data.Names[3 - side] or "RIVAL"
	local won = data.RoundWinner == side
	local matchOver = (data.Hearts[1] or 1) <= 0 or (data.Hearts[2] or 1) <= 0
	local title = if won
		then (if matchOver then "YOU WIN THE MATCH!" else "YOU WIN ROUND " .. data.Round .. "!")
		else string.upper(rival) .. (if matchOver then " WINS THE MATCH" else " WINS ROUND " .. data.Round)
	local label =
		U.text(self.Gui, "Round", title, UDim2.fromScale(0.7, 0.1), UDim2.fromScale(0.15, 0.58), Theme.Fonts.Heading)
	label.UITextSizeConstraint.MaxTextSize = Theme.TextSize.Title
	label.TextColor3 = if won then Theme.Colors.Highlight else Theme.Colors.Text
	U.make("UIStroke", label, { Thickness = 2, Color = Theme.Colors.Shadow, Transparency = 0.2 })
	local summary = U.text(
		self.Gui,
		"Hearts",
		"YOU " .. hearts(data.Hearts[side]) .. "     " .. string.upper(rival) .. " " .. hearts(data.Hearts[3 - side]),
		UDim2.fromScale(0.6, 0.06),
		UDim2.fromScale(0.2, 0.69),
		Theme.Fonts.Body
	)
	summary.TextColor3 = Theme.Colors.Heart
	U.make("UIStroke", summary, { Thickness = 1.5, Color = Theme.Colors.Shadow, Transparency = 0.2 })
	self.Data, self.Started = data, os.clock()
	self.Scale = U.make("UIScale", label, { Name = "PopScale" })
	return self
end

function Screens:Reveal()
	if self.Gui.Enabled then
		return
	end
	self.Gui.Enabled = true
	if self.Scale then
		self.Scale.Scale = 1.35
		game:GetService("TweenService")
			:Create(self.Scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
			:Play()
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
		if data.NoContest then "MATCH ENDED" elseif data.Won then "YOU WIN!" else "GOOD CLASH!",
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
		Size = UDim2.fromScale(0.92, 0.28),
		Position = UDim2.fromScale(0.04, 0.31),
		BackgroundTransparency = 1,
	})
	for _, child in history:GetChildren() do
		if child.Name:match("^Round%d+_") then
			child:Destroy()
		end
	end
	for row, side in { data.Side, 3 - data.Side } do
		U.text(
			history,
			"Side" .. row,
			if row == 1 then "YOU" else string.upper(data.Names and data.Names[side] or "RIVAL"),
			UDim2.fromScale(0.12, 0.4),
			UDim2.fromScale(0, (row - 1) * 0.5),
			Theme.Fonts.Caption
		)
		for i, round in data.History do
			local name = "Round" .. row .. "_" .. i
			U.prototype(history, "RoundPortrait", name)
			local p = Portrait.new(
				history,
				round.Picks[side],
				UDim2.fromScale(0.16, 0.5),
				UDim2.fromScale(0.13 + (i - 1) * 0.175, (row - 1) * 0.5),
				name
			)
			p.Position, p.Size = UDim2.fromScale(0.13 + (i - 1) * 0.175, (row - 1) * 0.5), UDim2.fromScale(0.16, 0.5)
			if row == 1 then
				local resultLabel = U.text(
					p,
					"Round",
					if round.Winner == side then "WIN" else "LOSS",
					UDim2.fromScale(1, 0.28),
					UDim2.fromScale(0, 0.72),
					Theme.Fonts.Caption
				)
				resultLabel.Visible = true
			elseif p:FindFirstChild("Round") then
				p.Round.Visible = false
			end
		end
	end
	self.Coins = U.text(panel, "Coins", "", UDim2.fromScale(0.42, 0.1), UDim2.fromScale(0.06, 0.6), Theme.Fonts.Heading)
	self.Trophies =
		U.text(panel, "Trophies", "", UDim2.fromScale(0.42, 0.1), UDim2.fromScale(0.52, 0.6), Theme.Fonts.Heading)
	local ready = 0
	for _, q in data.Quests or {} do
		if not q.Claimed and q.Progress >= q.Goal then
			ready += 1
		end
	end
	U.text(
		panel,
		"Save",
		(
			if data.NoContest
				then "No rewards — finish a round first"
				elseif data.Saved then "Rewards added!"
				else "Practice rewards reset when you leave"
		)
			.. (
				if ready > 0
					then " • " .. ready .. (if ready == 1 then " quest" else " quests") .. " ready to claim"
					else ""
			),
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
		self.Title.Text = "CHOOSE YOUR GLASSY · " .. tostring(math.max(0, math.ceil(self.Data.Deadline - now)))
		-- Upright, centered portraits match Inventory and Shop.
	elseif self.Gui.Name == "RoundEnd" then
		local fallback = require(RS.Shared.Config.Balance).Feel.RoundBannerFallbackSeconds
		if not self.Gui.Enabled and os.clock() - self.Started > fallback then
			self:Reveal()
		end
	elseif self.Result then
		local progress = math.clamp((os.clock() - self.Started) / 0.8, 0, 1)
		self.Coins.Text = "+" .. math.floor(self.Result.Rewards.Coins * progress) .. " COINS"
		self.Trophies.Text = string.format("%+d TROPHIES", self.Result.Rewards.Trophies * progress)
	end
end

function Screens:Destroy()
	for _, c in self.CardConnections or {} do
		c:Disconnect()
	end
	if self.CardsTemplate then
		self.CardsTemplate:Destroy()
	end
	if self.Info then
		self.Info:Destroy()
	end
	for _, connection in self.Connections do
		connection:Disconnect()
	end
	self.Gui:Destroy()
end

return Screens
