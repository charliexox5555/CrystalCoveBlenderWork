-- Edit mode. Add only our new prop; never rebuild the lobby or touch manual fences/decor.
local lobby = workspace:FindFirstChild("Lobby")
assert(lobby and lobby:FindFirstChild("Spots"), "Sky lobby is required")
local root = lobby:FindFirstChild("GlassClashProps")
if not root then
	root = Instance.new("Folder")
	root.Name = "GlassClashProps"
	root.Parent = lobby
end
if root:FindFirstChild("Kiln") then
	return { Existing = true, Path = root.Kiln:GetFullName() }
end
local spot = lobby.Spots:FindFirstChild("Kiln")
assert(spot, "Missing Kiln lobby spot")
local model = Instance.new("Model")
model.Name = "Kiln"
model:SetAttribute("GeneratedBy", "GlassClashKilnPlaceholder")
local function make(name, size, offset, color, material)
	local p = Instance.new("Part")
	p.Name, p.Size, p.CFrame = name, size, CFrame.new(spot.Position + offset)
	p.Anchored, p.Material, p.Color = true, material or Enum.Material.SmoothPlastic, Color3.fromHex(color)
	p.Parent = model
	return p
end
make("Base", Vector3.new(7, 0.8, 7), Vector3.new(0, 0.4, 0), "23345F")
local body = make("Body", Vector3.new(5.8, 4.5, 5), Vector3.new(0, 3, 0), "314678")
make("Rim", Vector3.new(6.3, 0.7, 5.5), Vector3.new(0, 5.6, 0), "FFC94D")
local crystal = make("Crystal", Vector3.new(2.2, 3, 2.2), Vector3.new(0, 7.4, 0), "6FE7FF", Enum.Material.Neon)
crystal.CFrame *= CFrame.Angles(0, math.pi / 4, 0)
crystal.CanCollide, crystal.CanTouch, crystal.CanQuery = false, false, false
local sign = Instance.new("SurfaceGui")
sign.Face = Enum.NormalId.Front
sign.CanvasSize = Vector2.new(600, 250)
sign.Parent = body
local label = Instance.new("TextLabel")
label.Size, label.BackgroundTransparency = UDim2.fromScale(1, 1), 1
label.Text, label.TextScaled, label.TextColor3 = "THE KILN\nCoin pulls • odds first", true, Color3.new(1, 1, 1)
label.FontFace = Font.fromName("Montserrat", Enum.FontWeight.ExtraBold)
label.Parent = sign
local prompt = Instance.new("ProximityPrompt")
prompt.Name, prompt.ActionText, prompt.ObjectText = "OpenKiln", "Open the Kiln", "Glassies • coin pulls"
prompt.RequiresLineOfSight, prompt.MaxActivationDistance, prompt.Parent = false, 14, body
model.PrimaryPart = body
model.Parent = root
return { Created = true, Path = model:GetFullName(), Position = tostring(spot.Position) }
