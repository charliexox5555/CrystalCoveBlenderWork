--!strict
-- The loading screen's little show (decision 123): a white pen with two glass balls on strings that swing in, clink
-- and bounce back. Frames only, so it draws on the first frame with nothing to download. Laid out in a square
-- `box` frame; positions are fractions of that box.
local RunService = game:GetService("RunService")

local Mini = {}
Mini.__index = Mini

local HOOK_GAP = 0.2 -- hooks sit this far either side of the middle
local HOOK_Y = 0.2
local STRING = 0.46 -- string length
local BALL = 0.11 -- ball radius
local PULL = 0.75 -- radians: how far back they swing
local PERIOD = 1.3 -- seconds from one clink to the next
-- The angle where the two balls just touch in the middle.
local CONTACT = math.asin(math.clamp((HOOK_GAP - BALL) / STRING, 0, 1))
local WHITE = Color3.new(1, 1, 1)
local GLASS = { Color3.fromHex("#BFEFFF"), Color3.fromHex("#FFC6D6") }

local function frame(parent: Instance, name: string, props: { [string]: any }): Frame
	local f = Instance.new("Frame")
	f.Name, f.BorderSizePixel, f.BackgroundColor3 = name, 0, WHITE
	for key, value in props do
		(f :: any)[key] = value
	end
	f.Parent = parent
	return f
end

function Mini.new(box: Frame)
	local self = setmetatable({ Box = box, Arms = {}, Flash = nil :: Frame?, Started = os.clock() }, Mini)
	-- The pen: a thin white outline, and the crossbar the strings hang from.
	local pen = frame(box, "Pen", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 })
	local stroke = Instance.new("UIStroke")
	stroke.Color, stroke.Thickness, stroke.Transparency = WHITE, 2, 0.2
	stroke.Parent = pen
	frame(box, "Bar", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, HOOK_Y),
		Size = UDim2.fromScale(HOOK_GAP * 2 + 0.16, 0.012),
	})
	for side = 1, 2 do
		local hookX = 0.5 + (if side == 1 then -1 else 1) * HOOK_GAP
		-- GUI rotation turns around the centre, so the string is placed at its midpoint each frame.
		local cord = frame(box, "String" .. side, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.new(0, 2, STRING, 0),
			BackgroundTransparency = 0.25,
		})
		local ball = frame(box, "Ball" .. side, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromScale(BALL * 2, BALL * 2),
			BackgroundColor3 = GLASS[side],
			BackgroundTransparency = 0.1,
		})
		local round = Instance.new("UICorner")
		round.CornerRadius, round.Parent = UDim.new(0.5, 0), ball
		local rim = Instance.new("UIStroke")
		rim.Color, rim.Thickness, rim.Parent = WHITE, 2, ball
		-- A small shine so they read as glass, not dots.
		local shine = frame(ball, "Shine", {
			Position = UDim2.fromScale(0.22, 0.18),
			Size = UDim2.fromScale(0.28, 0.28),
			BackgroundTransparency = 0.15,
		})
		local shineRound = Instance.new("UICorner")
		shineRound.CornerRadius, shineRound.Parent = UDim.new(0.5, 0), shine
		self.Arms[side] = { HookX = hookX, String = cord, Ball = ball }
	end
	self.Flash = frame(box, "Clink", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, HOOK_Y + STRING * math.cos(CONTACT)),
		Size = UDim2.fromScale(0.02, 0.02),
		BackgroundTransparency = 1,
		ZIndex = 5,
	})
	local flashRound = Instance.new("UICorner")
	flashRound.CornerRadius, flashRound.Parent = UDim.new(0.5, 0), self.Flash
	self.Connection = RunService.RenderStepped:Connect(function()
		self:Step()
	end)
	return self
end

function Mini:Step()
	local t = (os.clock() - self.Started) / PERIOD
	-- |cos| gives a hard bounce at the clink (cos = 0) and a smooth turn at full pull.
	local swing = math.abs(math.cos(t * math.pi))
	local theta = CONTACT - (CONTACT + PULL) * swing
	-- The box is square, so the same fraction works on both axes.
	for side, arm in self.Arms do
		local inward = if side == 1 then 1 else -1
		local x = arm.HookX + inward * STRING * math.sin(theta)
		local y = HOOK_Y + STRING * math.cos(theta)
		arm.Ball.Position = UDim2.fromScale(x, y)
		arm.String.Position = UDim2.fromScale((arm.HookX + x) / 2, (HOOK_Y + y) / 2)
		arm.String.Rotation = -inward * math.deg(theta)
	end
	-- A white spark right at the clink, fading over a fifth of a swing.
	local since = (t + 0.5) % 1
	local flash = self.Flash :: Frame
	local glow = math.clamp(1 - since / 0.2, 0, 1)
	flash.BackgroundTransparency = 1 - glow
	flash.Size = UDim2.fromScale(0.02 + 0.16 * (1 - glow), 0.02 + 0.16 * (1 - glow))
end

function Mini:Destroy()
	self.Connection:Disconnect()
end

return Mini
