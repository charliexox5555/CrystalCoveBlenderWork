--!strict
-- Pure "good moment to cast" read (decision 85), shared by bots and the balance tools on the
-- server and by the CAST button hint on the client. Numbers live in Balance.CombatRelease.Cast.
local Balance = if script then require(script.Parent.Config.Balance) else require("./Config/Balance")
local C = Balance.CombatRelease.Cast

local CastTiming = {}

local BRACE = { guard = true, mirror = true }
-- Shapes fired along the glassy's twisted facing: a fast-twisting string throws them off target.
local TWIST_AIMED = { ray = true, cone = true, breath = true, sweep = true }
local BOOST = { boost = true }
local SELF = { heal = true }

-- What a Ready power wants: "arm" (next contact pays off), "brace", "boost", "self" or "strike".
function CastTiming.kind(shape: string?, arm: boolean?): string
	if arm then
		return "arm"
	elseif shape and BRACE[shape] then
		return "brace"
	elseif shape and BOOST[shape] then
		return "boost"
	elseif shape and SELF[shape] then
		return "self"
	end
	return "strike"
end

-- Aim error (radians) of a twist-aimed shape at release, from the string's twist and spin.
function CastTiming.aimError(twist: number, spin: number, params: any): number
	local windup = (params and params.Windup or 0) + (params and params.Hold or 0)
	return math.abs((twist + spin * windup) * Balance.CombatRelease.TwistInfluence)
end

-- distance: centre-to-centre studs; closing: approach speed (studs/s, > 0 = coming together);
-- contact: centre distance at which the glassies touch; params: the kit (Windup, Range, Shape);
-- aimError: from CastTiming.aimError (only used for twist-aimed shapes).
function CastTiming.good(
	kind: string,
	distance: number,
	closing: number,
	contact: number,
	params: any,
	aimError: number?
): boolean
	local windup = (params and params.Windup or 0) + (params and params.Hold or 0)
	if kind == "self" then
		return true
	end
	local coming = closing >= C.MinClosingSpeed
	local due = if coming then math.max(0, distance - contact) / closing else math.huge
	if kind == "brace" then
		return coming and due <= windup + C.BraceLead
	elseif kind == "boost" then
		return coming and due >= windup * 0.5 and due <= windup + C.BoostLead
	elseif kind == "arm" then
		return coming and due <= C.ArmLead
	end
	local range = (params and params.Range or 6) * C.StrikeRangeSlack + contact * 0.5
	local predicted = distance - math.max(0, closing) * windup
	if predicted > range then
		return false
	end
	if aimError and params and TWIST_AIMED[params.Shape] then
		-- The target's angular size from here: wait while the string spins the shot off it.
		local tolerance =
			math.asin(math.clamp((contact * 0.5 + (params.Radius or 0.15)) / math.max(predicted, 0.5), 0, 1))
		return aimError <= tolerance * C.AimTolerance
	end
	return true
end

return CastTiming
