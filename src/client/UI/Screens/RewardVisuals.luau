-- How a reward bundle looks in a reward cell (decision 99): its icon and a short amount line.
-- Bundles: { Coins?, Marbles?, Pull?, Pulls?, Item? } (server RewardGrant). Shared by Daily and Playtime screens.
local UIAssets = require(game.ReplicatedStorage.Shared.Config.UIAssets)
local Visuals = {}

local PULL_ICON =
	{ Glassies = "reward/kiln_pull", Finishers = "reward/finisher_crate", Rideables = "reward/flyer_crate" }
local PULL_TEXT = { Glassies = "KILN PULL", Finishers = "FINISHER CRATE", Rideables = "FLYER CRATE" }

function Visuals.icon(reward)
	if reward.Pull then
		return UIAssets[PULL_ICON[reward.Pull]]
	elseif reward.Marbles and not reward.Coins then
		return UIAssets["icon/marble"]
	end
	return UIAssets["icon/coin"]
end

function Visuals.amount(reward)
	if reward.Pull then
		local text = "FREE " .. PULL_TEXT[reward.Pull]
		return if reward.Coins then text .. " +" .. reward.Coins else text
	elseif reward.Coins then
		return "x" .. reward.Coins
	elseif reward.Marbles then
		return "x" .. reward.Marbles
	end
	return ""
end

function Visuals.apply(cell, reward)
	local icon, amount = cell:FindFirstChild("Icon"), cell:FindFirstChild("Amount")
	if icon then
		icon.Image = Visuals.icon(reward)
	end
	if amount then
		amount.Text = Visuals.amount(reward)
	end
end

-- "hh:mm:ss" for long waits, "m:ss" for short ones.
function Visuals.clock(seconds)
	seconds = math.max(0, math.floor(seconds))
	local h, m, s = seconds // 3600, (seconds // 60) % 60, seconds % 60
	return if h > 0 then string.format("%d:%02d:%02d", h, m, s) else string.format("%d:%02d", m, s)
end

return Visuals
