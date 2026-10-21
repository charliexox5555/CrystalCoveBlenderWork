-- Drives StarterGui.PlaytimeRewardsScreen (design: docs/ui/screens/PlaytimeRewardsScreen.md; rules: decisions 99, 115).
-- Render(gifts, seconds): gifts from RetentionRules.view ({ Id, Seconds, Reward, Claimed }), seconds = today's play
-- time (server value plus local ticking). Time maps to the bar piecewise, so each gem sits over its cell.
-- Gifts collect themselves when their time is reached (decision 115), so a reached gift shows as collected at once
-- (the server grant and its toast follow within a second); there is no CLAIM step.
local UIAssets = require(game.ReplicatedStorage.Shared.Config.UIAssets)
local Visuals = require(script.Parent.RewardVisuals)
local Screen = {}
Screen.__index = Screen

local A = function(key)
	return UIAssets["screens/playtime_rewards/" .. key]
end
local ART = { Claimed = A("cell_open"), Ready = A("cell_ready"), Next = A("cell_open"), Locked = A("cell_locked") }
local SLATE, WHITE = Color3.fromHex("#B7B3CC"), Color3.new(1, 1, 1)
local LOCKED_ICON = Color3.fromHex("#8C88A3")
-- Same geometry as tools/studio/build_playtime_rewards_screen.luau (panel fractions).
local ROW_X, ROW_W, BAR_X0 = 0.05, 0.92, 0.058

function Screen.bind(gui, onClaim)
	local panel = gui:FindFirstChild("Panel")
	local self = setmetatable({
		Gui = gui,
		Rewards = panel and panel:FindFirstChild("Rewards"),
		Progress = panel and panel:FindFirstChild("Progress"),
		Note = panel and panel:FindFirstChild("Note"),
		Bound = {},
	}, Screen)
	if self.Note then
		self.Note.Text = "Play time adds up all day and resets at midnight UTC."
	end
	self.OnClaim = onClaim
	return self
end

function Screen:CellFor(gift)
	return self.Rewards and self.Rewards:FindFirstChild("R" .. gift.Seconds // 60)
end

function Screen:Bind(cell, index)
	if self.Bound[cell] then
		return
	end
	self.Bound[cell] = true
	local button = cell:FindFirstChild("ClaimButton")
	if button and button:IsA("GuiButton") then
		button.Activated:Connect(function()
			if cell:GetAttribute("State") == "Ready" then
				self.OnClaim(index, cell)
			end
		end)
	end
end

local function visible(cell, name, on)
	local child = cell:FindFirstChild(name)
	if child and child:IsA("GuiObject") then
		child.Visible = on
	end
end

function Screen:Render(gifts, seconds)
	local nextIndex = nil
	for i, gift in gifts do
		if not gift.Claimed and seconds < gift.Seconds then
			nextIndex = i
			break
		end
	end
	for i, gift in gifts do
		local cell = self:CellFor(gift)
		if not cell then
			continue
		end
		self:Bind(cell, gift.Id)
		local state = if gift.Claimed or seconds >= gift.Seconds
			then "Claimed"
			elseif i == nextIndex then "Next"
			else "Locked"
		cell:SetAttribute("State", state)
		Visuals.apply(cell, gift.Reward)
		local art = cell:FindFirstChild("Artwork")
		if art and not cell:GetAttribute("Best") then
			art.Image = ART[state]
		end
		visible(cell, "Glow", state == "Ready")
		visible(cell, "ClaimButton", state == "Ready")
		visible(cell, "Outline", state == "Next")
		visible(cell, "CountdownTag", state == "Next")
		visible(cell, "Countdown", state == "Next")
		visible(cell, "Dim", state == "Claimed")
		visible(cell, "ClaimedMark", state == "Claimed")
		visible(cell, "Status", state == "Claimed")
		visible(cell, "LockIcon", state == "Locked")
		local countdown = cell:FindFirstChild("Countdown")
		if countdown and state == "Next" then
			countdown.Text = Visuals.clock(gift.Seconds - seconds)
		end
		local locked = state == "Locked"
		local icon, amount, plaque =
			cell:FindFirstChild("Icon"), cell:FindFirstChild("Amount"), cell:FindFirstChild("TimePlaque")
		if icon then
			icon.ImageColor3 = if locked then LOCKED_ICON else WHITE
			icon.ImageTransparency = if locked then 0.15 else 0
		end
		if amount then
			amount.TextColor3 = if locked then SLATE else WHITE
		end
		if plaque then
			plaque.ImageColor3 = if locked then SLATE else WHITE
		end
		Visuals.sync(cell)
	end
	self:RenderBar(gifts, seconds)
end

-- Panel x of a play time: piecewise between cell centres, from the bar start (0 min) to the last cell's centre.
function Screen:TimeToX(gifts, seconds)
	local count = #gifts
	local prevSeconds, prevX = 0, BAR_X0
	for i, gift in gifts do
		local x = ROW_X + ROW_W * (i - 0.5) / count
		if seconds <= gift.Seconds then
			return prevX + (x - prevX) * (seconds - prevSeconds) / math.max(1, gift.Seconds - prevSeconds)
		end
		prevSeconds, prevX = gift.Seconds, x
	end
	return prevX
end

function Screen:RenderBar(gifts, seconds)
	local progress = self.Progress
	local track = progress and progress:FindFirstChild("Track")
	if not track then
		return
	end
	local x0, x1 = track.Position.X.Scale, track.Position.X.Scale + track.Size.X.Scale
	local last = gifts[#gifts]
	local x = if last and seconds >= last.Seconds then x1 else self:TimeToX(gifts, seconds)
	local fill = track:FindFirstChild("Fill")
	if fill then
		fill.Size = UDim2.fromScale(math.clamp((x - x0) / math.max(1e-3, x1 - x0), 0, 1), fill.Size.Y.Scale)
		fill.Visible = seconds > 0
	end
	progress:SetAttribute("PlayedMinutes", seconds // 60)
	local tag = progress:FindFirstChild("Time")
	if tag then
		tag.Position = UDim2.new(x, 0, tag.Position.Y.Scale, tag.Position.Y.Offset)
		local label = tag:FindFirstChild("Label")
		if label then
			label.Text = (seconds // 60) .. " MIN"
		end
	end
	local markers = progress:FindFirstChild("Markers")
	for _, gift in gifts do
		local marker = markers and markers:FindFirstChild("M" .. gift.Seconds // 60)
		if marker then
			local reached = seconds >= gift.Seconds
			marker:SetAttribute("Reached", reached)
			local best = marker.Name == "M" .. last.Seconds // 60
			local gem = marker:FindFirstChild("Gem")
			if gem then
				gem.Image = A(
					if best
						then (if reached then "gem_best_on" else "gem_best_off")
						else (if reached then "gem_on" else "gem_off")
				)
			end
			visible(marker, "Glow", reached)
			local label = marker:FindFirstChild("Label")
			if label then
				label.TextColor3 = if reached then WHITE else SLATE
			end
		end
	end
end

return Screen
