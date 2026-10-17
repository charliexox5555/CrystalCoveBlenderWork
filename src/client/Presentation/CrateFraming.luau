-- Front-on camera framing for crate/kiln previews (shop pages and the opening stage).
-- Models face -Z with their pivot at the floor; the camera looks at the front from slightly above,
-- centres the projected silhouette and fills the viewport with the same margin on every aspect ratio.
local RS = game:GetService("ReplicatedStorage")
local F = require(RS.Shared.Config.CrateMachines).Framing

local Framing = {}
local bindings = setmetatable({}, { __mode = "k" })

local function corners(world)
	local points = {}
	for _, part in world:GetDescendants() do
		if part:IsA("BasePart") and (part.Transparency < 1 or part.Name == "FrameHeadroom") and part.Name ~= "Root" then
			local half = part.Size / 2
			for _, x in { -1, 1 } do
				for _, y in { -1, 1 } do
					for _, z in { -1, 1 } do
						table.insert(points, part.CFrame:PointToWorldSpace(half * Vector3.new(x, y, z)))
					end
				end
			end
		end
	end
	return points
end

function Framing.fit(viewport: ViewportFrame)
	local world = viewport:FindFirstChildOfClass("WorldModel")
	local size = viewport.AbsoluteSize
	if not world or size.X < 1 or size.Y < 1 then
		return
	end
	local points = corners(world)
	if #points == 0 then
		return
	end
	local camera = viewport.CurrentCamera
	if not camera or camera.Parent ~= viewport then
		camera = Instance.new("Camera")
		camera.Parent = viewport
		viewport.CurrentCamera = camera
	end
	camera.FieldOfView = F.FieldOfView
	local pitch = math.rad(F.PitchDegrees)
	local rotation = CFrame.lookAt(Vector3.new(0, math.sin(pitch), -math.cos(pitch)), Vector3.zero).Rotation
	local tanY = math.tan(math.rad(F.FieldOfView) / 2)
	local tanX = tanY * size.X / size.Y
	local low, high = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, p in points do
		low, high = low:Min(p), high:Max(p)
	end
	local target = (low + high) / 2
	local distance = (high - low).Magnitude * 2
	-- A few fixed-point passes: centre the projected bounds, then set the distance that fills the frame.
	for _ = 1, 6 do
		local cf = CFrame.new(target - rotation.LookVector * distance) * rotation
		local uMin, uMax, vMin, vMax = math.huge, -math.huge, math.huge, -math.huge
		for _, p in points do
			local q = cf:PointToObjectSpace(p)
			local depth = math.max(-q.Z, 0.01)
			local u, v = q.X / (depth * tanX), q.Y / (depth * tanY)
			uMin, uMax, vMin, vMax = math.min(uMin, u), math.max(uMax, u), math.min(vMin, v), math.max(vMax, v)
		end
		target += rotation.RightVector * ((uMin + uMax) / 2 * tanX * distance) + rotation.UpVector * ((vMin + vMax) / 2 * tanY * distance)
		local extent = math.max((uMax - uMin) / 2, (vMax - vMin) / 2)
		distance *= extent / F.Fill
	end
	camera.CFrame = CFrame.new(target - rotation.LookVector * distance) * rotation
	return camera
end

-- Fits now and again whenever the viewport resizes (desktop/phone layouts), unless an opening has frozen it.
function Framing.bind(viewport: ViewportFrame)
	if bindings[viewport] then
		bindings[viewport]:Disconnect()
	end
	bindings[viewport] = viewport:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		if not viewport:GetAttribute("FreezePortraitCamera") then
			Framing.fit(viewport)
		end
	end)
	return Framing.fit(viewport)
end

return Framing
