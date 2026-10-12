local Theme = require(script.Parent.Parent.Theme)
local U = require(script.Parent.Util)
local ProgressBar = {}
function ProgressBar.new(parent, size, position)
	local track = U.make(
		"Frame",
		parent,
		{ Name = "HP", Size = size, Position = position, BackgroundColor3 = Theme.Colors.Inset, BorderSizePixel = 0 }
	)
	U.corner(track, Theme.Radius.Bar)
	local fill = U.make(
		"Frame",
		track,
		{ Name = "Fill", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 }
	)
	U.corner(fill, Theme.Radius.Bar)
	U.gradient(fill, Theme.Buttons.Green.Top, Theme.Buttons.Green.Bottom)
	local label = U.text(track, "Value", "", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0))
	return { Root = track, Fill = fill, Label = label }
end
function ProgressBar.set(bar, hp, maximum)
	local fraction = math.clamp(hp / maximum, 0, 1)
	bar.Fill.Size = UDim2.fromScale(fraction, 1)
	bar.Fill.BackgroundColor3 = fraction <= 0.25 and Theme.Meter.Weak.Top or Color3.new(1, 1, 1)
	bar.Label.Text = string.format("%d / %d", hp, maximum)
end
return ProgressBar
