local Theme = require(script.Parent.Parent.Theme)
local U = require(script.Parent.Util)
local Button = {}
local TweenService = game:GetService("TweenService")
function Button.new(parent, name, text, variant, size, position, anchor)
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
	local scale = U.make("UIScale", button, { Name = "PressScale" })
	button.InputBegan:Connect(function(input)
		if
			button.Active
			and (
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
				or input.KeyCode == Enum.KeyCode.ButtonA
			)
		then
			TweenService:Create(scale, Theme.Motion.ButtonPress, { Scale = Theme.Motion.ButtonPressScale }):Play()
		end
	end)
	button.InputEnded:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
			or input.KeyCode == Enum.KeyCode.ButtonA
		then
			TweenService:Create(scale, Theme.Motion.ButtonPress, { Scale = 1 }):Play()
		end
	end)
	button.MouseLeave:Connect(function()
		scale.Scale = 1
	end)
	return button
end
return Button
