local Theme = require(script.Parent.Parent.Theme)
local U = require(script.Parent.Util)
local Button = {}
function Button.new(parent, name, text, variant, size, position, anchor)
	local authored = parent:FindFirstChild(name)
	if authored and authored:GetAttribute("StainedGlass") then
		require(script.Parent.StainedGlass).buttonText(authored, text)
		return authored
	end
	local button = U.make("TextButton", parent, {
		Name = name,
		Text = text,
		Size = size,
		Position = position,
		AnchorPoint = anchor or Vector2.zero,
		BorderSizePixel = 0,
		BackgroundColor3 = Color3.new(1, 1, 1),
		TextColor3 = Theme.Colors.TextDark,
		FontFace = Theme.Fonts.Heading,
		TextScaled = true,
		AutoButtonColor = false,
		Selectable = true,
	})
	U.corner(button, Theme.Radius.Button)
	U.gradient(button, Theme.Buttons[variant].Top, Theme.Buttons[variant].Bottom)
	U.make(
		"UIStroke",
		button,
		{ Color = Theme.Colors.Text, Thickness = Theme.Stroke.Button, Transparency = Theme.Stroke.ButtonTransparency }
	)
	U.make("UITextSizeConstraint", button, { MinTextSize = 14, MaxTextSize = Theme.TextSize.Heading })
	-- Same hover/press feedback and click sound as every other button.
	require(script.Parent.Motion).button(button)
	return button
end
return Button
