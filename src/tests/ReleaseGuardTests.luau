-- Release guard (docs/testing/release_candidate/CHECKLIST.md): nothing free or test-only is live. A playtest that
-- turns one of these on again has to change this suite on purpose.
local Schema = if script
	then require(game.ServerScriptService.Server.Data.ProfileSchema)
	else require("../server/Data/ProfileSchema")
local Rules = if script
	then require(game.ServerScriptService.Server.Data.RetentionRules)
	else require("../server/Data/RetentionRules")
local Testing = if script
	then require(game:GetService("ReplicatedStorage").Shared.Config.Testing)
	else require("../shared/Config/Testing")
local Retention = if script
	then require(game:GetService("ReplicatedStorage").Shared.Config.Retention)
	else require("../shared/Config/Retention")
return function(t, d)
	t.test("release guard: tester Marbles are off", function()
		t.eq(Testing.TesterMarbles.Enabled, false, "Config/Testing.TesterMarbles must be off for release")
		t.eq(Schema.testerGrant(Schema.new(0), Testing.TesterMarbles), 0)
	end)
	t.test("release guard: test codes are Studio-only and refused on live servers", function()
		local now = 1792000000
		for code, def in Retention.Codes do
			if code:find("^TEST") or code:find("^STUDIO") then
				t.ok(def.StudioOnly == true, code .. " must be StudioOnly")
			end
			if def.StudioOnly then
				t.eq(Rules.redeem(Schema.new(0), code, false, now), false, code .. " works on a live server")
			end
			t.ok(def.Reward.Marbles == nil or def.StudioOnly == true, code .. " gives free Marbles live")
		end
	end)
	t.test("release guard: Studio and live data never share a store", function()
		local data = d.Balance.Data
		t.ok(data.StoreName ~= data.StudioStoreName, "Studio and live profile stores must differ")
		t.ok(data.StudioMock == true, "Studio tests run on mock profiles")
	end)
end
