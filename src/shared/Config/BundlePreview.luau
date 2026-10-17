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
	Post = Vector3.new(12.5, 0, 2.5), -- foot of the post, on the floor beside the pedestal
	Hook = Vector3.new(10.8, 9.6, 2.5),
	Arc = Vector3.new(1, 12.5, 9),
	Target = Vector3.new(-9.5, 4.5, 7), -- where the Lantern Eclipse plays
}

-- Orbit per focus. The pivot is the subject's measured bounding-box centre (BundleStage:MeasureFocus): the
-- rider + carriage for the overview and the flyer, the hanging glassy, or the eclipse area. Yaw/Pitch are
-- the starting angles (radians); Fill is how much of the stage area's height the subject spans.
BundlePreview.Focus = {
	Overview = { Yaw = -0.35, Pitch = 0.22, Fill = 0.75 },
	Rideables = { Yaw = -0.35, Pitch = 0.18, Fill = 0.78 },
	Glassies = { Yaw = 1.0, Pitch = 0.1, Fill = 0.45 },
	Finishers = { Yaw = -0.3, Pitch = 0.14, Fill = 0.8 },
}
-- The eclipse has no model at rest, so its area is a sphere around the burst point.
BundlePreview.FinisherArea = { Offset = Vector3.new(0, 1.5, 0), Radius = 6 }

BundlePreview.Camera = {
	FieldOfView = 50,
	MinZoom = 0.55, -- multiplier on the fitted distance (smaller is closer)
	MaxZoom = 1.6,
	MinPitch = 0.02, -- radians above the pivot (positive looks down)
	MaxPitch = 0.6,
	DragSpeed = 0.008, -- radians per pixel dragged
	WheelStep = 0.1, -- zoom change per wheel notch
	Smooth = 7, -- higher follows input faster; also eases focus changes and reset
	AutoSpin = 0.06, -- radians per second while idle on the overview
	IdleSeconds = 4, -- idle time before the slow auto spin resumes
}

-- Replay a few seconds before the eclipse when its tile is chosen.
BundlePreview.EclipseLead = 0.6

-- Combat Preview is planned later; shown disabled until then.
BundlePreview.CombatPreviewEnabled = false

BundlePreview.LimitedText = "LIMITED TIME"
BundlePreview.CountdownRefreshSeconds = 1

return BundlePreview
