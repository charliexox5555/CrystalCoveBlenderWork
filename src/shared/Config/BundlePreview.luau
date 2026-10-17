--!strict
-- Fullscreen bundle preview (UI/Screens/BundlePreview + Presentation/BundleStage, client-only).
-- The 3D stage is built in the world far above the lobby, only on the viewing client, and the camera is
-- pointed at it while the screen is open: particles, beams, trails and lights do not render inside a
-- ViewportFrame, and the carriage and the Lantern Eclipse are mostly made of them. Pure data.
local BundlePreview = {}

-- Stage placement (stud offsets in stage space; the stage faces +Z, towards the default camera).
BundlePreview.StageOrigin = Vector3.new(0, 1400, 0) -- well above the lobby; nothing else is up here
BundlePreview.Room = { Radius = 70, Height = 95, Panels = 24, Stars = 46 }
BundlePreview.Pedestal = { Radius = 8.5, Height = 1.4, RimInset = 0.35 }

BundlePreview.Carriage = {
	Offset = Vector3.new(0, 3.1, -0.5), -- pivot above the pedestal top
	Yaw = math.rad(205), -- three-quarter view of the carriage front
	YawSway = 0.14,
	YawHz = 0.07,
}

-- The Hollowlight hangs from a lantern post, swings, then flies into the eclipse (same beats as the
-- lobby stage demo; Config/Showcase.Demo supplies the timing).
BundlePreview.Glassy = {
	Post = Vector3.new(8, 0, 3), -- foot of the post, on the floor beside the pedestal
	Hook = Vector3.new(6.2, 9.6, 3),
	Arc = Vector3.new(-1, 12, 9),
	Target = Vector3.new(-9.5, 4.5, 7), -- where the Lantern Eclipse plays
}

-- Where each focus puts the camera: look-at point (stage space), distance and orbit angles (radians).
BundlePreview.Focus = {
	Overview = { At = Vector3.new(-2, 5.4, 2.5), Distance = 28, Yaw = 0, Pitch = 0.2 },
	Glassies = { At = Vector3.new(6.2, 7.6, 3), Distance = 10, Yaw = 0.35, Pitch = 0.08 },
	Rideables = { At = Vector3.new(0, 5.4, -0.5), Distance = 20, Yaw = -0.35, Pitch = 0.18 },
	Finishers = { At = Vector3.new(-8, 5.5, 6), Distance = 19, Yaw = -0.45, Pitch = 0.12 },
}

BundlePreview.Camera = {
	FieldOfView = 50,
	MinDistance = 7,
	MaxDistance = 42,
	MinPitch = -0.05, -- radians above/below the look-at point (positive looks down)
	MaxPitch = 0.75,
	DragSpeed = 0.009, -- radians per pixel dragged
	WheelStep = 0.12, -- fraction of the distance per wheel notch
	Smooth = 10, -- higher follows input faster
	AutoSpin = 0.06, -- radians per second while idle on the overview
	IdleSeconds = 4, -- idle time before the slow auto spin resumes
	-- The look-at point sits in the middle of the stage area to the right of the cards; the camera turns
	-- towards it so the subject is framed there rather than behind the cards.
}

-- Replay a few seconds before the eclipse when its tile is chosen.
BundlePreview.EclipseLead = 0.6

-- Combat Preview is planned later; shown disabled until then.
BundlePreview.CombatPreviewEnabled = false

BundlePreview.LimitedText = "LIMITED TIME"
BundlePreview.CountdownRefreshSeconds = 1

return BundlePreview
