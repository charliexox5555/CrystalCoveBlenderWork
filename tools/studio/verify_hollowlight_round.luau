-- Play/Server native QA Script context, mock only. Leaves a live round for client inspection.
local services = game.ServerScriptService.Server.Services
local MS, CS, FS = require(services.MatchService), require(services.CosmeticService), require(services.FightService)
local p = game.Players:GetPlayers()[1]
assert(CS.Services.DataService.Mock, "Mock only")
assert(game.ServerStorage.CosmeticDev:Invoke("PreviewHollowlight", p))
for category, id in { Skins = "hollowlight", Rideables = "lantern_skiff", Finishers = "lantern_eclipse" } do
	task.wait(require(game.ReplicatedStorage.Shared.Config.Balance).Data.RequestRateSeconds)
	assert(CS:Equip(p, category, id))
end
assert(MS:StartMatch(MS.Services.ArenaService.Arenas[1], { [1] = p }, workspace:GetServerTimeNow()))
local entry = MS.Matches[1]
assert(entry.Runner:Pick(1, "pop"))
for _ = 1, 3 do
	entry.Runner:Step(entry.Runner.Deadline + 1)
	MS:Dispatch(entry, workspace:GetServerTimeNow())
end
local session = assert(FS.Sessions[entry.FightId])
assert(session.Data.Phase == "Fighting" and session.Data.A.Skin == "hollowlight")
assert(session.Data.Finishers[1] == "lantern_eclipse")
local fighter = session.Sim.Fight.Fighters[1]
assert(fighter.Id == "pop")
local stats = require(game.ReplicatedStorage.Shared.Formula).stats(
	require(game.ReplicatedStorage.Shared.Config.Glassies).get("pop"),
	CS.Services.DataService:Get(p).Glassies.pop
)
assert(fighter.MaxHp == stats.HP)
FS:Sync(p)
return {
	Passed = 4,
	Phase = session.Data.Phase,
	BaseId = fighter.Id,
	MaxHp = fighter.MaxHp,
	Skin = session.Data.A.Skin,
	SyncSent = true,
}
