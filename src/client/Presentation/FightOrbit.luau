-- Local horizontal orbit. Aiming and the finishing sequence keep their own input/presentation.
local UIS = game:GetService("UserInputService")
local Feel = require(game.ReplicatedStorage.Shared.Config.Balance).Feel
local Orbit = {}
Orbit.__index = Orbit

function Orbit.new(view)
	local self = setmetatable({ View = view, Yaw = 0, Target = 0, Keys = {}, Stick = 0, Connections = {} }, Orbit)
	self.Connections = {
		UIS.InputBegan:Connect(function(input, processed)
			self:Begin(input, processed)
		end),
		UIS.InputChanged:Connect(function(input)
			self:Change(input)
		end),
		UIS.InputEnded:Connect(function(input)
			self:Finish(input)
		end),
		UIS.WindowFocusReleased:Connect(function()
			self:Cancel()
		end),
	}
	return self
end

function Orbit:Enabled()
	local v = self.View
	return v.Viewing
		and v.Phase == "Fighting"
		and not v.FinalTime
		and not (v.Scene and v.Scene.Finisher)
		and not UIS:GetFocusedTextBox()
end

function Orbit:Begin(input, processed)
	if processed or not self:Enabled() then
		return
	end
	local kind = input.UserInputType
	if (kind == Enum.UserInputType.Touch or kind == Enum.UserInputType.MouseButton1) and not self.Drag then
		self.Drag = { Input = input, X = input.Position.X }
	elseif input.KeyCode == Enum.KeyCode.Q or input.KeyCode == Enum.KeyCode.E then
		self.Keys[input.KeyCode] = true
	end
end

function Orbit:Change(input)
	if not self:Enabled() then
		self:Cancel()
		return
	end
	if input.KeyCode == Enum.KeyCode.Thumbstick2 then
		local x = input.Position.X
		self.Stick = if math.abs(x) > Feel.OrbitStickDeadzone then x else 0
	end
	local drag = self.Drag
	if
		drag
		and (
			input == drag.Input
			or (
				input.UserInputType == Enum.UserInputType.MouseMovement
				and drag.Input.UserInputType == Enum.UserInputType.MouseButton1
			)
		)
	then
		local width = math.max(1, workspace.CurrentCamera.ViewportSize.X)
		self.Target -= (input.Position.X - drag.X) / width * Feel.OrbitDragRadians
		drag.X = input.Position.X
	end
end

function Orbit:Finish(input)
	if self.Drag and input == self.Drag.Input then
		self.Drag = nil
	end
	self.Keys[input.KeyCode] = nil
	if input.KeyCode == Enum.KeyCode.Thumbstick2 then
		self.Stick = 0
	end
end

function Orbit:Cancel()
	self.Drag, self.Stick, self.Keys = nil, 0, {}
end

function Orbit:Step(dt)
	if self:Enabled() then
		local direction = (if self.Keys[Enum.KeyCode.E] then 1 else 0)
			- (if self.Keys[Enum.KeyCode.Q] then 1 else 0)
			+ self.Stick
		self.Target += direction * Feel.OrbitKeyRadiansPerSecond * dt
	else
		self:Cancel()
		-- Freeze exactly where the viewer was looking when the final blow arrives.
		self.Target = self.Yaw
	end
	local delta = math.atan2(math.sin(self.Target - self.Yaw), math.cos(self.Target - self.Yaw))
	self.Yaw += delta * (1 - math.exp(-dt * Feel.OrbitSmooth))
	self.Target = self.Yaw + math.atan2(math.sin(self.Target - self.Yaw), math.cos(self.Target - self.Yaw))
	return self.Yaw
end

function Orbit:Destroy()
	self:Cancel()
	for _, connection in self.Connections do
		connection:Disconnect()
	end
	self.Connections = {}
end

return Orbit
