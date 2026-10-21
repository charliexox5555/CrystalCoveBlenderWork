-- Group reward rules (decision 114, docs/design/GROUP_REWARD.md). Pure and Lune-tested: the stand's state, what a
-- join prompt's result means, which Kiln the gift opens (policy), the once-ever claim and the roll.
-- GroupRewardService only checks membership with Roblox, grants and plays the opening.
local Shared = if script then game.ReplicatedStorage.Shared else nil
local Formula = if Shared then require(Shared.Formula) else require("../../shared/Formula")
local Crates = if Shared then require(Shared.CrateRules) else require("../../shared/CrateRules")
local Rules = {}

-- Join (not a member: the prompt asks them to join) -> Ready (member, gift waiting) -> Claimed (spent, forever).
Rules.States = { "Join", "Ready", "Claimed" }

-- `member` is true only when the server confirmed membership; false or nil (unknown, a failed check) means Join.
function Rules.state(flags, member)
	if type(flags) == "table" and flags.GroupRewardClaimed == true then
		return "Claimed"
	end
	return if member == true then "Ready" else "Join"
end

-- GroupService:PromptJoinAsync results (Enum.GroupMembershipStatus names). Joined / AlreadyMember: ask the server to
-- check; JoinRequestPending (a group with join requests) and None (closed, not eligible): nothing to claim yet.
Rules.PromptResults = { None = "Stay", Joined = "Check", JoinRequestPending = "Stay", AlreadyMember = "Check" }

function Rules.afterPrompt(status)
	return Rules.PromptResults[status]
end

-- The gift is the Marble Kiln, a paid random item. Only where PolicyService says paid random items are allowed
-- (true, not unknown) does it open the Marble Kiln; everyone else gets a Coin Kiln open (AGENTS.md safety rules).
function Rules.kiln(paidRandomAllowed)
	return if paidRandomAllowed == true then "Marbles" else "Coins"
end

-- Membership from a GroupService:GetGroupsAsync list (tables with an Id), the server's uncached re-check.
function Rules.inGroups(groups, groupId)
	if type(groups) ~= "table" then
		return false
	end
	for _, group in groups do
		if type(group) == "table" and tonumber(group.Id) == groupId then
			return true
		end
	end
	return false
end

-- The claim itself: once ever, members only. Marks the profile before anything is granted, so a second claim (another
-- tap, another server after a rejoin) always fails. Returns ok, reason ("Claimed" | "NotMember" | "NoProfile").
function Rules.claim(data, member)
	if type(data) ~= "table" or type(data.Flags) ~= "table" then
		return false, "NoProfile"
	end
	if data.Flags.GroupRewardClaimed == true then
		return false, "Claimed"
	end
	if member ~= true then
		return false, "NotMember"
	end
	data.Flags.GroupRewardClaimed = true
	return true, nil
end

-- One open of `kiln` ("Marbles" | "Coins") over the installed Kiln glassies (`available` = KilnService:Pool()), with
-- the same odds a paid pull of that Kiln has. Returns id, rainbow.
function Rules.roll(kiln, available, rng)
	local odds = Crates.odds("Glassies", kiln, available, Formula.kilnOdds(available))
	if #odds == 0 then
		return nil, false
	end
	return Crates.roll(odds, rng), Formula.rollRainbow(rng)
end

return Rules
