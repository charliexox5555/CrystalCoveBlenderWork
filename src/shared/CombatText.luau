-- One source for ability copy in Inventory, Pick Any, collection and hand cards.
local Config = if script then script.Parent.Config else nil
local Visuals = if Config then require(Config.CombatKitVisuals) else require("./Config/CombatKitVisuals")
local Balance = if Config then require(Config.Balance) else require("./Config/Balance")
local Powers = if Config then require(Config.Powers) else require("./Config/Powers")
local Text = {}
local builds = {
	concept = "Builds up during the round and fires by itself.",
	contact = "Charges through body clashes, then fires by itself.",
	turnaround = "Charges at swing turnarounds, then fires by itself.",
	timer = "Charges over time, then fires by itself.",
	threshold = "Fires once when your glassy gets low.",
	received = "Charges from clashes you take, then fires by itself.",
	stored = "Stores some damage taken, then fires at a turnaround.",
	heavy = "A big hit taken arms a counter by itself.",
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
