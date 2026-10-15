local TweenService = game:GetService("TweenService")
local Theme = require(script.Parent.Parent.Theme)
local Motion = {}
local bound = setmetatable({}, { __mode = "k" })
function Motion.center(object)
	if object.AnchorPoint == Vector2.new(0.5, 0.5) then
		return
	end
	local p, s, a = object.Position, object.Size, object.AnchorPoint
	object.Position = UDim2.new(
		p.X.Scale + s.X.Scale * (0.5 - a.X),
		p.X.Offset + s.X.Offset * (0.5 - a.X),
		p.Y.Scale + s.Y.Scale * (0.5 - a.Y),
		p.Y.Offset + s.Y.Offset * (0.5 - a.Y)
	)
	object.AnchorPoint = Vector2.new(0.5, 0.5)
end
function Motion.button(button)
	if not button:IsA("GuiButton") then
		return
	end
	Motion.center(button)
	if bound[button] then
		return
	end
	bound[button] = true
	local target = if button.Name == "Open" then button.Parent else button
	Motion.center(target)
	local scale = target:FindFirstChild("InteractionScale") or Instance.new("UIScale")
	scale.Name, scale.Parent = "InteractionScale", target
	local hovering, pressing, tween = false, false, nil
	local function refresh()
		if tween then
			tween:Cancel()
		end
		local value = if not button.Active
			then 1
			elseif pressing then Theme.Motion.ButtonPressScale
			elseif hovering then Theme.Motion.ButtonHoverScale
			else 1
		tween = TweenService:Create(scale, Theme.Motion.ButtonPress, { Scale = value })
		tween:Play()
	end
	button.MouseEnter:Connect(function()
		hovering = true
		refresh()
	end)
	button.MouseLeave:Connect(function()
		hovering, pressing = false, false
		refresh()
	end)
	button.SelectionGained:Connect(function()
		hovering = true
		refresh()
	end)
	button.SelectionLost:Connect(function()
		hovering, pressing = false, false
		refresh()
	end)
	local function accepts(input)
		return input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
			or input.KeyCode == Enum.KeyCode.ButtonA
	end
	button.InputBegan:Connect(function(input)
		if accepts(input) then
			pressing = true
			refresh()
		end
	end)
	button.InputEnded:Connect(function(input)
		if accepts(input) then
			pressing = false
			refresh()
		end
	end)
	button:GetPropertyChangedSignal("Active"):Connect(refresh)
end
return Motion
