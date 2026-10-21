-- Studio Play (Client datamodel, MCP execute_luau): a side-by-side board for docs/testing/viewports. Each cell shows
-- the live viewport (left) next to the pre-rendered icon (right) on the tile's dark pane, then screen_capture it.
-- Set KEYS = { { "Glassies", "pop" }, { "Rideables", "skyboard" }, { "Machines", "Glassies:Coins" }, ... } (max ~8),
-- and optionally ICONS = { ["Glassies:pop"] = "rbxassetid://..." } for icons not in Config/ItemIcons yet.
-- Remove with PlayerGui.PortraitCompare:Destroy().
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Client = Players.LocalPlayer.PlayerScripts.Client
local Item = require(Client.UI.Components.ItemPresentation)
local Icons = require(RS.Shared.Config.ItemIcons)
local gui = Players.LocalPlayer.PlayerGui:FindFirstChild("PortraitCompare")
if gui then
	gui:Destroy()
end
gui = Instance.new("ScreenGui")
gui.Name, gui.DisplayOrder, gui.IgnoreGuiInset = "PortraitCompare", 100, true
local back = Instance.new("Frame")
back.Size, back.BackgroundColor3, back.Parent = UDim2.fromScale(1, 1), Color3.fromRGB(17, 20, 33), gui
local grid = Instance.new("UIGridLayout")
grid.CellSize, grid.CellPadding, grid.Parent = UDim2.fromScale(0.245, 0.48), UDim2.fromScale(0.005, 0.02), back
gui.Parent = Players.LocalPlayer.PlayerGui
for _, key in KEYS do
	local category, id = key[1], key[2]
	local cell = Instance.new("Frame")
	cell.BackgroundColor3, cell.BorderSizePixel, cell.Parent = Color3.fromRGB(38, 44, 70), 0, back
	local label = Instance.new("TextLabel")
	label.Size, label.Position, label.BackgroundTransparency = UDim2.fromScale(1, 0.1), UDim2.fromScale(0, 0.9), 1
	label.Text, label.TextScaled, label.TextColor3, label.Parent = id .. "  (live | icon)", true, Color3.new(1, 1, 1), cell
	local left = Instance.new("Frame")
	left.Size, left.BackgroundTransparency, left.Parent = UDim2.fromScale(0.5, 0.9), 1, cell
	local right = left:Clone()
	right.Position, right.Parent = UDim2.fromScale(0.5, 0), cell
	for _, side in { left, right } do
		local aspect = Instance.new("UIAspectRatioConstraint")
		aspect.Parent = side
	end
	if category == "Machines" then
		local cat, currency = id:match("(%w+):(%w+)")
		Item.crate(left, cat, currency, UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), "Portrait", nil, true)
	else
		Item.portrait(left, category, id, UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), "Portrait", true)
	end
	local image = (ICONS or {})[category .. ":" .. id]
	local entry = Icons.get(category, id)
	local icon = Instance.new("ImageLabel")
	icon.Size, icon.BackgroundTransparency, icon.ScaleType = UDim2.fromScale(1, 1), 1, Enum.ScaleType.Fit
	icon.Image = image or entry and (entry.Large or entry.Small) or ""
	icon.Parent = right
end
return "board ready"
