-- How a reward bundle looks in a reward cell (decisions 99, 115): its picture and a short amount line.
-- Bundles: { Coins?, Marbles?, Xp?, Pull?, Pulls?, Item? } (server RewardGrant). Shared by Daily and Playtime screens.
-- Coins show as a pile that grows with the amount (CoinPile, built from the coin art in the cell's Icon slot); a free
-- pull shows the real Kiln / crate machine (PullPortrait); a glassy shows its item picture (ItemPortrait); XP shows the
-- XP star. The cell's authored Icon stays the "state" source: screens dim or grey the Icon, and sync() copies that
-- look onto the pile or portrait.
local UIAssets = require(game.ReplicatedStorage.Shared.Config.UIAssets)
local Item = require(script.Parent.Parent.Components.ItemPresentation)
local Glassies = require(game.ReplicatedStorage.Shared.Config.Glassies)
local Visuals = {}

local PULL_ICON =
	{ Glassies = "reward/kiln_pull", Finishers = "reward/finisher_crate", Rideables = "reward/flyer_crate" }
local PULL_TEXT = { Glassies = "KILN PULL", Finishers = "FINISHER CRATE", Rideables = "FLYER CRATE" }

-- Coin pile layouts: centre x, centre y (fractions of the Icon slot) and tilt, back to front.
local PILES = {
	{ { 0.5, 0.5, 0 } },
	{ { 0.38, 0.58, -8 }, { 0.62, 0.44, 8 } },
	{ { 0.32, 0.62, -10 }, { 0.68, 0.62, 10 }, { 0.5, 0.4, 0 } },
	{ { 0.3, 0.66, -10 }, { 0.7, 0.66, 8 }, { 0.42, 0.44, -4 }, { 0.6, 0.36, 10 } },
	{ { 0.26, 0.68, -12 }, { 0.5, 0.7, 0 }, { 0.74, 0.68, 12 }, { 0.38, 0.46, -6 }, { 0.62, 0.44, 6 } },
	{
		{ 0.26, 0.7, -12 },
		{ 0.5, 0.72, 0 },
		{ 0.74, 0.7, 12 },
		{ 0.38, 0.48, -6 },
		{ 0.62, 0.46, 6 },
		{ 0.5, 0.26, 0 },
	},
}
local PILE_STEPS = { 35, 60, 90, 130, 180 } -- up to this many coins -> 1, 2, 3, 4, 5 coins; above -> 6

function Visuals.pileSize(coins)
	for i, limit in PILE_STEPS do
		if coins <= limit then
			return i
		end
	end
	return #PILES
end

function Visuals.icon(reward)
	if reward.Pull then
		return UIAssets[PULL_ICON[reward.Pull]]
	elseif reward.Marbles and not reward.Coins then
		return UIAssets["icon/marble"]
	elseif reward.Xp and not reward.Coins then
		return UIAssets["icon/xp"]
	end
	return UIAssets["icon/coin"]
end

function Visuals.amount(reward)
	if reward.Item then
		local def = reward.Item.Category == "Glassies" and Glassies.ById[reward.Item.Id]
		local name = if def then string.upper(def.Name) else "ITEM"
		return if reward.Coins then name .. " +" .. reward.Coins else name
	elseif reward.Xp and not reward.Coins then
		return "+" .. reward.Xp .. " XP"
	elseif reward.Pull then
		local text = "FREE " .. PULL_TEXT[reward.Pull]
		return if reward.Coins then text .. " +" .. reward.Coins else text
	elseif reward.Coins then
		return "x" .. reward.Coins
	elseif reward.Marbles then
		return "x" .. reward.Marbles
	end
	return ""
end

local function overlay(cell, icon, name, class)
	local object = cell:FindFirstChild(name)
	if not object then
		object = Instance.new(class)
		object.Name, object.BackgroundTransparency = name, 1
		object.Parent = cell
	end
	object.AnchorPoint, object.Position, object.Size = icon.AnchorPoint, icon.Position, icon.Size
	object.ZIndex = icon.ZIndex
	return object
end

local function pile(cell, icon, coins)
	local frame = overlay(cell, icon, "CoinPile", "Frame")
	local layout = PILES[Visuals.pileSize(coins)]
	if frame:GetAttribute("Count") ~= #layout then
		frame:ClearAllChildren()
		local size = 0.8 - #layout * 0.04
		for i, spot in layout do
			local coin = Instance.new("ImageLabel")
			coin.Name, coin.BackgroundTransparency, coin.Image = "Coin" .. i, 1, UIAssets["icon/coin"]
			coin.AnchorPoint, coin.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(spot[1], spot[2])
			coin.Size, coin.Rotation = UDim2.fromScale(size, size), spot[3]
			coin.SizeConstraint = Enum.SizeConstraint.RelativeYY
			coin.ScaleType, coin.ZIndex = Enum.ScaleType.Fit, icon.ZIndex + i
			coin.Parent = frame
		end
		frame:SetAttribute("Count", #layout)
	end
	return frame
end

local function portrait(cell, icon, category)
	local existing = cell:FindFirstChild("PullPortrait")
	if existing and existing:GetAttribute("Category") ~= category then
		existing:Destroy()
		existing = nil
	end
	if not existing then
		-- The Coin Kiln for glassy pulls; the Burst Dome / Cloud Globe machines for cosmetic crates.
		existing = Item.crate(cell, category, "Coins", icon.Size, icon.Position, "PullPortrait")
		existing:SetAttribute("Category", category)
	end
	existing.AnchorPoint, existing.ZIndex = icon.AnchorPoint, icon.ZIndex
	return existing
end

function Visuals.apply(cell, reward)
	local icon, amount = cell:FindFirstChild("Icon"), cell:FindFirstChild("Amount")
	if amount then
		amount.Text = Visuals.amount(reward)
	end
	if not icon then
		return
	end
	icon.Image = Visuals.icon(reward)
	local pileFrame, view = cell:FindFirstChild("CoinPile"), cell:FindFirstChild("PullPortrait")
	local itemView = cell:FindFirstChild("ItemPortrait")
	local mode = if reward.Item
		then "Item"
		elseif reward.Pull then "Pull"
		elseif reward.Coins and not reward.Marbles then "Coins"
		else "Icon"
	if mode == "Item" then
		local id = reward.Item.Id
		if not itemView or itemView:GetAttribute("ItemId") ~= id then
			if itemView then
				itemView:Destroy()
			end
			local ok, made =
				pcall(Item.portrait, cell, reward.Item.Category, id, icon.Size, icon.Position, "ItemPortrait")
			itemView = if ok then made else nil
			if itemView then
				itemView:SetAttribute("ItemId", id)
			else
				mode = "Icon"
			end
		end
		if itemView then
			itemView.AnchorPoint, itemView.ZIndex = icon.AnchorPoint, icon.ZIndex + 1
		end
	elseif mode == "Pull" then
		local ok, made = pcall(portrait, cell, icon, reward.Pull)
		view = if ok then made else nil
		if not ok then
			mode = "Icon" -- no model available (e.g. a place without the machines): keep the flat icon
		end
	elseif mode == "Coins" then
		pileFrame = pile(cell, icon, reward.Coins)
	end
	-- The Icon keeps its state styling but is invisible when a pile or portrait stands in for it.
	icon:SetAttribute("Mode", mode)
	if pileFrame then
		pileFrame.Visible = mode == "Coins"
	end
	if view then
		view.Visible = mode == "Pull"
	end
	if itemView then
		itemView.Visible = mode == "Item"
	end
end

-- Copy the Icon's state look (claimed fade, locked grey) onto the pile or portrait. Call after a screen styles
-- the cell's Icon for its state.
function Visuals.sync(cell)
	local icon = cell:FindFirstChild("Icon")
	if not icon then
		return
	end
	local mode = icon:GetAttribute("Mode") or "Icon"
	local color, transparency = icon.ImageColor3, icon.ImageTransparency
	if mode == "Icon" then
		return
	end
	-- Keep the Icon's state values for the next render; just hide its picture.
	icon.ImageTransparency = 1
	icon:SetAttribute("StateTransparency", transparency)
	local pileFrame = cell:FindFirstChild("CoinPile")
	if mode == "Coins" and pileFrame then
		for _, coin in pileFrame:GetChildren() do
			coin.ImageColor3, coin.ImageTransparency = color, transparency
		end
	end
	local view = cell:FindFirstChild(if mode == "Item" then "ItemPortrait" else "PullPortrait")
	if (mode == "Pull" or mode == "Item") and view then
		view.ImageColor3, view.ImageTransparency = color, transparency
	end
end

-- "hh:mm:ss" for long waits, "m:ss" for short ones.
function Visuals.clock(seconds)
	seconds = math.max(0, math.floor(seconds))
	local h, m, s = seconds // 3600, (seconds // 60) % 60, seconds % 60
	return if h > 0 then string.format("%d:%02d:%02d", h, m, s) else string.format("%d:%02d", m, s)
end

return Visuals
