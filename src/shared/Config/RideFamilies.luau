--!strict
-- Rider animation families (docs/art/FLYERS_V3.md "Rider animations" and "Adding a flyer"). Pure data.
-- A family is a riding style shared by many flyers. Each has the clips Idle (loop), LeanLeft (loop; LeanRight is
-- its mirror unless authored), Launch and Land (one-shots). The same data is sampled by RideKeyframes for the
-- uploaded KeyframeSequences (tools/studio/build_ride_animations.luau) and for the code fallback in RidePose, so
-- the two never drift apart.
--
-- Angles are degrees per channel, {x, y, z} in the parent part's frame (x pitch: positive tips limbs forward and
-- torsos back; y yaw: positive turns left; z roll: positive tips left; left limbs swing out with negative z, right
-- limbs with positive z). Channels: Root, Spine, Head, LeftArm, RightArm, LeftElbow, RightElbow, LeftHip,
-- RightHip, LeftKnee, RightKnee, LeftAnkle, RightAnkle. R6 rigs fold Spine into Root and part of each elbow and
-- knee into the shoulder and hip (R6KneeFold, R6ElbowFold).
--   Base: the family pose.  Offset: added for the whole clip.  Waves: { channel, axis 1..3, amplitude, cycles per
--   clip (whole numbers so loops are seamless), phase 0..1 }.  Keys: { time 0..1, { channel = delta } } smoothed.
local F = {}

F.Families = {
	-- Standing on a board or a creature's back: balance crouch, arms out. Skyboard, Prism Ray.
	Surf = {
		Contact = "Feet",
		R6KneeFold = 0.5,
		Base = {
			Spine = { -4, -10, 0 },
			Head = { 2, 10, 0 },
			LeftArm = { 10, -6, -50 },
			RightArm = { 16, 6, 46 },
			LeftElbow = { 14, 0, 0 },
			RightElbow = { 18, 0, 0 },
			LeftHip = { 20, -10, 0 },
			RightHip = { 24, 10, 0 },
			LeftKnee = { -38, 0, 0 },
			RightKnee = { -46, 0, 0 },
			LeftAnkle = { 18, 0, 0 },
			RightAnkle = { 22, 0, 0 },
		},
		Clips = {
			Idle = {
				Seconds = 2.8,
				Waves = {
					{ "Spine", 1, 2, 2, 0 }, -- breathing
					{ "LeftKnee", 1, 6, 1, 0 }, -- weight shifts from leg to leg
					{ "RightKnee", 1, 6, 1, 0.5 },
					{ "Root", 3, 2, 1, 0.1 },
					{ "Spine", 3, 3, 1, 0.25 }, -- balance sway, head follows a beat later
					{ "Head", 3, -2, 1, 0.38 },
					{ "Head", 2, 5, 1, 0.5 },
					{ "LeftArm", 3, 7, 1, 0.12 }, -- arms balance with follow-through
					{ "RightArm", 3, 7, 1, 0.62 },
					{ "LeftArm", 1, 4, 2, 0.2 },
					{ "RightArm", 1, 4, 2, 0.7 },
					{ "LeftElbow", 1, 6, 1, 0.3 },
					{ "RightElbow", 1, 6, 1, 0.8 },
				},
			},
			LeanLeft = {
				Seconds = 1.4,
				Offset = {
					Root = { 0, 4, 10 },
					Spine = { 0, 0, 6 },
					Head = { 0, 0, -9 },
					LeftArm = { -6, 0, 18 },
					RightArm = { 6, 0, 16 },
					LeftKnee = { -14, 0, 0 },
					LeftHip = { 8, 0, 0 },
					RightKnee = { 8, 0, 0 },
				},
				Waves = { { "Spine", 1, 2, 1, 0 }, { "Head", 2, 3, 1, 0.3 } },
			},
			Launch = {
				Seconds = 0.8,
				Keys = {
					{ 0, {} },
					{
						0.28,
						{
							LeftKnee = { -30, 0, 0 },
							RightKnee = { -30, 0, 0 },
							LeftHip = { 16, 0, 0 },
							RightHip = { 16, 0, 0 },
							Spine = { -10, 0, 0 },
							LeftArm = { -20, 0, 22 },
							RightArm = { -20, 0, -22 },
						},
					},
					{
						0.55,
						{
							LeftKnee = { 24, 0, 0 },
							RightKnee = { 24, 0, 0 },
							LeftHip = { -8, 0, 0 },
							RightHip = { -8, 0, 0 },
							Spine = { 6, 0, 0 },
							Head = { 8, 0, 0 },
							LeftArm = { 40, 0, -25 },
							RightArm = { 40, 0, 25 },
						},
					},
					{ 1, {} },
				},
			},
			Land = {
				Seconds = 0.6,
				Keys = {
					{ 0, {} },
					{
						0.3,
						{
							LeftKnee = { -32, 0, 0 },
							RightKnee = { -32, 0, 0 },
							LeftHip = { 18, 0, 0 },
							RightHip = { 18, 0, 0 },
							Spine = { -12, 0, 0 },
							Head = { 6, 0, 0 },
							LeftArm = { 0, 0, -15 },
							RightArm = { 0, 0, 15 },
						},
					},
					{ 0.62, { LeftKnee = { 6, 0, 0 }, RightKnee = { 6, 0, 0 }, Spine = { 3, 0, 0 } } },
					{ 1, {} },
				},
			},
		},
	},

	-- No flyer (decision 95): standing tall in the air on a faint hover pad, a still, confident stand.
	Stand = {
		Contact = "Feet",
		R6KneeFold = 0.5,
		Base = {
			Spine = { 3, 0, 0 },
			Head = { -3, 0, 0 },
			LeftArm = { -4, 0, -12 },
			RightArm = { -4, 0, 12 },
			LeftElbow = { 12, 0, 0 },
			RightElbow = { 12, 0, 0 },
			LeftHip = { 0, -4, -5 },
			RightHip = { 0, 4, 5 },
			LeftKnee = { -4, 0, 0 },
			RightKnee = { -4, 0, 0 },
			LeftAnkle = { 4, 0, 5 },
			RightAnkle = { 4, 0, -5 },
		},
		Clips = {
			Idle = {
				Seconds = 3.6,
				Waves = {
					{ "Spine", 1, 1.5, 2, 0 }, -- calm breathing
					{ "Root", 3, 1.2, 1, 0 }, -- slow weight shift
					{ "LeftKnee", 1, 3, 1, 0 },
					{ "RightKnee", 1, 3, 1, 0.5 },
					{ "Head", 2, 6, 1, 0.3 }, -- looks around the arena
					{ "Head", 1, 2, 2, 0.1 },
					{ "LeftArm", 3, 2.5, 1, 0.15 },
					{ "RightArm", 3, 2.5, 1, 0.65 },
				},
			},
			LeanLeft = {
				Seconds = 1.8,
				Offset = {
					Root = { 0, 2, 5 },
					Spine = { 0, 0, 3 },
					Head = { 0, 0, -5 },
					LeftArm = { 0, 0, 6 },
					RightArm = { 0, 0, 6 },
				},
				Waves = { { "Spine", 1, 1, 1, 0 } },
			},
			Launch = {
				Seconds = 0.7,
				Keys = {
					{ 0, {} },
					{
						0.3,
						{
							LeftKnee = { -20, 0, 0 },
							RightKnee = { -20, 0, 0 },
							LeftHip = { 10, 0, 0 },
							RightHip = { 10, 0, 0 },
							Spine = { -6, 0, 0 },
						},
					},
					{
						0.6,
						{ Spine = { 4, 0, 0 }, Head = { 4, 0, 0 }, LeftArm = { 0, 0, -10 }, RightArm = { 0, 0, 10 } },
					},
					{ 1, {} },
				},
			},
			Land = {
				Seconds = 0.5,
				Keys = {
					{ 0, {} },
					{
						0.35,
						{
							LeftKnee = { -18, 0, 0 },
							RightKnee = { -18, 0, 0 },
							LeftHip = { 9, 0, 0 },
							RightHip = { 9, 0, 0 },
							Spine = { -5, 0, 0 },
						},
					},
					{ 1, {} },
				},
			},
		},
	},

	-- Sitting in a soft seat, legs forward. Cloud Cushion.
	Sit = {
		Contact = "Seat",
		R6KneeFold = 0,
		Base = {
			Spine = { -5, 0, 0 },
			LeftArm = { 0, 0, -6 },
			RightArm = { 0, 0, 6 },
			LeftElbow = { 18, 0, 0 },
			RightElbow = { 18, 0, 0 },
			LeftHip = { 85, -10, 0 },
			RightHip = { 85, 10, 0 },
			LeftKnee = { -80, 0, 0 },
			RightKnee = { -80, 0, 0 },
			LeftAnkle = { 10, 0, 0 },
			RightAnkle = { 10, 0, 0 },
		},
		Clips = {
			Idle = {
				Seconds = 3.2,
				Waves = {
					{ "Spine", 1, 2.5, 2, 0 }, -- breathing
					{ "Spine", 3, 2.5, 1, 0 },
					{ "Head", 2, 9, 1, 0.3 }, -- looking around
					{ "Head", 1, 3, 2, 0.1 },
					{ "LeftKnee", 1, 9, 2, 0 }, -- happy kicking feet
					{ "RightKnee", 1, 9, 2, 0.5 },
					{ "LeftArm", 1, 4, 1, 0.2 },
					{ "RightArm", 1, 4, 1, 0.7 },
				},
			},
			LeanLeft = {
				Seconds = 1.6,
				Offset = {
					Root = { 0, 3, 8 },
					Spine = { 0, 0, 6 },
					Head = { 0, 0, -7 },
					LeftArm = { 0, 0, 8 },
					RightArm = { 6, 0, 6 },
				},
				Waves = { { "Spine", 1, 2, 1, 0 } },
			},
			Launch = {
				Seconds = 0.8,
				Keys = {
					{ 0, {} },
					{
						0.28,
						{
							Spine = { -12, 0, 0 },
							Head = { -6, 0, 0 },
							LeftArm = { 10, 0, 0 },
							RightArm = { 10, 0, 0 },
							LeftKnee = { -8, 0, 0 },
							RightKnee = { -8, 0, 0 },
						},
					},
					{
						0.55,
						{
							Spine = { 10, 0, 0 },
							Head = { 8, 0, 0 },
							LeftArm = { 30, 0, -30 },
							RightArm = { 30, 0, 30 },
							LeftKnee = { 25, 0, 0 },
							RightKnee = { 25, 0, 0 },
						},
					},
					{ 1, {} },
				},
			},
			Land = {
				Seconds = 0.6,
				Keys = {
					{ 0, {} },
					{
						0.3,
						{
							Spine = { -10, 0, 0 },
							Head = { -6, 0, 0 },
							LeftKnee = { -10, 0, 0 },
							RightKnee = { -10, 0, 0 },
						},
					},
					{ 0.65, { Spine = { 3, 0, 0 } } },
					{ 1, {} },
				},
			},
		},
	},

	-- Kneeling low on a small craft (one knee down, hands forward). For coming low-profile flyers.
	Kneel = {
		Contact = "Low",
		R6KneeFold = 0.4,
		Base = {
			Spine = { -10, 0, 0 },
			Head = { 8, 0, 0 },
			LeftArm = { 35, 0, -12 },
			RightArm = { 35, 0, 12 },
			LeftElbow = { 35, 0, 0 },
			RightElbow = { 35, 0, 0 },
			LeftHip = { 75, -6, 0 },
			LeftKnee = { -95, 0, 0 },
			LeftAnkle = { 20, 0, 0 },
			RightHip = { -5, 6, 0 },
			RightKnee = { -110, 0, 0 },
			RightAnkle = { 40, 0, 0 },
		},
		Clips = {
			Idle = {
				Seconds = 2.6,
				Waves = {
					{ "Spine", 1, 2, 2, 0 },
					{ "Spine", 3, 2.5, 1, 0.2 },
					{ "Head", 2, 7, 1, 0.4 },
					{ "LeftArm", 1, 4, 1, 0.1 },
					{ "RightArm", 1, 4, 1, 0.6 },
					{ "LeftElbow", 1, 5, 2, 0.3 },
					{ "RightElbow", 1, 5, 2, 0.8 },
				},
			},
			LeanLeft = {
				Seconds = 1.4,
				Offset = {
					Root = { 0, 4, 10 },
					Spine = { 0, 0, 6 },
					Head = { 0, 0, -9 },
					LeftArm = { -6, 0, 12 },
					RightArm = { 6, 0, 12 },
				},
				Waves = { { "Spine", 1, 2, 1, 0 } },
			},
			Launch = {
				Seconds = 0.8,
				Keys = {
					{ 0, {} },
					{
						0.28,
						{
							Spine = { -10, 0, 0 },
							LeftKnee = { -12, 0, 0 },
							LeftArm = { -15, 0, 0 },
							RightArm = { -15, 0, 0 },
						},
					},
					{
						0.55,
						{ Spine = { 8, 0, 0 }, Head = { 8, 0, 0 }, LeftArm = { 30, 0, -20 }, RightArm = { 30, 0, 20 } },
					},
					{ 1, {} },
				},
			},
			Land = {
				Seconds = 0.6,
				Keys = {
					{ 0, {} },
					{ 0.3, { Spine = { -12, 0, 0 }, Head = { 6, 0, 0 }, LeftKnee = { -10, 0, 0 } } },
					{ 0.65, { Spine = { 3, 0, 0 } } },
					{ 1, {} },
				},
			},
		},
	},

	-- Standing and holding a handlebar. Rocket Skiff. Hands are authored onto the standard standing grips below
	-- and locked onto each flyer's GripL/GripR attachments with IK where the rig supports it.
	HandleStand = {
		Contact = "Feet",
		R6KneeFold = 0.5,
		R6ElbowFold = 0.6,
		Handles = true,
		Base = {
			Spine = { -12, 0, 0 },
			Head = { 6, 0, 0 },
			LeftArm = { 54, -8, 8 },
			RightArm = { 54, 8, -8 },
			LeftElbow = { 30, 0, 0 },
			RightElbow = { 30, 0, 0 },
			LeftHip = { 16, 0, 0 },
			RightHip = { 22, 0, 0 },
			LeftKnee = { -32, 0, 0 },
			RightKnee = { -44, 0, 0 },
			LeftAnkle = { 16, 0, 0 },
			RightAnkle = { 22, 0, 0 },
		},
		Clips = {
			Idle = {
				Seconds = 2.0,
				Waves = {
					{ "Spine", 1, 2, 2, 0 }, -- breathing
					{ "Spine", 1, 0.8, 8, 0 }, -- engine buzz
					{ "Head", 2, 7, 1, 0.25 }, -- looking around past the handlebar
					{ "Head", 1, 3, 2, 0.6 },
					{ "LeftKnee", 1, 5, 1, 0 },
					{ "RightKnee", 1, 5, 1, 0.5 },
					{ "LeftElbow", 1, 3, 2, 0.1 },
					{ "RightElbow", 1, 3, 2, 0.6 },
				},
			},
			LeanLeft = {
				Seconds = 1.2,
				Offset = {
					Root = { 0, 6, 10 },
					Spine = { 0, 4, 6 },
					Head = { 0, 4, -8 },
					LeftArm = { -6, 0, 0 },
					RightArm = { 6, 0, 0 },
					LeftElbow = { 12, 0, 0 },
					RightElbow = { -8, 0, 0 },
					LeftKnee = { -12, 0, 0 },
					RightKnee = { 8, 0, 0 },
				},
				Waves = { { "Spine", 1, 1.5, 1, 0 }, { "Spine", 1, 0.8, 5, 0 } },
			},
			Launch = {
				Seconds = 0.8,
				Keys = {
					{ 0, {} },
					{
						0.28,
						{
							LeftKnee = { -25, 0, 0 },
							RightKnee = { -25, 0, 0 },
							LeftHip = { 12, 0, 0 },
							RightHip = { 12, 0, 0 },
							Spine = { -8, 0, 0 },
							LeftElbow = { 15, 0, 0 },
							RightElbow = { 15, 0, 0 },
						},
					},
					{
						0.55,
						{
							LeftKnee = { 20, 0, 0 },
							RightKnee = { 20, 0, 0 },
							LeftHip = { -6, 0, 0 },
							RightHip = { -6, 0, 0 },
							Spine = { 8, 0, 0 },
							Head = { 8, 0, 0 },
							LeftElbow = { -10, 0, 0 },
							RightElbow = { -10, 0, 0 },
						},
					},
					{ 1, {} },
				},
			},
			Land = {
				Seconds = 0.6,
				Keys = {
					{ 0, {} },
					{
						0.3,
						{
							LeftKnee = { -28, 0, 0 },
							RightKnee = { -28, 0, 0 },
							LeftHip = { 14, 0, 0 },
							RightHip = { 14, 0, 0 },
							Spine = { -10, 0, 0 },
							LeftElbow = { 12, 0, 0 },
							RightElbow = { 12, 0, 0 },
						},
					},
					{ 0.62, { LeftKnee = { 5, 0, 0 }, RightKnee = { 5, 0, 0 }, Spine = { 3, 0, 0 } } },
					{ 1, {} },
				},
			},
		},
	},

	-- Seated and holding a handlebar in front. Built for the Moonlantern Carriage pose (workstream I).
	HandleSit = {
		Contact = "Seat",
		R6KneeFold = 0,
		R6ElbowFold = 0.6,
		Handles = true,
		Base = {
			Spine = { -6, 0, 0 },
			Head = { 4, 0, 0 },
			LeftArm = { 82, -4, 22 }, -- hands inward onto the carriage grips (+-0.62)
			RightArm = { 82, 4, -22 },
			LeftElbow = { 22, 0, 0 },
			RightElbow = { 22, 0, 0 },
			LeftHip = { 108, -6, 0 }, -- legs reach forward-up toward a footrest (measured on the v5 carriage)
			RightHip = { 108, 6, 0 },
			LeftKnee = { -12, 0, 0 },
			RightKnee = { -12, 0, 0 },
			LeftAnkle = { 12, 0, 0 },
			RightAnkle = { 12, 0, 0 },
		},
		Clips = {
			Idle = {
				Seconds = 2.6,
				Waves = {
					{ "Spine", 1, 2, 2, 0 },
					{ "Spine", 3, 2, 1, 0.1 },
					{ "Head", 2, 8, 1, 0.3 },
					{ "Head", 1, 3, 2, 0.6 },
					{ "LeftKnee", 1, 4, 1, 0 },
					{ "RightKnee", 1, 4, 1, 0.5 },
					{ "LeftElbow", 1, 3, 2, 0.15 },
					{ "RightElbow", 1, 3, 2, 0.65 },
				},
			},
			LeanLeft = {
				Seconds = 1.4,
				Offset = {
					Root = { 0, 4, 8 },
					Spine = { 0, 4, 6 },
					Head = { 0, 4, -7 },
					LeftElbow = { 10, 0, 0 },
					RightElbow = { -6, 0, 0 },
				},
				Waves = { { "Spine", 1, 1.5, 1, 0 } },
			},
			Launch = {
				Seconds = 0.8,
				Keys = {
					{ 0, {} },
					{
						0.28,
						{
							Spine = { -10, 0, 0 },
							Head = { -5, 0, 0 },
							LeftElbow = { 12, 0, 0 },
							RightElbow = { 12, 0, 0 },
						},
					},
					{
						0.55,
						{ Spine = { 8, 0, 0 }, Head = { 8, 0, 0 }, LeftKnee = { 18, 0, 0 }, RightKnee = { 18, 0, 0 } },
					},
					{ 1, {} },
				},
			},
			Land = {
				Seconds = 0.6,
				Keys = {
					{ 0, {} },
					{
						0.3,
						{
							Spine = { -9, 0, 0 },
							Head = { -5, 0, 0 },
							LeftElbow = { 10, 0, 0 },
							RightElbow = { 10, 0, 0 },
						},
					},
					{ 0.65, { Spine = { 3, 0, 0 } } },
					{ 1, {} },
				},
			},
		},
	},
}

-- Which family each flyer rides with (keyed by the ride's PoseId or RideId). A new flyer picks a family here
-- (see FLYERS_V3.md "Adding a flyer").
F.Flyers = {
	skyboard = { Family = "Surf" },
	prism_ray = { Family = "Surf" },
	cloud_cushion = { Family = "Sit" },
	rocket_skiff = { Family = "HandleStand" },
	lantern_carriage = { Family = "HandleSit" }, -- Moonlantern Carriage (PoseId), grips added by workstream I
	stand = { Family = "Stand" }, -- no flyer equipped: the hover pad (Assets.RideStand)
	honey_hover = { Family = "Surf" },
	bubble_pod = { Family = "Sit" },
	paper_jet = { Family = "Kneel" },
	dragonfly = { Family = "HandleSit" },
	carousel = { Family = "HandleSit" }, -- rider follows the bobbing pony (model attribute RiderMount = "Pony")
	sunwing = { Family = "Kneel" },
	starwhale = { Family = "Sit" },
}

-- Standard grip layout per handle family, in rider space (contact point at the origin, nose toward -Z). Handle
-- flyers place their GripL/GripR attachments here (or close) so the family's authored hands already fit.
F.StandardGrips = {
	HandleStand = { L = { -0.96, 2.58, -1.56 }, R = { 0.96, 2.58, -1.56 } },
	HandleSit = { L = { -0.62, 1.46, -1.74 }, R = { 0.62, 1.46, -1.74 } }, -- Moonlantern Carriage v5 handlebar corners
}

F.ClipNames = { "Idle", "LeanLeft", "LeanRight", "Launch", "Land" }
F.Loops = { Idle = true, LeanLeft = true, LeanRight = true }

-- Uploaded Animation assets (group 11116787) per family, clip and rig. Missing -> RidePose uses the code fallback.
-- Generated by tools/write_ride_animation_ids.py from assets/animations/rider/roblox_assets.json.
-- BEGIN ANIMATION IDS
F.AnimationIds = {
	HandleSit = {
		Idle = { R15 = "rbxassetid://136867290254632", R6 = "rbxassetid://119728664118108" },
		LeanLeft = { R15 = "rbxassetid://105593890982328", R6 = "rbxassetid://105946790515834" },
		LeanRight = { R15 = "rbxassetid://94267938707993", R6 = "rbxassetid://118618690542730" },
		Launch = { R15 = "rbxassetid://90561652247397", R6 = "rbxassetid://90769939550746" },
		Land = { R15 = "rbxassetid://93676222793236", R6 = "rbxassetid://111180934812673" },
	},
	HandleStand = {
		Idle = { R15 = "rbxassetid://75105075466978", R6 = "rbxassetid://102210952721526" },
		LeanLeft = { R15 = "rbxassetid://80179386074804", R6 = "rbxassetid://123954039977166" },
		LeanRight = { R15 = "rbxassetid://93849259711686", R6 = "rbxassetid://97596113308347" },
		Launch = { R15 = "rbxassetid://103692296156844", R6 = "rbxassetid://88334503541283" },
		Land = { R15 = "rbxassetid://74608047871821", R6 = "rbxassetid://92051064987024" },
	},
	Kneel = {
		Idle = { R15 = "rbxassetid://85200387933314", R6 = "rbxassetid://114212037688776" },
		LeanLeft = { R15 = "rbxassetid://117498931769987", R6 = "rbxassetid://86215737382567" },
		LeanRight = { R15 = "rbxassetid://135348027464833", R6 = "rbxassetid://106811376154903" },
		Launch = { R15 = "rbxassetid://119151216002207", R6 = "rbxassetid://98654346617546" },
		Land = { R15 = "rbxassetid://96217824421455", R6 = "rbxassetid://91800315979446" },
	},
	Sit = {
		Idle = { R15 = "rbxassetid://87975438939379", R6 = "rbxassetid://130872617269161" },
		LeanLeft = { R15 = "rbxassetid://104505947950474", R6 = "rbxassetid://91027322347019" },
		LeanRight = { R15 = "rbxassetid://138163421499357", R6 = "rbxassetid://76405921719794" },
		Launch = { R15 = "rbxassetid://131946276035619", R6 = "rbxassetid://131473690975463" },
		Land = { R15 = "rbxassetid://135332403647717", R6 = "rbxassetid://92643804232249" },
	},
	Stand = {
		Idle = { R15 = "rbxassetid://108357607085651", R6 = "rbxassetid://128435535784589" },
		LeanLeft = { R15 = "rbxassetid://94179503119866", R6 = "rbxassetid://108113200663136" },
		LeanRight = { R15 = "rbxassetid://99532351528821", R6 = "rbxassetid://95536629717905" },
		Launch = { R15 = "rbxassetid://132708193018907", R6 = "rbxassetid://96769927126282" },
		Land = { R15 = "rbxassetid://125949925509863", R6 = "rbxassetid://136892529657311" },
	},
	Surf = {
		Idle = { R15 = "rbxassetid://131974159115214", R6 = "rbxassetid://99567348879394" },
		LeanLeft = { R15 = "rbxassetid://138646521851380", R6 = "rbxassetid://134571322506689" },
		LeanRight = { R15 = "rbxassetid://88695921499825", R6 = "rbxassetid://85031785797787" },
		Launch = { R15 = "rbxassetid://85862772762265", R6 = "rbxassetid://132674781013604" },
		Land = { R15 = "rbxassetid://118170947487501", R6 = "rbxassetid://138807592292271" },
	},
}
-- END ANIMATION IDS

return F
