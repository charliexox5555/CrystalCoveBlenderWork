local TweenService = game:GetService("TweenService")
local Theme = require(script.Parent.Parent.Theme)
local U = require(script.Parent.Util)
local ProgressBar = {}
function ProgressBar.new(parent, size, position, compact)
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
	local damage
	if compact then
		track.BackgroundTransparency = 1
		fill.Position, fill.Size = UDim2.fromScale(0, 0.34), UDim2.fromScale(0.67, 0.32)
		fill.UIGradient.Color = ColorSequence.new(Theme.Battle.HpTop, Theme.Battle.HpBottom)
		local rail = fill:Clone()
		rail.Name, rail.BackgroundColor3 = "Rail", Theme.Colors.TextMuted
		rail.UIGradient:Destroy()
		rail.BackgroundTransparency, rail.ZIndex = 0.8, 0
		rail.Parent = track
		damage = fill:Clone()
		damage.Name, damage.BackgroundColor3 = "DamageTrail", Theme.Colors.Highlight
		damage.UIGradient:Destroy()
		damage.Parent = track
		damage.ZIndex, fill.ZIndex = 1, 2
		label.Position, label.Size = UDim2.fromScale(0.7, 0), UDim2.fromScale(0.3, 1)
		label.FontFace, label.TextColor3 = Theme.Fonts.Caption, Theme.Colors.TextMuted
		label.TextXAlignment = Enum.TextXAlignment.Right
		label.UITextSizeConstraint.MaxTextSize = Theme.TextSize.Small
	end
	return { Root = track, Fill = fill, Label = label, Compact = compact, Damage = damage }
end
function ProgressBar.set(bar, hp, maximum)
	local fraction = math.clamp(hp / maximum, 0, 1)
	if bar.Compact then
		local size = UDim2.fromScale(fraction * 0.67, 0.32)
		if bar.Tween then
			bar.Tween:Cancel()
		end
		if bar.DamageTween then
			bar.DamageTween:Cancel()
		end
		bar.Tween = TweenService:Create(bar.Fill, TweenInfo.new(0.12), { Size = size })
		bar.DamageTween = TweenService:Create(
			bar.Damage,
			TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0.12),
			{ Size = size }
		)
		bar.Tween:Play()
		bar.DamageTween:Play()
	else
		bar.Fill.Size = UDim2.fromScale(fraction, 1)
	end
	bar.Fill.BackgroundColor3 = Color3.new(1, 1, 1)
	local healthy = bar.Compact and { Top = Theme.Battle.HpTop, Bottom = Theme.Battle.HpBottom } or Theme.Buttons.Green
	local colors = fraction <= 0.25 and Theme.Meter.Weak or healthy
	bar.Fill.UIGradient.Color = ColorSequence.new(colors.Top, colors.Bottom)
	bar.Label.Text = string.format("%d / %d", hp, maximum)
end
return ProgressBar
