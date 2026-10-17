local Theme = require(script.Parent.Parent.Theme)
local U = require(script.Parent.Util)
local Panel = {}
-- Cut-glass pane for rows, cards and small panels inside Stained Glass windows (stretches without clipping).
function Panel.glass(parent, name, size, position)
	local S = require(script.Parent.StainedGlass)
	local old = parent:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	local pane = Instance.new("ImageLabel")
	pane.Name, pane.Size, pane.Position, pane.BackgroundTransparency = name, size, position, 1
	pane.Parent = parent
	S.setAsset(pane, "panel/pane_dark")
	return pane
end
function Panel.new(parent, name, size, position, compact)
	local authored = parent:FindFirstChild(name)
	if authored and authored:GetAttribute("StainedGlass") then
		return authored
	end
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
	if compact then
		panel.BackgroundTransparency = Theme.Battle.PanelTransparency
		panel.UIGradient.Color = ColorSequence.new(Theme.Battle.PanelTop, Theme.Battle.PanelBottom)
		edge.Thickness, edge.Transparency = Theme.Stroke.Button, Theme.Battle.EdgeTransparency
		local highlight = U.make("Frame", panel, {
			Name = "GlassHighlight",
			Size = UDim2.fromScale(0.94, 0.006),
			Position = UDim2.fromScale(0.03, 0),
			BackgroundColor3 = Theme.Colors.Text,
			BackgroundTransparency = 0.65,
			BorderSizePixel = 0,
		})
		U.gradient(highlight, Theme.Colors.EdgeA, Theme.Colors.EdgeB, 0)
	end
	return panel
end
return Panel
