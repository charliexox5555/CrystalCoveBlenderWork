-- Client-only native mesh/crack/shard fixtures. No inventory grants or gameplay inputs.
local RS = game:GetService("ReplicatedStorage")
local client = game.Players.LocalPlayer.PlayerScripts.Client
local Scene = require(client.Presentation.FightScene)
local Shatter = table.clone(require(client.Controllers.ShatterController))
Shatter:Init()
local Formula = require(RS.Shared.Formula)
local Glassies = require(RS.Shared.Config.Glassies)
local ids = {
	"milk_bottle",
	"pickle_jar",
	"glass_cup",
	"ketchup_bottle",
	"water_jug",
	"lemonade_bottle",
	"mason_jar",
	"hot_sauce",
	"crystal_tumbler",
}
local report = {}
for _, id in ids do
	local hp = Formula.stats(Glassies.get(id), {}).HP
	local scene = Scene.new({
		Id = "wave1-qa",
		A = { Id = id },
		B = { Id = "pop" },
		Frame = CFrame.new(0, 30, 0),
		HookPositions = { Vector3.new(-3, 30, 0), Vector3.new(3, 30, 0) },
	}, { hp, 100 }, Shatter)
	scene:Pose(1, Vector3.new(0, -7, 0), 0, Vector3.zero)
	local fighter = scene.Fighters[1]
	assert(fighter.RenderId == id, "Native art fell back to a proxy")
	Shatter:SetCracks(fighter, hp * 0.3, hp)
	assert(#fighter.Cracks > 0, "Missing native surface cracks")
	Shatter:Break(fighter, scene.Root)
	local shards = 0
	for _, p in scene.Root:GetChildren() do
		if p.Name == "LocalShard" then
			shards += 1
		end
	end
	assert(shards >= 16, "Native shatter set incomplete")
	table.insert(report, { Id = id, Cracks = #fighter.Cracks, ShardsAndDetails = shards })
	scene:Destroy()
end
-- Temporary 3x3 gallery for checking actual imported body/detail alignment and materials.
local U = require(client.UI.Components.Util)
local Portrait = require(client.UI.Components.GlassyPortrait)
local gui = U.screen("Wave1AssetQA", 100)
U.make(
	"Frame",
	gui,
	{
		Name = "Backdrop",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(13, 23, 39),
		BorderSizePixel = 0,
	}
)
for i, id in ids do
	local panel = U.make("Frame", gui, {
		Name = id,
		Size = UDim2.fromScale(0.31, 0.3),
		Position = UDim2.fromScale(0.025 + ((i - 1) % 3) * 0.32, 0.025 + math.floor((i - 1) / 3) * 0.32),
		BackgroundColor3 = Color3.fromRGB(27, 43, 65),
		BorderSizePixel = 0,
	})
	Portrait.new(panel, id, UDim2.fromScale(1, 0.85), UDim2.new())
	U.text(panel, "Name", Glassies.get(id).Name, UDim2.fromScale(1, 0.15), UDim2.fromScale(0, 0.83))
end
local meshes = {}
for _, child in gui:GetDescendants() do
	if child:IsA("MeshPart") then
		table.insert(meshes, child)
	end
end
game:GetService("ContentProvider"):PreloadAsync(meshes)
task.wait(0.3)
return report
