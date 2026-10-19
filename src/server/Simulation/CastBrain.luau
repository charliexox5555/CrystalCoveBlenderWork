-- Who presses CAST for sides that aren't a real player (decision 85).
--   bot   = live bots: reaction delay and moment-reading chance from Skill
--   smart = balance tools: a quick player who waits for a good moment
--   mash  = balance tools: presses as soon as the power is Ready
--   auto / player = nobody here (the timer, or the CastPower remote)
local Shared = if script then game.ReplicatedStorage.Shared else nil
local Balance = if Shared then require(Shared.Config.Balance) else require("../../shared/Config/Balance")
local Rules = if Shared then require(Shared.FightRules) else require("../../shared/FightRules")
local Rng = if Shared then require(Shared.Rng) else require("../../shared/Rng")
local CastTiming = if Shared then require(Shared.CastTiming) else require("../../shared/CastTiming")
local C, M = Balance.CombatRelease.Cast, Balance.Motion
local CastBrain = {}

local function lerp(a, b, t)
	return a + (b - a) * math.clamp(t, 0, 1)
end

-- Distance, closing speed and touching distance between the two glassies, for CastTiming.
function CastBrain.read(sim, center, side)
	local fight = sim.Fight
	local ca, cb = center(sim, side), center(sim, 3 - side)
	local delta = cb - ca
	local distance = delta.Magnitude
	local normal = if distance > 0.0001 then delta / distance else delta
	local closing = (sim.Bodies[side].V - sim.Bodies[3 - side].V):Dot(normal)
	local contact = (fight.Fighters[1].Radius + fight.Fighters[2].Radius) * M.GlassyScale
	return distance, closing, contact
end

function CastBrain.step(sim, center)
	local fight = sim.Fight
	for side, f in fight.Fighters do
		local s = f.Signature
		local r = s and s.Ready
		local policy = s and s.Policy
		if not r or r.Requested or policy == "player" or policy == "auto" then
			continue
		end
		if not r.Brain then
			sim.CastRng = sim.CastRng or Rng.new(sim.Seed + 7331)
			local smart = policy == "smart"
			r.Brain = {
				Reaction = if smart
					then C.SmartReaction
					elseif policy == "mash" then C.SmartReaction
					else lerp(C.BotReactionMax, C.BotReactionMin, s.Skill),
				Reads = smart
					or (policy == "bot" and sim.CastRng() < lerp(C.BotReadChanceMin, C.BotReadChanceMax, s.Skill)),
			}
		end
		if fight.Time - r.Since < r.Brain.Reaction then
			continue
		end
		if not r.Brain.Reads then
			Rules.requestCast(fight, side)
			continue
		end
		local params = r.Brain.Params
		if not params then
			params = s.Kit
			if r.Overrides then
				params = table.clone(s.Kit)
				for key, value in r.Overrides do
					params[key] = value
				end
			end
			r.Brain.Params = params -- merged once per Ready, not every step
		end
		local distance, closing, contact = CastBrain.read(sim, center, side)
		local body = sim.Bodies[side]
		local aim = CastTiming.aimError(body.Twist, body.Spin, params)
		if CastTiming.good(CastTiming.kind(r.Shape, r.Arm), distance, closing, contact, params, aim) then
			Rules.requestCast(fight, side)
		end
	end
end

return CastBrain
