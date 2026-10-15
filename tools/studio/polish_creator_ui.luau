-- Targeted migration of the creator's v0.5 edits; never reruns the theme installer.
assert(not game:GetService("RunService"):IsRunning(), "Edit mode required")
local StarterGui = game:GetService("StarterGui")
local RS = game:GetService("ReplicatedStorage")
assert(game.ServerStorage:FindFirstChild("UIBackup_UserEdits_20261015"), "Back up creator templates first")
local inventory = StarterGui.CollectionScreen.Panel
inventory.Size = UDim2.fromScale(0.74, 0.8)
local info = inventory.Content.InfoPane
info.ViewportPane.Position = UDim2.fromScale(0.05, 0.215)
info.InfoPortrait.Position = UDim2.fromScale(0.15, 0.22)
local rows = {
	{ "PassiveCaption", 0.48, 0.04 },
	{ "PassiveName", 0.52, 0.045 },
	{ "PassiveDescription", 0.565, 0.085 },
	{ "PowerCaption", 0.655, 0.04 },
	{ "PowerName", 0.695, 0.045 },
	{ "PowerDescription", 0.74, 0.10 },
}
for _, row in rows do
	local label = info[row[1]]
	label.Position = UDim2.fromScale(label.Position.X.Scale, row[2])
	label.Size = UDim2.fromScale(label.Size.X.Scale, row[3])
end
for _, name in { "PowerLabel", "HPLabel", "SwingLabel" } do
	local label = info[name]
	label.Size = UDim2.fromScale(label.Size.X.Scale, 0.04)
end
local shop = StarterGui.KilnScreen.Panel
shop.Size = UDim2.fromScale(0.81, 0.84)
shop.Tabs.Size = UDim2.fromScale(0.53, shop.Tabs.Size.Y.Scale)
shop.Coins.Position = UDim2.fromScale(0.63, 0.11)
shop.Marbles.Position = UDim2.fromScale(0.8, 0.11)
local icons = {
	{ StarterGui.LobbyHUD.Currency.Coins.Icon, "rbxassetid://139764505735042" },
	{ shop.Coins.Icon, "rbxassetid://139764505735042" },
	{ StarterGui.LobbyHUD.Currency.Marbles.Icon, "rbxassetid://126376968177419" },
	{ shop.Marbles.Icon, "rbxassetid://126376968177419" },
	{ StarterGui.LobbyHUD.Navigation.InventoryButton.Icon, "rbxassetid://125282322841576" },
}
for _, entry in icons do
	entry[1].Image, entry[1].ScaleType = entry[2], Enum.ScaleType.Fit
end
-- Keep all authored HUD placement and PLAY sizing. Stars stay removed.
local body = RS.Assets.UI.FightBillboard.Body
local hp = body:FindFirstChild("HpAmount") or Instance.new("TextLabel")
hp.Name, hp.BackgroundTransparency = "HpAmount", 1
body.GlassyTag.Position = UDim2.fromScale(0.08, 0.62)
hp.Size, hp.Position = UDim2.fromScale(0.84, 0.18), UDim2.fromScale(0.08, 0.81)
hp.FontFace = require(game.StarterPlayer.StarterPlayerScripts.Client.UI.Theme).Fonts.Body
hp.TextColor3, hp.TextSize, hp.Text = Color3.fromHex("#FFF8DE"), 18, "110 / 110 HP"
hp.TextScaled, hp.TextWrapped = false, false
hp:SetAttribute("FitSingleLine", true)
hp:SetAttribute("MaxTextSize", 18)
local cap = hp:FindFirstChildOfClass("UITextSizeConstraint") or Instance.new("UITextSizeConstraint")
cap.MinTextSize, cap.MaxTextSize, cap.Parent = 1, 18, hp
hp.Parent = body
StarterGui.FightHud.PowerBanner.Visible = false
StarterGui.RoundEnd.Enabled, StarterGui.ResultsScreen.Enabled = false, false
StarterGui:SetAttribute("GameplayPolishVersion", 1)
-- Centre every interactive control without changing its authored visual placement.
local Motion = require(game.StarterPlayer.StarterPlayerScripts.Client.UI.Components.Motion)
local centered = 0
for _, object in StarterGui:GetDescendants() do
	if object:IsA("GuiButton") then
		Motion.center(object)
		if object.Name == "Open" and object.Parent:IsA("GuiObject") then
			Motion.center(object.Parent)
		end
		centered += 1
	end
end
StarterGui:SetAttribute("CenteredButtons", centered)
return "Creator edits preserved; smaller menus, separated tabs/currency, matching icons, HP billboard installed"
