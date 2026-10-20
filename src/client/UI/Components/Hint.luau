-- Onboarding pointers (decision 100): a golden cursor that bobs next to a GuiObject, with a short line of text, and
-- an optional gentle repeating bump on the target. The pointer lives in the target's own ScreenGui (same inset
-- space, drawn on top) and follows it every frame; Destroy() removes it.
local RunService = game:GetService("RunService")
local Assets = require(game.ReplicatedStorage.Shared.Config.UIAssets)
local Theme = require(script.Parent.Parent.Theme)
local Motion = require(script.Parent.Motion)
local Hint = {}
Hint.__index = Hint

local SIZE = 50
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
		-- A small dark pill: readable on any background, and too small to bury the screen under it.
		local label = Instance.new("TextLabel")
		label.Name, label.Text = "OnboardingHintText", text
		label.BackgroundColor3, label.BackgroundTransparency = Theme.Palette.lead, 0.15
		label.FontFace, label.TextColor3, label.TextSize = Theme.Fonts.Heading, Color3.new(1, 1, 1), 22
		label.AutomaticSize, label.Size = Enum.AutomaticSize.X, UDim2.fromOffset(0, 34)
		label.AnchorPoint, label.ZIndex = Vector2.new(0, 0.5), TOP
		label:SetAttribute("TextFit", false)
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = label
		local padding = Instance.new("UIPadding")
		padding.PaddingLeft, padding.PaddingRight = UDim.new(0, 14), UDim.new(0, 14)
		padding.Parent = label
		local stroke = Instance.new("UIStroke")
		stroke.ApplyStrokeMode, stroke.Color, stroke.Thickness =
			Enum.ApplyStrokeMode.Border, Color3.fromHex("#FFD98A"), 2
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
		-- The cursor's tip (its top-left) touches the target's right edge and bobs toward it, so it never covers
		-- the text around the target. Near the right edge of the screen (CAST) it flips to the left edge, turned to
		-- point up-right; it never drops below the screen (PLAY).
		local bob = if Motion.reduced() then 0 else math.abs(math.sin(t * 4)) * 8
		local size = gui.AbsoluteSize
		local flip = target.AbsolutePosition.X + target.AbsoluteSize.X * 0.97 + SIZE + 8
			> gui.AbsolutePosition.X + size.X
		local tip = target.AbsolutePosition
			+ target.AbsoluteSize * Vector2.new(if flip then 0.03 else 0.97, 0.55)
			- gui.AbsolutePosition
		tip = Vector2.new(tip.X, math.min(tip.Y, size.Y - SIZE - 12))
		if flip then
			-- Rotated 90 degrees about its centre the tip moves to the top-right corner.
			pointer.Rotation = 90
			pointer.Position = UDim2.fromOffset(tip.X - SIZE - bob, tip.Y + bob)
		else
			pointer.Rotation = 0
			pointer.Position = UDim2.fromOffset(tip.X + bob, tip.Y + bob)
		end
		pointer.Visible = shown
		if self.Label then
			self.Label.AnchorPoint = Vector2.new(if flip then 1 else 0, 0.5)
			self.Label.Position =
				UDim2.fromOffset(if flip then tip.X - SIZE - 4 else tip.X + SIZE + 4, tip.Y + SIZE * 0.75)
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
