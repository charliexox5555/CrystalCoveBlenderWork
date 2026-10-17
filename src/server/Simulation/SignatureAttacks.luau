-- Traveling volumes are deterministic values, never physical Roblox parts.
local Shared = if script then game.ReplicatedStorage.Shared else nil
local Rules = if Shared then require(Shared.FightRules) else require("../../shared/FightRules")
local Balance = if Shared then require(Shared.Config.Balance) else require("../../shared/Config/Balance")
local Geometry = if script then require(script.Parent.AttackGeometry) else require("./AttackGeometry")
local Path = if Shared then require(Shared.AttackPath) else require("../../shared/AttackPath")
local V = if script then Vector3 else require("@lune/roblox").Vector3
local Attacks = {}
local function array(v)
	return { v.X, v.Y, v.Z }
end

function Attacks.add(sim, cast, origin, direction, target)
	if not table.find({ "projectile", "volley", "cone", "breath", "pulse", "orbit", "bloom" }, cast.Shape) then
		return false
	end
	sim.ReleaseAttacks = sim.ReleaseAttacks or {}
	local count = if cast.Shape == "volley" then cast.Params.Pulses else 1
	for i = 1, count do
		local dir = Geometry.fanDirection(direction, i, count, cast.Params.Arc or 0, V.yAxis)
		table.insert(sim.ReleaseAttacks, {
			Cast = cast,
			Origin = origin,
			Direction = dir,
			Age = 0,
			Index = i,
			NextPulse = 1,
			PreviousPoint = origin,
			PreviousTarget = target,
		})
	end
	if cast.Shape == "orbit" then
		sim.Well = {
			Origin = origin,
			Until = sim.Fight.Time + cast.Params.Duration,
			Range = cast.Params.Range,
			Force = cast.Params.Force,
		}
	end
	return true
end

function Attacks.step(sim, dt, center)
	local waiting = {}
	for _, a in sim.ReleaseAttacks or {} do
		if sim.Fight.Over then
			break
		end
		local c, oldAge = a.Cast, a.Age
		local p = c.Params
		a.Age = math.min(p.Duration, a.Age + dt)
		local target = center(sim, 3 - c.Side)
		local radius = sim.Fight.Fighters[3 - c.Side].Radius * Balance.Motion.GlassyScale + p.Radius
		local hit, point, done = false, target, false
		if p.Path == "return" then
			-- Split at the apex, including large steps, so the swept volume never shortcuts the return.
			local from = oldAge / p.Duration
			local finish = a.Age / p.Duration
			local previousTarget = a.PreviousTarget
			while from < finish do
				local leg = if from < 0.5 then 1 else 2
				local edge = math.min(finish, leg / 2)
				local nextTarget =
					previousTarget:Lerp(target, (edge - oldAge / p.Duration) / (finish - oldAge / p.Duration))
				local first = a.Origin + a.Direction * p.Range * Path.distance(from, p.Path)
				point = a.Origin + a.Direction * p.Range * Path.distance(edge, p.Path)
				if not (c.Results and c.Results[leg]) then
					hit = Geometry.movingSphere(first, point, a.PreviousTarget, nextTarget, radius)
					if hit or edge >= leg / 2 then
						Rules.resolveAbility(sim.Fight, c.Id, hit, if hit then array(point) else nil, leg)
					end
				end
				a.PreviousTarget, from = nextTarget, edge
			end
			done = a.Age >= p.Duration
		elseif c.Shape == "projectile" or c.Shape == "volley" then
			point = a.Origin + a.Direction * p.Range * (a.Age / p.Duration)
			hit = Geometry.movingSphere(a.PreviousPoint, point, a.PreviousTarget, target, radius)
			done = hit or a.Age >= p.Duration
		elseif c.Shape == "pulse" then
			local before = (a.PreviousTarget - a.Origin).Magnitude - p.Range * oldAge / p.Duration
			local after = (target - a.Origin).Magnitude - p.Range * a.Age / p.Duration
			hit = math.min(before, after) <= radius and math.max(before, after) >= -radius
			done = hit or a.Age >= p.Duration
		elseif c.Shape == "orbit" then
			done = a.Age >= p.Duration
			hit = done and (target - a.Origin).Magnitude <= p.Range + radius
		elseif c.Shape == "breath" then
			local at = (a.NextPulse - 1) * p.Duration / p.Pulses
			if a.Age >= at and a.NextPulse <= p.Pulses then
				hit = Geometry.coneSphere(a.Origin, a.Direction, p.Range, p.Arc, target, radius)
				Rules.resolveAbility(sim.Fight, c.Id, hit, if hit then array(target) else nil, a.NextPulse)
				a.NextPulse += 1
			end
			done = a.NextPulse > p.Pulses
		elseif c.Shape == "bloom" then
			-- Wisps burst out of the seeded foe one at a time and home back; shields still block.
			while a.NextPulse <= p.Pulses and a.Age >= (a.NextPulse - 0.5) * p.Duration / p.Pulses do
				Rules.resolveAbility(sim.Fight, c.Id, true, array(target), a.NextPulse)
				a.NextPulse += 1
			end
			done = a.NextPulse > p.Pulses
		else
			hit = Geometry.coneSphere(a.Origin, a.Direction, p.Range, p.Arc, target, radius)
			done = hit or a.Age >= p.Duration
		end
		if done then
			if c.Shape ~= "breath" and c.Shape ~= "bloom" and p.Path ~= "return" then
				Rules.resolveAbility(sim.Fight, c.Id, hit, if hit then array(point) else nil, a.Index)
			end
		else
			a.PreviousPoint, a.PreviousTarget = point, target
			table.insert(waiting, a)
		end
	end
	sim.ReleaseAttacks = if sim.Fight.Over then {} else waiting
	if sim.Fight.Over then
		sim.Well = nil
	end
end

return Attacks
