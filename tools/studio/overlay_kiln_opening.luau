-- Creator feedback: transparent overlay and Collect-to-Inventory exit.
assert(not game:GetService("RunService"):IsRunning(), "Stop Play first")
local gui = game.StarterGui.KilnRevealScreen
assert(gui:GetAttribute("KilnOpeningVersion") == 2, "Preserve creator edits: overlay already installed")
local before = gui:Clone()
before.Name, before.Parent = "KilnOpeningV2_20261015", game.ServerStorage.UIBackups
gui.Panel.BackgroundTransparency = 1
gui.Backdrop:Destroy()
local outline = Instance.new("UIStroke")
outline.Color, outline.Thickness, outline.Parent = Color3.fromHex("1F1830"), 2, gui.Panel.Content.Status
gui.Panel.Content.Back.Name = "Collect"
gui.Panel.Content.Collect.Label.Text = "COLLECT"
gui:SetAttribute("KilnOpeningVersion", 3)
gui:SetAttribute(
	"EditHint",
	"Transparent UI opening. Reels, kiln and cards are editable. Collect flies the glassies into LobbyHUD.Navigation.InventoryButton."
)
return "Transparent opening overlay installed; Collect replaces Back"
