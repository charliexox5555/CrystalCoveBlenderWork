local RS = game:GetService("ReplicatedStorage")
local U = require(script.Parent.Util)
local Portrait = {}

-- The approved meshes provide a sharp portrait without another texture upload.
function Portrait.new(parent, id, size, position, name)
	local viewport = U.make("ViewportFrame", parent, {
		Name = name or "Portrait",
		Size = size,
		Position = position,
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(195, 211, 230),
		LightColor = Color3.new(1, 1, 1),
		LightDirection = Vector3.new(-1, -1, -2),
	})
	for _, child in viewport:GetChildren() do
		if child:IsA("WorldModel") or child:IsA("Camera") then
			child:Destroy()
		end
	end
	local icon = viewport:FindFirstChild("Icon")
		or U.make(
			"ImageLabel",
			viewport,
			{ Name = "Icon", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = "" }
		)
	icon.Visible = icon.Image ~= ""
	local placeholder = viewport:FindFirstChild("Placeholder")
	if placeholder then
		placeholder.Visible = false
	end
	local world = Instance.new("WorldModel")
	world.Parent = viewport
	if icon.Visible then
		return viewport
	end
	local def = require(RS.Shared.Config.Glassies).get(id)
	local source = RS.Assets.Glassies:FindFirstChild(id)
		or RS.Assets.Glassies[if def.Type == "Heavy" then "jam" elseif def.Type == "Sharp" then "prism" else "pop"]
	local parts = { source.Body }
	for _, detail in (source:FindFirstChild("Details") and source.Details:GetChildren() or {}) do
		table.insert(parts, detail)
	end
	for _, template in parts do
		local part = template:Clone()
		part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery = true, false, false, false
		if template == source.Body and source.Name ~= def.Asset then
			part.Color = Color3.fromHex(def.Tint)
		end
		part:PivotTo(CFrame.Angles(0, 0, math.rad(-12)))
		part.Parent = world
	end
	local camera = Instance.new("Camera")
	-- Fit the real body and details, including wide handles/caps, inside the portrait.
	local low, high = Vector3.one * math.huge, Vector3.one * -math.huge
	local corners = {}
	for _, part in world:GetChildren() do
		if part:IsA("BasePart") then
			for _, x in { -1, 1 } do
				for _, y in { -1, 1 } do
					for _, z in { -1, 1 } do
						local p = part.CFrame:PointToWorldSpace(part.Size * Vector3.new(x, y, z) / 2)
						low, high = low:Min(p), high:Max(p)
						table.insert(corners, p)
					end
				end
			end
		end
	end
	local center = (low + high) / 2
	local rotation = CFrame.lookAt(Vector3.new(1.5, 0.4, 5.5), Vector3.zero)
	local tangent = math.tan(math.rad(30) / 2)
	local aspect = viewport:FindFirstChildOfClass("UIAspectRatioConstraint")
	local ratio = if aspect then aspect.AspectRatio else 1
	local distance = 0
	for _, p in corners do
		local q = rotation:VectorToObjectSpace(p - center)
		distance = math.max(distance, math.abs(q.Y) / tangent + q.Z, math.abs(q.X) / (tangent * ratio) + q.Z)
	end
	camera.CFrame = CFrame.new(center) * rotation.Rotation + rotation.ZVector * distance * 1.18
	camera.FieldOfView = 30
	camera.Parent, viewport.CurrentCamera = viewport, camera
	return viewport
end
return Portrait
