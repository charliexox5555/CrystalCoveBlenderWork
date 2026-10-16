-- Edit / MCP. Preserve the creator's previous screen before changing its editable layout.
assert(not game:GetService("RunService"):IsRunning(), "Stop Play first")
local gui = game.StarterGui.RollScreen
if gui:GetAttribute("SelectionPolishVersion") == 2 then
	return "Already installed; creator edits preserved"
end
local backups = game.ServerStorage:FindFirstChild("UIBackups") or Instance.new("Folder")
backups.Name, backups.Parent = "UIBackups", game.ServerStorage
local before = gui:Clone()
before.Name, before.Parent = "RollBeforeSelectionPolish_20261015", backups
local modules = game.StarterPlayer.StarterPlayerScripts.Client.UI:Clone()
modules.Name, modules.Parent = "SelectionPolishBuild", game.ServerStorage
local Theme = require(modules.Theme)
local S = require(modules.Components.StainedGlass)
local function place(o, x, y, w, h, center)
	o.AnchorPoint = if center then Vector2.new(0.5, 0.5) else Vector2.zero
	o.Position, o.Size = UDim2.fromScale(x, y), UDim2.fromScale(w, h)
end
local function label(parent, name, text, x, y, w, h, max)
	local o = Instance.new("TextLabel")
	o.Name, o.Text, o.BackgroundTransparency = name, text, 1
	o.FontFace, o.TextColor3 = Theme.Fonts.Caption, Theme.Colors.Text
	o.TextSize, o.TextScaled, o.TextWrapped = max, false, false
	o:SetAttribute("FitSingleLine", true)
	local fit = Instance.new("UITextSizeConstraint")
	fit.MinTextSize, fit.MaxTextSize, fit.Parent = 1, max, o
	place(o, x, y, w, h)
	o.Parent = parent
	return o
end
local p = gui.Roll
place(p, 0.5, 0.5, 0.9, 0.88, true)
p.BackgroundColor3, p.BackgroundTransparency, p.BorderSizePixel = Theme.Palette.smoke, 0.06, 0
local edge = Instance.new("UIStroke")
edge.Color, edge.Thickness, edge.Transparency, edge.Parent = Theme.Palette.amethystLight, 2, 0.3, p
place(p.Title, 0.23, 0.025, 0.54, 0.09)
place(p.Player1, 0.02, 0.02, 0.18, 0.12)
place(p.Player2, 0.8, 0.02, 0.18, 0.12)
place(p.Cards, 0.14, 0.17, 0.72, 0.56)
local cards = { p.Cards.Templates.GlassyCard, p.Cards.Card1, p.Cards.Card2, p.Cards.Card3 }
for _, card in cards do
	card.Size = UDim2.fromScale(0.29, 1)
	place(card.Portrait, 0.5, 0.36, 0.86, 0.59, true)
	place(card:FindFirstChild("Name"), 0.06, 0.67, 0.88, 0.095)
	place(card.TypeTag, 0.1, 0.79, 0.35, 0.055)
	place(card.RarityTag, 0.53, 0.79, 0.37, 0.055)
	place(card.Power, 0.08, 0.87, 0.84, 0.10)
	card.Power.UITextSizeConstraint.MaxTextSize = 18
	label(card, "SelectedCheck", "✓", 0.78, 0.035, 0.17, 0.16, 40).TextColor3 = Theme.Palette.emeraldLight
	card.SelectedCheck.FontFace = Theme.Fonts.Heading
	card.SelectedCheck.Visible = false
end
place(p.PickAny, 0.32, 0.84, 0.29, 0.105, true)
place(p.Reroll, 0.69, 0.84, 0.25, 0.105, true)
place(p.Wallet, 0.36, 0.745, 0.28, 0.04)
place(p.Message, 0.12, 0.96, 0.76, 0.035)
label(p, "RerollOdds", "", 0.055, 0.91, 0.73, 0.04, 16)
local odds = p.Reroll:Clone()
odds.Name, odds.Parent = "ViewOdds", p
place(odds, 0.88, 0.93, 0.15, 0.055, true)
S.buttonText(odds, "VIEW ODDS")
place(p.PickAnyChooser, 0.055, 0.14, 0.89, 0.65)
place(p.PickAnyChooser.Title, 0.04, 0.035, 0.74, 0.10)
place(p.PickAnyChooser.Cancel, 0.9, 0.09, 0.14, 0.10, true)
place(p.PickAnyChooser.Grid, 0.04, 0.20, 0.92, 0.73)
p.Confirm.Visible = false
gui:SetAttribute("SelectionPolishVersion", 2)
gui:SetAttribute(
	"EditHint",
	"Single-tap spending; inline uniform reroll odds. PickAnyChooser lists owned glassies. MarblesRequested runtime event is the future purchase hook; no product is enabled."
)
S.bindSlices(gui)
modules:Destroy()
return { Screen = gui:GetFullName(), Backup = before:GetFullName(), Version = 2 }
