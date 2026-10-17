--!strict
-- Crate Machines v2: the Blender-built opening machines for Finishers (Burst Dome) and Flyers (Cloud Globe).
-- Templates live in ReplicatedStorage.Assets.CrateMachines as "<Category>_<Currency>" (e.g. "Finishers_Coins").
-- Presentation only: nothing here changes prices, odds or rewards.
local CrateMachines = {}

CrateMachines.Version = 2
CrateMachines.Tag = "CrateMachine"
CrateMachines.AssetId = 115123551485957
CrateMachines.Categories = { "Finishers", "Rideables" }
CrateMachines.Currencies = { "Coins", "Marbles" }
CrateMachines.Names = { Finishers = "Burst Dome", Rideables = "Cloud Globe" }

-- Currency trim, matching the existing capsule tint (ItemPresentation.crate).
CrateMachines.Trim = { Coins = "#FFD98A", Marbles = "#93BCFF" }

-- Opening timeline for machine crates (seconds). Glassies keep Theme.Kiln.
CrateMachines.Opening = {
	ChargeSeconds = 1.5, -- anticipation: crank turns, contents churn faster, core heats, machine trembles
	ReleaseSeconds = 0.45, -- lid pops and spins up, core flashes
	FireSeconds = 2.0, -- then the reward cards launch from RevealCore
	SpinBoost = 7, -- idle spin speed multiplier at full charge
	CrankTurns = 2.5,
	ShakeStuds = 0.06,
	CoreGrow = 0.45,
	LidLiftStuds = 1.2, -- the opening stage frames this much headroom above the machine
	LidTurns = 1,
	PropellerBoost = 5,
}

-- Shop/opening preview camera for machines and kilns (CrateFraming): front-on, centred, same margin everywhere.
CrateMachines.Framing = {
	FieldOfView = 30,
	PitchDegrees = 12, -- look down slightly so the chamber contents read
	Fill = 0.92, -- the silhouette spans 92% of the tighter viewport axis
	LightDirection = Vector3.new(-0.6, -1, 1.2), -- light the -Z front faces
}

-- Idle motion (radians per second unless noted). Per-part speeds come from template attributes.
CrateMachines.Idle = {
	SwirlSpeed = 0.22,
	OrbitSpeed = 1.6,
	BobStuds = 0.12,
	BobSpeed = 1.8,
	BlinkSpeed = 2.4,
	PulseSpeed = 1.3,
	CrankIdleSpeed = 0.35,
}

-- Client-only lobby ambience around placed machines.
CrateMachines.World = {
	ActiveDistance = 90, -- animate and show effects only when the local character is this close
	ScanSeconds = 0.5,
	LightRange = 10,
	LightBrightness = 1.4,
	SparkleRate = 5,
}

function CrateMachines.templateName(category: string, currency: string): string
	return category .. "_" .. currency
end

return CrateMachines
