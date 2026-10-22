--!strict
-- What the client loads when, in three tiers (ReplicatedFirst LoadingScreen/Loader; docs/ui/LOADING_SCREEN.md).
--   Essential  behind the loading screen; its progress is the bar. Only what the first minute shows.
--   Soon       right after the screen closes, two at a time: the Shop, the first fight, the player's glassies.
--   Later      idle background, one at a time, with a gap: everything else (anything not listed lands here).
-- Each tier is a list of items. An item listed in an earlier tier is skipped by the later ones.
--   "ui:<prefix>"           Shared.Config.UIAssets ids whose key starts with <prefix> ("ui:" = all of them)
--   "screen:<Name>"         a StarterGui screen template (its images, fonts and any viewport models)
--   "asset:<Folder>[/<Child>]"  ReplicatedStorage.Assets models (a folder = one job per child)
--   "rs:<Name>"             any other ReplicatedStorage child (the Clash Stand)
--   "images:<Config>"       every rbxassetid in Shared.Config.<Config>, as images ("images:<Config>/<Key>/..." takes
--                           only that part of the table, e.g. "images:ItemIcons/Small")
--   "sounds:<Config>"       ... as Sounds (a bare id string only ever loads as an image)
--   "anims:<Config>"        ... the ids under R15 / R6 / Animation keys, as Animations
--   "id:rbxassetid://<n>"   one image id, for art that lives in no config yet
--   "fonts"                 the UI fonts (Theme.Fonts)
--   "spawn"                 the streamed-in world within SpawnRadius studs of the spawn
--   "lobby"                 the rest of the streamed-in world
--   "owned"                 the player's glassies and equipped cosmetics (filled in from ProfileSnapshot)
-- OnDemand: when a screen with this name opens, or a PlayerGui attribute with this name turns true, its items jump
-- the queue. Remote payloads (Kiln/crate results, roll offers, the welcome reveal) do the same for the glassies,
-- flyers and finishers they name.
local LoadTiers = {}

LoadTiers.Order = { "Essential", "Soon", "Later" }

LoadTiers.SpawnRadius = 150 -- studs; the lobby view from the spawn pad, Kilns and arena sign included
LoadTiers.CharacterWait = 6 -- seconds to wait for the character before using the SpawnLocation instead

-- Workers = PreloadAsync calls in flight; Gap = seconds between jobs per worker (keeps the frame smooth).
-- Urgent is the lane on-demand items jump into.
LoadTiers.Lanes = {
	Urgent = { Workers = 4, Gap = 0 },
	Essential = { Workers = 6, Gap = 0 },
	Soon = { Workers = 2, Gap = 0 },
	Later = { Workers = 1, Gap = 0.05, BusyGap = 0.4 }, -- BusyGap while the player is in a match
}

LoadTiers.BatchSize = 24 -- image / sound / animation ids per PreloadAsync call
LoadTiers.RetryDelay = 3 -- a job with a failed asset runs once more this long after, in the Later lane
LoadTiers.SkipAssets = { CombatReleasePreview = true } -- review-only models, never shown to players

LoadTiers.Tiers = {
	Essential = {
		"fonts",
		-- HUD, top bar, buttons, hearts, coins and Marbles, the onboarding pointer and beam chevron.
		"ui:hud/",
		"ui:icon/",
		"ui:topbar/",
		"ui:button/",
		"ui:onboarding/",
		"ui:reward/",
		"ui:bar/",
		"ui:tag/",
		"ui:panel/title_",
		"ui:panel/pane_",
		"ui:screens/daily_rewards/",
		"ui:screens/playtime_rewards/glow",
		"screen:LobbyHUD",
		"screen:WelcomeScreen",
		"screen:DailyRewardsScreen",
		-- The Coin Kiln picture on the welcome card and the Daily pull cells (decision 113).
		"images:ItemIcons/Small/Machines/Glassies:Coins",
		-- The Daily Rewards glassies' pictures (Day 2 and Day 7 cells; the screen can open by itself on join, decision 115).
		"images:ItemIcons/Small/Glassies/whiskers",
		"images:ItemIcons/Small/Glassies/midnight_moon",
		-- The Featured stage is in view from the spawn.
		"asset:Glassies/hollowlight",
		"asset:Seasonal/Hollowlight",
		"spawn",
	},
	Soon = {
		"owned",
		-- The Shop and its opening.
		"screen:KilnScreen",
		"screen:KilnRevealScreen",
		"ui:kiln/",
		"ui:card/",
		"ui:tile/",
		"ui:tab/",
		"ui:panel/",
		"ui:banner/",
		"images:KilnAssets",
		"images:PrizeCardAssets",
		"asset:Kilns",
		"asset:Crates",
		"asset:CrateMachines",
		-- Glassy pictures: the Shop's Featured cards and prize carousels, the Inventory grid, the 10-pull reels.
		"images:ItemIcons/Small/Glassies",
		-- The Starter Pack's three exclusives (decision 117): their pictures sell the pack in the Shop, and the
		-- glassy, flyer and finisher models back its preview and the first ride / show after a purchase.
		"images:ItemIcons/Small/Rideables/dawn_kite",
		"images:ItemIcons/Small/Finishers/daybreak",
		"asset:Glassies/sunny_rooster",
		"asset:Rideables/dawn_kite",
		-- The first fight: queue, roll, stand, billboards, hits, cracks, the shatter, powers.
		"screen:QueuePanel",
		"screen:RollScreen",
		"screen:RollInfoScreen",
		"screen:FightHud",
		"screen:MatchNotice",
		"screen:RoundEnd",
		"screen:ResultsScreen",
		"rs:ClashStand",
		"asset:RideStand",
		"asset:UI",
		"asset:VFX/Combat",
		"asset:VFX/RoundHeroV2",
		"sounds:Audio",
		"sounds:PowerAudio",
		"asset:VFX/HollowlightPrototype",
		"screen:PlaytimeRewardsScreen",
		"ui:screens/playtime_rewards/",
		"lobby",
	},
	-- Everything not listed above also runs here, after these.
	Later = {
		-- Flyer, finisher and machine pictures (512 px; the 1024 px ones load when a big slot shows them).
		"images:ItemIcons/Small",
		"asset:Glassies",
		"asset:Rideables",
		"anims:RideAnimations",
		"anims:RideFamilies",
		"sounds:RideFamilies",
		"asset:RoundFinishers",
		"images:FinisherShows",
		"asset:VFX",
		"asset:Seasonal",
		"asset:WorldKit",
		"screen:",
		"ui:",
	},
}

-- Screen (Window / ScreenGui) names and PlayerGui attributes -> items that jump the queue.
LoadTiers.OnDemand = {
	KilnScreen = {
		"screen:KilnScreen",
		"screen:KilnRevealScreen",
		"ui:kiln/",
		"ui:card/",
		"ui:tile/",
		"ui:tab/",
		"images:KilnAssets",
		"images:PrizeCardAssets",
		"asset:Kilns",
		"asset:Crates",
		"asset:CrateMachines",
		"images:ItemIcons/Small",
	},
	KilnRevealScreen = { "screen:KilnRevealScreen", "images:PrizeCardAssets", "asset:Kilns" },
	CollectionScreen = {
		"screen:CollectionScreen",
		"screen:GlassyDetailScreen",
		"ui:tile/",
		"owned",
		"images:ItemIcons/Small/Glassies",
	},
	ProfileScreen = { "screen:ProfileScreen", "ui:screens/profile/", "images:ItemIcons/Small" },
	SettingsScreen = { "screen:SettingsScreen", "ui:screens/settings/" },
	CodesScreen = { "screen:CodesScreen", "ui:screens/codes/" },
	PlaytimeRewardsScreen = { "screen:PlaytimeRewardsScreen", "ui:screens/playtime_rewards/" },
	RewardsScreen = { "screen:RewardsScreen" },
	QuestsScreen = { "screen:QuestsScreen" },
	IndexScreen = { "screen:IndexScreen" },
	-- PlayerGui attributes (MatchController): stepping on a pad loads the fight first.
	Queued = {
		"screen:QueuePanel",
		"screen:RollScreen",
		"screen:RollInfoScreen",
		"screen:FightHud",
		"screen:MatchNotice",
		"screen:RoundEnd",
		"rs:ClashStand",
		"asset:RideStand",
		"asset:UI",
		"asset:VFX/Combat",
		"asset:VFX/RoundHeroV2",
		"sounds:Audio",
		"sounds:PowerAudio",
		"owned",
	},
	InMatch = { "screen:ResultsScreen", "asset:VFX/Combat", "sounds:Audio", "sounds:PowerAudio" },
}

-- Remotes whose payloads name glassies / flyers / finishers to fetch now (any string that is the name of a model in
-- these Assets folders). ProfileSnapshot feeds "owned" instead.
LoadTiers.HintRemotes = { "OnboardingReveal", "KilnResult", "RollOffers", "CosmeticResult", "StoreResult" }
LoadTiers.HintFolders = { "Glassies", "Rideables", "RoundFinishers", "Seasonal" }
-- Extra items per hinted name, e.g. its pre-rendered icon: "images:ItemIcons/Small/{category}/{name}".
-- {name} = the model name, {category} = HintCategories[its Assets folder] (a template with {category} is skipped for
-- folders not listed). Ids with a colon ("Machines/Glassies:Coins") are fine in a path.
LoadTiers.HintItems = { "images:ItemIcons/Small/{category}/{name}" }
LoadTiers.HintCategories = { Glassies = "Glassies", Rideables = "Rideables", RoundFinishers = "Finishers" }

return LoadTiers
