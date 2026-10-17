-- Play/Server, mock profiles only. Leaves one held aiming round for the client review.
local p = game.Players:GetPlayers()[1]
local CS = require(game.ServerScriptService.Server.Services.CosmeticService)
local DS, MS, FS = CS.Services.DataService, CS.Services.MatchService, CS.Services.FightService
assert(DS.Mock, "Never grant test cosmetics to production profiles")
local C = require(game.ReplicatedStorage.Shared.Config.RoundCosmetics)
local Rules = require(game.ReplicatedStorage.Shared.RoundCosmeticRules)
local checks = 0
local function check(value, message)
	assert(value, message)
	checks += 1
end
local function equip(category, id)
	task.wait(require(game.ReplicatedStorage.Shared.Config.Balance).Data.RequestRateSeconds)
	return CS:Equip(p, category, id)
end
local data = DS:Get(p)
local coins, marbles = data.Coins, data.Marbles
check(not equip("Skins", "hollowlight"), "Unowned seasonal skin rejected")
check(not equip({}, "hollowlight"), "Malformed category rejected")
check(not equip("Skins", {}), "Malformed ID rejected")
check(game.ServerStorage.CosmeticDev:Invoke("PreviewHollowlight", p), "Mock-only test grant")
check(game.ServerStorage.CosmeticDev:Invoke("PreviewHollowlight", p), "Repeated preview is idempotent")
for category, id in { Skins = "hollowlight", Rideables = "lantern_skiff", Finishers = "lantern_eclipse" } do
	check(Rules.count(data, category, id) == 1, "Exactly one test copy")
	check(equip(category, id), "Owned seasonal cosmetic equips")
end
check(not CS:Equip(p, "Skins", ""), "Immediate spam rejected")
local saved = game.ServerStorage.DataDev:Invoke("Save", p)
check(saved.Saved, "Mock profile saves")
local reloaded = game.ServerStorage.DataDev:Invoke("Reload", p)
for category, id in { Skins = "hollowlight", Rideables = "lantern_skiff", Finishers = "lantern_eclipse" } do
	check(reloaded.Cosmetics["Equipped" .. category] == id, "Equipment survives reload")
	check(Rules.count(reloaded, category, id) == 1, "Copy count survives reload")
end
check(reloaded.Coins == coins and reloaded.Marbles == marbles, "Grant/equip does not spend currency")
local arena = MS.Services.ArenaService.Arenas[1]
check(MS:StartMatch(arena, { [1] = p }, workspace:GetServerTimeNow()), "Normal match starts with equipment")
local entry = MS.Matches[1]
check(entry.Cosmetics.Skins[1] == "hollowlight", "Match captures skin")
check(entry.Cosmetics.Finishers[1] == "lantern_eclipse", "Match captures finisher")
local ride = entry.Stage.Folder:FindFirstChild("Ride1")
if not ride then
	for _, o in entry.Stage.Folder:GetChildren() do
		if o:IsA("Model") and o:GetAttribute("RideId") == "lantern_skiff" then
			ride = o
		end
	end
end
check(ride and ride:GetAttribute("PoseId") == "prism_ray", "Real stage selects imported skiff and pose")
check(equip("Skins", ""), "Midmatch change applies to next match")
check(entry.Cosmetics.Skins[1] == "hollowlight", "Current match appearance stays frozen")
local described = FS:Describe(arena, { A = { Id = "pop" }, B = { Id = "jam" } }, MS:Meta(entry))
check(described.A.Skin == "hollowlight" and described.B.Skin == nil, "Skin only applies to its base glassy")
check(described.Skins[1] == "hollowlight", "Late-join description carries frozen appearance")
check(equip("Skins", "hollowlight"), "Restore next-match look for creator testing")
check(entry.Runner:Pick(1, "pop"), "Pop remains a normal combat choice")
entry.Runner:Step(entry.Runner.Deadline + 1)
MS:Dispatch(entry, workspace:GetServerTimeNow())
_G.HollowlightEquipmentReview = { Player = p, Entry = entry }
return { Passed = checks, Mock = true, Coins = reloaded.Coins, Marbles = reloaded.Marbles, Phase = entry.Runner.Phase }
