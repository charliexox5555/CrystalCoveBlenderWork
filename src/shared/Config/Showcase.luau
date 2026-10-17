--!strict
-- Lobby Featured Collection showcase and capsule opening area (ShowcaseController, client-only).
-- The world pieces are built by tools/studio/build_featured_showcase.luau into Workspace.FeaturedShowcase;
-- these numbers drive the cosmetic demos placed on them. Pure data, no Roblox APIs.
local Showcase = {}

-- Which collection the stage headlines. BundleId points at DailyStore.Bundles; if that bundle ever gets
-- an `EndsAt` (unix seconds) the sign counts down to it, otherwise it shows LimitedText.
Showcase.Featured = {
	BundleId = "hollowlight_collection",
	Glassy = "hollowlight",
	Flyer = "lantern_skiff", -- shown as the Moonlantern Carriage
	Finisher = "lantern_eclipse",
	LimitedText = "LIMITED TIME",
}

-- Everything switches on when the camera is this close to a section and off past it (+ hysteresis).
Showcase.ActiveDistance = 130
Showcase.Hysteresis = 12
Showcase.FullDetailDistance = 55 -- farther than this, finishers run in low detail
Showcase.EmitterDistance = 75 -- ride / stage particles, trails, beams and lights
Showcase.AudioDistance = 60 -- the demo impact is only heard this close
Showcase.AudioVolume = 0.45 -- scale on the finisher's normal impact volume

-- Finisher demo: the Hollowlight bottle hangs on its hook, rises, swoops into the target and the real
-- Lantern Eclipse plays there. One loop is Idle + Rise + Fly + After seconds.
Showcase.Demo = {
	GlassyScale = 1.75, -- same as glassies in arenas
	StringLength = 1.6, -- hook to hang point
	IdleSeconds = 2.6,
	RiseSeconds = 0.5,
	RiseHeight = 1.6,
	FlySeconds = 0.6,
	AfterSeconds = 3.4, -- Eclipse (2.2 s) plus a breath before the bottle pops back
	RespawnSeconds = 0.35,
	SwayAngle = 0.12, -- radians, the bottle swinging on its hook while idle
	SwayHz = 0.45,
	FlySpin = 9, -- radians over the whole flight
	ShardSeconds = 0.9,
	ShardSpeed = 14,
	ShardGravity = 40,
}

-- The Hollowlight glassy turning above its pedestal.
Showcase.Glassy = { Scale = 1.75, SpinSpeed = 0.7, Bob = 0.25, BobHz = 0.35 }

-- Flyers: the carriage on the stage plus two rotating pads beside the Flyers stand, each carrying a
-- copy of the local player's avatar through every installed flyer in turn.
Showcase.Carriage = { YawSway = 0.18, YawHz = 0.08 }
Showcase.FlyerRotation = {
	Slots = 2, -- RiderSpot1..N in FeaturedShowcase.FlyersDisplay
	Seconds = 7, -- each flyer shows this long
	TransitionSeconds = 0.7,
	LeaveRise = 14, -- studs the outgoing flyer zooms up and away
	LeaveForward = 6,
	ArriveDrop = 6, -- studs the incoming flyer drops from
	ArriveSpin = 3, -- radians it turns while landing
	FlashSize = 7,
	FlashColor = "#FF8EA0", -- ruby light
}
Showcase.RiderYawSway = 0.12
Showcase.RiderYawHz = 0.11

-- Capsule opening stands, keyed by the stand's Category attribute. The build script places the
-- Assets.CrateMachines.<Category>_Coins machine on each; the prompt sits on its "PromptPoint".
-- Tab is the shop page the prompt opens.
Showcase.Stands = {
	Finishers = { Tab = "Finishers", ActionText = "Open Finishers", ObjectText = "Burst Capsule" },
	Rideables = { Tab = "Flyers", ActionText = "Open Flyers", ObjectText = "Sky Capsule" },
}
-- The stage prompt opens the bundle preview screen directly (falls back to the shop's Featured tab).
Showcase.FeaturedPrompt = {
	Bundle = "hollowlight_collection",
	Tab = "Featured",
	ActionText = "View Collection",
	ObjectText = "Hollowlight",
}
Showcase.PromptDistance = 10
Showcase.ShopWaitSeconds = 4 -- how long to wait for the shop to open before giving up on the tab switch

-- Examples floating above the stands.
Showcase.ExampleFinishers = { "glass_burst", "party_burst", "bubble_bloom", "brick_boom", "starfall" }
Showcase.FinisherExampleSeconds = 4.5
-- Off: the riders on the Flyers display behind the stand already show the flyers.
Showcase.FlyerStandExample = false
Showcase.FlyerExampleSeconds = 5
Showcase.FlyerExampleSpin = 0.6
Showcase.FlyerExampleRise = 0.45 -- seconds for a new example flyer to swoop up into place
Showcase.FlyerExampleDrop = 2.5 -- studs it rises from

return Showcase
