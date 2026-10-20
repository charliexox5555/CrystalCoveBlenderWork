-- Edit mode (Studio MCP), with the Studio lock held. Builds StarterGui.WelcomeScreen, the onboarding welcome card
-- (decision 100, docs/design/ONBOARDING.md): the small Stained Glass window of the Codes screen, re-dressed.
--   Panel.Title            "WELCOME!"
--   Panel.Content.Body     "Here are 3 free Kiln opens to start your glassy collection!"
--   Panel.Content.Odds     the welcome odds line (OnboardingController fills it from the server)
--   Panel.Content.Sub      a small line under the button
--   Panel.Content.OpenButton  green gem "OPEN" (fires OnboardingAction "OpenWelcome")
-- No Close: the card goes away when the opens start. Replaces an earlier WelcomeScreen after backing it up.
assert(not game:GetService("RunService"):IsRunning(), "Run in Edit")
local StarterGui = game:GetService("StarterGui")
local SS = game:GetService("ServerStorage")
local source = StarterGui:FindFirstChild("CodesScreen")
assert(source, "CodesScreen template missing")
local old = StarterGui:FindFirstChild("WelcomeScreen")
if old then
	local backups = SS:FindFirstChild("UIBackup_Topbar") or Instance.new("Folder")
	backups.Name, backups.Parent = "UIBackup_Topbar", SS
	old.Name = "WelcomeScreen_" .. os.time()
	old.Parent = backups
end
local gui = source:Clone()
gui.Name, gui.Enabled = "WelcomeScreen", false
gui:SetAttribute("TopbarScreen", nil)
gui:SetAttribute("Onboarding", true)
gui.DisplayOrder = 40
local panel = gui.Panel
panel.Close:Destroy()
panel.Title.Text = "WELCOME!"
local content = panel.Content
local field = content:FindFirstChild("InputField")
local fieldPos, fieldSize, fieldAnchor = field.Position, field.Size, field.AnchorPoint
field:Destroy()
local body = content.Hint:Clone()
body.Name, body.Text = "Body", "Here are 3 free Kiln opens to start your glassy collection!"
body.Position, body.Size, body.AnchorPoint = fieldPos, fieldSize, fieldAnchor
body.TextWrapped, body.TextColor3 = true, Color3.new(1, 1, 1)
body.Parent = content
local button = content.RedeemButton
button.Name = "OpenButton"
local label = button:FindFirstChild("Label")
if label then
	label.Text = "OPEN"
end
local status = content.Status
status.Name, status.Visible = "Odds", true
status.Text = "1 COMMON · 1 UNCOMMON · 1 RARE (100%) · NEVER ONE YOU OWN"
status.TextColor3 = Color3.fromHex("#CDAAFF")
local sub = content.Hint
sub.Name, sub.Text = "Sub", "Glassies are glass fighters. Collect them, then clash!"
gui.Parent = StarterGui
return "WelcomeScreen built"
