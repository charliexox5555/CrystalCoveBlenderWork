local Rules = if script
	then require(game.ServerScriptService.Server.Data.GroupRewardRules)
	else require("../server/Data/GroupRewardRules")
local Schema = if script
	then require(game.ServerScriptService.Server.Data.ProfileSchema)
	else require("../server/Data/ProfileSchema")
local Config = if script
	then require(game.ReplicatedStorage.Shared.Config.GroupReward)
	else require("../shared/Config/GroupReward")
local Roster = if script
	then require(game.ReplicatedStorage.Shared.Config.ReleaseRoster)
	else require("../shared/Config/ReleaseRoster")
return function(t, d)
	local available = {}
	for _, id in Roster.Ids do
		local def = d.Glassies.ById[id]
		if def and def.Rarity ~= "Starter" then
			available[id] = true
		end
	end
	t.test("group reward: the creator's group", function()
		t.eq(Config.GroupId, 11116787)
	end)
	t.test("group reward: stand state", function()
		t.eq(Rules.state({ GroupRewardClaimed = false }, false), "Join")
		t.eq(Rules.state({ GroupRewardClaimed = false }, nil), "Join") -- unknown is not a member
		t.eq(Rules.state({ GroupRewardClaimed = false }, true), "Ready")
		t.eq(Rules.state({ GroupRewardClaimed = true }, true), "Claimed")
		t.eq(Rules.state({ GroupRewardClaimed = true }, false), "Claimed") -- left the group later: still spent
	end)
	t.test("group reward: prompt results", function()
		t.eq(Rules.afterPrompt("Joined"), "Check")
		t.eq(Rules.afterPrompt("AlreadyMember"), "Check")
		t.eq(Rules.afterPrompt("JoinRequestPending"), "Stay")
		t.eq(Rules.afterPrompt("None"), "Stay")
		t.eq(Rules.afterPrompt("Bogus"), nil)
	end)
	t.test("group reward: Marble Kiln only where paid random items are allowed", function()
		t.eq(Rules.kiln(true), "Marbles")
		t.eq(Rules.kiln(false), "Coins")
		t.eq(Rules.kiln(nil), "Coins") -- policy unknown or failed: the safe Kiln
	end)
	t.test("group reward: membership from GetGroupsAsync", function()
		t.ok(Rules.inGroups({ { Id = 1 }, { Id = 11116787, Name = "x" } }, 11116787))
		t.ok(not Rules.inGroups({ { Id = 1 } }, 11116787))
		t.ok(not Rules.inGroups({}, 11116787))
		t.ok(not Rules.inGroups(nil, 11116787))
	end)
	t.test("group reward: claimed once ever, members only", function()
		local data = Schema.new(0)
		t.eq(data.Flags.GroupRewardClaimed, false)
		local ok, why = Rules.claim(data, false)
		t.ok(not ok and why == "NotMember")
		t.eq(data.Flags.GroupRewardClaimed, false)
		t.ok((Rules.claim(data, true)))
		t.eq(data.Flags.GroupRewardClaimed, true)
		ok, why = Rules.claim(data, true)
		t.ok(not ok and why == "Claimed", "a second claim always fails")
		t.ok(not Rules.claim(nil, true))
		t.ok(not Rules.claim({}, true))
	end)
	t.test("group reward: old profiles reconcile the flag", function()
		local old = Schema.new(0)
		old.Flags.GroupRewardClaimed = nil
		old.Version = 1
		Schema.reconcile(old, 0)
		t.eq(old.Flags.GroupRewardClaimed, false)
		local junk = Schema.new(0)
		junk.Flags.GroupRewardClaimed = "yes"
		Schema.reconcile(junk, 0)
		t.eq(junk.Flags.GroupRewardClaimed, false)
		local spent = Schema.new(0)
		spent.Flags.GroupRewardClaimed = true
		Schema.reconcile(spent, 0)
		t.eq(spent.Flags.GroupRewardClaimed, true)
	end)
	t.test("group reward: the roll uses that Kiln's odds", function()
		local mythic, rarities, rng = d.Balance.Crates.MarbleWeights.Mythic, {}, d.Rng.new(7)
		for _ = 1, 400 do
			local id, rainbow = Rules.roll("Marbles", available, rng)
			t.ok(available[id], "a Kiln glassy")
			t.eq(type(rainbow), "boolean")
			rarities[d.Glassies.ById[id].Rarity] = true
		end
		t.ok(rarities.Common and rarities.Rare and rarities.Epic, "spread across rarities")
		t.ok(mythic and mythic > 0, "the Marble Kiln has Mythics")
		-- The Marble Kiln is the better Kiln: more Epic-or-better than the Coin Kiln over the same draws.
		local function rare(kiln)
			local n, r = 0, d.Rng.new(11)
			for _ = 1, 2000 do
				local order = d.Balance.Rarities[d.Glassies.ById[Rules.roll(kiln, available, r)].Rarity].Order
				n += if order >= d.Balance.Rarities.Epic.Order then 1 else 0
			end
			return n
		end
		t.ok(rare("Marbles") > rare("Coins") * 2, "Marble Kiln odds, not Coin Kiln odds")
		t.eq(Rules.roll("Marbles", {}, d.Rng.new(1)), nil)
	end)
end
