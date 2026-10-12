local Theme = require(script.Parent.Parent.Theme)
local Util = {}
function Util.make(class, parent, properties)
	local object = Instance.new(class)
	for key, value in properties or {} do
		object[key] = value
	end
	object.Parent = parent
	return object
end
function Util.corner(parent, radius)
	return Util.make("UICorner", parent, { CornerRadius = radius })
end
function Util.gradient(parent, top, bottom, rotation)
	return Util.make("UIGradient", parent, { Color = ColorSequence.new(top, bottom), Rotation = rotation or 90 })
end
function Util.text(parent, name, text, size, position, font)
	local label = Util.make("TextLabel", parent, {
		Name = name,
		BackgroundTransparency = 1,
		Text = text,
		Size = size,
		Position = position,
		TextColor3 = Theme.Colors.Text,
		FontFace = font or Theme.Fonts.Body,
		TextScaled = true,
	})
	Util.make("UITextSizeConstraint", label, { MinTextSize = 10, MaxTextSize = Theme.TextSize.Label })
	return label
end
return Util
