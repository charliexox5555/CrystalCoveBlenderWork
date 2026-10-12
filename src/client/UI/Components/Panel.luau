local Theme = require(script.Parent.Parent.Theme)
local U = require(script.Parent.Util)
local Panel = {}
function Panel.new(parent, name, size, position)
	local panel = U.make("Frame", parent, {
		Name = name,
		Size = size,
		Position = position,
		BorderSizePixel = 0,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = Theme.Colors.PanelTransparency,
	})
	U.corner(panel, Theme.Radius.Panel)
	U.gradient(panel, Theme.Colors.PanelTop, Theme.Colors.PanelBottom)
	local edge =
		U.make("UIStroke", panel, { Thickness = Theme.Stroke.Edge, Color = Color3.new(1, 1, 1), Transparency = 0.15 })
	U.gradient(edge, Theme.Colors.EdgeA, Theme.Colors.EdgeB, 25)
	return panel
end
return Panel
