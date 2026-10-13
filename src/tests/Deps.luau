-- Loads the pure shared modules so tests run both in Roblox (ServerStorage.Tests) and in Lune.

local Shared = if game then game:GetService("ReplicatedStorage"):WaitForChild("Shared") else nil

local function load(instancePath: { string }, filePath: string): any
	if Shared then
		local node = Shared
		for _, name in instancePath do
			node = node:WaitForChild(name)
		end
		return require(node)
	end
	return require(filePath)
end

return {
	Balance = load({ "Config", "Balance" }, "../shared/Config/Balance"),
	Glassies = load({ "Config", "Glassies" }, "../shared/Config/Glassies"),
	Powers = load({ "Config", "Powers" }, "../shared/Config/Powers"),
	Cosmetics = load({ "Config", "Cosmetics" }, "../shared/Config/Cosmetics"),
	Formula = load({ "Formula" }, "../shared/Formula"),
	FightRules = load({ "FightRules" }, "../shared/FightRules"),
	MatchLogic = load({ "MatchLogic" }, "../shared/MatchLogic"),
	Rng = load({ "Rng" }, "../shared/Rng"),
}
