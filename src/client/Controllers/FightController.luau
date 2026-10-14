local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("ReplicatedStorage")
local Remotes = require(RS.Shared.Remotes)
local Codec = require(RS.Shared.SnapshotCodec)
local Rules = require(RS.Shared.FightRules)
local Balance = require(RS.Shared.Config.Balance)
local View = require(script.Parent.Parent.Presentation.FightView)
local Controller = {}
function Controller:Init(controllers)
	self.Controllers, self.Views, self.SnapshotCount, self.Keys = controllers, {}, 0, {}
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
			for key, id in self.Keys do
				if id == data.Id then
					self.Keys[key] = nil
				end
			end
		elseif data.Frame and data.Id then
			if type(data.Key) == "number" then
				self.Keys[data.Key] = data.Id
			end
			local view = self.Views[data.Id]
			if not view then
				view = View.new(self.Controllers)
				self.Views[data.Id] = view
			end
			view:State(data)
		end
	end)
	Remotes.FightSnapshot.OnClientEvent:Connect(function(packet)
		self.SnapshotCount += 1
		if self.DropEvery and self.SnapshotCount % self.DropEvery == 0 then
			return
		end
		if type(packet) ~= "buffer" then
			return
		end
		local key, snapshot = Codec.decode(packet)
		local id = key and self.Keys[key]
		if not id or not snapshot then
			return
		end
		snapshot.Id = id
		local view = self.Views[id]
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
		local profile = self.Profile
		local started = profile and os.clock()
		local active = self:Active()
		for _, view in self.Views do
			if view.Scene then
				view.Scene.Muted = active ~= nil and active ~= view
				for _, fighter in view.Scene.Fighters do
					fighter.SoundScale = if view.Scene.Muted then 0 else 1
				end
			end
			if profile then
				local kind = if view.Participant then "Participant" elseif view.Viewing then "Spectate" else "Nearby"
				local newest = view.Snapshots[#view.Snapshots]
				if not view.Viewing and (not newest or workspace:GetServerTimeNow() - newest.SentAt > 1) then
					kind = "Far"
				end
				local t = os.clock()
				view:Render(dt)
				profile.ByKind[kind] = (profile.ByKind[kind] or 0) + os.clock() - t
			else
				view:Render(dt)
			end
		end
		if profile then
			local spent = os.clock() - started
			profile.Frames += 1
			profile.Total += spent
			profile.Max = math.max(profile.Max, spent)
			profile.Dt += dt
			profile.MaxDt = math.max(profile.MaxDt, dt)
			profile.Views = math.max(
				profile.Views,
				(function()
					local n = 0
					for _ in self.Views do
						n += 1
					end
					return n
				end)()
			)
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
			if command == "Profile" then
				-- Studio-only: time this controller's per-frame render work over `arg` seconds.
				self.Profile = { Frames = 0, Total = 0, Max = 0, Dt = 0, MaxDt = 0, Views = 0, ByKind = {} }
				task.wait(arg or 5)
				local p = self.Profile
				self.Profile = nil
				local byKind = {}
				for kind, total in p.ByKind do
					byKind[kind] = total / math.max(1, p.Frames) * 1000
				end
				return {
					MeanMsByKind = byKind,
					Frames = p.Frames,
					Fps = p.Frames / math.max(p.Dt, 1e-6),
					MaxFrameMs = p.MaxDt * 1000,
					MeanRenderMs = p.Total / math.max(1, p.Frames) * 1000,
					MaxRenderMs = p.Max * 1000,
					Views = p.Views,
				}
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
