local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CAS = game:GetService("ContextActionService")
local UIS = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Shared = RS:WaitForChild("Shared")
local Balance = require(Shared.Config.Balance)
local Audio = require(Shared.Config.Audio)
local Remotes = require(Shared.Remotes)
local BattleHud = require(script.Parent.Parent.UI.Screens.BattleHud)
local Feel = Balance.Feel
local Controller = {}

local function now()
	return workspace:GetServerTimeNow()
end
local function token(input)
	return input.UserInputType == Enum.UserInputType.Touch and input
		or tostring(input.UserInputType) .. tostring(input.KeyCode)
end

function Controller:Init(controllers)
	self.Shatter = controllers.ShatterController
	self.Player = Players.LocalPlayer
	self.Stand = workspace:WaitForChild("ClashStand")
	self.Assets = RS:WaitForChild("Assets"):WaitForChild("Glassies")
	self.Active = false
	local playerModule = self.Player:WaitForChild("PlayerScripts"):FindFirstChild("PlayerModule")
	if playerModule then
		self.Controls = require(playerModule):GetControls()
	end
end

function Controller:CreateFighter(id, hook, stats)
	local source = self.Assets[id]
	local model = Instance.new("Model")
	model.Name = id
	model.Parent = self.Root
	local body = source.Body:Clone()
	body.Parent = model
	local parts = { body }
	for _, part in source.Details:GetChildren() do
		local detail = part:Clone()
		detail.Parent = model
		table.insert(parts, detail)
	end
	local endPoint = Instance.new("Attachment")
	endPoint.Name, endPoint.CFrame = "StringEnd", body.PivotOffset
	endPoint.Parent = body
	local beam = Instance.new("Beam")
	beam.Name, beam.Attachment0, beam.Attachment1 = "String", hook, endPoint
	beam.Width0, beam.Width1, beam.FaceCamera = 0.035, 0.035, true
	beam.Color, beam.Transparency = ColorSequence.new(Color3.fromHex("#E2E8EF")), NumberSequence.new(0.05)
	beam.Parent = model
	local fighter = {
		Id = id,
		Model = model,
		Body = body,
		Parts = parts,
		Hook = hook,
		Beam = beam,
		Angle = 0,
		Stats = stats,
		CrackStage = 0,
	}
	self:Pose(fighter, 0)
	return fighter
end

function Controller:Pose(fighter, angle)
	fighter.Angle = angle
	local contact = fighter.Hook.Name == "HookA" and Feel.ContactAngle or -Feel.ContactAngle
	local curve = math.sin((angle - contact) / Feel.PullAngle * math.pi)
	fighter.Pivot = CFrame.new(fighter.Hook.WorldPosition)
		* CFrame.Angles(curve * Feel.DepthAngle, 0, angle)
		* CFrame.new(0, -Feel.StringLength, 0)
		* CFrame.Angles(0, curve * Feel.BodyTwist, fighter.Recoil or 0)
	for _, parts in { fighter.Parts, fighter.Cracks or {} } do
		for _, part in parts do
			part:PivotTo(fighter.Pivot)
		end
	end
end
function Controller:MakeScene(a, b)
	if self.Root then
		self.Root:Destroy()
	end
	self.Root = Instance.new("Folder")
	self.Root.Name = "LocalBattle"
	self.Root:SetAttribute("ClientOnly", true)
	self.Root.Parent = workspace
	local bar = self.Stand:WaitForChild("Crossbar")
	self.A = self:CreateFighter(a.Id, bar:WaitForChild("HookA"), a)
	self.B = self:CreateFighter(b.Id, bar:WaitForChild("HookB"), b)
	self.Focus = (self.A.Hook.WorldPosition + self.B.Hook.WorldPosition) / 2
		- Vector3.new(0, Feel.StringLength - Feel.CameraFocusOffset, 0)
end
function Controller:Idle()
	self:MakeScene({ Id = Balance.Prototype.PlayerId }, { Id = Balance.Prototype.OpponentId })
end

function Controller:Begin(inputToken)
	if not self.Active or self.Phase ~= "Meter" or self.Holding or now() < self.StartTime then
		return
	end
	if now() - self.StartTime >= Balance.Meter.MaxHoldTime then
		return
	end
	self.Holding, self.InputToken = true, inputToken
end
function Controller:Release(inputToken)
	if not self.Active or self.Phase ~= "Meter" or not self.Holding or inputToken ~= self.InputToken then
		return
	end
	self.Holding = false
	local elapsed = now() - self.StartTime
	self.Phase = "Waiting"
	self.Hud:Release()
	if elapsed <= Balance.Meter.MaxHoldTime then
		Remotes.ReleaseSwing:FireServer(self.BattleId, self.ClashIndex, math.max(0, elapsed))
	end
end

function Controller:BeginBattle(data)
	self:EndBattle()
	self.BattleId, self.Active, self.Phase = data.BattleId, true, "Starting"
	if self.Controls then
		self.Controls:Disable()
	end
	self.OldTouchControls = GuiService.TouchControlsEnabled
	GuiService.TouchControlsEnabled = false
	self:MakeScene(data.A, data.B)
	self.Hud = BattleHud.new(data.A, data.B)
	self.Hud.Gui:SetAttribute("BattleId", self.BattleId)
	local camera = workspace.CurrentCamera
	self.OldCamera = { Type = camera.CameraType, Subject = camera.CameraSubject, FOV = camera.FieldOfView }
	self.CameraPose = camera.CFrame
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = Feel.CameraFieldOfView
	local character = self.Player.Character
	self.HiddenParts = {}
	if character then
		local humanoid = character:FindFirstChildWhichIsA("Humanoid")
		if humanoid then
			self.Humanoid, self.OldMovement =
				humanoid, {
					Speed = humanoid.WalkSpeed,
					Jump = humanoid.JumpPower,
					Height = humanoid.JumpHeight,
					Rotate = humanoid.AutoRotate,
				}
			humanoid.WalkSpeed, humanoid.JumpPower, humanoid.JumpHeight, humanoid.AutoRotate = 0, 0, 0, false
		end
		for _, part in character:GetDescendants() do
			if part:IsA("BasePart") then
				self.HiddenParts[part] = part.LocalTransparencyModifier
				part.LocalTransparencyModifier = 1
			end
		end
	end
	CAS:BindActionAtPriority(
		"ClashHold",
		function(_, state, input)
			if state == Enum.UserInputState.Begin then
				self:Begin(token(input))
			elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
				self:Release(token(input))
			end
			return Enum.ContextActionResult.Sink
		end,
		false,
		Enum.ContextActionPriority.High.Value,
		Enum.KeyCode.Space,
		Enum.UserInputType.MouseButton1,
		Enum.KeyCode.ButtonA,
		Enum.KeyCode.ButtonR2
	)
end

function Controller:EndBattle()
	CAS:UnbindAction("ClashHold")
	if self.Controls then
		self.Controls:Enable()
	end
	if self.OldTouchControls ~= nil then
		GuiService.TouchControlsEnabled = self.OldTouchControls
		self.OldTouchControls = nil
	end
	self.Active, self.Holding, self.InputToken = false, false, nil
	if self.Hud then
		self.Hud:Destroy()
		self.Hud = nil
	end
	if self.OldCamera then
		local camera = workspace.CurrentCamera
		camera.CameraType, camera.CameraSubject, camera.FieldOfView =
			self.OldCamera.Type, self.OldCamera.Subject, self.OldCamera.FOV
		self.OldCamera = nil
	end
	if self.Humanoid and self.Humanoid.Parent then
		self.Humanoid.WalkSpeed, self.Humanoid.JumpPower, self.Humanoid.JumpHeight, self.Humanoid.AutoRotate =
			self.OldMovement.Speed, self.OldMovement.Jump, self.OldMovement.Height, self.OldMovement.Rotate
	end
	self.Humanoid = nil
	for part, transparency in self.HiddenParts or {} do
		if part.Parent then
			part.LocalTransparencyModifier = transparency
		end
	end
	self.HiddenParts = {}
	if self.Root then
		self.Root:Destroy()
		self.Root = nil
	end
end

function Controller:Clash(data)
	if not self.Active or data.BattleId ~= self.BattleId then
		return
	end
	self.ClashIndex, self.StartTime, self.Phase = data.ClashIndex, data.StartTime, "Meter"
	self.Holding, self.InputToken, self.Resolution = false, nil, nil
	self.ApproachStart = data.StartTime - Balance.Battle.ClashLeadSeconds
	self.ApproachTime = data.ApproachTime
	self.InitialA, self.InitialB = self.A.Angle, self.B.Angle
	self.A.Recoil, self.B.Recoil = 0, 0
	self.Hud:SetClash(data.ClashIndex)
	self.Hud.Gui:SetAttribute("ClashIndex", data.ClashIndex)
end
function Controller:Resolved(data)
	if not self.Active or data.BattleId ~= self.BattleId or data.ClashIndex ~= self.ClashIndex then
		return
	end
	self.Resolution, self.Phase, self.Holding = data, "Swing", false
	self.ApproachTime = data.LaunchTime + Balance.Battle.SwingSeconds
	self.Impacted = false
	self.Hud.Instruction.Text = "BOOST LOCKED"
	self.Hud.Zone.Text = string.upper(data.Result.ActionA) .. "  ×" .. Balance.Meter.Multipliers[data.Result.ActionA]
	self.Hud.Gui:SetAttribute("Zone", data.Result.ActionA)
	self.Shatter:Sound(Audio.Whoosh, self.A.Body, 1, 0.18, 0.6)
end

-- Motion follows the server cadence, independently of the player's HOLD input.
function Controller:Approach(time)
	local start = self.ApproachStart
	local initial = self.ClashIndex == 1 and Feel.InitialPullSeconds or 0
	if time < start + initial and initial > 0 then
		local p = math.sin(math.clamp((time - start) / initial, 0, 1) * math.pi / 2)
		self:Pose(self.A, self.InitialA + (-Feel.PullAngle - self.InitialA) * p)
		self:Pose(self.B, self.InitialB + (Feel.PullAngle - self.InitialB) * p)
		return
	end
	local p = math.clamp((time - start - initial) / (self.ApproachTime - start - initial), 0, 1)
	local ease = 1 - math.cos(p * math.pi / 2)
	local angle = -Feel.PullAngle + (Feel.PullAngle + Feel.ContactAngle) * ease
	self:Pose(self.A, angle)
	self:Pose(self.B, -angle)
end

function Controller:Frame(dt)
	if not self.Active then
		return
	end
	local time = now()
	self.Hud.Gui:SetAttribute("Phase", self.Phase)
	if self.Phase == "Meter" or self.Phase == "Waiting" then
		self:Approach(time)
		if self.Phase == "Meter" then
			local elapsed = math.max(0, time - self.StartTime)
			if elapsed >= Balance.Meter.MaxHoldTime then
				self.Phase, self.Holding = "Waiting", false
				self.Hud:Release()
				self.Hud.Instruction.Text = "NO BOOST • WEAK"
			else
				self.Hud:SetMeter(elapsed, self.Holding, time >= self.StartTime, self.A.Stats.Swing)
			end
		end
	elseif self.Phase == "Swing" then
		local data = self.Resolution
		local motionTime = time
		if data.Result.Winner and time > data.LaunchTime then
			local elapsed = time - data.LaunchTime
			local normal = math.max(0, Balance.Battle.SwingSeconds - Feel.SlowMotionSeconds * Feel.SlowMotionRate)
			motionTime = data.LaunchTime
				+ math.min(elapsed, normal)
				+ math.max(0, elapsed - normal) * Feel.SlowMotionRate
		end
		self:Approach(motionTime)
		if time >= data.ImpactTime and not self.Impacted then
			-- Clamp contact exactly before applying the server's result.
			self:Pose(self.A, Feel.ContactAngle)
			self:Pose(self.B, -Feel.ContactAngle)
			self.Impacted, self.Phase = true, "Bounce"
			self.ShakeUntil = time + Feel.ShakeSeconds
			self.ShakePower = math.clamp(
				math.max(data.Result.DamageToA / self.A.Stats.MaxHP, data.Result.DamageToB / self.B.Stats.MaxHP) / 0.3,
				0,
				1
			) * Feel.ShakeMax
			self.Shatter:Impact(self.A, self.B, data.Result, self.Hud, self.Root)
		end
	elseif self.Phase == "Bounce" then
		local elapsed = time - self.Resolution.ImpactTime - Feel.HitstopSeconds
		if elapsed > 0 then
			local p = math.clamp(elapsed / (Balance.Battle.BounceSeconds - Feel.HitstopSeconds), 0, 1)
			local rebound = math.sin(p * math.pi / 2)
			local angle = Feel.ContactAngle - (Feel.ContactAngle + Feel.PullAngle) * rebound
			local wobble = math.sin(p * math.pi * 4) * (1 - p) * Feel.RecoilAngle
			self.A.Recoil, self.B.Recoil = -wobble, wobble
			self:Pose(self.A, angle)
			self:Pose(self.B, -angle)
		end
	end
	local camera = workspace.CurrentCamera
	local viewport = camera.ViewportSize
	local scale = math.max(1, Feel.CameraMinimumAspect / (viewport.X / math.max(viewport.Y, 1)))
	local offset = Vector3.new(-7, 4.3, 13) * scale
	if self.Resolution and self.Resolution.Result.Winner then
		local push = math.clamp((time - self.Resolution.LaunchTime) / 2, 0, 1)
		offset = Vector3.new(0, 1.6, 12 - push * 1.5) * scale
	end
	local target = CFrame.lookAt(self.Focus + offset, self.Focus)
	self.CameraPose = self.CameraPose:Lerp(target, 1 - math.exp(-dt * 10))
	local shake = Vector3.zero
	if self.ShakeUntil and time < self.ShakeUntil then
		local amplitude = self.ShakePower * (self.ShakeUntil - time) / Feel.ShakeSeconds
		shake = Vector3.new(math.sin(time * 93), math.cos(time * 111), 0) * amplitude
	end
	camera.CFrame = self.CameraPose * CFrame.new(shake)
end

function Controller:Start()
	self:Idle()
	Remotes.BattleStarted.OnClientEvent:Connect(function(data)
		self:BeginBattle(data)
	end)
	Remotes.ClashStarted.OnClientEvent:Connect(function(data)
		self:Clash(data)
	end)
	Remotes.ClashResolved.OnClientEvent:Connect(function(data)
		self:Resolved(data)
	end)
	Remotes.BattleEnded.OnClientEvent:Connect(function(data)
		if self.Active and data.BattleId == self.BattleId then
			self:EndBattle()
			self:Idle()
		end
	end)
	UIS.InputBegan:Connect(function(input, processed)
		if not processed and input.UserInputType == Enum.UserInputType.Touch then
			self:Begin(token(input))
		end
	end)
	UIS.InputEnded:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1
		then
			self:Release(token(input))
		end
	end)
	UIS.WindowFocusReleased:Connect(function()
		if self.Holding then
			self:Release(self.InputToken)
		end
	end)
	self.Player.CharacterRemoving:Connect(function()
		self:EndBattle()
	end)
	RunService:BindToRenderStep("GlassClashBattle", Enum.RenderPriority.Camera.Value + 1, function(dt)
		self:Frame(dt)
	end)
end
return Controller
