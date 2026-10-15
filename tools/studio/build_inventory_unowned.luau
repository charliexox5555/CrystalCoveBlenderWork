-- Edit-only migration; preserve the creator's Inventory shell and tile art.
assert(not game:GetService("RunService"):IsRunning(), "Stop Play first")
local gui = game.StarterGui.CollectionScreen
assert(not gui:GetAttribute("UnownedInventoryVersion"), "Preserve creator edits: sections already installed")
local before = gui:Clone()
before.Name, before.Parent = "InventoryBeforeUnowned_20261015", game.ServerStorage.UIBackups
local modules = game.StarterPlayer.StarterPlayerScripts.Client.UI:Clone()
modules.Name, modules.Parent = "InventorySectionBuild", game.ServerStorage
local Theme = require(modules.Theme)
local S = require(modules.Components.StainedGlass)
local P = Theme.Palette
local function make(class, parent, name, props)
	local o = Instance.new(class)
	o.Name = name
	for key, value in props do
		o[key] = value
	end
	o.Parent = parent
	return o
end
local function text(parent, name, value, x, y, w, h, max)
	local label = make("TextLabel", parent, name, {
		Text = value,
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(x, y),
		Size = UDim2.fromScale(w, h),
		FontFace = Theme.Fonts.Heading,
		TextColor3 = P.milkLight,
		TextSize = max,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	label:SetAttribute("FitSingleLine", true)
	make("UITextSizeConstraint", label, "UITextSizeConstraint", { MinTextSize = 1, MaxTextSize = max })
	return label
end
local grid = gui.Panel.Content.Grid
local original = grid.Tiles.UIGridLayout
grid:SetAttribute("SectionTileHeight", original.CellSize.Y.Scale * grid.CanvasSize.Y.Scale)
grid:SetAttribute("SectionTileGap", original.CellPadding.Y.Scale * grid.CanvasSize.Y.Scale)
grid:SetAttribute("SectionHeaderHeight", 0.08)
grid:SetAttribute("SectionGap", 0.04)
grid:SetAttribute("SectionEmptyHeight", 0.10)
grid:SetAttribute("SectionBottomPadding", 0.02)
local unowned = make("Frame", grid, "UnownedTiles", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 })
original:Clone().Parent = unowned
for _, kind in { "Owned", "Unowned" } do
	local header =
		make("Frame", grid, kind .. "Header", { Size = UDim2.fromScale(1, 0.08), BackgroundTransparency = 1 })
	text(header, "Label", kind:upper(), 0.18, 0, 0.64, 1, 25)
	for _, x in { 0, 0.84 } do
		make("Frame", header, "Divider", {
			Size = UDim2.fromScale(0.16, 0.035),
			Position = UDim2.fromScale(x, 0.5),
			BackgroundColor3 = P.slate,
			BackgroundTransparency = 0.35,
			BorderSizePixel = 0,
		})
	end
	text(
		grid,
		kind .. "Empty",
		if kind == "Owned" then "Your glassies will appear here" else "You own every glassy!",
		0.02,
		0,
		0.96,
		0.10,
		16
	).TextColor3 =
		P.milk
end
text(grid.Templates.GlassyTile, "Unknown", "?", 0.15, 0.14, 0.7, 0.53, 52).Visible = false
local unknown = grid.Templates.GlassyTile:Clone()
unknown.Name, unknown.Parent = "UnownedGlassyTile", grid.Templates
unknown.Portrait.ImageColor3, unknown.Portrait.ImageTransparency = Color3.fromRGB(160, 165, 180), 0.12
unknown.Artwork.ImageTransparency = 0.12
local info = gui.Panel.Content.InfoPane
info.TypeTag.Position = UDim2.fromScale(info.TypeTag.Position.X.Scale, 0.17)
info.RarityTag.Position = UDim2.fromScale(info.RarityTag.Position.X.Scale, 0.17)
info.ViewportPane.Position = UDim2.fromScale(info.ViewportPane.Position.X.Scale, 0.225)
info.InfoPortrait.Position = UDim2.fromScale(0.5, 0.35)
text(info, "Ownership", "OWNED", 0.06, 0.128, 0.88, 0.037, 14)
text(info, "UnknownPortrait", "?", 0.15, 0.25, 0.70, 0.16, 56).Visible = false
text(info, "ArtworkPending", "Artwork coming soon", 0.06, 0.42, 0.88, 0.032, 12).Visible = false
gui:SetAttribute("UnownedInventoryVersion", 1)
gui:SetAttribute(
	"EditHint",
	"Inventory: OwnedHeader/Tiles, then UnownedHeader/UnownedTiles in one scroller. Edit GlassyTile and UnownedGlassyTile prototypes. All catalog entries are inspectable; missing artwork uses a ?."
)
S.bindSlices(gui)
modules:Destroy()
return { Screen = gui:GetFullName(), Backup = before:GetFullName() }
