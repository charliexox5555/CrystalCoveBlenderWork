-- Scene-owned numbers follow each glassy without rotating with its mesh.
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local VFX = require(RS.Shared.Config.Balance).CombatVFX
local Theme = require(script.Parent.Parent.UI.Theme)
local Health = {}

function Health.new(fighter, root)
	local gui = Instance.new("BillboardGui")
	gui.Name, gui.Adornee = "GlassyHealth", fighter.Body
	gui.Size = UDim2.fromOffset(VFX.HealthWidth, VFX.HealthHeight)
	gui.StudsOffsetWorldSpace = -Vector3.yAxis * (fighter.Body.Size.Y / 2 + VFX.HealthGap)
	gui.AlwaysOnTop, gui.LightInfluence, gui.Enabled = true, 0, false
	local label = Instance.new("TextLabel")
	label.Name, label.Size, label.BackgroundTransparency = "Amount", UDim2.fromScale(1, 1), 1
	label.FontFace, label.TextSize = Theme.Fonts.Heading, VFX.HealthTextSize
	label.TextColor3, label.Text = Theme.Colors.Text, ""
	label.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Name, scale.Parent = "HitScale", label
	local stroke = Instance.new("UIStroke")
	stroke.Color, stroke.Thickness, stroke.Parent = Theme.Colors.Shadow, VFX.HealthStroke, label
	gui.Parent = root
	fighter.Health = gui
	Health.update(fighter, fighter.Stats.MaxHP, false)
end

function Health.bump(fighter)
	if not fighter.Health or not fighter.Health.Enabled then
		return
	end
	if fighter.HealthTween then
		fighter.HealthTween:Cancel()
	end
	local scale = fighter.Health.Amount.HitScale
	scale.Scale = VFX.HealthPulseScale
	fighter.HealthTween =
		TweenService:Create(scale, TweenInfo.new(VFX.HealthPulseSeconds, Enum.EasingStyle.Back), { Scale = 1 })
	fighter.HealthTween:Play()
end

function Health.update(fighter, hp, viewing)
	local gui = fighter.Health
	local value = math.clamp(math.ceil(hp), 0, math.ceil(fighter.Stats.MaxHP))
	gui.Amount.Text = string.format("%d HP", value)
	gui.Amount.TextColor3 = if hp / fighter.Stats.MaxHP <= VFX.LowHealthFraction
		then Theme.Palette.rubyLight
		else Theme.Colors.Text
	gui.Enabled = viewing == true and not fighter.Broken and not fighter.Finishing
end

return Health
