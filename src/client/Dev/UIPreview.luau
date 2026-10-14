-- Studio-only visual fixture. It neither sends gameplay inputs nor grants rewards.
local Players = game:GetService("Players")
local Screens = require(script.Parent.Parent.UI.Screens.MatchScreens)
local Preview = {}
function Preview.new(kind)
	assert(game:GetService("RunService"):IsStudio())
	local screen
	local data = {
		Round = 2,
		MatchId = "ui-preview",
		Deadline = workspace:GetServerTimeNow() + 600,
		Names = { "YOU", "Glass Bot" },
		PlayerIds = { Players.LocalPlayer.UserId, 0 },
		LastPicks = { "pop", "jam" },
	}
	if kind == "Roll" then
		screen = Screens.roll(data, function() end, function() end)
		screen:Offers({
			Offers = { "pop", "jam", "prism" },
			Collection = { pop = { Stars = 1 }, jam = { Stars = 0 }, prism = { Stars = 2 } },
			CanReroll = true,
		})
	elseif kind == "Queue" then
		data.Deadline = workspace:GetServerTimeNow() + 10
		screen = Screens.queue(data, function() end)
	elseif kind == "Results" then
		screen = Screens.results(
			{
				Side = 1,
				Won = true,
				Saved = false,
				Rewards = { Coins = 36, Trophies = 0 },
				History = {
					{ Winner = 1, Picks = { "pop", "jam" } },
					{ Winner = 2, Picks = { "prism", "pop" } },
					{ Winner = 1, Picks = { "jam", "prism" } },
					{ Winner = 2, Picks = { "pop", "jam" } },
					{ Winner = 1, Picks = { "prism", "pop" } },
				},
			},
			function() end,
			function() end
		)
	else
		error("Unknown UI preview")
	end
	return {
		Window = { Gui = screen.Gui },
		Step = function()
			screen:Render(workspace:GetServerTimeNow())
		end,
		Destroy = function()
			screen:Destroy()
		end,
	}
end
return Preview
