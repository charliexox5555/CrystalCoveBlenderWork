local RS = game:GetService("ReplicatedStorage")
local U = require(script.Parent.Util)
local Portrait = {}
function Portrait.fitEffect(viewport, radius)
	local camera = viewport.CurrentCamera
	if not camera then
		return
	end
	local size = viewport.AbsoluteSize
	local aspect = math.max(1, size.X) / math.max(1, size.Y)
	local vertical = math.rad(camera.FieldOfView) / 2
	local limiting = math.atan(math.tan(vertical) * math.min(1, aspect))
	-- Fit a sphere so expansion/depth stays within both axes, including narrow previews.
	local distance = radius / math.sin(limiting)
	camera.CFrame = CFrame.lookAt(Vector3.zAxis * distance, Vector3.zero)
end
function Portrait.new(parent, category, id, size, position, name)
	local viewport = U.make("ViewportFrame", parent, {
		Name = name or "CosmeticPortrait",
		Size = size,
		Position = position,
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(180, 195, 220),
		LightColor = Color3.new(1, 1, 1),
		LightDirection = Vector3.new(-1, -1, -2),
	})
	for _, child in viewport:GetChildren() do
		if child:IsA("WorldModel") or child:IsA("Camera") then
			child:Destroy()
		end
	end
	local world = Instance.new("WorldModel")
	world.Parent = viewport
	local folder = RS.Assets:FindFirstChild(if category == "Rideables" then "Rideables" else "RoundFinishers")
	local source = folder and folder:FindFirstChild(id)
	if source then
		source:Clone().Parent = world
	end
	local camera = Instance.new("Camera")
	camera.FieldOfView = 38
	camera.CFrame = if category == "Rideables"
		then CFrame.lookAt(Vector3.new(9, 8, 10), Vector3.new(0, -0.25, 0))
		else CFrame.lookAt(Vector3.new(0, 1, 10), Vector3.zero)
	camera.Parent, viewport.CurrentCamera = viewport, camera
	return viewport, world
end
return Portrait
