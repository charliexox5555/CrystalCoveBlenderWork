local Theme = require(script.Parent.Parent.Theme)
local U = require(script.Parent.Util)
local Button = {}
function Button.new(parent, name, text, variant, size, position)
	local button = U.make("TextButton", parent, {
		Name = name,
		Text = text,
		Size = size,
		Position = position,
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
	U.make("UIScale", button, { Name = "PressScale" })
	return button
end
return Button
