-- Polish pass (2026-10-14): safe, re-runnable migration of the editable StarterGui placeholders.
-- Run in Edit mode through the Studio MCP. It:
--   1. backs up every StarterGui ScreenGui once into ServerStorage.UIBackups.Polish_2026_10_14;
--   2. only moves/resizes controls whose geometry still matches the original placeholder builder,
--      so anything the creator has already restyled is left alone;
--   3. adds new named elements (with Scale-only layout) when they are missing.
-- Re-running is harmless: matched geometry has already moved and existing elements are kept.

local StarterGui = game:GetService("StarterGui")
local ServerStorage = game:GetService("ServerStorage")
local changed, skipped = {}, {}

local function note(list, text)
	table.insert(list, text)
end

-- 1. Backup -----------------------------------------------------------------------------------
local backups = ServerStorage:FindFirstChild("UIBackups") or Instance.new("Folder")
backups.Name, backups.Parent = "UIBackups", ServerStorage
if not backups:FindFirstChild("Polish_2026_10_14") then
	local folder = Instance.new("Folder")
	folder.Name = "Polish_2026_10_14"
	for _, gui in StarterGui:GetChildren() do
		if gui:IsA("ScreenGui") then
			gui:Clone().Parent = folder
		end
	end
	folder.Parent = backups
	note(changed, "backup created")
end

local function same(a: UDim2, b: UDim2)
	return math.abs(a.X.Scale - b.X.Scale) < 1e-4
		and math.abs(a.Y.Scale - b.Y.Scale) < 1e-4
		and a.X.Offset == b.X.Offset
		and a.Y.Offset == b.Y.Offset
end

-- Move a control only if it still sits exactly where the placeholder builder put it.
local function migrate(item: GuiObject?, label: string, oldSize: UDim2, oldPos: UDim2, newSize: UDim2, newPos: UDim2)
	if not item then
		note(skipped, label .. " missing")
		return
	end
	if same(item.Size, newSize) and same(item.Position, newPos) then
		return
	end
	if same(item.Size, oldSize) and same(item.Position, oldPos) then
		item.Size, item.Position = newSize, newPos
		note(changed, label)
	else
		note(skipped, label .. " (custom layout kept)")
	end
end

local function textLabel(parent: Instance, name: string, text: string, size: UDim2, position: UDim2)
	local existing = parent:FindFirstChild(name)
	if existing then
		return existing
	end
	local label = Instance.new("TextLabel")
	label.Name, label.Text, label.Size, label.Position = name, text, size, position
	label.BackgroundTransparency, label.TextScaled = 1, true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.FontFace = Font.fromName("Montserrat", Enum.FontWeight.Bold)
	local limit = Instance.new("UITextSizeConstraint")
	limit.MinTextSize, limit.MaxTextSize = 10, 20
	limit.Parent = label
	label.Parent = parent
	note(changed, parent.Name .. "." .. name .. " added")
	return label
end

-- 2. Round result banner: centred above the pen instead of a thin line at the bottom ---------
local roundEnd = StarterGui:FindFirstChild("RoundEnd")
if roundEnd then
	migrate(
		roundEnd:FindFirstChild("Round") :: GuiObject?,
		"RoundEnd.Round",
		UDim2.fromScale(0.6, 0.08),
		UDim2.fromScale(0.2, 0.83),
		UDim2.fromScale(0.7, 0.1),
		UDim2.fromScale(0.15, 0.58)
	)
	local hearts =
		textLabel(roundEnd, "Hearts", "YOU ♥♥♡     RIVAL ♥♥♥", UDim2.fromScale(0.6, 0.06), UDim2.fromScale(0.2, 0.69))
	hearts.TextColor3 = Color3.fromHex("#FF5C7A")
end

-- 3. Fight HUD: side colour stripes match the queue pads (A blue, B orange) ------------------
local fightHud = StarterGui:FindFirstChild("FightHud")
for side, color in { Color3.fromHex("#4FB8FF"), Color3.fromHex("#FF9F43") } do
	local panel = fightHud and fightHud:FindFirstChild("Side" .. side)
	if panel and not panel:FindFirstChild("SideStripe") then
		local stripe = Instance.new("Frame")
		stripe.Name, stripe.BorderSizePixel, stripe.BackgroundColor3 = "SideStripe", 0, color
		stripe.Size = UDim2.fromScale(0.012, 0.76)
		stripe.Position = UDim2.fromScale(if side == 1 then 0.004 else 0.984, 0.12)
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = stripe
		stripe.Parent = panel
		note(changed, "FightHud.Side" .. side .. ".SideStripe added")
	end
end

-- 4. Fight HUD: STOP WATCHING button for spectators, styled by the shared Button component so the
--    creator can restyle it in the template. Hidden by default; FightHud shows it only while watching.
if fightHud and not fightHud:FindFirstChild("StopWatching") then
	local Button = require(game.StarterPlayer.StarterPlayerScripts.Client.UI.Components.Button)
	local stop = Button.new(
		fightHud,
		"StopWatching",
		"STOP WATCHING",
		"Red",
		UDim2.fromScale(0.26, 0.1),
		UDim2.fromScale(0.5, 0.98),
		Vector2.new(0.5, 1)
	)
	local limit = Instance.new("UISizeConstraint")
	limit.MinSize = Vector2.new(120, 44)
	limit.Parent = stop
	stop.Visible = false
	note(changed, "FightHud.StopWatching added")
end

return { Changed = changed, Skipped = skipped }
