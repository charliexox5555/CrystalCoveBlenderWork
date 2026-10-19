-- Edit mode (Studio MCP), with the Studio lock held. Creates the placeholder ScreenGuis the top bar opens
-- (Config/Topbar, TopbarController; decision 98) in StarterGui so they can be designed in Studio:
-- SettingsScreen, DailyRewardsScreen, PlaytimeRewardsScreen, CodesScreen, QuestsScreen.
-- Each is a Stained Glass window like the other menus: the Inventory window's artwork, title banner, title and
-- close diamond (cloned from StarterGui.CollectionScreen.Panel), an empty Content frame and a "Coming soon" label.
-- The controller only needs the ScreenGui name and a GuiButton named "Close" somewhere inside it.
-- Never overwrites: a screen that already exists in StarterGui is left alone (it may hold the creator's design).
assert(not game:GetService("RunService"):IsRunning(), "Run in Edit")
local StarterGui = game:GetService("StarterGui")
local SCREENS = {
	{ Name = "SettingsScreen", Title = "SETTINGS", Banner = "rbxassetid://127187062345543" }, -- sapphire
	{ Name = "DailyRewardsScreen", Title = "DAILY REWARDS", Banner = "rbxassetid://98596836833682" }, -- amber
	{ Name = "PlaytimeRewardsScreen", Title = "PLAYTIME", Banner = "rbxassetid://98596836833682" },
	{ Name = "CodesScreen", Title = "CODES", Banner = "rbxassetid://81888106457155" }, -- amethyst
	{ Name = "QuestsScreen", Title = "QUESTS", Banner = "rbxassetid://105909304666917" }, -- emerald
}
local source = StarterGui:WaitForChild("CollectionScreen"):WaitForChild("Panel")
local report = {}
for _, spec in SCREENS do
	if StarterGui:FindFirstChild(spec.Name) then
		table.insert(report, spec.Name .. ": kept (already in StarterGui)")
		continue
	end
	local gui = Instance.new("ScreenGui")
	gui.Name, gui.Enabled, gui.ResetOnSpawn = spec.Name, false, false
	gui.ScreenInsets, gui.DisplayOrder = Enum.ScreenInsets.CoreUISafeInsets, 20
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui:SetAttribute("TopbarScreen", true)
	local panel = Instance.new("Frame")
	panel.Name, panel.BackgroundTransparency, panel.Active = "Panel", 1, true
	panel.AnchorPoint, panel.Position, panel.Size = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.7, 0.78)
	panel:SetAttribute("StainedGlass", true)
	panel.Parent = gui
	for _, part in { "UIAspectRatioConstraint", "WindowArtwork", "TitleBanner", "Title", "Close" } do
		source[part]:Clone().Parent = panel
	end
	panel.WindowArtwork.ZIndex = 0
	panel.TitleBanner.ZIndex, panel.Title.ZIndex, panel.Close.ZIndex = 3, 4, 5
	panel.TitleBanner.Image = spec.Banner
	panel.Title.Text = spec.Title
	local content = Instance.new("Frame")
	content.Name, content.BackgroundTransparency = "Content", 1
	content.Position, content.Size = source.Content.Position, source.Content.Size
	content.ZIndex = 2
	content.Parent = panel
	local note = Instance.new("TextLabel")
	note.Name, note.BackgroundTransparency, note.Text = "Placeholder", 1, "Coming soon"
	note.AnchorPoint, note.Position, note.Size = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.45), UDim2.fromScale(0.6, 0.14)
	note.FontFace, note.TextColor3, note.TextScaled = source.Title.FontFace, source.Title.TextColor3, true
	note.ZIndex = 2
	note.Parent = content
	local stroke = source.Title:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke:Clone().Parent = note
	end
	gui.Parent = StarterGui
	table.insert(report, spec.Name .. ": created")
end
return table.concat(report, "\n")
