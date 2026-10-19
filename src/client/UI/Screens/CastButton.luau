-- The optional CAST button (decision 85). It lights up when your glassy's power is Ready: tap it
-- to cast now, or let it cast by itself when the ring runs out. It glows gold at a good moment
-- (CastTiming, read from the newest snapshot), which teaches timing without punishing kids who wait.
local TweenService = game:GetService("TweenService")
local ContextActionService = game:GetService("ContextActionService")
local RS = game:GetService("ReplicatedStorage")
local Balance = require(RS.Shared.Config.Balance)
local Glassies = require(RS.Shared.Config.Glassies)
local Geometry = require(RS.Shared.Config.ReleaseGeometry)
local CastTiming = require(RS.Shared.CastTiming)
local Theme = require(script.Parent.Parent.Theme)
local Kit = require(script.Parent.Parent.Components.MatchKit)
local Cast = {}
Cast.__index = Cast

local M = Balance.Motion
local GOLD = Color3.fromRGB(255, 214, 92)
local ACTION = "GlassClashCast"
-- Bound above the default controls only while CAST is lit, so Space/ButtonA don't also jump.
local KEYS = { Enum.KeyCode.Space, Enum.KeyCode.F, Enum.KeyCode.ButtonA, Enum.KeyCode.ButtonR2 }

function Cast.new(onPress)
	local self = setmetatable({ OnPress = onPress }, Cast)
	self.Gui = Kit.gui("CastButton", 22)
	self.Root = Instance.new("Frame")
	self.Root.Name, self.Root.BackgroundTransparency = "Cast", 1
	self.Root.AnchorPoint, self.Root.Size = Vector2.new(0.5, 0.5), UDim2.fromScale(0.26, 0.3)
	self.Root.Position, self.Root.Visible, self.Root.Parent = UDim2.fromScale(0.85, 0.74), false, self.Gui
	self.Scale = Instance.new("UIScale")
	self.Scale.Parent = self.Root
	self.Power = Kit.label(
		self.Root,
		"PowerName",
		"",
		UDim2.fromScale(1, 0.2),
		UDim2.fromScale(0, 0),
		{ Font = Theme.Fonts.Body, MaxSize = Theme.TextSize.Label, Outline = 2 }
	)
	self.Button =
		Kit.gem(self.Root, "CastButton", "CAST!", "amber", UDim2.fromScale(1, 0.55), UDim2.fromScale(0.5, 0.5))
	self.Glow = Instance.new("UIStroke")
	self.Glow.Thickness, self.Glow.Color, self.Glow.Transparency = 0, GOLD, 1
	self.Glow.ApplyStrokeMode, self.Glow.Parent = Enum.ApplyStrokeMode.Border, self.Button
	-- Auto ring: a bar that drains until the power casts by itself.
	local track = Instance.new("Frame")
	track.Name, track.AnchorPoint, track.BorderSizePixel = "AutoTrack", Vector2.new(0.5, 0), 0
	track.Size, track.Position = UDim2.fromScale(0.7, 0.06), UDim2.fromScale(0.5, 0.84)
	track.BackgroundColor3, track.BackgroundTransparency, track.Parent = Theme.Colors.Shadow, 0.35, self.Root
	Kit.outline(track, 1.5)
	self.Fill = Instance.new("Frame")
	self.Fill.Name, self.Fill.BorderSizePixel, self.Fill.Size = "Fill", 0, UDim2.fromScale(1, 1)
	self.Fill.BackgroundColor3, self.Fill.Parent = GOLD, track
	self.Hint = Kit.label(
		self.Root,
		"Hint",
		"",
		UDim2.fromScale(1, 0.12),
		UDim2.fromScale(0, 0.9),
		{ Font = Theme.Fonts.Body, MaxSize = 22, Outline = 2 }
	)
	self.Connection = self.Button.Activated:Connect(function()
		self:Press()
	end)
	return self
end

-- A power became Ready for our side.
function Cast:Ready(event, serverNow)
	self.ReadyId, self.Shape, self.Arm = event.ReadyId, event.Shape, event.Arm
	self.Kind = CastTiming.kind(event.Shape, event.Arm)
	self.AutoAt, self.Seconds = event.AutoAt, math.max(0.1, event.Seconds or Balance.CombatRelease.Cast.AutoSeconds)
	-- Fight time vs. our clock: AutoAt is in fight time, so remember the offset on arrival.
	self.ClockAtReady, self.FightAtReady = os.clock(), event.Time or (event.AutoAt - self.Seconds)
	self.Pressed = false
	local def = Glassies.get(event.Kit)
	self.KitId = event.Kit
	self.Power.Text = def and def.SpecialName or "POWER"
	Kit.enable(self.Button, true)
	self.Root.Visible = true
	ContextActionService:BindActionAtPriority(ACTION, function(_, state)
		if state == Enum.UserInputState.Begin then
			self:Press()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value + 10, table.unpack(KEYS))
	self.Scale.Scale = 0.6
	TweenService:Create(self.Scale, TweenInfo.new(0.22, Enum.EasingStyle.Back), { Scale = 1 }):Play()
end

function Cast:Press()
	if not self.Root.Visible or self.Pressed then
		return
	end
	self.Pressed = true
	ContextActionService:UnbindAction(ACTION)
	self.OnPress()
	Kit.enable(self.Button, false)
	self.Scale.Scale = 1.18
	TweenService:Create(self.Scale, TweenInfo.new(0.18, Enum.EasingStyle.Quad), { Scale = 0 }):Play()
	task.delay(0.2, function()
		if self.Pressed and self.Root then
			self.Root.Visible = false
		end
	end)
end

function Cast:Clear()
	self.ReadyId = nil
	ContextActionService:UnbindAction(ACTION)
	if self.Root then
		self.Root.Visible = false
	end
end

-- Positions of both glassies from a snapshot, in the arena's local frame (Pendulum.center).
local function centers(view, snapshot)
	local data = view.Data
	local hooks = data.HookPositions
	local gap = if hooks then (hooks[2] - hooks[1]).Magnitude else M.HookGap
	local out = {}
	for side = 1, 2 do
		local b = snapshot.B and snapshot.B[side]
		local setup = if side == 1 then data.A else data.B
		if not b or not setup then
			return nil
		end
		local geometry = Geometry[setup.Id]
		local def = Glassies.get(setup.Id)
		local k = 1 + (geometry and geometry.Center or M.BodyCenter) * M.GlassyScale / M.StringLength
		local hook = Vector3.new((if side == 1 then -1 else 1) * gap / 2, 0, 0)
		out[side] = {
			C = hook + Vector3.new(b[1], b[2], b[3]) * k,
			V = Vector3.new(b[4], b[5], b[6]) * k,
			R = geometry and geometry.Radius or (def and def.Radius) or 0.7,
			Twist = b[7] or 0,
			Spin = b[8] or 0,
		}
	end
	return out
end

function Cast:Update(view)
	if not self.Root.Visible or self.Pressed or not self.AutoAt then
		return
	end
	local left = math.max(0, self.Seconds - (os.clock() - self.ClockAtReady))
	self.Fill.Size = UDim2.fromScale(left / self.Seconds, 1)
	local snapshot = view.Snapshots and view.Snapshots[#view.Snapshots]
	local good = false
	local c = snapshot and view.Side and centers(view, snapshot)
	if c then
		local mine, other = c[view.Side], c[3 - view.Side]
		local delta = other.C - mine.C
		local distance = delta.Magnitude
		local normal = if distance > 0.0001 then delta / distance else Vector3.xAxis
		local closing = (mine.V - other.V):Dot(normal)
		local kit = Balance.CombatRelease.Kits[self.KitId]
		local aim = CastTiming.aimError(mine.Twist, mine.Spin, kit)
		good = CastTiming.good(self.Kind, distance, closing, (mine.R + other.R) * M.GlassyScale, kit, aim)
	end
	if good ~= self.Good then
		self.Good = good
		self.Glow.Transparency = if good then 0 else 1
		self.Hint.Text = if good then "NOW!" else ""
		self.Hint.TextColor3 = GOLD
	end
	-- Breathe faster at a good moment so it reads at a glance.
	local hz = if good then 5 else 1.6
	self.Glow.Thickness = if good then 3 + 2 * math.sin(os.clock() * hz * math.pi * 2) else 0
	self.Scale.Scale = 1 + (if good then 0.06 else 0.025) * math.sin(os.clock() * hz * math.pi * 2)
end

function Cast:Destroy()
	ContextActionService:UnbindAction(ACTION)
	self.Connection:Disconnect()
	self.Gui:Destroy()
	self.Root = nil
end

return Cast
