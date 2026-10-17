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
		if child.Name == "Icon" or child.Name == "Placeholder" then
			child.Visible = false
		end
	end
	local world = Instance.new("WorldModel")
	world.Parent = viewport
	local folder = RS.Assets:FindFirstChild(if category == "Rideables" then "Rideables" else "RoundFinishers")
	local source = folder and folder:FindFirstChild(id)
	local config = require(RS.Shared.Config.RoundCosmetics)
	local def = config.ByCategory[category] and config.ByCategory[category][id]
	if def and def.AssetBundle then
		local seasonal = RS.Assets:FindFirstChild("Seasonal")
		local bundle = seasonal and seasonal:FindFirstChild(def.AssetBundle)
		source = bundle and bundle:FindFirstChild(def.AssetName)
	end
	if source then
		source:Clone().Parent = world
	end
	local rotation =
		CFrame.lookAt(if category == "Rideables" then Vector3.new(6, 5, 9) else Vector3.new(4, 2, 10), Vector3.zero)
	require(script.Parent.GlassyPortrait).fitOnResize(viewport, rotation, 35)
	return viewport, world
end
return Portrait
