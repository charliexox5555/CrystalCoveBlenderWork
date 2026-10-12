local Theme = require(script.Parent.Parent.Theme)
local U = require(script.Parent.Util)
local Pill = {}
function Pill.new(parent, kind, size, position, compact)
	local pill = U.make("Frame", parent, {
		Name = "Type",
		Size = size,
		Position = position,
		BackgroundColor3 = Theme.Types[kind],
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
	})
	U.corner(pill, Theme.Radius.Tag)
	local icon = U.make("Frame", pill, {
		Name = "Icon",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(0.25, 0.75),
		Position = UDim2.fromScale(0.05, 0.12),
	})
	U.make("UIAspectRatioConstraint", icon, { AspectRatio = 1 })
	local function shape(s, p, r)
		local f =
			U.make("Frame", icon, { Size = s, Position = p, BackgroundColor3 = Theme.Colors.Text, BorderSizePixel = 0 })
		if r then
			U.corner(f, UDim.new(1, 0))
		end
		return f
	end
	if kind == "Fizzy" then
		shape(UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0, 0.45), true)
		shape(UDim2.fromScale(0.32, 0.32), UDim2.fromScale(0.6, 0.22), true)
		shape(UDim2.fromScale(0.25, 0.25), UDim2.fromScale(0.25, 0), true)
	elseif kind == "Sharp" then
		shape(UDim2.fromScale(0.6, 0.6), UDim2.fromScale(0.2, 0.2)).Rotation = 45
	else
		shape(UDim2.fromScale(0.8, 0.55), UDim2.fromScale(0.1, 0.4))
		local handle = shape(UDim2.fromScale(0.4, 0.3), UDim2.fromScale(0.3, 0.12), true)
		handle.BackgroundTransparency = 1
		U.make("UIStroke", handle, { Color = Theme.Colors.Text, Thickness = 2 })
	end
	U.text(pill, "Label", string.upper(kind), UDim2.fromScale(0.65, 0.8), UDim2.fromScale(0.32, 0.1))
	if compact then
		pill.BackgroundTransparency = 1
		pill.Label.Visible = false
		icon.Position, icon.Size = UDim2.fromScale(0, 0), UDim2.fromScale(1, 1)
		for _, shapePart in icon:GetChildren() do
			if shapePart:IsA("Frame") then
				shapePart.BackgroundColor3 = Theme.Types[kind]
				local stroke = shapePart:FindFirstChildWhichIsA("UIStroke")
				if stroke then
					stroke.Color = Theme.Types[kind]
				end
			end
		end
	end
	return pill
end
return Pill
