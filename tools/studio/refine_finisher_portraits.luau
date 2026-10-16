-- Edit only, preserve original prototypes while giving the two spectacular effects distinct icons.
assert(not game:GetService("RunService"):IsRunning(), "Edit only")
local source = game.ReplicatedStorage.Assets.RoundFinishers
assert(
	not game.ServerStorage.LobbyBeforeNight_20261016:FindFirstChild("FinisherPortraitsBeforeRefine"),
	"Portraits already refined"
)
local backup = source:Clone()
backup.Name, backup.Parent = "FinisherPortraitsBeforeRefine", game.ServerStorage.LobbyBeforeNight_20261016
local star = source.starfall
star.Core.Shape = Enum.PartType.Block
star.Core.Size = Vector3.new(2.2, 0.38, 0.3)
star.Core.CFrame = CFrame.Angles(0, 0, math.pi / 4)
local cross = star.Core:Clone()
cross.Name, cross.CFrame, cross.Color, cross.Parent =
	"StarCross", CFrame.Angles(0, 0, -math.pi / 4), Color3.fromHex("#FFAFE9"), star
local block = source.brick_boom
for _, x in { -0.7, 0.7 } do
	local fire = block.Core:Clone()
	fire.Name, fire.Size, fire.Position, fire.Color, fire.Parent =
		"ToyFlame", Vector3.one * 1.1, Vector3.new(x, 0.6, 0), Color3.fromHex("#FFF2A0"), block
end
for _, parent in
	{ game.StarterGui.CollectionScreen.Panel.Content, game.StarterGui.KilnScreen.Panel.Content.FinishersPage }
do
	for id, tile in { brick_boom = parent.CosmeticPage.Cards.brick_boom, starfall = parent.CosmeticPage.Cards.starfall } do
		local world = tile.CosmeticPortrait:FindFirstChildOfClass("WorldModel")
		for _, m in world:GetChildren() do
			m:Destroy()
		end
		source[id]:Clone().Parent = world
	end
end
return { DistinctPortraits = 2, OriginalsPreserved = true }
