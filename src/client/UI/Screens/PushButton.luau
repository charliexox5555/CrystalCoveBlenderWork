-- The PUSH button (decision 122): shove your glassy along its swing to win a glint race, line up a smash or
-- dodge. Three charges shown as pips; one comes back every Arena.Push.RechargeSeconds. Never automatic, so a
-- player who only watches still gets a fair fight. The server owns the charges (ArenaRules); this follows
-- our side's Push / PushCharge events.
local TweenService = game:GetService("TweenService")
local ContextActionService = game:GetService("ContextActionService")
local RS = game:GetService("ReplicatedStorage")
local Balance = require(RS.Shared.Config.Balance)
local Theme = require(script.Parent.Parent.Theme)
local Kit = require(script.Parent.Parent.Components.MatchKit)
local InputGlyph = require(script.Parent.Parent.Components.InputGlyph)
local Push = {}
Push.__index = Push

local P = Balance.Arena.Push
local AQUA = Color3.fromRGB(120, 230, 255)
local ACTION = "GlassClashPush"
-- Bound only while PUSH is shown. Space/F/A/X/R1/R2 belong to CAST, Q/E to the fight camera.
local KEYS = {
	Enum.KeyCode.LeftShift,
	Enum.KeyCode.R,
	Enum.KeyCode.ButtonY,
	Enum.KeyCode.ButtonL1,
	Enum.KeyCode.ButtonL2,
}

function Push.new(onPress)
	local self = setmetatable({ OnPress = onPress, Charges = P.Charges, ChangedAt = os.clock() }, Push)
	self.Gui = Kit.gui("PushButton", 21)
	self.Root = Instance.new("Frame")
	self.Root.Name, self.Root.BackgroundTransparency = "Push", 1
	self.Root.AnchorPoint, self.Root.Size = Vector2.new(0.5, 0.5), UDim2.fromScale(0.2, 0.22)
	self.Root.Position, self.Root.Visible, self.Root.Parent = UDim2.fromScale(0.64, 0.82), false, self.Gui
	self.Scale = Instance.new("UIScale")
	self.Scale.Parent = self.Root
	self.Button =
		Kit.gem(self.Root, "PushButton", "PUSH!", "aqua", UDim2.fromScale(1, 0.62), UDim2.fromScale(0.5, 0.42))
	self.Glyph = InputGlyph.new(
		self.Button,
		{ Keyboard = Enum.KeyCode.LeftShift, Gamepad = Enum.KeyCode.ButtonY },
		UDim2.fromScale(0.3, 0.42),
		UDim2.fromScale(0.86, 0.14)
	)
	local square = Instance.new("UIAspectRatioConstraint")
	square.AspectRatio, square.Parent = 1, self.Glyph.Root
	-- One pip per charge; the next empty pip fills while it recharges.
	local row = Kit.frame(self.Root, "Charges", UDim2.fromScale(0.6, 0.14), UDim2.fromScale(0.2, 0.82))
	local layout = Instance.new("UIListLayout")
	layout.FillDirection, layout.HorizontalAlignment = Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Center
	layout.Padding, layout.Parent = UDim.new(0.06, 0), row
	self.Pips = {}
	for i = 1, P.Charges do
		local pip = Instance.new("Frame")
		pip.Name, pip.Size, pip.BorderSizePixel, pip.LayoutOrder = "Pip" .. i, UDim2.fromScale(0.26, 1), 0, i
		pip.BackgroundColor3, pip.BackgroundTransparency, pip.Parent = Theme.Colors.Shadow, 0.3, row
		Kit.outline(pip, 1.5)
		local fill = Instance.new("Frame")
		fill.Name, fill.BorderSizePixel, fill.Size = "Fill", 0, UDim2.fromScale(1, 1)
		fill.BackgroundColor3, fill.Parent = AQUA, pip
		self.Pips[i] = fill
	end
	self.Connection = self.Button.Activated:Connect(function()
		self:Press()
	end)
	return self
end

function Push:Show(on)
	if on == self.Root.Visible then
		return
	end
	self.Root.Visible = on
	if on then
		ContextActionService:BindActionAtPriority(ACTION, function(_, state)
			if state == Enum.UserInputState.Begin then
				self:Press()
			end
			return Enum.ContextActionResult.Sink
		end, false, Enum.ContextActionPriority.High.Value + 10, table.unpack(KEYS))
		self.Scale.Scale = 0.6
		TweenService:Create(self.Scale, TweenInfo.new(0.22, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	else
		ContextActionService:UnbindAction(ACTION)
	end
end

-- A fresh round: full charges.
function Push:Reset()
	self.Charges, self.ChangedAt = P.Charges, os.clock()
	Kit.enable(self.Button, true)
end

function Push:SetCharges(charges)
	if charges ~= self.Charges then
		self.Charges, self.ChangedAt = charges, os.clock()
	end
	Kit.enable(self.Button, charges > 0)
end

function Push:Press()
	if not self.Root.Visible or self.Charges <= 0 or os.clock() - (self.PressedAt or 0) < P.Cooldown then
		return
	end
	self.PressedAt = os.clock()
	self.OnPress()
	self.Scale.Scale = 0.86
	TweenService:Create(self.Scale, TweenInfo.new(0.16, Enum.EasingStyle.Back), { Scale = 1 }):Play()
end

function Push:Update()
	if not self.Root.Visible then
		return
	end
	local refill = math.clamp((os.clock() - self.ChangedAt) / P.RechargeSeconds, 0, 1)
	for i, fill in self.Pips do
		local amount = if i <= self.Charges then 1 elseif i == self.Charges + 1 then refill else 0
		fill.Size = UDim2.fromScale(1, amount)
		fill.Position = UDim2.fromScale(0, 1 - amount)
		fill.BackgroundTransparency = if i <= self.Charges then 0 else 0.45
	end
end

function Push:Destroy()
	ContextActionService:UnbindAction(ACTION)
	self.Glyph:Destroy()
	self.Connection:Disconnect()
	self.Gui:Destroy()
end

return Push
