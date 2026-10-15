-- One-time Edit-only installer. The entire opening lives in StarterGui, with editable prototypes.
assert(not game:GetService("RunService"):IsRunning(), "Stop Play first")
local starter, storage = game.StarterGui, game.ServerStorage
assert(
	not starter.KilnRevealScreen:GetAttribute("KilnOpeningVersion"),
	"Preserve creator edits: opening already installed"
)
local backups = storage.UIBackups
local before = starter.KilnRevealScreen:Clone()
before.Name, before.Parent = "KilnOpeningBefore_20261015", backups
local modules = starter.Parent.StarterPlayer.StarterPlayerScripts.Client.UI:Clone()
modules.Name, modules.Parent = "KilnOpeningBuild", storage
local S = require(modules.Components.StainedGlass)
local Portrait = require(modules.Components.GlassyPortrait)
local Theme = require(modules.Theme)
local FX = require(game.ReplicatedStorage.Shared.Config.KilnAssets)
local P = Theme.Palette
local function make(class, parent, name, props)
	local o = Instance.new(class)
	o.Name = name
	for k, v in props or {} do
		o[k] = v
	end
	o.Parent = parent
	return o
end
local function frame(parent, name, w, h, x, y)
	return make("Frame", parent, name, {
		Size = UDim2.fromScale(w, h),
		Position = UDim2.fromScale(x or 0, y or 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	})
end
local function text(parent, name, value, w, h, x, y, maximum, color)
	local t = make("TextLabel", parent, name, {
		Size = UDim2.fromScale(w, h),
		Position = UDim2.fromScale(x, y),
		BackgroundTransparency = 1,
		Text = value,
		TextColor3 = color or P.milkLight,
		FontFace = Theme.Fonts.Heading,
		TextSize = maximum,
		TextScaled = false,
	})
	t:SetAttribute("FitSingleLine", true)
	make("UITextSizeConstraint", t, "UITextSizeConstraint", { MinTextSize = 1, MaxTextSize = maximum })
	return t
end
local function pane(parent)
	local a = S.image(parent, "Artwork", "panel/pane_dark", UDim2.fromScale(1, 1))
	a.UIAspectRatioConstraint:Destroy()
	a:SetAttribute("StretchArtwork", true)
	return a
end
local function effect(parent, name, image, w, h, x, y)
	return make("ImageLabel", parent, name, {
		Size = UDim2.fromScale(w, h),
		Position = UDim2.fromScale(x, y),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Image = image,
		ScaleType = Enum.ScaleType.Fit,
	})
end
local gui = starter.KilnScreen:Clone()
gui.Name, gui.Enabled = "KilnRevealScreen", false
gui:SetAttribute("KilnOpeningVersion", 1)
gui:SetAttribute("ShopLayoutVersion", nil)
gui:SetAttribute(
	"EditHint",
	"Edit opening stage, kiln, reel and reward prototypes here. PreviewKiln in Studio plays one or ten without purchases."
)
local p, c = gui.Panel, gui.Panel.Content
for _, name in { "Tabs", "Coins", "Marbles" } do
	p[name]:Destroy()
end
c:ClearAllChildren()
c.Position, c.Size = UDim2.fromScale(0.03, 0.15), UDim2.fromScale(0.94, 0.81)
p.Title.Text = "THE KILN"
local status = text(c, "Status", "SHAPING YOUR GLASS…", 1, 0.075, 0, 0, 25, P.amberLight)
local reels = frame(c, "Reels", 1, 0.76, 0, 0.10)
local kiln = frame(c, "KilnStage", 1, 0.76, 0, 0.10)
kiln.Visible = false
effect(kiln, "Burst", FX.Burst, 0.86, 1.25, 0.5, 0.48)
local v = starter.KilnScreen.Panel.Content.GlassiesPage.CoinKiln.KilnPortrait:Clone()
v.Name, v.Parent, v.Size, v.Position, v.AnchorPoint =
	"KilnPortrait", kiln, UDim2.fromScale(0.68, 0.95), UDim2.fromScale(0.5, 0.52), Vector2.new(0.5, 0.5)
effect(kiln, "Flame", FX.Flame, 0.31, 0.65, 0.5, 0.57)
effect(kiln, "FlameEcho", FX.Flame, 0.25, 0.55, 0.5, 0.57).ImageColor3 = P.amberLight
local sparks = frame(kiln, "Sparks", 1, 1)
local rewards = frame(c, "Rewards", 1, 0.76, 0, 0.10)
rewards.Visible = false
local buttonSource = starter.KilnScreen.Panel.Content.GlassiesPage.CoinKiln.Pull1
for _, spec in { { "Skip", "SKIP ANIMATION", "sapphire", 0.24, 0.5 }, { "Back", "BACK TO SHOP", "emerald", 0.32, 0.5 } } do
	local b = buttonSource:Clone()
	b.Name, b.Parent, b.Size, b.Position, b.AnchorPoint =
		spec[1], c, UDim2.fromScale(spec[4], 0.105), UDim2.fromScale(spec[5], 0.945), Vector2.new(0.5, 0.5)
	S.setAsset(b.Artwork, "button/gem_" .. spec[3])
	b.Label.Text = spec[2]
	b.Label.UITextSizeConstraint.MaxTextSize = 22
	b.Visible = spec[1] == "Skip"
end
local templates = make("Folder", c, "Templates")
local reel = frame(templates, "Reel", 1, 1)
reel.Visible = false
pane(reel)
local track = frame(reel, "Track", 0.97, 0.90, 0.015, 0.05)
track.ClipsDescendants = true
local line = make("Frame", reel, "Marker", {
	Size = UDim2.new(0, 2, 0.94, 0),
	Position = UDim2.fromScale(0.5, 0.5),
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundColor3 = P.amberLight,
	BorderSizePixel = 0,
	ZIndex = 5,
})
for _, y in { 0.02, 0.98 } do
	make("Frame", reel, "Diamond", {
		Size = UDim2.fromOffset(10, 10),
		Position = UDim2.fromScale(0.5, y),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Rotation = 45,
		BackgroundColor3 = P.amber,
		BorderSizePixel = 0,
		ZIndex = 6,
	})
end
local cell = frame(templates, "ReelCell", 0.22, 0.94)
cell.Visible = false
cell.AnchorPoint = Vector2.new(0.5, 0.5)
pane(cell)
local band = make("Frame", cell, "RarityBand", {
	Size = UDim2.fromScale(0.94, 0.04),
	Position = UDim2.fromScale(0.03, 0.92),
	BackgroundColor3 = P.milk,
	BorderSizePixel = 0,
})
S.aspect(Portrait.new(cell, "pop", UDim2.fromScale(0.88, 0.73), UDim2.fromScale(0.06, 0.015)), 1)
text(cell, "NameLabel", "Pop Bottle", 0.92, 0.18, 0.04, 0.74, 18)
local card = frame(templates, "RewardCard", 0.17, 0.47)
card.Visible = false
card.AnchorPoint = Vector2.new(0.5, 0.5)
local bg = S.image(card, "Artwork", "tile/tile_common", UDim2.fromScale(1, 1))
bg.UIAspectRatioConstraint.AspectType = Enum.AspectType.FitWithinMaxSize
effect(card, "Glow", FX.Burst, 1.45, 1.45, 0.5, 0.40).ImageTransparency = 0.5
S.aspect(Portrait.new(card, "pop", UDim2.fromScale(0.78, 0.53), UDim2.fromScale(0.11, 0.10)), 1)
text(card, "Rarity", "COMMON", 0.80, 0.10, 0.10, 0.04, 15, P.milk)
text(card, "NameLabel", "Pop Bottle", 0.84, 0.12, 0.08, 0.66, 23)
text(card, "RewardLabel", "NEW GLASSY!", 0.84, 0.10, 0.08, 0.79, 16, P.emeraldLight)
text(card, "BonusLabel", "", 0.80, 0.08, 0.10, 0.89, 14, P.amberLight)
make("UIScale", card, "RevealScale", { Scale = 1 })
starter.KilnRevealScreen:Destroy()
gui.Parent = starter
S.bindSlices(gui)
Portrait.bindCameras(gui)
modules:Destroy()
return { Screen = gui:GetFullName(), Backup = before:GetFullName(), Version = 1 }
