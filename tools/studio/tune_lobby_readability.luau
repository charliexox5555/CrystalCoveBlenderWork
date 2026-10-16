-- Edit only: preserve warm sky while reducing glare and redundant labels.
assert(not game:GetService("RunService"):IsRunning(), "Edit only")
local L = game.Lighting
local backup = game.ServerStorage.LobbyBeforeNight_20261016
if not backup:FindFirstChild("LightingBeforeNight") then
	local b = Instance.new("Folder")
	b.Name, b.Parent = "LightingBeforeNight", backup
	for _, key in { "ClockTime", "Brightness", "Ambient", "OutdoorAmbient" } do
		b:SetAttribute(key, L[key])
	end
	for _, v in L:GetChildren() do
		v:Clone().Parent = b
	end
end
for _, v in L:GetChildren() do
	if v:IsA("SunRaysEffect") then
		v.Intensity = 0.035
	end
	if v:IsA("Sky") then
		v.SunAngularSize = 6
	end
end
workspace.Lobby.GlassClashProps.Kiln.Interaction.KilnTitle.Enabled = false
local decor = workspace.Lobby.NightPolishV1
for _, name in { "KilnHeader", "KilnHeaderPost" } do
	local p = decor:FindFirstChild(name)
	if p then
		p.Transparency = 1
		for _, g in p:GetChildren() do
			if g:IsA("SurfaceGui") then
				g.Enabled = false
			end
		end
	end
end
if not decor:FindFirstChild("KioskCanopies") then
	local root = Instance.new("Model")
	root.Name, root.Parent = "KioskCanopies", decor
	local function p(name, size, pos, color)
		local part = Instance.new("Part")
		part.Name, part.Size, part.Position = name, size, pos
		part.Color, part.Material = Color3.fromHex(color), Enum.Material.SmoothPlastic
		part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery = true, false, false, false
		part.Parent = root
	end
	for _, x in { -31, 31 } do
		for _, dx in { -3, 3 } do
			p("KioskPost", Vector3.new(0.3, 5, 0.3), Vector3.new(x + dx, 2.5, 8), "#80634C")
		end
		for i = 1, 6 do
			p(
				"ClothStripe",
				Vector3.new(1.1, 0.18, 4.3),
				Vector3.new(x + (i - 3.5) * 1.1, 5.1, 9),
				if i % 2 == 0 then "#D6B5DE" else "#F2E3C5"
			)
		end
		p("AwningValance", Vector3.new(6.6, 0.4, 0.18), Vector3.new(x, 4.9, 11.1), "#8C80AA")
	end
end
return { SunRays = 0.035, SunAngularSize = 6, RedundantKilnLabelsHidden = true, KioskCanopies = 2 }
