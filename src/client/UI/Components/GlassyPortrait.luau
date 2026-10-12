local RS = game:GetService("ReplicatedStorage")
local U = require(script.Parent.Util)
local Portrait = {}

-- The approved meshes provide a sharp portrait without another texture upload.
function Portrait.new(parent, id, size, position)
	local viewport = U.make("ViewportFrame", parent, {
		Name = "Portrait",
		Size = size,
		Position = position,
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(195, 211, 230),
		LightColor = Color3.new(1, 1, 1),
		LightDirection = Vector3.new(-1, -1, -2),
	})
	local world = Instance.new("WorldModel")
	world.Parent = viewport
	local source = RS.Assets.Glassies[id]
	local parts = { source.Body }
	for _, detail in source.Details:GetChildren() do
		table.insert(parts, detail)
	end
	for _, template in parts do
		local part = template:Clone()
		part:PivotTo(CFrame.Angles(0, 0, math.rad(-12)))
		part.Parent = world
	end
	local camera = Instance.new("Camera")
	local center = Vector3.new(0, -1.2, 0)
	camera.CFrame = CFrame.lookAt(center + Vector3.new(1.5, 0.4, 5.5), center)
	camera.FieldOfView = 30
	camera.Parent, viewport.CurrentCamera = viewport, camera
	return viewport
end
return Portrait
