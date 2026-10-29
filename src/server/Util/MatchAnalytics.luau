-- Server-owned, versioned match funnel. A forfeit never fills the natural-completion step.
local Analytics = game:GetService("AnalyticsService")
local RunService = game:GetService("RunService")
local Keys = Enum.AnalyticsCustomFieldKeys
local Metrics = {}
local STEPS = { "Match started", "First fight started", "First shatter resolved", "Match completed" }

local function fields(entry, player, side, outcome)
	return {
		[Keys.CustomField01.Name] = if entry.Tutorial
			then "IntroBot"
			elseif entry.Players[3 - side] then "PvP"
			else "Bot",
		[Keys.CustomField02.Name] = if entry.FirstMatch[player] then "First" else "Returning",
		[Keys.CustomField03.Name] = outcome or "ClassicV1",
	}
end

function Metrics.step(entry, step)
	entry.AnalyticsProgress = entry.AnalyticsProgress or {}
	for side, player in entry.Players do
		local previous = entry.AnalyticsProgress[player] or 0
		-- Never let Roblox backfill a skipped completion, and never log a round twice.
		if step ~= previous + 1 or not player.Parent then
			continue
		end
		entry.AnalyticsProgress[player] = step
		if RunService:IsStudio() then
			print(string.format("[ClassicMatchV1] %s %d %s", player.Name, step, STEPS[step]))
		else
			pcall(function()
				Analytics:LogFunnelStepEvent(
					player,
					"ClassicMatchV1",
					entry.Id,
					step,
					STEPS[step],
					fields(entry, player, side)
				)
			end)
		end
	end
end

function Metrics.ended(entry, player, side, outcome)
	entry.AnalyticsEnded = entry.AnalyticsEnded or {}
	if entry.AnalyticsEnded[player] then
		return
	end
	entry.AnalyticsEnded[player] = true
	local duration = math.max(0, workspace:GetServerTimeNow() - entry.StartedAt)
	if RunService:IsStudio() then
		print(string.format("[ClassicMatchDurationV1] %s %s %.1fs", player.Name, outcome, duration))
	else
		pcall(function()
			Analytics:LogCustomEvent(player, "ClassicMatchDurationV1", duration, fields(entry, player, side, outcome))
		end)
	end
end

return Metrics
