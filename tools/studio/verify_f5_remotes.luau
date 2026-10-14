-- Run in Client mode outside a match. Sends invalid inputs through real remotes.
local RS = game:GetService("ReplicatedStorage")
local player = game:GetService("Players").LocalPlayer
assert(not player.PlayerGui:GetAttribute("InMatch"), "Finish the current match first")
local remotes = require(RS.Shared.Remotes)
task.wait(0.7) -- independent from the controller's startup requests
local replies = { Profile = 0, Odds = 0, Claim = 0, Code = 0 }
local latest
local connections = {
	remotes.ProfileSnapshot.OnClientEvent:Connect(function(data)
		replies.Profile += 1
		latest = data
	end),
	remotes.KilnOdds.OnClientEvent:Connect(function()
		replies.Odds += 1
	end),
	remotes.RetentionResult.OnClientEvent:Connect(function(data)
		if data.Message and data.Message:find("code", 1, true) then
			replies.Code += 1
		else
			replies.Claim += 1
		end
	end),
}
for _ = 1, 20 do
	remotes.RequestProfile:FireServer()
	remotes.RequestKiln:FireServer()
	remotes.RequestFightState:FireServer()
	remotes.ClaimRetention:FireServer("Gift", 999)
	remotes.RedeemCode:FireServer({ Coins = 999999 })
end
remotes.PullKiln:FireServer(1000, "invalid")
remotes.PickGlassy:FireServer({ Id = "pop" })
remotes.SetAim:FireServer(0 / 0, math.huge)
task.wait(1.1)
for _, connection in connections do
	connection:Disconnect()
end
assert(latest, "No valid profile response")
assert(replies.Profile <= 2, "Profile flood bypassed limiter") -- includes periodic retention sync
assert(replies.Odds <= 2, "Kiln flood bypassed limiter") -- invalid pull can refresh once
assert(replies.Claim + replies.Code <= 2, "Retention flood bypassed limiter")
for _, private in { "Flags", "CodesRedeemed", "RecentMatches", "Receipts", "Marbles" } do
	assert(latest[private] == nil, "Private field exposed: " .. private)
end
return { Replies = replies, Coins = latest.Coins, PrivateFieldsHidden = true, RequestsPerRemote = 20 }
