local Theme = require(script.Parent.Parent.Theme)
local U = require(script.Parent.Parent.Components.Util)
local Window = require(script.Parent.Parent.Components.Window)
local Panel = require(script.Parent.Parent.Components.Panel)
local Button = require(script.Parent.Parent.Components.Button)
local Screen = {}
Screen.__index = Screen
local tabs = { "Quests", "Gifts", "Streak", "Codes" }
function Screen.new(profile, close, claim, redeem)
	local self = setmetatable(
		{ Profile = profile, Selected = "Quests", Pages = {}, QuestRows = {}, GiftRows = {}, Days = {} },
		Screen
	)
	self.Window = Window.new("RewardsScreen", "FREE REWARDS", close)
	local parent = self.Window.Content
	for i, name in tabs do
		local button = Button.new(
			parent,
			name .. "Tab",
			name:upper(),
			"Blue",
			UDim2.fromScale(0.235, 0.17),
			UDim2.fromScale((i - 1) * 0.255, 0)
		)
		self.Window:Connect(button, function()
			self:Select(name)
		end)
		self.Pages[name] = U.make(
			"Frame",
			parent,
			{
				Name = name,
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 0.76),
				Position = UDim2.fromScale(0, 0.23),
			}
		)
	end
	for i = 1, 3 do
		local row = Panel.new(
			self.Pages.Quests,
			"Quest" .. i,
			UDim2.fromScale(0.96, 0.3),
			UDim2.fromScale(0.02, (i - 1) * 0.335),
			true
		)
		local name = U.text(row, "Name", "Quest", UDim2.fromScale(0.64, 0.36), UDim2.fromScale(0.03, 0.08))
		local progress = U.text(
			row,
			"Progress",
			"0 / 3 • +75 COINS",
			UDim2.fromScale(0.64, 0.34),
			UDim2.fromScale(0.03, 0.55),
			Theme.Fonts.Caption
		)
		local button =
			Button.new(row, "Claim", "CLAIM", "Green", UDim2.fromScale(0.26, 0.8), UDim2.fromScale(0.71, 0.1))
		self.QuestRows[i] = { Name = name, Progress = progress, Button = button }
		self.Window:Connect(button, function()
			local q = self.Profile.Retention.Quests[i]
			if q and not q.Claimed and q.Progress >= q.Goal then
				claim("Quest", q.Id)
			elseif q and not q.Claimed then
				close()
			end
		end)
	end
	for i = 1, 4 do
		local row = Panel.new(
			self.Pages.Gifts,
			"Gift" .. i,
			UDim2.fromScale(0.47, 0.46),
			UDim2.fromScale(0.01 + ((i - 1) % 2) * 0.51, math.floor((i - 1) / 2) * 0.52),
			true
		)
		local label = U.text(row, "Gift", "5 MIN • 40 COINS", UDim2.fromScale(0.92, 0.4), UDim2.fromScale(0.04, 0.03))
		local button =
			Button.new(row, "Claim", "WAIT", "Green", UDim2.fromScale(0.86, 0.45), UDim2.fromScale(0.07, 0.5))
		self.GiftRows[i] = { Label = label, Button = button }
		self.Window:Connect(button, function()
			local g = self.Profile.Retention.Gifts[i]
			if g and not g.Claimed then
				claim("Gift", g.Id)
			end
		end)
	end
	for i = 1, 7 do
		local size, pos =
			UDim2.fromScale(0.225, 0.4), UDim2.fromScale(((i - 1) % 3) * 0.245, math.floor((i - 1) / 3) * 0.45)
		if i == 7 then
			size, pos = UDim2.fromScale(0.245, 0.85), UDim2.fromScale(0.75, 0)
		end
		local card = Panel.new(self.Pages.Streak, "Day" .. i, size, pos, true)
		U.text(card, "Day", "DAY " .. i, UDim2.fromScale(0.92, 0.32), UDim2.fromScale(0.04, 0.08), Theme.Fonts.Heading)
		self.Days[i] = U.text(
			card,
			"State",
			"CHECK-IN",
			UDim2.fromScale(0.92, 0.36),
			UDim2.fromScale(0.04, 0.48),
			Theme.Fonts.Caption
		)
	end
	self.Streak = U.text(self.Pages.Streak, "StreakCount", "", UDim2.fromScale(1, 0.1), UDim2.fromScale(0, 0.89))
	local codes = self.Pages.Codes
	U.text(
		codes,
		"Help",
		"Codes from game updates go here",
		UDim2.fromScale(0.9, 0.14),
		UDim2.fromScale(0.05, 0.03),
		Theme.Fonts.Caption
	)
	self.Code = U.make("TextBox", codes, {
		Name = "Code",
		Text = "",
		PlaceholderText = "ENTER CODE",
		ClearTextOnFocus = false,
		Size = UDim2.fromScale(0.8, 0.25),
		Position = UDim2.fromScale(0.1, 0.22),
		BackgroundColor3 = Theme.Colors.Inset,
		TextColor3 = Theme.Colors.Text,
		FontFace = Theme.Fonts.Body,
		TextScaled = true,
		Selectable = true,
	})
	U.corner(self.Code, Theme.Radius.Button)
	self.Window:Connect(
		Button.new(codes, "Redeem", "REDEEM", "Green", UDim2.fromScale(0.5, 0.25), UDim2.fromScale(0.25, 0.55)),
		function()
			redeem(self.Code.Text)
		end
	)
	table.insert(
		self.Window.Connections,
		self.Code.FocusLost:Connect(function(enter)
			if enter then
				redeem(self.Code.Text)
			end
		end)
	)
	self.Message =
		U.text(parent, "Message", "", UDim2.fromScale(1, 0.08), UDim2.fromScale(0, 0.18), Theme.Fonts.Caption)
	self:Select("Quests")
	self:Refresh(profile)
	return self
end
function Screen:Select(tab)
	self.Selected = tab
	for name, page in self.Pages do
		page.Visible = name == tab
	end
end
function Screen:Refresh(profile)
	self.Profile = profile
	local r = profile and profile.Retention
	if not r then
		return
	end
	for i, row in self.QuestRows do
		local q = r.Quests[i]
		row.Name.Text = q.Name
		row.Progress.Text = q.Progress .. " / " .. q.Goal .. " • +" .. q.Coins .. " COINS"
		row.Button.Text = if q.Claimed then "DONE" elseif q.Progress >= q.Goal then "CLAIM" else "PLAY"
		row.Button.Active = not q.Claimed
	end
	local cycle = (r.Streak - 1) % 7 + 1
	for i, label in self.Days do
		label.Text = if i <= cycle then "CHECKED IN" else "NEXT"
		label.TextColor3 = if i <= cycle then Theme.Colors.Highlight else Theme.Colors.TextMuted
	end
	self.Streak.Text = "CHECK-IN STREAK: " .. r.Streak .. " DAYS"
	self:Step(0)
end
function Screen:Step()
	local r = self.Profile and self.Profile.Retention
	if not r then
		return
	end
	local elapsed = math.max(0, workspace:GetServerTimeNow() - (self.Profile.ServerNow or workspace:GetServerTimeNow()))
	for i, row in self.GiftRows do
		local g = r.Gifts[i]
		local left = math.max(0, math.ceil(g.Seconds - r.PlaytimeSeconds - elapsed))
		row.Label.Text = (g.Seconds / 60) .. " MIN • " .. g.Coins .. " COINS"
		row.Button.Text = if g.Claimed
			then "CLAIMED"
			elseif left == 0 then "CLAIM"
			else string.format("%d:%02d", math.floor(left / 60), left % 60)
		row.Button.Active = not g.Claimed and left == 0
	end
end
function Screen:Result(data)
	self.Message.Text = data.Message
end
function Screen:Destroy()
	self.Window:Destroy()
end
return Screen
