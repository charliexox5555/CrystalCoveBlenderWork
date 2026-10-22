local Players = game:GetService("Players")
local SocialService = game:GetService("SocialService")
local RS = game:GetService("ReplicatedStorage")
local Glassies = require(RS.Shared.Config.Glassies)
local Powers = require(RS.Shared.CombatText)
local Theme = require(script.Parent.Parent.Theme)
local U = require(script.Parent.Parent.Components.Util)
local S = require(script.Parent.Parent.Components.StainedGlass)
local Portrait = require(script.Parent.Parent.Components.GlassyPortrait)
local Window = require(script.Parent.Parent.Components.Window)
local Kit = require(script.Parent.Parent.Components.MatchKit)
local GamepadNav = require(script.Parent.Parent.Components.GamepadNav)
local Screens = {}
Screens.__index = Screens

function Screens.new(name)
	local self = setmetatable({ Connections = {}, Portraits = {} }, Screens)
	self.Gui = Kit.gui(name, 15)
	return self
end

function Screens:Connect(button, callback)
	table.insert(self.Connections, button.Activated:Connect(callback))
end

-- Floating queue controls over the arena: no backing frame, the camera sits on the arena middle meanwhile.
function Screens.queue(data, leave)
	local self = Screens.new("QueuePanel")
	local panel = Kit.frame(self.Gui, "Queue", UDim2.fromScale(1, 1))
	self.Panel = panel
	-- The arena board already says "waiting for a challenger"; here only the countdown, the bar and the buttons.
	self.Timer = Kit.label(
		panel,
		"Timer",
		"",
		UDim2.fromScale(0.5, 0.055),
		UDim2.fromScale(0.25, 0.6),
		{ Font = Theme.Fonts.Body, MaxSize = Theme.TextSize.Label }
	)
	local track = Instance.new("ImageLabel")
	track.Name, track.Size, track.Position, track.BackgroundTransparency =
		"Progress", UDim2.fromScale(0.36, 0.032), UDim2.fromScale(0.32, 0.665), 1
	track.Parent = panel
	S.setAsset(track, "bar/stat_track")
	self.Fill = Instance.new("ImageLabel")
	self.Fill.Name, self.Fill.Size, self.Fill.BackgroundTransparency = "Fill", UDim2.fromScale(0, 1), 1
	self.Fill.Parent = track
	S.setAsset(self.Fill, "bar/stat_fill_aqua")
	-- Leave is the big red button; inviting a friend is the quieter blue one.
	self:Connect(
		Kit.gem(panel, "Leave", "LEAVE", "ruby", UDim2.fromScale(0.25, 0.14), UDim2.fromScale(0.38, 0.79)),
		leave
	)
	local invite =
		Kit.gem(panel, "Invite", "INVITE FRIEND", "sapphire", UDim2.fromScale(0.22, 0.11), UDim2.fromScale(0.64, 0.79))
	-- Still a finger-sized target on a phone (it was 30 px tall on a Galaxy A06).
	local ratio = invite:FindFirstChildOfClass("UIAspectRatioConstraint").AspectRatio
	U.make("UISizeConstraint", invite, { MinSize = Vector2.new(math.ceil(40 * ratio), 40) })
	self:Connect(invite, function()
		local ok = pcall(function()
			SocialService:PromptGameInvite(Players.LocalPlayer)
		end)
		if not ok then
			self.Timer.Text = "Invite a friend from the Roblox menu"
		end
	end)
	self.Data = data
	-- Controller: B leaves the queue; nothing is pre-selected so a stray A press never leaves by accident.
	self.Nav = GamepadNav.push(panel, { Close = leave, AutoSelect = false })
	Kit.popIn(panel, true)
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

local function heartRow(parent, name, count, position, right)
	return Kit.hearts(parent, name, count, UDim2.fromScale(0.3, 0.55), position, right)
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
	local banner = Kit.frame(self.Gui, "Banner", UDim2.fromScale(1, 1))
	local label = Kit.label(banner, "Round", title, UDim2.fromScale(0.7, 0.1), UDim2.fromScale(0.15, 0.58), {
		MaxSize = Theme.TextSize.Title,
		Outline = 3,
		Color = if won then Theme.Palette.amberLight else Theme.Colors.Text,
	})
	self.Label = label
	-- Hearts left for each side, with the names above them.
	local summary = Kit.frame(banner, "Hearts", UDim2.fromScale(0.6, 0.12), UDim2.fromScale(0.2, 0.69))
	for column, who in { side, 3 - side } do
		local right = column == 2
		local x = if right then Enum.TextXAlignment.Right else Enum.TextXAlignment.Left
		Kit.label(
			summary,
			"Name" .. column,
			if column == 1 then "YOU" else string.upper(rival),
			UDim2.fromScale(0.4, 0.42),
			UDim2.fromScale(if right then 0.6 else 0, 0),
			{ XAlign = x, Color = Theme.Sides[who], MaxSize = 26 }
		)
		heartRow(summary, "Hearts" .. column, data.Hearts[who], UDim2.fromScale(if right then 0.7 else 0, 0.45), right)
	end
	self.Data, self.Started = data, os.clock()
	self.Scale = U.make("UIScale", banner, { Name = "PopScale" })
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

-- Match results in the same cut-glass pane as the lobby windows.
function Screens.results(data, replay, lobby)
	local self = Screens.new("ResultsScreen")
	self.Result = data
	self.Started = os.clock()
	local panel = Instance.new("ImageLabel")
	panel.Name, panel.AnchorPoint, panel.Position = "Results", Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
	panel.Size, panel.BackgroundTransparency, panel.Parent = UDim2.fromScale(0.8, 0.86), 1, self.Gui
	S.setAsset(panel, "panel/pane_dark")
	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.AspectRatio, ratio.Parent = 1.6, panel
	self.Panel = panel
	-- Same cut-glass window frame as every menu (borrowed from the Inventory template), over the dark pane.
	local template = game.StarterGui:FindFirstChild("CollectionScreen")
	local artwork = template and template:FindFirstChild("Panel") and template.Panel:FindFirstChild("WindowArtwork")
	if artwork then
		local frame = artwork:Clone()
		frame.ZIndex = 0
		frame.Parent = panel
		panel.ImageTransparency = 1
		S.bindSlices(panel)
	end
	Kit.label(
		panel,
		"Title",
		if data.NoContest then "MATCH ENDED" elseif data.Won then "YOU WIN!" else "GOOD CLASH!",
		UDim2.fromScale(0.9, 0.14),
		UDim2.fromScale(0.05, 0.05),
		{ MaxSize = Theme.TextSize.Title, Color = if data.Won then Theme.Palette.amberLight else Theme.Colors.Text }
	)
	local wins = { 0, 0 }
	for _, round in data.History do
		wins[round.Winner] += 1
	end
	Kit.label(
		panel,
		"Score",
		wins[data.Side] .. " – " .. wins[3 - data.Side],
		UDim2.fromScale(0.5, 0.1),
		UDim2.fromScale(0.25, 0.2)
	)
	local history = Kit.frame(panel, "History", UDim2.fromScale(0.92, 0.3), UDim2.fromScale(0.04, 0.31))
	for row, side in { data.Side, 3 - data.Side } do
		Kit.label(
			history,
			"Side" .. row,
			if row == 1 then "YOU" else string.upper(data.Names and data.Names[side] or "RIVAL"),
			UDim2.fromScale(0.12, 0.2),
			UDim2.fromScale(0, (row - 1) * 0.55 + 0.08),
			{ Font = Theme.Fonts.Caption, Color = Theme.Sides[side], MaxSize = 16 }
		)
		for i, round in data.History do
			local p = Portrait.new(
				history,
				round.Picks[side],
				UDim2.fromScale(0.16, 0.36),
				UDim2.fromScale(0.13 + (i - 1) * 0.175, (row - 1) * 0.55),
				"Round" .. row .. "_" .. i
			)
			-- The portrait helper centres its anchor; place from the top-left so rows sit inside the history box.
			p.AnchorPoint = Vector2.zero
			p.Position, p.Size = UDim2.fromScale(0.13 + (i - 1) * 0.175, (row - 1) * 0.55), UDim2.fromScale(0.16, 0.36)
			if row == 1 then
				Kit.label(
					history,
					"Result" .. i,
					if round.Winner == side then "WIN" else "LOSS",
					UDim2.fromScale(0.16, 0.14),
					UDim2.fromScale(0.13 + (i - 1) * 0.175, 0.37),
					{
						Font = Theme.Fonts.Caption,
						Color = if round.Winner == side then Theme.Palette.emeraldLight else Theme.Palette.rubyLight,
						MaxSize = 16,
					}
				)
			end
		end
	end
	-- Rewards: our coin icon beside the coins, trophies on the other side.
	Kit.icon(panel, "CoinIcon", "icon/coin", UDim2.fromScale(0.08, 0.1), UDim2.fromScale(0.06, 0.61)).UIAspectRatioConstraint.DominantAxis =
		Enum.DominantAxis.Height
	self.Coins = Kit.label(
		panel,
		"Coins",
		"",
		UDim2.fromScale(0.34, 0.1),
		UDim2.fromScale(0.15, 0.61),
		{ XAlign = Enum.TextXAlignment.Left, Color = Theme.Palette.amberLight }
	)
	self.Trophies = Kit.label(
		panel,
		"Trophies",
		"",
		UDim2.fromScale(0.4, 0.1),
		UDim2.fromScale(0.54, 0.61),
		{ XAlign = Enum.TextXAlignment.Left }
	)
	local ready = 0
	for _, q in data.Quests or {} do
		if not q.Claimed and q.Progress >= q.Goal then
			ready += 1
		end
	end
	Kit.label(
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
		UDim2.fromScale(0.9, 0.06),
		UDim2.fromScale(0.05, 0.685),
		{ Font = Theme.Fonts.Caption, Color = Theme.Palette.milkDark, MaxSize = 18, Outline = 1.5 }
	)
	local again =
		Kit.gem(panel, "PlayAgain", "PLAY AGAIN", "emerald", UDim2.fromScale(0.4, 0.15), UDim2.fromScale(0.28, 0.83))
	self:Connect(again, replay)
	self:Connect(
		Kit.gem(panel, "Lobby", "LOBBY", "sapphire", UDim2.fromScale(0.4, 0.15), UDim2.fromScale(0.72, 0.83)),
		lobby
	)
	-- Controller: lands on PLAY AGAIN; B goes back to the lobby.
	self.Nav = GamepadNav.push(panel, { First = again, Close = lobby })
	Kit.popIn(panel)
	return self
end

function Screens:Render(now)
	if self.Gui.Name == "QueuePanel" then
		if not self.Data.Deadline then -- Bot Play off (decision 99): no countdown
			self.Timer.Text = "Waiting for a player…"
			self.Fill.Size = UDim2.fromScale(0, 1)
			return
		end
		local remaining = math.max(0, self.Data.Deadline - now)
		self.Timer.Text = "A bot joins in " .. math.ceil(remaining) .. "s"
		self.Fill.Size =
			UDim2.fromScale(1 - remaining / require(RS.Shared.Config.Balance).Match.QueueBotAfterSeconds, 1)
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
	if self.Nav then
		self.Nav.Pop()
	end
	if self.Info then
		self.Info:Destroy()
	end
	for _, connection in self.Connections do
		connection:Disconnect()
	end
	local gui, panel = self.Gui, self.Panel
	if not panel or not gui.Parent or not gui.Enabled then
		gui:Destroy()
		return
	end
	-- Same quick pop-out as the lobby windows; the name is freed for whatever opens next.
	gui.Name = gui.Name .. "_Closing"
	Kit.popOut(panel, function()
		gui:Destroy()
	end)
end

return Screens
