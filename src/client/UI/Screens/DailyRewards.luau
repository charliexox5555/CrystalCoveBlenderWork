-- Drives StarterGui.DailyRewardsScreen (design: docs/ui/screens/DailyRewardsScreen.md; rules: decision 99).
-- Render(view, now) takes RetentionRules.calendar's view: { Count, Next, ClaimedToday, ResetAt, Rewards }.
local UIAssets = require(game.ReplicatedStorage.Shared.Config.UIAssets)
local Visuals = require(script.Parent.RewardVisuals)
local Screen = {}
Screen.__index = Screen

local A = function(key)
	return UIAssets["screens/daily_rewards/" .. key]
end
local CELL = { Claimed = A("cell_claimed"), Today = A("cell_today"), Locked = A("cell_locked") }
local TAG =
	{ Claimed = UIAssets["tag/tag_emerald"], Today = UIAssets["tag/tag_amber"], Locked = UIAssets["tag/tag_slate"] }
local CLAIMED_TEXT, LOCKED_TEXT = Color3.fromHex("#86EDB8"), Color3.fromHex("#B7B3CC")

function Screen.bind(gui, onClaim)
	local panel = gui:FindFirstChild("Panel")
	local self = setmetatable({
		Gui = gui,
		Days = panel and panel:FindFirstChild("Days"),
		Progress = panel and panel:FindFirstChild("Progress"),
		Timer = panel and panel:FindFirstChild("Timer"),
	}, Screen)
	for i = 1, 7 do
		local cell = self.Days and self.Days:FindFirstChild("Day" .. i)
		local button = cell and cell:FindFirstChild("ClaimButton")
		if button and button:IsA("GuiButton") then
			button.Activated:Connect(function()
				if cell:GetAttribute("State") == "Today" then
					onClaim(cell)
				end
			end)
		end
	end
	return self
end

local function show(cell, name, visible)
	local child = cell:FindFirstChild(name)
	if child and child:IsA("GuiObject") then
		child.Visible = visible
	elseif child then -- a Folder of pieces (Day 7 sparkles)
		for _, piece in child:GetChildren() do
			if piece:IsA("GuiObject") then
				piece.Visible = visible
			end
		end
	end
end

local function setFaded(cell, faded)
	local icon, amount = cell:FindFirstChild("Icon"), cell:FindFirstChild("Amount")
	if icon then
		icon.ImageTransparency = if faded then 0.45 else 0
	end
	if amount then
		amount.TextTransparency = if faded then 0.45 else 0
		local stroke = amount:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Transparency = if faded then 0.45 else 0
		end
	end
end

function Screen:Cell(i, state, reward, status)
	local cell = self.Days and self.Days:FindFirstChild("Day" .. i)
	if not cell then
		return
	end
	cell:SetAttribute("State", state)
	Visuals.apply(cell, reward)
	local art = cell:FindFirstChild("Art")
	if i == 7 then
		if art then
			art.ImageColor3 = if state == "Claimed" then Color3.fromRGB(150, 150, 165) else Color3.new(1, 1, 1)
		end
		local glow = cell:FindFirstChild("IconGlow")
		if glow then
			glow.ImageTransparency = if state == "Claimed" then 0.7 else 0
		end
		show(cell, "Sparkles", state ~= "Claimed")
	else
		if art then
			art.Image = CELL[state]
		end
		local tag = cell:FindFirstChild("LabelTag")
		if tag then
			tag.Image = TAG[state]
		end
	end
	show(cell, "Glow", state == "Today")
	show(cell, "ClaimedMark", state == "Claimed")
	show(cell, "ClaimButton", state == "Today")
	setFaded(cell, state == "Claimed")
	local label = cell:FindFirstChild("Status")
	if label then
		label.Text = status or ""
		label.Visible = status ~= nil and state ~= "Today"
		label.TextColor3 = if state == "Claimed" then CLAIMED_TEXT else LOCKED_TEXT
	end
	Visuals.sync(cell)
end

function Screen:Render(view, now)
	local count, rewards = view.Count, view.Rewards
	-- The day the player can claim next: today's if unclaimed, otherwise tomorrow's (a new week after Day 7).
	local upcoming = if view.ClaimedToday then (if count >= #rewards then nil else count + 1) else view.Next
	for i = 1, #rewards do
		local state = if i <= count then "Claimed" elseif i == view.Next then "Today" else "Locked"
		local status = nil
		if state == "Claimed" then
			status = "CLAIMED"
		elseif view.ClaimedToday and i == upcoming then
			status = "TOMORROW"
		elseif i == #rewards and upcoming then
			local days = #rewards - upcoming + (if view.ClaimedToday then 1 else 0)
			status = if days > 0 then days .. (if days == 1 then " DAY TO GO" else " DAYS TO GO") else nil
		end
		self:Cell(i, state, rewards[i], status)
	end
	local progress = self.Progress
	if progress then
		progress:SetAttribute("Claimed", count)
		local segments = progress:FindFirstChild("Segments")
		for i = 1, #rewards do
			local seg = segments and segments:FindFirstChild("Seg" .. i)
			if seg then
				seg.Image = if i <= count then A("seg_lit") else A("seg_off")
			end
		end
		local gem = progress:FindFirstChild("Gem")
		if gem then
			gem.Image = if count >= #rewards then A("gem_lit") else A("gem_off")
			gem:SetAttribute("Lit", count >= #rewards)
		end
		local label = progress:FindFirstChild("Count")
		if label then
			label.Text = count .. "/" .. #rewards
		end
	end
	local timer = self.Timer and self.Timer:FindFirstChild("Text")
	if timer then
		timer.Text = if view.ClaimedToday
			then "Next reward in " .. Visuals.clock(view.ResetAt - now)
			else "Today's reward is ready!"
	end
end

return Screen
