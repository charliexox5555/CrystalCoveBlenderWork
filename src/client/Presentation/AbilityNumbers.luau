-- Readable numbers and words for signature abilities: damage dealt (multi-hit casts count up on one
-- label), heals, blocked/reflected amounts and short status calls (SLOWED, MARKED, BOOST, SEED 2/3).
-- Presentation only; every amount comes from the server's FightRules events.
local RS = game:GetService("ReplicatedStorage")
local Visuals = require(RS.Shared.Config.CombatKitVisuals)
local Health = require(script.Parent.FightHealth)
local Numbers = {}

local HEAL, GUARD, STATUS = Color3.fromHex("#86EDB8"), Color3.fromHex("#F5D99A"), Color3.fromHex("#E1E9FF")
local ABOVE = Vector3.yAxis * 1.6
-- Status kinds -> label, and whether it sits on the event's Target (otherwise on the caster).
local STATUSES = {
	Slow = { Text = "SLOWED", OnTarget = true },
	Mark = { Text = "MARKED", OnTarget = true },
	Boost = { Text = "BOOST!" },
	Mirror = { Text = "MIRROR UP" },
	Counter = { Text = "COUNTER READY" },
	Echo = { Text = "ECHO STORED" },
	SeedLost = { Text = "SEED KNOCKED!", OnTarget = true },
	Pierce = { Text = "GUARD BROKEN!", OnTarget = true },
}
-- A powered clash's damage number is bigger and in the power's colour, so the payoff reads as the power's hit.
local POWERED_SCALE = 1.35

local function round(x)
	return math.floor((x or 0) + 0.5)
end

local function lane(side)
	return if side == 1 then -1 else 1
end

function Numbers.event(scene, e, hud)
	local totals = scene.AbilityTotals or { Seen = {}, Count = 0 }
	scene.AbilityTotals = totals
	-- Snapshots can repeat an event; count each cast pulse or status once.
	local key = e.Type .. ":" .. tostring(e.CastId or e.Time) .. ":" .. tostring(e.Pulse or e.Kind or e.Side)
	if totals.Seen[key] then
		return
	end
	totals.Seen[key] = true
	totals.Count += 1
	if totals.Count > 256 then
		scene.AbilityTotals = { Seen = { [key] = true }, Count = 1 }
		totals = scene.AbilityTotals
	end
	local caster = e.Side and scene.Fighters[e.Side]
	if e.Type == "CastContact" and not e.Missed then
		local target = scene.Fighters[e.Target]
		Health.bump(target)
		if hud and target then
			if e.Blocked then
				hud:Popup("BLOCKED", target.Body.Position, GUARD, lane(e.Target), "Power" .. e.CastId)
			else
				-- Multi-pulse casts (wisps, breath, volleys) add up on one label instead of overwriting.
				totals[e.CastId] = (totals[e.CastId] or 0) + (e.Amount or 0)
				hud:Popup(
					"−" .. round(totals[e.CastId]),
					target.Body.Position,
					Color3.fromHex(caster.Def.Tint),
					lane(e.Target),
					"Power" .. e.CastId
				)
			end
		end
	elseif e.Type == "SignatureStatus" and caster then
		if e.Kind == "Heal" and (e.Amount or 0) > 0 then
			Health.bump(caster)
			if hud then
				hud:Popup("+" .. round(e.Amount), caster.Body.Position, HEAL, 0, "Heal" .. e.Side)
			end
		elseif e.Kind == "MirrorCatch" and hud then
			hud:Popup("REFLECT " .. round(e.Amount), caster.Body.Position + ABOVE, GUARD, 0, "Status" .. e.Side)
		elseif e.Kind == "Seed" and hud then
			local target = scene.Fighters[e.Target]
			if target then
				hud:Popup(
					"SEED " .. e.Count .. "/3",
					target.Body.Position + ABOVE,
					Color3.fromHex("#FFB347"),
					0,
					"Status" .. e.Target
				)
			end
		elseif STATUSES[e.Kind] and hud then
			local status = STATUSES[e.Kind]
			local who = if status.OnTarget and e.Target then scene.Fighters[e.Target] else caster
			if who then
				hud:Popup(status.Text, who.Body.Position + ABOVE, STATUS, 0, "Status" .. who.Side)
			end
		end
	elseif e.Type == "SignatureBlock" and caster and hud then
		hud:Popup("BLOCKED " .. round(e.Amount), caster.Body.Position + ABOVE, GUARD, 0, "Status" .. e.Side)
	elseif e.Type == "SignatureContact" and caster and hud and e.Shape ~= "splat" then
		scene.PoweredClash = { Side = e.Side, Time = e.Time }
		-- Contact-boosted clashes: name the ability; the extra damage is in the clash number.
		local visual = Visuals[caster.Id]
		if visual and visual.Name then
			hud:Popup(
				string.upper(visual.Name) .. "!",
				caster.Body.Position + ABOVE,
				Color3.fromHex(caster.Def.Tint),
				0,
				"Status" .. e.Side
			)
		end
	end
end

-- Tint and size for the clash damage number on `side`: the power's colour when the other side's power paid off
-- on this clash (boosts, armed hits), else plain white.
function Numbers.clash(scene, e, side)
	local powered = scene.PoweredClash
	if powered and powered.Side ~= side and math.abs((e.Time or 0) - (powered.Time or 0)) < 0.1 then
		local caster = scene.Fighters[powered.Side]
		local visual = caster and Visuals[caster.Id]
		if visual and visual.Color then
			return Color3.fromHex(visual.Color), POWERED_SCALE
		end
	end
	return Color3.new(1, 1, 1), nil
end

return Numbers
