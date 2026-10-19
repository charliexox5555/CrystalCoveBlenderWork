--!strict
-- Pure "good moment to cast" read (decision 85), shared by bots and the balance tools on the
-- server and by the CAST button hint on the client. Numbers live in Balance.CombatRelease.Cast.
local Balance = if script then require(script.Parent.Config.Balance) else require("./Config/Balance")
local C = Balance.CombatRelease.Cast

local CastTiming = {}

local BRACE = { guard = true, mirror = true }
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

-- distance: centre-to-centre studs; closing: approach speed (studs/s, > 0 = coming together);
-- contact: centre distance at which the glassies touch; params: the kit (Windup, Range).
function CastTiming.good(kind: string, distance: number, closing: number, contact: number, params: any): boolean
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
	return predicted <= range
end

return CastTiming
