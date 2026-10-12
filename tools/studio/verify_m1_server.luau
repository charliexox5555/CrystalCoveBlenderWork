-- Run in the Server datamodel. MCP requires have a separate cache from live scripts.
-- Exercise release validation without changing the live service's state.
local service = table.clone(require(game.ServerScriptService.Server.Services.BattleService))
local Logic = require(game.ReplicatedStorage.Shared.BattleLogic)
local Glassies = require(game.ReplicatedStorage.Shared.Config.Glassies)
local player = game.Players:GetPlayers()[1]
assert(player, "Start a play-test first")
service.Active, service.ReleaseTimes = {}, {}
local state = {
	Id = "validation-fixture",
	Index = 1,
	Phase = "Meter",
	Released = false,
	StartTime = workspace:GetServerTimeNow() - 0.55,
	A = Logic.newFighter(Glassies.get("pop"), { Level = 10 }),
}
service.Active[player] = state
local function reject(id, index, elapsed)
	service.ReleaseTimes[player] = nil
	assert(not service:AcceptRelease(player, id, index, elapsed), "Invalid release accepted")
end
reject("wrong", 1, 0.55)
reject(state.Id, 2, 0.55)
reject(state.Id, 1.5, 0.55)
reject(state.Id, 1, "0.55")
reject(state.Id, 1, 0 / 0)
reject(state.Id, 1, math.huge)
reject(state.Id, 1, -1)
reject(state.Id, 1, 10)
state.StartTime = workspace:GetServerTimeNow() + 1
reject(state.Id, 1, 0)
state.StartTime = workspace:GetServerTimeNow() - 0.55
service.ReleaseTimes[player] = nil
assert(service:AcceptRelease(player, state.Id, 1, 0.55))
assert(state.Zone == "Perfect")
reject(state.Id, 1, 0.55) -- one release per clash
state.Released = false
service.ReleaseTimes[player] = workspace:GetServerTimeNow()
assert(not service:AcceptRelease(player, state.Id, 1, 0.55)) -- rate limit
service.ReleaseTimes[player] = nil
state.StartTime = workspace:GetServerTimeNow() - 2
reject(state.Id, 1, 0.55) -- expired clash
service.Active[player] = nil
reject(state.Id, 1, 0.55)
return "14 server release validation checks passed"
