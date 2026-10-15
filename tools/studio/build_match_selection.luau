assert(not game:GetService("RunService"):IsRunning(), "Stop Play first")
local gui = game.StarterGui.RollScreen
assert(not gui:GetAttribute("MatchHandVersion"), "Preserve creator edits: match hand installed")
local before = gui:Clone()
before.Name, before.Parent = "RollBeforeMatchHand_20261015", game.ServerStorage.UIBackups
local modules = game.StarterPlayer.StarterPlayerScripts.Client.UI:Clone()
modules.Name, modules.Parent = "MatchSelectionBuild", game.ServerStorage
local S = require(modules.Components.StainedGlass)
local Theme = require(modules.Theme)
local function make(class, parent, name, props)
	local o = Instance.new(class)
	o.Name = name
	for k, v in props do
		o[k] = v
	end
	o.Parent = parent
	return o
end
local function frame(parent, name, x, y, w, h)
	return make(
		"Frame",
		parent,
		name,
		{ Position = UDim2.fromScale(x, y), Size = UDim2.fromScale(w, h), BackgroundTransparency = 1 }
	)
end
local function label(parent, name, text, x, y, w, h, max)
	local l = make("TextLabel", parent, name, {
		Text = text,
		Position = UDim2.fromScale(x, y),
		Size = UDim2.fromScale(w, h),
		BackgroundTransparency = 1,
		FontFace = Theme.Fonts.Heading,
		TextColor3 = Theme.Palette.milkLight,
		TextSize = max,
	})
	l:SetAttribute("FitSingleLine", true)
	make("UITextSizeConstraint", l, "UITextSizeConstraint", { MinTextSize = 1, MaxTextSize = max })
	return l
end
local function pane(o)
	o.BackgroundColor3, o.BackgroundTransparency = Theme.Palette.smoke2, 0.04
	local a = S.image(o, "Artwork", "panel/pane_dark", UDim2.fromScale(1, 1))
	a.UIAspectRatioConstraint:Destroy()
	a:SetAttribute("StretchArtwork", true)
end
local p = gui.Roll
local old = p.Reroll
old.Name = "PickAny"
old.Size, old.Position = UDim2.fromScale(0.27, 0.10), UDim2.fromScale(0.5, 0.88)
old.Label.Text = "PICK ANY • FREE"
local function button(parent, name, text, x, y, w, h, color)
	local b = old:Clone()
	b.Name, b.Parent = name, parent
	b.Size, b.Position = UDim2.fromScale(w, h), UDim2.fromScale(x, y)
	b.AnchorPoint = Vector2.new(0.5, 0.5)
	S.setAsset(b.Artwork, "button/gem_" .. color)
	b.Label.Text = text
	return b
end
button(p, "Reroll", "REROLL • 3", 0.85, 0.88, 0.17, 0.08, "amethyst")
label(p, "Wallet", "0 MARBLES", 0.70, 0.79, 0.27, 0.045, 20)
frame(p, "ReelLayer", 0, 0, 1, 1)
local chooser = frame(p, "PickAnyChooser", 0.09, 0.17, 0.82, 0.62)
chooser.Visible = false
pane(chooser)
label(chooser, "Title", "PICK ANY • FREE", 0.04, 0.03, 0.70, 0.11, 28)
button(chooser, "Cancel", "BACK", 0.90, 0.09, 0.14, 0.10, "sapphire")
local grid = make("ScrollingFrame", chooser, "Grid", {
	Position = UDim2.fromScale(0.04, 0.18),
	Size = UDim2.fromScale(0.92, 0.77),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	CanvasSize = UDim2.fromScale(0, 1),
	ScrollBarThickness = 4,
	ClipsDescendants = true,
})
local root = frame(grid, "Tiles", 0, 0, 1, 1)
make("UIGridLayout", root, "UIGridLayout", {
	CellSize = UDim2.fromScale(0.18, 0.70),
	CellPadding = UDim2.fromScale(0.02, 0.04),
	SortOrder = Enum.SortOrder.LayoutOrder,
})
local templates = make("Folder", grid, "Templates", {})
local tile = game.StarterGui.CollectionScreen.Panel.Content.Grid.Templates.GlassyTile:Clone()
tile.Name, tile.Parent = "GlassyTile", templates
local confirm = frame(p, "Confirm", 0.23, 0.27, 0.54, 0.43)
confirm.Visible = false
pane(confirm)
label(confirm, "Title", "REROLL • 3 MARBLES", 0.05, 0.05, 0.90, 0.15, 27)
local copy = label(confirm, "Body", "", 0.06, 0.24, 0.88, 0.40, 19)
copy:SetAttribute("FitSingleLine", false)
copy.TextScaled, copy.TextWrapped = true, true
local odds = make("ScrollingFrame", confirm, "Odds", {
	Position = UDim2.fromScale(0.06, 0.42),
	Size = UDim2.fromScale(0.88, 0.29),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 3,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
	Visible = false,
})
make("UIListLayout", odds, "UIListLayout", { SortOrder = Enum.SortOrder.Name, Padding = UDim.new(0, 2) })
button(confirm, "Accept", "CONFIRM", 0.30, 0.84, 0.42, 0.19, "emerald")
button(confirm, "Cancel", "CANCEL", 0.76, 0.84, 0.34, 0.19, "sapphire")
gui:SetAttribute("MatchHandVersion", 1)
gui:SetAttribute(
	"EditHint",
	"Three-card match hand; PickAnyChooser lists owned entries, Confirm shows Marble cost and reroll odds, ReelLayer contains transient vertical card rolls."
)
S.bindSlices(gui)
modules:Destroy()
return { Screen = gui:GetFullName(), Backup = before:GetFullName() }
