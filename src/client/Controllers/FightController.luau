local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("ReplicatedStorage")
local Remotes = require(RS.Shared.Remotes)
local Codec = require(RS.Shared.SnapshotCodec)
local Rules = require(RS.Shared.FightRules)
local Balance = require(RS.Shared.Config.Balance)
local View = require(script.Parent.Parent.Presentation.FightView)
local CastButton = require(script.Parent.Parent.UI.Screens.CastButton)
local Controller = {}
function Controller:Init(controllers)
	self.Controllers, self.Views, self.SnapshotCount, self.Keys = controllers, {}, 0, {}
	self.Prompts, self.PromptClock = {}, 0
end

-- Watching (GAME_DESIGN 7): a local prompt at each busy stand points your camera at that fight.
local WATCHABLE = { Aiming = true, Countdown = true, Fighting = true, RoundEnd = true }

function Controller:CanWatch()
	local pg = Players.LocalPlayer:FindFirstChild("PlayerGui")
	if pg and (pg:GetAttribute("InMatch") or pg:GetAttribute("Queued") or pg:GetAttribute("ResultsOpen")) then
		return false
	end
	for _, view in self.Views do
		if view.Viewing then
			return false
		end
	end
	return true
end

function Controller:WatchableView(arenaId)
	for _, view in self.Views do
		if view.Data and view.Data.ArenaId == arenaId and view.Scene and not view.Participant then
			return view
		end
	end
	return nil
end

function Controller:StartWatching(arenaId)
	local view = self:WatchableView(arenaId)
	if view and WATCHABLE[view.Phase] and self:CanWatch() then
		self.WatchArena, self.WatchUntil = arenaId, nil
		view:Watch(true)
	end
end

function Controller:StopWatching()
	self.WatchArena, self.WatchUntil = nil, nil
	for _, view in self.Views do
		if view.Watching then
			view:Watch(false)
		end
	end
end

function Controller:AddPrompt(stand)
	local id = stand:GetAttribute("ArenaId")
	if type(id) ~= "number" or self.Prompts[id] then
		return
	end
	-- With StreamingEnabled the stand model can arrive before its parts.
	local floor = stand:WaitForChild("PenFloor", 30)
	if not floor or self.Prompts[id] then
		return
	end
	local attachment = Instance.new("Attachment")
	attachment.Name, attachment.Position = "WatchPrompt", Vector3.yAxis * 3
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Watch"
	prompt.ObjectText = if stand:GetAttribute("Featured") then "Featured Arena" else "Arena " .. id
	prompt.HoldDuration, prompt.RequiresLineOfSight, prompt.Enabled = 0, false, false
	prompt.MaxActivationDistance = Balance.Feel.WatchPromptDistance
	prompt.Parent = attachment
	attachment.Parent = floor
	prompt.Triggered:Connect(function()
		self:StartWatching(id)
	end)
	attachment.Destroying:Connect(function()
		if self.Prompts[id] == prompt then
			self.Prompts[id] = nil
		end
	end)
	self.Prompts[id] = prompt
end

function Controller:UpdatePrompts(dt)
	self.PromptClock += dt
	if self.PromptClock < 0.25 then
		return
	end
	self.PromptClock = 0
	local allowed = self:CanWatch()
	for id, prompt in self.Prompts do
		local view = if allowed then self:WatchableView(id) else nil
		prompt.Enabled = view ~= nil and WATCHABLE[view.Phase] == true
	end
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
-- CAST button (decision 85): follows our own side's Ready / cast events.
local CLEARS = { ReadyCancel = true, CastStart = true, SignatureArmed = true, Shatter = true, End = true }

function Controller:CastEvents(view, events)
	if not view or not view.Participant or not view.Side then
		return
	end
	for _, e in events do
		if e.Type == "Shatter" or e.Type == "End" then
			self.CastUi:Clear()
		elseif e.Side == view.Side then
			if e.Type == "SignatureReady" then
				self.CastUi:Ready(e)
			elseif CLEARS[e.Type] and (e.Type ~= "ReadyCancel" or e.ReadyId == self.CastUi.ReadyId) then
				if e.Type ~= "CastStart" or e.Held then
					self.CastUi:Clear()
				end
			end
		end
	end
end

function Controller:Start()
	self.CastUi = CastButton.new(function()
		Remotes.CastPower:FireServer()
	end)
	Remotes.MatchState.OnClientEvent:Connect(function(data)
		local mine = self.Views[data.Id]
		if data.Phase ~= "Fighting" and mine and mine.Participant then
			self.CastUi:Clear()
		end
		if data.Phase == "Idle" then
			local view = self.Views[data.Id]
			if view then
				if view.Watching then
					-- Keep watching this arena if its next round starts soon.
					self.WatchUntil = os.clock() + Balance.Feel.WatchRejoinSeconds
				end
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
				view.OnStopWatching = function()
					self.WatchArena, self.WatchUntil = nil, nil
				end
				self.Views[data.Id] = view
			end
			view:State(data)
			if data.Phase == "Fighting" and data.SignatureState then
				self:CastEvents(view, data.SignatureState)
			end
			if
				self.WatchArena == data.ArenaId
				and self.WatchUntil
				and os.clock() < self.WatchUntil
				and WATCHABLE[view.Phase]
				and not view.Participant
				and self:CanWatch()
			then
				self.WatchUntil = nil
				view:Watch(true)
			end
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
			self:CastEvents(view, packet.Events or {})
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
		self.CastUi:Clear()
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
	for _, stand in CollectionService:GetTagged("ArenaStand") do
		task.spawn(self.AddPrompt, self, stand)
	end
	CollectionService:GetInstanceAddedSignal("ArenaStand"):Connect(function(stand)
		task.spawn(self.AddPrompt, self, stand)
	end)
	local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
	for _, attribute in { "InMatch", "Queued" } do
		pg:GetAttributeChangedSignal(attribute):Connect(function()
			if pg:GetAttribute(attribute) then
				self:StopWatching()
			end
		end)
	end
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
		if active and active.Participant and active.Phase == "Fighting" then
			self.CastUi:Update(active)
		end
		-- After rendering, so prompt bookkeeping can never stall the fights.
		self:UpdatePrompts(dt)
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
			if command == "Orbit" then
				local view = self:Active()
				if not view or not view.Orbit or not view.Orbit:Enabled() then
					return false
				end
				if type(arg) ~= "number" or arg ~= arg or math.abs(arg) == math.huge then
					return false
				end
				view.Orbit.Target = arg
				return true
			end
			if command == "Rejoin" then
				local view = self.Views[arg]
				if view then
					view:EndFight()
					self.Views[arg] = nil
				end
				Remotes.RequestFightState:FireServer()
				return true
			end
			if command == "DropEvery" then
				self.DropEvery = arg
				return true
			end
			if command == "Profile" then
				-- Studio-only: time this controller's per-frame render work over `arg` seconds.
				self.Profile = { Frames = 0, Total = 0, Max = 0, Dt = 0, MaxDt = 0, Views = 0, ByKind = {} }
				if type(arg) == "table" then
					for _ = 1, math.clamp(arg.Frames or 30, 1, 120) do
						RunService.RenderStepped:Wait()
					end
				else
					task.wait(arg or 5)
				end
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
				out[id] = {
					Time = v.RenderTime,
					Phase = v.Phase,
					Viewing = v.Viewing,
					Side = v.Side,
					Buffer = #v.Snapshots,
					OrbitYaw = v.Orbit and v.Orbit.Yaw,
				}
			end
			return out
		end
		dev.Parent = Players.LocalPlayer.PlayerScripts
	end
	Remotes.RequestFightState:FireServer()
end
return Controller
