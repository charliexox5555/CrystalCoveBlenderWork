-- Group reward (decision 114, docs/design/GROUP_REWARD.md): a stand in the lobby. Join the creator's group from its
-- prompt, then claim one free Marble Kiln open (a Coin Kiln open where paid random items are restricted), once ever.
-- Rules in server/Data/GroupRewardRules; the stand itself lives in the place (Workspace.Lobby.GroupRewardStand).
return {
	GroupId = 11116787,
	-- The stand model carries this CollectionService tag; its ProximityPrompt is named PromptName.
	StandTag = "GroupRewardStand",
	PromptName = "GroupReward",
	-- Server re-checks membership this many times after a join (the group service can lag a moment behind the prompt).
	CheckTries = 3,
	CheckRetrySeconds = 2,
	-- Rate limits per player (RemoteGuard).
	PromptRateSeconds = 2,
	ClaimRateSeconds = 1.5,
	-- Client: how long to wait for the server to confirm a join before giving up quietly, and how long one join prompt
	-- blocks another (a prompt that never answers can't lock the stand).
	ConfirmWaitSeconds = 10,
	PromptGuardSeconds = 30,
	-- Stand motion (client, skipped under Reduced Motion): the glass heart bobs and turns, faster when a gift is ready.
	BobStuds = 0.35,
	BobSeconds = { Join = 3.2, Ready = 1.6 },
	TurnSeconds = { Join = 14, Ready = 6 },
}
