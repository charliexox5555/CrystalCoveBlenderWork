-- PUSH for sides without a player (decision 122): bots, and simulator sides so balance runs see both
-- glassies pushing. Shoves while closing in on the other glass or when a glint is just ahead.
local Shared = if script then game.ReplicatedStorage.Shared else nil
local Balance = if Shared then require(Shared.Config.Balance) else require("../../shared/Config/Balance")
local Rules = if Shared then require(Shared.FightRules) else require("../../shared/FightRules")
local Arena = if Shared then require(Shared.ArenaRules) else require("../../shared/ArenaRules")
local V = if script then Vector3 else require("@lune/roblox").Vector3
local P = Balance.Arena.Push
local Brain = {}

-- `center(sim, side)` and `velocity(sim, side)` come from Pendulum (body centre position and velocity).
function Brain.step(sim, center, velocity)
	local fight = sim.Fight
	if fight.Over or fight.Time < (sim.NextPushThink or 0) then
		return
	end
	sim.NextPushThink = fight.Time + P.BrainSeconds
	for side, f in fight.Fighters do
		if f.CastPolicy == "player" or f.PushSkill == 0 or Arena.pushCharges(fight, side) <= 0 then
			continue
		end
		local skill = f.PushSkill or f.CastSkill or 0.5
		local me = center(sim, side)
		local toFoe = center(sim, 3 - side) - me
		local distance = toFoe.Magnitude
		local v = velocity(sim, side)
		local want = distance >= P.BotApproachMin and distance <= P.BotApproachMax and v:Dot(toFoe / distance) > 2
		if not want and v.Magnitude > 0.5 then
			local ahead = me + v * 0.3
			for _, glint in Arena.glints(fight) do
				local p = glint.Point
				if p and (ahead - V.new(p[1], p[2], p[3])).Magnitude <= P.BotGlintReach then
					want = true
					break
				end
			end
		end
		if want and sim.Rng() < 0.3 + 0.5 * skill then
			Rules.requestPush(fight, side)
		end
	end
end

return Brain
