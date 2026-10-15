-- Creator feedback: separate full-screen opening, centered card, restrained kiln fire.
assert(not game:GetService("RunService"):IsRunning(), "Stop Play first")
local gui = game.StarterGui.KilnRevealScreen
assert(gui:GetAttribute("KilnOpeningVersion") == 1, "Refinement is one-time; preserve creator edits")
local before = gui:Clone()
before.Name, before.Parent = "KilnOpeningV1_20261015", game.ServerStorage.UIBackups
local modules = game.StarterPlayer.StarterPlayerScripts.Client.UI:Clone()
modules.Name, modules.Parent = "OpeningRefine", game.ServerStorage
local Portrait = require(modules.Components.GlassyPortrait)
local Theme = require(modules.Theme)
local Assets = require(game.ReplicatedStorage.Shared.Config.UIAssets)
local p, c = gui.Panel, gui.Panel.Content
for _, name in { "WindowArtwork", "TitleBanner", "Tabs", "Coins", "Marbles", "UIAspectRatioConstraint" } do
	local o = p:FindFirstChild(name)
	if o then
		o:Destroy()
	end
end
p.Size, p.Position, p.AnchorPoint = UDim2.fromScale(1, 1), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5)
p.BackgroundColor3, p.BackgroundTransparency = Theme.Palette.lead, 0.04
p.Title.Size, p.Title.Position = UDim2.fromScale(0.6, 0.08), UDim2.fromScale(0.2, 0.035)
p.Title.TextXAlignment = Enum.TextXAlignment.Center
p.Title.UITextSizeConstraint.MaxTextSize = 42
p.Close.Size, p.Close.Position = UDim2.fromScale(0.06, 0.08), UDim2.fromScale(0.95, 0.065)
c.Size, c.Position = UDim2.fromScale(0.88, 0.82), UDim2.fromScale(0.06, 0.14)
c.Status.UITextSizeConstraint.MaxTextSize = 24
local stage = c.KilnStage
stage.KilnPortrait.Size, stage.KilnPortrait.Position = UDim2.fromScale(0.58, 1), UDim2.fromScale(0.5, 0.48)
local camera = stage.KilnPortrait:FindFirstChildOfClass("Camera")
if camera then
	camera:Destroy()
end
Portrait.fit(stage.KilnPortrait, CFrame.identity, 30)
stage.Burst.Image = Assets["kiln/glow"]
stage.Burst.ImageTransparency = 0.80
stage.Burst.Size, stage.Burst.Position = UDim2.fromScale(0.45, 0.72), UDim2.fromScale(0.5, 0.58)
stage.Flame.Size, stage.Flame.Position = UDim2.fromScale(0.10, 0.24), UDim2.fromScale(0.5, 0.65)
stage.FlameEcho.Visible = false
local scale = Instance.new("UIScale")
scale.Name, scale.Parent = "FireScale", stage.KilnPortrait
local card = c.Templates.RewardCard
local shape = Instance.new("UIAspectRatioConstraint")
shape.AspectRatio, shape.AspectType, shape.Parent = 5 / 6, Enum.AspectType.FitWithinMaxSize, card
card.Artwork.AnchorPoint, card.Artwork.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
card.Glow.Image = Assets["kiln/glow"]
card.Glow.Size, card.Glow.Position, card.Glow.ImageTransparency =
	UDim2.fromScale(0.90, 0.76), UDim2.fromScale(0.5, 0.38), 0.80
card.Rarity.Position, card.Rarity.Size = UDim2.fromScale(0.1, 0.08), UDim2.fromScale(0.8, 0.08)
card.Portrait.Position, card.Portrait.Size = UDim2.fromScale(0.5, 0.40), UDim2.fromScale(0.76, 0.46)
card.NameLabel.Position, card.NameLabel.Size = UDim2.fromScale(0.08, 0.66), UDim2.fromScale(0.84, 0.10)
card.RewardLabel.Position, card.RewardLabel.Size = UDim2.fromScale(0.10, 0.78), UDim2.fromScale(0.80, 0.08)
card.BonusLabel.Position, card.BonusLabel.Size = UDim2.fromScale(0.10, 0.86), UDim2.fromScale(0.80, 0.07)
c.Templates.Reel.Marker.BackgroundTransparency = 0.7
gui:SetAttribute("KilnOpeningVersion", 2)
modules:Destroy()
return "Full-screen opening and centered 5:6 reward card installed; V1 backed up"
