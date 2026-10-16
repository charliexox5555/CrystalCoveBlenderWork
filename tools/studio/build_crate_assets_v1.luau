-- Edit only. Original capsule displays assembled from our Blender-authored meshes.
assert(not game:GetService("RunService"):IsRunning(), "Build in Edit")
local RS, SS = game.ReplicatedStorage, game.ServerStorage
assert(not RS.Assets:FindFirstChild("Crates"), "Preserve existing crates")
local backups = SS:FindFirstChild("UIBackups")
if not backups then
	backups = Instance.new("Folder")
	backups.Name = "UIBackups"
	backups.Parent = SS
end
local backup = Instance.new("Folder")
backup.Name = "CrateShopBeforeV1"
backup.Parent = backups
for _, name in { "KilnScreen", "CollectionScreen", "KilnRevealScreen" } do
	game.StarterGui[name]:Clone().Parent = backup
end
local folder = Instance.new("Folder")
folder.Name = "Crates"
folder.Parent = RS.Assets
local models = {}
local function model(name)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = folder
	models[name] = m
	return m
end
local function piece(m, source, name, size, pose, color, neon, currencyTint)
	local p = source:Clone()
	p.Name = name
	for _, child in p:GetChildren() do
		child:Destroy()
	end
	p.Size, p.CFrame, p.Color = size, pose, Color3.fromHex(color)
	p.Material = if neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = true, false, false, false, false
	p:SetAttribute("CurrencyTint", currencyTint or false)
	p.Parent = m
	return p
end
local vfx = RS.Assets.VFX.RoundHeroV2
local m = model("Finishers")
piece(m, vfx.BlastBloom, "CapsuleHull", Vector3.new(3.2, 2.6, 2.8), CFrame.identity, "57299F")
piece(
	m,
	vfx.ShockCrown,
	"RevealLid",
	Vector3.new(3.2, 3.2, 0.25),
	CFrame.new(0, 1.35, 0) * CFrame.Angles(math.pi / 2, 0, 0),
	"FFD98A",
	false,
	true
)
piece(m, vfx.NovaStar, "RevealCore", Vector3.new(1.1, 1.1, 0.2), CFrame.new(0, 0.15, -1.4), "CDAAFF", true, true)
piece(
	m,
	vfx.ShockCrown,
	"BaseHalo",
	Vector3.new(3.35, 3.35, 0.15),
	CFrame.new(0, -1, 0) * CFrame.Angles(math.pi / 2, 0, 0),
	"CDAAFF",
	true
)
m.WorldPivot = CFrame.identity
m = model("Rideables")
piece(
	m,
	RS.Assets.Rideables.cloud_cushion.SculptedCloud,
	"CapsuleHull",
	Vector3.new(3.1, 2.2, 3.1),
	CFrame.identity,
	"E2ECFF"
)
piece(m, RS.Assets.Rideables.skyboard.Deck, "RevealLid", Vector3.new(3.25, 0.55, 3.4), CFrame.new(0, 1.1, 0), "2E6BE6")
piece(m, vfx.NovaStar, "RevealCore", Vector3.new(0.85, 0.85, 0.18), CFrame.new(0, 0.2, -1.55), "93BCFF", true, true)
for _, side in { -1, 1 } do
	piece(
		m,
		RS.Assets.Rideables.prism_ray[if side < 0 then "WingL" else "WingR"],
		"LiftWing" .. side,
		Vector3.new(2, 0.65, 1.6),
		CFrame.new(side * 2, 0.15, 0),
		"61D4DF"
	)
end
m.WorldPivot = CFrame.identity
m = model("Glassies")
local viewport = game.StarterGui.KilnScreen.Panel.Content.GlassiesPage.CoinKiln:FindFirstChild("KilnPortrait", true)
for _, obj in viewport:FindFirstChildOfClass("WorldModel"):GetChildren() do
	obj:Clone().Parent = m
end
for _, p in m:GetDescendants() do
	if p:IsA("BasePart") and p.Material == Enum.Material.Neon then
		p:SetAttribute("CurrencyTint", true)
	end
end
m.WorldPivot = CFrame.identity
-- Larger shells and three readable inventory columns; authored artwork is retained.
game.StarterGui.KilnScreen.Panel.Size = UDim2.fromScale(0.94, 0.94)
game.StarterGui.CollectionScreen.Panel.Size = UDim2.fromScale(0.86, 0.9)
local grid = game.StarterGui.CollectionScreen.Panel.Content.Grid
for _, root in { grid.Tiles, grid.UnownedTiles } do
	local layout = root.UIGridLayout
	layout.CellSize = UDim2.fromScale(0.31, layout.CellSize.Y.Scale)
	layout.CellPadding = UDim2.fromScale(0.025, layout.CellPadding.Y.Scale)
end
return { Models = 3, Backup = backup:GetFullName(), Published = false }
