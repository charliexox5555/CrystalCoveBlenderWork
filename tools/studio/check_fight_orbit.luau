-- Play / Client: synthetic input through the real handlers; never sends desktop input.
local client = game.Players.LocalPlayer.PlayerScripts.Client
local View = require(client.Presentation.FightView)
local Orbit = require(client.Presentation.FightOrbit)
local camera = workspace.CurrentCamera
local old =
	{ CFrame = camera.CFrame, Type = camera.CameraType, FOV = camera.FieldOfView, Subject = camera.CameraSubject }
local checks = 0
local function check(value, message)
	assert(value, message)
	checks += 1
end
local function near(a, b, message)
	check(math.abs(a - b) < 0.001, message)
end
local view = setmetatable({
	Viewing = true,
	Phase = "Fighting",
	Data = { CameraFacing = 1 },
	Hidden = {},
	HiddenGuis = {},
	Scene = {
		Frame = CFrame.new(0, 200, 3000),
		Fighters = {
			{ Body = { Position = Vector3.new(-3, 190, 3000) } },
			{
				Body = { Position = Vector3.new(3, 190, 3000) },
			},
		},
		GetStand = function()
			return nil
		end,
	},
}, { __index = View })
local orbit = Orbit.new(view)
view.Orbit = orbit
local function input(kind, x, key)
	return { UserInputType = kind, Position = Vector3.new(x or 0, 0, 0), KeyCode = key or Enum.KeyCode.Unknown }
end
local ok, problem = pcall(function()
	view:Camera(1 / 60, 0)
	local initial = camera.CFrame.Position - view.Focus
	for _, yaw in { math.pi / 2, math.pi, math.pi * 1.5, math.pi * 2 } do
		orbit.Target, orbit.Yaw = yaw, yaw
		view:Camera(1 / 60, 0)
		local offset = camera.CFrame.Position - view.Focus
		near(offset.Magnitude, initial.Magnitude, "constant distance")
		near(offset.Y, initial.Y, "constant height")
		check(camera.CFrame.LookVector:Dot((view.Focus - camera.CFrame.Position).Unit) > 0.999, "arena stays centered")
		check(
			(offset - CFrame.fromAxisAngle(Vector3.yAxis, yaw):VectorToWorldSpace(initial)).Magnitude < 0.001,
			"correct orbit quadrant"
		)
	end
	local mouse = input(Enum.UserInputType.MouseButton1, 100)
	orbit:Begin(mouse, true)
	check(orbit.Drag == nil, "GUI input ignored")
	view.Phase = "Aiming"
	orbit:Begin(mouse, false)
	check(orbit.Drag == nil, "aim untouched")
	view.Phase = "Fighting"
	orbit:Begin(mouse, false)
	local before = orbit.Target
	orbit:Change(input(Enum.UserInputType.MouseMovement, 180))
	check(orbit.Target < before, "mouse drag rotates")
	orbit:Finish(mouse)
	check(orbit.Drag == nil, "mouse release")
	local touch = input(Enum.UserInputType.Touch, 200)
	local other = input(Enum.UserInputType.Touch, 500)
	orbit:Begin(touch, false)
	orbit:Begin(other, false)
	before = orbit.Target
	other.Position = Vector3.new(600, 0, 0)
	orbit:Change(other)
	near(orbit.Target, before, "second finger ignored")
	touch.Position = Vector3.new(250, 0, 0)
	orbit:Change(touch)
	check(orbit.Target < before, "touch swipe rotates")
	orbit:Finish(other)
	check(orbit.Drag ~= nil, "other finger cannot release drag")
	orbit:Finish(touch)
	check(orbit.Drag == nil, "touch release")
	local key = input(Enum.UserInputType.Keyboard, 0, Enum.KeyCode.E)
	orbit:Begin(key, false)
	before = orbit.Target
	orbit:Step(0.1)
	check(orbit.Target > before, "E rotates")
	orbit:Finish(key)
	check(next(orbit.Keys) == nil, "key release")
	orbit:Change(input(Enum.UserInputType.Gamepad1, 0.1, Enum.KeyCode.Thumbstick2))
	near(orbit.Stick, 0, "stick deadzone")
	orbit:Change(input(Enum.UserInputType.Gamepad1, 0.8, Enum.KeyCode.Thumbstick2))
	near(orbit.Stick, 0.8, "right stick")
	orbit:Cancel()
	check(orbit.Drag == nil and orbit.Stick == 0 and next(orbit.Keys) == nil, "focus cancellation")
	view.FinalTime = 1
	before = orbit.Yaw
	orbit.Target += 1
	orbit:Step(0.1)
	near(orbit.Yaw, before, "finisher freezes angle")
	view.FinalTime = nil
	view.Viewing = false
	orbit:Begin(mouse, false)
	check(orbit.Drag == nil, "inactive spectator cannot orbit")
	orbit:Destroy()
	check(#orbit.Connections == 0, "connections released")
end)
orbit:Destroy()
camera.CameraType, camera.CameraSubject, camera.FieldOfView, camera.CFrame = old.Type, old.Subject, old.FOV, old.CFrame
assert(ok, problem)
return { Checks = checks, CameraRestored = true, DesktopInput = false }
