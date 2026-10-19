-- One source for ability copy in Inventory, Pick Any, collection and hand cards.
local Config = if script then script.Parent.Config else nil
local Visuals = if Config then require(Config.CombatKitVisuals) else require("./Config/CombatKitVisuals")
local Balance = if Config then require(Config.Balance) else require("./Config/Balance")
local Powers = if Config then require(Config.Powers) else require("./Config/Powers")
local Text = {}
local builds = {
	contact = "Charges through body clashes. Tap CAST when it's Ready, or it casts by itself.",
	turnaround = "Charges at swing turnarounds. Tap CAST when it's Ready, or it casts by itself.",
	timer = "Charges over time. Tap CAST when it's Ready, or it casts by itself.",
	threshold = "Ready once when your glassy gets low. Tap CAST, or it casts by itself.",
	received = "Charges from clashes you take. Tap CAST when it's Ready, or it casts by itself.",
	stored = "Stores some damage taken; Ready at a turnaround. Tap CAST, or it casts by itself.",
	heavy = "A big hit taken makes a counter Ready. Tap CAST to arm it, or it arms by itself.",
}
function Text.passive(def)
	local kit = Balance.CombatRelease.Enabled and Balance.CombatRelease.Kits[def.Id]
	if kit then
		return { Name = "Build-up", Description = builds[kit.Trigger] }
	end
	local legacy = table.clone(Powers.passive(def.Passive))
	legacy.Name = def.PassiveName or legacy.Name
	return legacy
end
function Text.special(def)
	if Balance.CombatRelease.Enabled and Visuals[def.Id] then
		return Visuals[def.Id]
	end
	local legacy = table.clone(Powers.special(def.Special))
	legacy.Name = def.SpecialName or legacy.Name
	return legacy
end
return Text
