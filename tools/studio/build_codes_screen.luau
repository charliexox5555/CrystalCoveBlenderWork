-- Edit mode (Studio MCP), with the Studio lock held. Rebuilds StarterGui.CodesScreen (the top bar "Codes" window,
-- decision 98): a small Stained Glass window with a CODES banner, the Close diamond, a dark inset code field
-- (TextBox CodeInput) with the green REDEEM gem stacked under it, and a hidden Status line. Design only: no scripts,
-- no remotes.
-- Re-runnable: the previous CodesScreen is copied to ServerStorage.UIBackup_Topbar first, then replaced.
-- Art: assets/ui/screens/codes (tools/ui/codes_art.mjs); ids also in Config/UIAssets (screens/codes/*).
-- The close diamond and the title come from StarterGui.CollectionScreen.Panel so they match the other windows.
assert(not game:GetService("RunService"):IsRunning(), "Run in Edit")
local StarterGui = game:GetService("StarterGui")
local ServerStorage = game:GetService("ServerStorage")

local WINDOW = "rbxassetid://130439492899536" -- screens/codes/window_codes, 900x560 (aspect 1.607)
local FIELD = "rbxassetid://98997316553457" -- screens/codes/field_inset, 520x80 (aspect 6.5)
local FIELD_FOCUS = "rbxassetid://99561576715408" -- screens/codes/field_focus
local BANNER = "rbxassetid://81888106457155" -- panel/title_amethyst
local GEM_EMERALD = "rbxassetid://108061531278853" -- button/gem_emerald, 600x172 (aspect 3.488)

local LEAD = Color3.fromHex("#1F1830")
local HINT = Color3.fromHex("#B7B3CC")
local PLACEHOLDER = Color3.fromHex("#8C88A8")
local DENK = Font.new("rbxasset://fonts/families/DenkOne.json")
local NUNITO = Font.new("rbxasset://fonts/families/Nunito.json", Enum.FontWeight.Heavy)

local source = StarterGui:WaitForChild("CollectionScreen"):WaitForChild("Panel")

-- Back up and replace.
local old = StarterGui:FindFirstChild("CodesScreen")
if old then
	local backups = ServerStorage:FindFirstChild("UIBackup_Topbar")
	if not backups then
		backups = Instance.new("Folder")
		backups.Name = "UIBackup_Topbar"
		backups.Parent = ServerStorage
	end
	local copy = old:Clone()
	copy.Name = "CodesScreen_" .. os.date("%Y%m%d_%H%M%S")
	copy.Enabled = false
	copy.Parent = backups
	old:Destroy()
end

-- The window art is 900x560 units; Content is its dark inner pane. place() takes a centre and a size in window units
-- and returns Scale values inside Content, so the layout reads like the drawing.
local W, H = 900, 560
local CX, CY, CW, CH = 0.04, 0.068, 0.92, 0.864
local function place(cx, cy, w, h)
	return UDim2.fromScale((cx / W - CX) / CW, (cy / H - CY) / CH), UDim2.fromScale(w / W / CW, h / H / CH)
end

local function aspect(parent, ratio)
	local c = Instance.new("UIAspectRatioConstraint")
	c.AspectRatio = ratio
	c.Parent = parent
	return c
end

local function image(name, id, parent, z)
	local i = Instance.new("ImageLabel")
	i.Name, i.Image, i.BackgroundTransparency, i.ScaleType, i.ZIndex = name, id, 1, Enum.ScaleType.Fit, z
	i.Size = UDim2.fromScale(1, 1)
	i.Parent = parent
	return i
end

local function label(name, text, font, color, parent)
	local t = Instance.new("TextLabel")
	t.Name, t.Text, t.FontFace, t.TextColor3, t.BackgroundTransparency = name, text, font, color, 1
	t.TextScaled, t.TextWrapped, t.ZIndex, t.AnchorPoint = true, true, 2, Vector2.new(0.5, 0.5)
	t.Parent = parent
	return t
end

local function sizeLimit(parent, max)
	local c = Instance.new("UITextSizeConstraint")
	c.MinTextSize, c.MaxTextSize = 8, max
	c.Parent = parent
end

local gui = Instance.new("ScreenGui")
gui.Name, gui.Enabled, gui.ResetOnSpawn = "CodesScreen", false, false
gui.ScreenInsets, gui.DisplayOrder = Enum.ScreenInsets.CoreUISafeInsets, 20
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui:SetAttribute("TopbarScreen", true)

local panel = Instance.new("Frame")
panel.Name, panel.BackgroundTransparency, panel.Active = "Panel", 1, true
panel.AnchorPoint, panel.Position, panel.Size = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.3, 0.62)
panel:SetAttribute("StainedGlass", true)
aspect(panel, W / H)
local limit = Instance.new("UISizeConstraint") -- small on purpose; never smaller than a phone can read
limit.MinSize, limit.MaxSize = Vector2.new(400, 249), Vector2.new(640, 398)
limit.Parent = panel
panel.Parent = gui

local art = image("WindowArtwork", WINDOW, panel, 0)
aspect(art, W / H)

-- Title banner (amethyst) over the top-left of the border, like the other windows.
local banner = source.TitleBanner:Clone()
banner.Image, banner.ZIndex = BANNER, 3
banner.Position, banner.Size = UDim2.fromScale(0.05, -0.071), UDim2.fromScale(0.333, 0.135)
banner.Parent = panel
local title = source.Title:Clone()
title:SetAttribute("TextFitBackup", nil)
title.Text, title.ZIndex = "CODES", 4
title.Position, title.Size = UDim2.fromScale(0.07, -0.059), UDim2.fromScale(0.287, 0.084)
title.Parent = panel

-- Close diamond (the controller closes the screen on any GuiButton named Close).
local close = source.Close:Clone()
close.ZIndex = 5
close.Position, close.Size = UDim2.fromScale(0.977, 0.024), UDim2.fromScale(0.078, 0.125)
close.Parent = panel

local content = Instance.new("Frame")
content.Name, content.BackgroundTransparency, content.ZIndex = "Content", 1, 2
content.Position, content.Size = UDim2.fromScale(CX, CY), UDim2.fromScale(CW, CH)
content.Parent = panel

-- Code field (top): dark inset glass; CodeInput is the TextBox, FocusOutline is the aqua ring for its focused state.
local field = Instance.new("Frame")
field.Name, field.BackgroundTransparency, field.ZIndex, field.AnchorPoint = "InputField", 1, 2, Vector2.new(0.5, 0.5)
field.Position, field.Size = place(450, 160, 640, 98) -- the aspect sets the real height
aspect(field, 6.5)
field.Parent = content
image("Artwork", FIELD, field, 1)
local focus = image("FocusOutline", FIELD_FOCUS, field, 2)
focus.Visible = false
local input = Instance.new("TextBox")
input.Name, input.BackgroundTransparency, input.ZIndex = "CodeInput", 1, 3
input.Position, input.Size = UDim2.fromScale(0.05, 0.16), UDim2.fromScale(0.9, 0.68)
input.Text, input.PlaceholderText, input.PlaceholderColor3 = "", "Enter code…", PLACEHOLDER
input.ClearTextOnFocus, input.MultiLine, input.TextEditable = false, false, true
input.FontFace, input.TextColor3 = NUNITO, Color3.new(1, 1, 1)
input.TextScaled, input.TextXAlignment = true, Enum.TextXAlignment.Center
input:SetAttribute("TextFit", false) -- the guard must not fight typing
sizeLimit(input, 34)
input.Parent = field

-- REDEEM (under the field): green gem (green = claim), same parts as every gem button (Artwork, Label, InteractionScale).
local redeem = Instance.new("TextButton")
redeem.Name, redeem.Text, redeem.BackgroundTransparency, redeem.AutoButtonColor = "RedeemButton", "", 1, false
redeem.AnchorPoint, redeem.ZIndex = Vector2.new(0.5, 0.5), 2
redeem.Position, redeem.Size = place(450, 292, 340, 97)
redeem:SetAttribute("StainedGlass", true)
aspect(redeem, 600 / 172)
local gem = image("Artwork", GEM_EMERALD, redeem, 1)
gem:SetAttribute("AssetPath", "button/gem_emerald")
aspect(gem, 600 / 172)
local text = label("Label", "REDEEM", DENK, Color3.new(1, 1, 1), redeem)
text.AnchorPoint = Vector2.zero
text.Position, text.Size, text.ZIndex = UDim2.fromScale(0.13, 0.17), UDim2.fromScale(0.74, 0.66), 2
text.TextScaled, text.TextSize = false, 30
text:SetAttribute("FitSingleLine", true)
sizeLimit(text, 45)
text:FindFirstChildOfClass("UITextSizeConstraint").MinTextSize = 1
local stroke = Instance.new("UIStroke")
stroke.Thickness, stroke.Color, stroke.LineJoinMode = 2.5, LEAD, Enum.LineJoinMode.Round
stroke.Parent = text
local scale = Instance.new("UIScale")
scale.Name = "InteractionScale"
scale.Parent = redeem
redeem.Parent = content

-- Status slot: hidden and empty until a redeem attempt gives it a message (green-ish for success, pink for errors).
local status = label("Status", "", NUNITO, Color3.fromHex("#86EDB8"), content)
status.Position, status.Size = place(450, 395, 760, 50)
status.Visible = false
sizeLimit(status, 30)

local hint = label("Hint", "Find codes in our group and socials!", NUNITO, HINT, content)
hint.Position, hint.Size = place(450, 462, 760, 36)
sizeLimit(hint, 20)

gui.Parent = StarterGui
return "CodesScreen built (Enabled = false)"
