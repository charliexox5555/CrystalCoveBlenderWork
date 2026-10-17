-- Small Stained Glass building blocks for the match UI (queue, selection, fight HUD, round banners).
-- Everything here is built in code, so the match screens do not depend on place-authored templates.
local TweenService = game:GetService("TweenService")
local Theme = require(script.Parent.Parent.Theme)
local U = require(script.Parent.Util)
local S = require(script.Parent.StainedGlass)
local Motion = require(script.Parent.Motion)
local UiAudio = require(script.Parent.UiAudio)
local Specs = require(script.Parent.StainedAssetSpecs)

local Kit = {}

local FADE = {
	Frame = { "BackgroundTransparency" },
	TextLabel = { "BackgroundTransparency", "TextTransparency", "TextStrokeTransparency" },
	TextButton = { "BackgroundTransparency", "TextTransparency", "TextStrokeTransparency" },
	ImageLabel = { "BackgroundTransparency", "ImageTransparency" },
	ImageButton = { "BackgroundTransparency", "ImageTransparency" },
	ViewportFrame = { "BackgroundTransparency", "ImageTransparency" },
	UIStroke = { "Transparency" },
}

-- A ScreenGui with nothing authored in it: match screens are fully built from code.
function Kit.gui(name, order)
	local gui = U.screen(name, order)
	gui:ClearAllChildren()
	return gui
end

function Kit.frame(parent, name, size, position, anchor)
	local frame = Instance.new("Frame")
	frame.Name, frame.Size, frame.Position = name, size, position or UDim2.new()
	frame.AnchorPoint, frame.BackgroundTransparency, frame.BorderSizePixel = anchor or Vector2.zero, 1, 0
	frame.Parent = parent
	return frame
end

-- Dark outline so text stays readable over the bright world.
function Kit.outline(object, thickness)
	return U.make("UIStroke", object, {
		Thickness = thickness or 2,
		Color = Theme.Palette.lead,
		Transparency = 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
	})
end

function Kit.label(parent, name, text, size, position, options)
	options = options or {}
	local label = Instance.new("TextLabel")
	label.Name, label.Text, label.Size, label.Position = name, text, size, position or UDim2.new()
	label.AnchorPoint = options.Anchor or Vector2.zero
	label.BackgroundTransparency, label.BorderSizePixel = 1, 0
	label.FontFace = options.Font or Theme.Fonts.Heading
	label.TextColor3 = options.Color or Theme.Colors.Text
	label.TextScaled, label.RichText = true, options.RichText == true
	label.TextXAlignment = options.XAlign or Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Parent = parent
	local limit = Instance.new("UITextSizeConstraint")
	limit.MinTextSize, limit.MaxTextSize = options.MinSize or 8, options.MaxSize or Theme.TextSize.Heading
	limit.Parent = label
	if options.Outline ~= false then
		Kit.outline(label, options.Outline)
	end
	return label
end

function Kit.icon(parent, name, path, size, position, anchor)
	local image = Instance.new("ImageLabel")
	image.Name, image.Size, image.Position = name, size, position or UDim2.new()
	image.AnchorPoint, image.BackgroundTransparency, image.BorderSizePixel = anchor or Vector2.zero, 1, 0
	image.Parent = parent
	S.setAsset(image, path)
	S.aspect(image, Specs[path].Width / Specs[path].Height)
	return image
end

-- Row of three glass hearts (full or broken), square and as tall as the row.
function Kit.hearts(parent, name, count, size, position, right)
	local row = Kit.frame(parent, name, size, position)
	local layout = Instance.new("UIListLayout")
	layout.FillDirection, layout.Padding = Enum.FillDirection.Horizontal, UDim.new(0, 3)
	layout.HorizontalAlignment = if right then Enum.HorizontalAlignment.Right else Enum.HorizontalAlignment.Left
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = row
	local hearts = {}
	for i = 1, 3 do
		local heart = Kit.icon(row, "Heart" .. i, "icon/heart_full", UDim2.new())
		heart.UIAspectRatioConstraint:Destroy()
		heart.LayoutOrder = if right then 4 - i else i
		hearts[i] = heart
	end
	local function fit()
		local side = math.max(8, math.floor(row.AbsoluteSize.Y))
		for _, heart in hearts do
			heart.Size = UDim2.fromOffset(side, side)
		end
	end
	row:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	fit()
	S.hearts(row, count)
	return row
end

-- Small coloured tag (type / rarity) with its label inside.
function Kit.tag(parent, name, text, colour, size, position)
	local tag = Kit.icon(parent, name, "tag/tag_" .. colour, size, position)
	local label = Kit.label(
		tag,
		"Label",
		text,
		UDim2.fromScale(0.72, 0.8),
		UDim2.fromScale(0.14, 0.08),
		{ Font = Theme.Fonts.Caption, Outline = false, MaxSize = 20 }
	)
	S.tag(tag, text, colour)
	return tag
end

-- Marble amount: our Marble icon, then the number. `free` shows FREE instead of an amount.
function Kit.marbleChip(parent, name, amount, size, position, anchor)
	local chip = Kit.frame(parent, name, size, position, anchor)
	local icon =
		Kit.icon(chip, "Icon", "icon/marble", UDim2.fromScale(0.5, 1), UDim2.fromScale(0, 0.5), Vector2.new(0, 0.5))
	icon.UIAspectRatioConstraint.DominantAxis = Enum.DominantAxis.Height
	local value = Kit.label(
		chip,
		"Amount",
		tostring(amount),
		UDim2.fromScale(0.5, 1),
		UDim2.fromScale(0.5, 0),
		{ XAlign = Enum.TextXAlignment.Left, MaxSize = 30 }
	)
	return chip, icon, value
end

-- One sentence that can contain Marble icons: Set("Need {M}2 more") puts the icon where {M} is.
function Kit.marbleLine(parent, name, size, position, anchor)
	local frame = Kit.frame(parent, name, size, position, anchor)
	local layout = Instance.new("UIListLayout")
	layout.FillDirection, layout.SortOrder = Enum.FillDirection.Horizontal, Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment, layout.VerticalAlignment =
		Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 4)
	layout.Parent = frame
	local line = { Frame = frame, Text = "", Color = Theme.Colors.Text }
	function line:Set(text, color)
		self.Text, self.Color = text, color or self.Color
		for _, child in frame:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local pixel = math.clamp(math.floor(frame.AbsoluteSize.Y * 0.8), 14, 30)
		local order = 0
		for index, piece in string.split(text, "{M}") do
			if index > 1 then
				order += 1
				local icon =
					Kit.icon(frame, "Marble" .. order, "icon/marble", UDim2.fromOffset(pixel * 1.3, pixel * 1.3))
				icon.LayoutOrder = order
				icon.UIAspectRatioConstraint.DominantAxis = Enum.DominantAxis.Height
			end
			if piece ~= "" then
				order += 1
				local label = Instance.new("TextLabel")
				label.Name, label.Text, label.LayoutOrder = "Text" .. order, piece, order
				label.AutomaticSize, label.Size = Enum.AutomaticSize.X, UDim2.fromOffset(0, pixel * 1.4)
				label.BackgroundTransparency, label.FontFace = 1, Theme.Fonts.Body
				label.TextSize, label.TextColor3 = pixel, self.Color
				label.TextXAlignment = Enum.TextXAlignment.Center
				label.Parent = frame
				Kit.outline(label, 2)
			end
		end
	end
	frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		if line.Text ~= "" then
			line:Set(line.Text)
		end
	end)
	return line
end

local GEM_RATIO = Specs["button/gem_aqua"].Width / Specs["button/gem_aqua"].Height

-- Cut-glass button with a label and an optional Marble cost chip. Centre-anchored; the shared Motion
-- gives it hover/press feedback, the click sound and (for green/amber) the idle shine.
function Kit.gem(parent, name, text, tint, size, position, cost)
	local button = Instance.new("ImageButton")
	button.Name, button.Size, button.Position, button.AnchorPoint = name, size, position, Vector2.new(0.5, 0.5)
	button.BackgroundTransparency, button.Image, button.AutoButtonColor, button.Selectable = 1, "", false, true
	button.Parent = parent
	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.AspectRatio, ratio.Parent = GEM_RATIO, button
	local art = Instance.new("ImageLabel")
	art.Name, art.Size, art.BackgroundTransparency, art.ZIndex = "Artwork", UDim2.fromScale(1, 1), 1, 1
	art.Parent = button
	S.setAsset(art, "button/gem_" .. tint)
	local label =
		Kit.label(button, "Label", text, UDim2.fromScale(0.8, 0.66), UDim2.fromScale(0.1, 0.17), { MaxSize = 44 })
	label.ZIndex = 2
	local chip = Kit.marbleChip(button, "Cost", 0, UDim2.fromScale(0.34, 0.5), UDim2.fromScale(0.58, 0.25))
	for _, part in chip:GetDescendants() do
		if part:IsA("GuiObject") then
			part.ZIndex = 2
		end
	end
	Motion.button(button)
	Kit.setCost(button, cost)
	return button
end

-- cost: nil hides the chip, 0 shows FREE, anything else shows the Marble icon and amount.
function Kit.setCost(button, cost)
	local chip, label = button:FindFirstChild("Cost"), button:FindFirstChild("Label")
	if not chip or not label then
		return
	end
	chip.Visible = cost ~= nil
	chip.Icon.Visible = cost ~= nil and cost ~= 0
	chip.Amount.Text = if cost == 0 then "FREE" else tostring(cost or "")
	if cost == 0 then
		chip.Amount.Position, chip.Amount.Size = UDim2.fromScale(0, 0), UDim2.fromScale(1, 1)
		chip.Amount.TextXAlignment = Enum.TextXAlignment.Center
	else
		chip.Amount.Position, chip.Amount.Size = UDim2.fromScale(0.5, 0), UDim2.fromScale(0.5, 1)
		chip.Amount.TextXAlignment = Enum.TextXAlignment.Left
	end
	label.Position, label.Size = UDim2.fromScale(0.1, 0.17), UDim2.fromScale(if cost == nil then 0.8 else 0.46, 0.66)
end

function Kit.enable(button, on)
	button.Active, button.Selectable = on, on
	local fade = if on then 0 else 0.55
	button.Artwork.ImageTransparency = fade
	for _, part in button:GetDescendants() do
		if part:IsA("TextLabel") then
			part.TextTransparency = fade
		elseif part:IsA("ImageLabel") and part.Name == "Icon" then
			part.ImageTransparency = fade
		end
	end
end

function Kit.fade(root, info, to)
	local count = 0
	for _, object in root:GetDescendants() do
		local props = FADE[object.ClassName]
		if props then
			local goal = {}
			for _, prop in props do
				if object[prop] < (to or 1) then
					goal[prop] = to or 1
				end
			end
			if next(goal) then
				count += 1
				if count > 600 then
					return
				end
				TweenService:Create(object, info, goal):Play()
			end
		end
	end
end

function Kit.popIn(object, silent)
	local scale = object:FindFirstChild("OpenScale") or Instance.new("UIScale")
	scale.Name, scale.Parent = "OpenScale", object
	if Motion.reduced() then
		scale.Scale = 1
		return scale
	end
	scale.Scale = Motion.Tuning.WindowFrom
	TweenService:Create(scale, Motion.Tuning.WindowOpen, { Scale = 1 }):Play()
	if not silent then
		UiAudio.play("Open")
	end
	return scale
end

-- Shrinks a little while fading, then calls `done` (immediately with reduced motion).
function Kit.popOut(object, done)
	if Motion.reduced() then
		done()
		return
	end
	local info = Motion.Tuning.WindowClose
	local scale = object:FindFirstChild("OpenScale")
	if scale then
		TweenService:Create(scale, info, { Scale = Motion.Tuning.WindowCloseScale }):Play()
	end
	Kit.fade(object, info)
	task.delay(info.Time + 0.02, done)
end

return Kit
