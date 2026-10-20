-- Onboarding pointers (decision 100): a golden cursor that bobs next to a GuiObject, with a short line of text, and
-- an optional gentle repeating bump on the target. The pointer lives in the target's own ScreenGui (same inset
-- space, drawn on top) and follows it every frame; Destroy() removes it.
local RunService = game:GetService("RunService")
local Assets = require(game.ReplicatedStorage.Shared.Config.UIAssets)
local Theme = require(script.Parent.Parent.Theme)
local Motion = require(script.Parent.Motion)
local Hint = {}
Hint.__index = Hint

local SIZE = 64
local TOP = 1000 -- ZIndex above everything a screen authors

-- `target`: the GuiObject to point at; `text`: a short line (optional); `bump`: also pulse the target.
function Hint.point(target, text, bump)
	local self = setmetatable({ Target = target, Objects = {} }, Hint)
	local gui = target:FindFirstAncestorOfClass("ScreenGui")
	if not gui then
		return self
	end
	local pointer = Instance.new("ImageLabel")
	pointer.Name, pointer.BackgroundTransparency = "OnboardingPointer", 1
	pointer.Image = Assets["onboarding/pointer"] or ""
	pointer.Size, pointer.ZIndex = UDim2.fromOffset(SIZE, SIZE), TOP
	pointer.Parent = gui
	table.insert(self.Objects, pointer)
	if text then
		local label = Instance.new("TextLabel")
		label.Name, label.BackgroundTransparency, label.Text = "OnboardingHintText", 1, text
		label.FontFace, label.TextColor3, label.TextScaled = Theme.Fonts.Heading, Color3.new(1, 1, 1), true
		label.Size, label.AnchorPoint = UDim2.fromOffset(340, 42), Vector2.new(0, 0.5)
		label.TextXAlignment, label.ZIndex = Enum.TextXAlignment.Left, TOP
		label:SetAttribute("TextFit", false)
		local stroke = Instance.new("UIStroke")
		stroke.Color, stroke.Thickness = Theme.Palette.lead, 3
		stroke.Parent = label
		label.Parent = gui
		self.Label = label
		table.insert(self.Objects, label)
	end
	local start, lastBump = os.clock(), 0
	self.Connection = RunService.RenderStepped:Connect(function()
		if not target.Parent or not pointer.Parent then
			self:Destroy()
			return
		end
		local shown = target.Visible and target.AbsoluteSize.X > 0 and gui.Enabled
		local t = os.clock() - start
		-- The cursor's tip (its top-left) sits on the target's lower-right area and bobs toward it.
		local bob = if Motion.reduced() then 0 else math.abs(math.sin(t * 4)) * 10
		local tip = target.AbsolutePosition + target.AbsoluteSize * Vector2.new(0.72, 0.72) - gui.AbsolutePosition
		pointer.Position = UDim2.fromOffset(tip.X + bob, tip.Y + bob)
		pointer.Visible = shown
		if self.Label then
			self.Label.Position = UDim2.fromOffset(tip.X + SIZE + 8, tip.Y + SIZE * 0.6)
			self.Label.Visible = shown
		end
		if bump and shown and t - lastBump > 0.9 then
			lastBump = t
			Motion.bump(target, 0.07)
		end
	end)
	return self
end

function Hint:Destroy()
	if self.Connection then
		self.Connection:Disconnect()
		self.Connection = nil
	end
	for _, object in self.Objects do
		object:Destroy()
	end
	table.clear(self.Objects)
end

return Hint
