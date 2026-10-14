local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("ReplicatedStorage")
local Remotes = require(RS.Shared.Remotes)
local Rules = require(RS.Shared.FightRules)
local Balance = require(RS.Shared.Config.Balance)
local View = require(script.Parent.Parent.Presentation.FightView)
local Controller = {}
function Controller:Init(controllers)
	self.Controllers, self.Views, self.SnapshotCount = controllers, {}, 0
end
function Controller:Active()
	for _, view in self.Views do
		if view.Participant then
			return view
		end
	end
	for _, view in self.Views do
		if view.Viewing then
			return view
		end
	end
end
function Controller:Start()
	Remotes.MatchState.OnClientEvent:Connect(function(data)
		if data.Phase == "Idle" then
			local view = self.Views[data.Id]
			if view then
				view:EndFight()
				self.Views[data.Id] = nil
			end
		elseif data.Frame and data.Id then
			local view = self.Views[data.Id]
			if not view then
				view = View.new(self.Controllers)
				self.Views[data.Id] = view
			end
			view:State(data)
		end
	end)
	Remotes.FightSnapshot.OnClientEvent:Connect(function(snapshot)
		self.SnapshotCount += 1
		if self.DropEvery and self.SnapshotCount % self.DropEvery == 0 then
			return
		end
		local view = self.Views[snapshot.Id]
		if view then
			view:Snapshot(snapshot)
		end
	end)
	Remotes.FightEvents.OnClientEvent:Connect(function(packet)
		local view = self.Views[packet.Id]
		if view then
			view:Queue(packet)
		end
	end)
	UIS.InputBegan:Connect(function(input, processed)
		local view = self:Active()
		if processed or not view or not view.Participant or view.Phase ~= "Aiming" or view.Locked then
			return
		end
		if
			input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1
		then
			view.Drag = {
				Input = input,
				Origin = Vector2.new(input.Position.X, input.Position.Y),
				Aim = view.Aim,
				Yaw = view.Yaw,
			}
		end
	end)
	UIS.InputChanged:Connect(function(input)
		local view = self:Active()
		local drag = view and view.Drag
		if not drag then
			return
		end
		if
			input == drag.Input
			or input.UserInputType == Enum.UserInputType.MouseMovement
				and drag.Input.UserInputType == Enum.UserInputType.MouseButton1
		then
			local delta = Vector2.new(input.Position.X, input.Position.Y) - drag.Origin
			view.Aim = Rules.clampAim(
				Balance.Motion.AimMin
					+ delta.Magnitude / Balance.Feel.AimDragPixels * (Balance.Motion.AimMax - Balance.Motion.AimMin)
			)
			view.Yaw = Rules.clampYaw(drag.Yaw + delta.X / Balance.Feel.AimYawPixels * Balance.Motion.AimYawMax)
		end
	end)
	UIS.InputEnded:Connect(function(input)
		local view = self:Active()
		if view and view.Drag and input == view.Drag.Input then
			view.Drag = nil
		end
	end)
	UIS.WindowFocusReleased:Connect(function()
		local v = self:Active()
		if v then
			v.Drag = nil
		end
	end)
	Players.LocalPlayer.CharacterRemoving:Connect(function()
		for _, view in self.Views do
			view:EndFight()
		end
		self.Views = {}
	end)
	Players.LocalPlayer.CharacterAdded:Connect(function()
		task.delay(0.2, function()
			Remotes.RequestFightState:FireServer()
		end)
	end)
	RunService:BindToRenderStep("GlassClashFight", Enum.RenderPriority.Camera.Value + 1, function(dt)
		local active = self:Active()
		for _, view in self.Views do
			if view.Scene then
				view.Scene.Muted = active ~= nil and active ~= view
				for _, fighter in view.Scene.Fighters do
					fighter.SoundScale = if view.Scene.Muted then 0 else 1
				end
			end
			view:Render(dt)
		end
	end)
	if RunService:IsStudio() then
		local dev = Instance.new("BindableFunction")
		dev.Name = "FightClientDev"
		dev.OnInvoke = function(command, arg)
			if command == "DropEvery" then
				self.DropEvery = arg
				return true
			end
			local out = {}
			for id, v in self.Views do
				out[id] =
					{ Time = v.RenderTime, Phase = v.Phase, Viewing = v.Viewing, Side = v.Side, Buffer = #v.Snapshots }
			end
			return out
		end
		dev.Parent = Players.LocalPlayer.PlayerScripts
	end
	Remotes.RequestFightState:FireServer()
end
return Controller
