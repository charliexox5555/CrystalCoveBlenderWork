-- Studio Play / Server Command Bar. Test profiles only; repeat without adding duplicates.
local player = assert(game.Players:GetPlayers()[1], "Start Play first")
local dev = game.ServerStorage.DataDev
local profile = dev:Invoke("Inspect", player)
assert(profile.Mock and profile.Active, "Isolated Studio test profile required")
for _, glassy in require(game.ReplicatedStorage.Shared.Config.Glassies).ReleaseList do
	if not profile.Data.Glassies[glassy.Id] then
		dev:Invoke("Grant", player, glassy.Id)
	end
end
return { Glassies = 24, Marbles = dev:Invoke("Marbles", player, 10000) }
