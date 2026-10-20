-- Edit mode (Studio MCP), with the Studio lock held. Builds StarterGui.WelcomeScreen, the onboarding welcome card
-- (decision 100, docs/design/ONBOARDING.md): the small Stained Glass window of the Codes screen, re-dressed as a
-- reward claim (almost no reading: kids see one Kiln, a big x3 and a button).
--   Panel.Title                 "WELCOME!"
--   Panel.Content.Reward        the claim: Glow, Kiln (the Coin Kiln viewport, framed at runtime) with Count "x3"
--   Panel.Content.OpenButton    green gem "OPEN" (fires OnboardingAction "OpenWelcome")
--   Panel.Content.Odds          the welcome odds, small (the Kiln always shows odds before a pull)
-- No Close: the card goes away when the opens start. Replaces an earlier WelcomeScreen after backing it up.
assert(not game:GetService("RunService"):IsRunning(), "Run in Edit")
local StarterGui = game:GetService("StarterGui")
local SS = game:GetService("ServerStorage")
local codes = StarterGui:FindFirstChild("CodesScreen")
assert(codes, "CodesScreen template missing")
local old = StarterGui:FindFirstChild("WelcomeScreen")
if old then
	local backups = SS:FindFirstChild("UIBackup_Topbar") or Instance.new("Folder")
	backups.Name, backups.Parent = "UIBackup_Topbar", SS
	old.Name = "WelcomeScreen_" .. os.time()
	old.Parent = backups
end
local gui = codes:Clone()
gui.Name, gui.Enabled = "WelcomeScreen", false
gui:SetAttribute("TopbarScreen", nil)
gui:SetAttribute("Onboarding", true)
gui.DisplayOrder = 40
local panel = gui.Panel
panel.Close:Destroy()
panel.Title.Text = "WELCOME!"
local content = panel.Content
local Assets = require(game.ReplicatedStorage.Shared.Config.UIAssets)
content.InputField:Destroy()
content.Hint:Destroy()
-- The claim: one Kiln with a big "x3".
local reward = Instance.new("Frame")
reward.Name, reward.BackgroundTransparency = "Reward", 1
reward.AnchorPoint, reward.Position, reward.Size =
	Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.33), UDim2.fromScale(0.9, 0.56)
reward.Parent = content
local glow = Instance.new("ImageLabel")
glow.Name, glow.BackgroundTransparency, glow.Image = "Glow", 1, Assets["screens/daily_rewards/glow_burst"]
glow.AnchorPoint, glow.Position, glow.Size =
	Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), UDim2.fromScale(1.15, 1.15)
glow.ImageTransparency, glow.ZIndex = 0.25, 2
local square = Instance.new("UIAspectRatioConstraint")
square.Parent = glow
glow.Parent = reward
-- The Coin Kiln: a copy of the shop's KilnPortrait viewport (OnboardingController re-frames it at runtime).
local source = StarterGui.KilnScreen.Panel.Content.GlassiesPage.CoinKiln:FindFirstChild("KilnPortrait", true)
assert(source, "KilnScreen KilnPortrait missing")
local icon = source:Clone()
icon.Name, icon.BackgroundTransparency, icon.ZIndex = "Kiln", 1, 3
icon.AnchorPoint, icon.Position, icon.Size = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.9, 0.9)
if not icon:FindFirstChildOfClass("UIAspectRatioConstraint") then
	square:Clone().Parent = icon
end
icon.Parent = reward
local count = panel.Title:Clone() -- inside the Icon's square, so it sits on the Kiln's corner
count.Name, count.Text = "Count", "x3"
count.AnchorPoint, count.Position, count.Size =
	Vector2.new(0.5, 0.5), UDim2.fromScale(0.95, 0.86), UDim2.fromScale(0.62, 0.42)
count.TextColor3, count.Rotation, count.ZIndex = Color3.fromHex("#FFD98A"), -8, 5
count.TextXAlignment = Enum.TextXAlignment.Center
count.Parent = icon
local button = content.RedeemButton
button.Name = "OpenButton"
button.Position = UDim2.fromScale(0.5, 0.76)
local label = button:FindFirstChild("Label")
if label then
	label.Text = "OPEN"
end
local odds = content.Status
odds.Name, odds.Visible = "Odds", true
odds.Text = "1 COMMON · 1 UNCOMMON · 1 RARE (100%)"
odds.TextColor3 = Color3.fromHex("#CDAAFF")
odds.Position, odds.Size = UDim2.fromScale(0.5, 0.93), UDim2.fromScale(0.9, 0.07)
gui.Parent = StarterGui
return "WelcomeScreen built"
