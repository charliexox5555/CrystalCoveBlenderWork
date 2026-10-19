local Theme = require(script.Parent.Parent.Theme)
local Util = {}
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local authored = {
	Image = true,
	ImageColor3 = true,
	ImageTransparency = true,
	ScaleType = true,
	SliceCenter = true,
	SliceScale = true,
	AspectRatio = true,
	DominantAxis = true,
	AspectType = true,
	TextXAlignment = true,
	TextYAlignment = true,
	TextWrapped = true,
	MinSize = true,
	MaxSize = true,
	CellSize = true,
	CellPadding = true,
	Padding = true,
	PaddingTop = true,
	PaddingBottom = true,
	PaddingLeft = true,
	PaddingRight = true,
	Size = true,
	Position = true,
	AnchorPoint = true,
	FontFace = true,
	TextColor3 = true,
	BackgroundColor3 = true,
	BackgroundTransparency = true,
	BorderSizePixel = true,
	Color = true,
	Thickness = true,
	Transparency = true,
	CornerRadius = true,
	Rotation = true,
	MinTextSize = true,
	MaxTextSize = true,
}
local singletons = {
	UICorner = true,
	UIGradient = true,
	UIStroke = true,
	UITextSizeConstraint = true,
	UIAspectRatioConstraint = true,
	UIScale = true,
	UIListLayout = true,
	UIGridLayout = true,
	UISizeConstraint = true,
}

function Util.screen(name, order)
	local parent = if RunService:IsRunning() then Players.LocalPlayer:WaitForChild("PlayerGui") else StarterGui
	local gui = parent:FindFirstChild(name)
	if not gui then
		local source = StarterGui:FindFirstChild(name)
		gui = if source then source:Clone() else Instance.new("ScreenGui")
		gui.Name, gui.Parent = name, parent
	end
	gui.ResetOnSpawn, gui.ScreenInsets = false, Enum.ScreenInsets.CoreUISafeInsets
	gui.DisplayOrder, gui.ZIndexBehavior, gui.Enabled = order or 15, Enum.ZIndexBehavior.Sibling, true
	gui:SetAttribute("TemplateBacked", true)
	require(script.Parent.StainedGlass).bindSlices(gui)
	require(script.Parent.GlassyPortrait).bindCameras(gui)
	return gui
end

function Util.prototype(parent, name, target)
	local templates = parent:FindFirstChild("Templates")
	local source = templates and templates:FindFirstChild(name)
	if source then
		local object = source:Clone()
		object.Name, object.Parent = target, parent
		if object:IsA("GuiObject") then
			object.Visible = true
		end
		return object
	end
	return nil
end

function Util.make(class, parent, properties, transient)
	local key = properties and properties.Name or (singletons[class] and class)
	local object = not transient and key and parent and parent:FindFirstChild(key)
	if object and not object:IsA(class) then
		object = nil
	end
	local reuse = object ~= nil and object ~= false
	object = object or Instance.new(class)
	for key, value in properties or {} do
		if not (reuse and authored[key]) then
			object[key] = value
		end
	end
	object.Parent = parent
	if object:IsA("GuiButton") then
		require(script.Parent.Motion).center(object)
	end
	return object
end
function Util.corner(parent, radius)
	return nil -- Stained Glass uses cut artwork; never create rounded corners.
end
function Util.gradient(parent, top, bottom, rotation)
	return Util.make("UIGradient", parent, { Color = ColorSequence.new(top, bottom), Rotation = rotation or 90 })
end
function Util.text(parent, name, text, size, position, font, transient)
	local label = Util.make("TextLabel", parent, {
		Name = name,
		BackgroundTransparency = 1,
		Text = text,
		Size = size,
		Position = position,
		TextColor3 = Theme.Colors.Text,
		FontFace = font or Theme.Fonts.Body,
		TextScaled = true,
	}, transient)
	-- Fit policy: shrink to Theme.TextFit.Min, then two lines, then "…" (Components/TextFit guards every label).
	Util.make("UITextSizeConstraint", label, { MinTextSize = Theme.TextFit.Min, MaxTextSize = Theme.TextSize.Label })
	return label
end
return Util
