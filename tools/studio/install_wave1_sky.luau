-- Native imported meshes only. Restores measured stud scale; preserves raw source Models.
assert(not game:GetService("RunService"):IsRunning(), "Stop Play first")
local Manifest = game:GetService("HttpService"):JSONDecode(
	[==[{"crystal_single":{"file":"Wave1_crystal_single.fbx","meshes":[{"Name":"Wave1_crystal_single_Crystal","Source":"Crystal","Role":"World","Center":[0,1.350000023841858,0],"Size":[1.2999999523162842,2.700000047683716,1.1258330345153809],"Color":"#6FE7FF","Material":"SmoothPlastic"}]},"crystal_small":{"file":"Wave1_crystal_small.fbx","meshes":[{"Name":"Wave1_crystal_small_Crystal","Source":"Crystal","Role":"World","Center":[-0.07150000333786011,1.649999976158142,0],"Size":[3.057000160217285,3.299999952316284,1.299038052558899],"Color":"#6FE7FF","Material":"SmoothPlastic"}]},"crystal_big":{"file":"Wave1_crystal_big.fbx","meshes":[{"Name":"Wave1_crystal_big_Crystal","Source":"Crystal","Role":"World","Center":[-0.031999945640563965,2.5,-0.09999996423721313],"Size":[4.61400032043457,5,2.7526278495788574],"Color":"#6FE7FF","Material":"SmoothPlastic"}]},"kiln_crystal":{"file":"Wave1_kiln_crystal.fbx","meshes":[{"Name":"Wave1_kiln_crystal_KilnCrystal","Source":"KilnCrystal","Role":"World","Center":[0,9,0],"Size":[10.399999618530273,18,10.399999618530273],"Color":"#6FE7FF","Material":"SmoothPlastic"},{"Name":"Wave1_kiln_crystal_Satellites","Source":"Satellites","Role":"World","Center":[-0.35500001907348633,3.5,-0.16339749097824097],"Size":[13.430000305175781,7,3.098076343536377],"Color":"#B58CFF","Material":"SmoothPlastic"}]},"featured_arch":{"file":"Wave1_featured_arch.fbx","meshes":[{"Name":"Wave1_featured_arch_Arch","Source":"Arch","Role":"World","Center":[0,11.699124336242676,0],"Size":[24.898151397705078,23.501752853393555,3.200000047683716],"Color":"#B58CFF","Material":"SmoothPlastic"},{"Name":"Wave1_featured_arch_CrownGem","Source":"CrownGem","Role":"World","Center":[0,24.5,0],"Size":[3.200000047683716,4,2.7712812423706055],"Color":"#FFD166","Material":"SmoothPlastic"},{"Name":"Wave1_featured_arch_FootCrystals","Source":"FootCrystals","Role":"World","Center":[0,3,0],"Size":[26.871999740600586,6,3.6373066902160645],"Color":"#6FE7FF","Material":"SmoothPlastic"}]},"cloud_puff":{"file":"Wave1_cloud_puff.fbx","meshes":[{"Name":"Wave1_cloud_puff_Cloud","Source":"Cloud","Role":"World","Center":[-0.09510564804077148,0.5500000715255737,-0.20000004768371582],"Size":[11.135712623596191,4.699999809265137,6.399999618530273],"Color":"#F4F7FF","Material":"SmoothPlastic"}]},"cloud_long":{"file":"Wave1_cloud_long.fbx","meshes":[{"Name":"Wave1_cloud_long_Cloud","Source":"Cloud","Role":"World","Center":[-0.14265871047973633,0.75,0],"Size":[17.32314682006836,4.699999809265137,5.999999523162842],"Color":"#F4F7FF","Material":"SmoothPlastic"}]},"cloud_bank":{"file":"Wave1_cloud_bank.fbx","meshes":[{"Name":"Wave1_cloud_bank_Cloud","Source":"Cloud","Role":"World","Center":[-0.09510564804077148,1,-0.15000009536743164],"Size":[20.939945220947266,5.599999904632568,7.899999618530273],"Color":"#F4F7FF","Material":"SmoothPlastic"}]}}]==]
)
local RS, SS = game:GetService("ReplicatedStorage"), game:GetService("ServerStorage")
local unsorted = SS:FindFirstChild("Unsorted") or Instance.new("Folder")
unsorted.Name, unsorted.Parent = "Unsorted", SS
local imports = workspace:FindFirstChild("GlassClashImports")
assert(imports, "Stage Wave1 imports in Workspace.GlassClashImports")
local kit = RS.Assets:FindFirstChild("WorldKit") or Instance.new("Folder")
kit.Name, kit.Parent = "WorldKit", RS.Assets
local sources = SS.Wave1ImportedSources:FindFirstChild("SkyKit") or Instance.new("Folder")
sources.Name, sources.Parent = "SkyKit", SS.Wave1ImportedSources
local installed = {}
local function vec(values)
	return Vector3.new(values[1], values[2], values[3])
end
for id, data in Manifest do
	if kit:FindFirstChild(id) then
		continue
	end
	local raw = imports:FindFirstChild("Wave1_" .. id)
	assert(raw, "Missing native import: " .. id)
	local model = Instance.new("Model")
	model.Name, model.WorldPivot = id, CFrame.identity
	for _, e in data.meshes do
		local p = raw:FindFirstChild(e.Name, true)
		assert(p and p:IsA("MeshPart"), "Missing mesh: " .. e.Name)
		local copy = p:Clone()
		copy.Name, copy.Size = e.Source, vec(e.Size)
		copy.CFrame = CFrame.new(vec(e.Center)) * p.CFrame.Rotation
		copy.PivotOffset = copy.CFrame:Inverse()
		copy.Color, copy.Material = Color3.fromHex(e.Color), Enum.Material[e.Material]
		copy.Anchored, copy.CanCollide, copy.CanTouch, copy.CanQuery = true, false, false, false
		copy.Reflectance, copy.Transparency, copy.CastShadow = 0, 0, id:sub(1, 6) ~= "cloud_"
		copy.TextureID = ""
		copy.Parent = model
	end
	model.Parent, raw.Parent = kit, sources
	table.insert(installed, id)
end
local empty = SS.Wave1ImportedSources:FindFirstChild("EmptyContainers") or Instance.new("Folder")
empty.Name, empty.Parent = "EmptyContainers", SS.Wave1ImportedSources
for _, m in imports:GetChildren() do
	if m:IsA("Model") and #m:GetDescendants() == 0 then
		m.Parent = empty
	end
end
local props = workspace.Lobby.GlassClashProps
assert(not props:FindFirstChild("SkyArt"), "Sky art already placed; preserve edits before rerunning")
local art = Instance.new("Folder")
art.Name, art.Parent = "SkyArt", props
local function place(id, name, position, yaw, scale)
	local model = kit[id]:Clone()
	model.Name = name
	model:ScaleTo(scale or 1)
	model:PivotTo(CFrame.new(position) * CFrame.Angles(0, math.rad(yaw or 0), 0))
	model.Parent = art
	return model
end
-- Original Kiln placeholder remains recoverable; its prompt is reused on the native hero.
local old = props:FindFirstChild("Kiln")
local prompt = old and old:FindFirstChild("OpenKiln", true)
local kiln = place("kiln_crystal", "Kiln", Vector3.new(-22, 0.05, -11))
kiln.Parent = props
local anchor = Instance.new("Part")
anchor.Name, anchor.Size, anchor.CFrame = "Interaction", Vector3.new(4, 5, 1), CFrame.new(-22, 2.5, -4.5)
anchor.Anchored, anchor.CanCollide, anchor.CanTouch, anchor.CanQuery, anchor.Transparency = true, false, false, false, 1
anchor.Parent = kiln
if prompt then
	prompt:Clone().Parent = anchor
end
if old then
	local backup = unsorted:FindFirstChild("PreviousKiln") or Instance.new("Folder")
	backup.Name, backup.Parent = "PreviousKiln", unsorted
	old.Parent = backup
end
local gui = Instance.new("BillboardGui")
gui.Name, gui.Size, gui.StudsOffsetWorldSpace, gui.MaxDistance =
	"KilnTitle", UDim2.fromOffset(250, 50), Vector3.new(0, 17.5, 0), 90
gui.AlwaysOnTop, gui.Parent = false, anchor
local label = Instance.new("TextLabel")
label.Size, label.BackgroundTransparency = UDim2.fromScale(1, 1), 1
label.Text, label.TextScaled, label.TextColor3 = "THE KILN", true, Color3.fromRGB(255, 235, 160)
label.FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Bold)
label.Parent = gui
place("featured_arch", "FeaturedArch", Vector3.new(0, 9, -224))
place("crystal_single", "LobbyCrystal", Vector3.new(39, 0, 15), 15, 1.4)
place("crystal_small", "LobbyCluster", Vector3.new(-39, 0, 14), -20, 1.1)
for i, z in { -55, -105, -155 } do
	place("crystal_big", "CrystalLeft" .. i, Vector3.new(-44, i * 2 - 9, z - 3), i * 43, 1.1)
	place("crystal_small", "CrystalRight" .. i, Vector3.new(44, i * 2 - 7, z + 3), -i * 37, 1.3)
end
place("crystal_big", "FeaturedCrystal", Vector3.new(32, 3, -211), 35, 1.2)
place("cloud_puff", "CloudFront", Vector3.new(-48, -16, 27), 25, 1.7)
place("cloud_long", "CloudLeft", Vector3.new(-63, -24, -65), 15, 1.8)
place("cloud_bank", "CloudRight", Vector3.new(66, -27, -134), -10, 1.8)
place("cloud_puff", "CloudFar", Vector3.new(-46, -21, -206), -30, 2)
place("cloud_long", "CloudUnder", Vector3.new(0, -39, -103), 80, 2)
return { Installed = installed, Placed = #art:GetChildren() + 1, RawBackup = sources:GetFullName() }
