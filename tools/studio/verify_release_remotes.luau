-- Release-candidate remote flood (docs/testing/release_candidate/CHECKLIST.md). Run in Client mode, in the lobby,
-- outside a match. Sends 20 malformed calls through every client -> server remote (NaN, inf, wrong types, huge
-- strings, tables, unknown ids, instances) and checks the profile gained nothing. It never sends a valid purchase or
-- the group claim, so no Robux prompt opens and no reward is due.
local RS = game:GetService("ReplicatedStorage")
local player = game:GetService("Players").LocalPlayer
assert(not player.PlayerGui:GetAttribute("InMatch"), "Finish the current match first")
local remotes = require(RS.Shared.Remotes)
local latest
local connection = remotes.ProfileSnapshot.OnClientEvent:Connect(function(data)
	latest = data
end)
local function snapshot()
	latest = nil
	task.wait(0.6)
	remotes.RequestProfile:FireServer()
	local stop = os.clock() + 5
	while not latest and os.clock() < stop do
		task.wait(0.1)
	end
	assert(latest, "No profile response")
	local glassies = 0
	for _, owned in latest.Glassies or {} do
		glassies += type(owned) == "table" and owned.Count or 1
	end
	return {
		Coins = latest.Coins,
		Marbles = latest.Marbles,
		Trophies = latest.Trophies,
		Xp = latest.Level and latest.Level.Xp,
		Glassies = glassies,
		KilnPulls = latest.Stats and latest.Stats.KilnPulls,
	}
end
local before = snapshot()
local nan, inf, long = 0 / 0, math.huge, string.rep("x", 5000)
local junk = { nan, inf, -inf, long, { Coins = 999999 }, workspace, true, -1, 1e300 }
for _ = 1, 20 do
	for _, value in junk do
		remotes.PickGlassy:FireServer(value)
		remotes.Reroll:FireServer(value, value, value, value)
		remotes.PickAny:FireServer(value, value, value, value, value)
		remotes.SetAim:FireServer(value, value)
		remotes.CastPower:FireServer(value)
		remotes.LeaveQueue:FireServer(value)
		remotes.JoinNearestArena:FireServer(value)
		remotes.RequestRematch:FireServer(value)
		remotes.RequestFightState:FireServer(value)
		remotes.RequestProfile:FireServer(value)
		remotes.RequestPlayerProfile:FireServer(value)
		remotes.RequestKiln:FireServer(value)
		remotes.PullKiln:FireServer(value, value, value, value)
		remotes.ClaimRetention:FireServer(value, value)
		remotes.RedeemCode:FireServer(value)
		remotes.EquipRoundCosmetic:FireServer(value, value)
		remotes.RequestStore:FireServer(value)
		remotes.BuyStoreOffer:FireServer(value, value, value)
		remotes.BuyStoreBundle:FireServer(value)
		remotes.BuyMarblePack:FireServer(value)
		remotes.Deals:FireServer("Buy", value)
		remotes.Deals:FireServer(value, value)
		remotes.OnboardingAction:FireServer(value)
		remotes.RequestSettings:FireServer(value)
		remotes.SetSetting:FireServer(value, value)
		remotes.GroupReward:FireServer("Prompt", value)
		remotes.GroupReward:FireServer(value, value)
	end
	task.wait(0.5) -- about 490 calls/s: under Roblox's ~500/s per-client remote throttle, so the server sees them
end
task.wait(1.5)
local after = snapshot()
connection:Disconnect()
for key, value in before do
	assert(after[key] == value, key .. " changed: " .. tostring(value) .. " -> " .. tostring(after[key]))
end
for _, private in { "Flags", "CodesRedeemed", "RecentMatches", "ProcessedReceipts", "Store" } do
	assert(latest[private] == nil, "Private field exposed: " .. private)
end
return { Before = before, After = after, CallsPerRemote = 20 * #junk, Unchanged = true }
