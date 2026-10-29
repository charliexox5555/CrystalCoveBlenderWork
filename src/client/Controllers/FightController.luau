local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local UIS = game:GetService("UserInputService")
local CAS = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local RS = game:GetService("ReplicatedStorage")
local Remotes = require(RS.Shared.Remotes)
local Codec = require(RS.Shared.SnapshotCodec)
local Rules = require(RS.Shared.FightRules)
local Balance = require(RS.Shared.Config.Balance)
local View = require(script.Parent.Parent.Presentation.FightView)
local Isolation = require(script.Parent.Parent.Presentation.StageIsolation)
local ViewCull = require(script.Parent.Parent.Presentation.ViewCull)
local bystanderEvery
local Controller = {}
function Controller:Init(controllers)
	self.Controllers, self.Views, self.SnapshotCount, self.Keys = controllers, {}, 0, {}
	self.Prompts, self.PromptClock = {}, 0
end

-- Watching (GAME_DESIGN 7): a local prompt at each busy stand points your camera at that fight.
-- A watch lasts the whole match: every round, effect, finisher and heart pop. Each round is its own fight view,
-- so the watch lives here, per match (self.Watch): between rounds the last round's view stays on screen
-- (camera, HUD, the survivor at rest) until the next round's view takes over in the same frame. It ends when
-- the server says the match is over, or the player exits.
local WATCHABLE = { Aiming = true, Countdown = true, Fighting = true, RoundEnd = true }

function Controller:CanWatch()
	local pg = Players.LocalPlayer:FindFirstChild("PlayerGui")
	if pg and (pg:GetAttribute("InMatch") or pg:GetAttribute("Queued") or pg:GetAttribute("ResultsOpen")) then
		return false
	end
	if self.Watch then
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
		local data = view.Data
		self.Watch = {
			ArenaId = arenaId,
			MatchId = data.MatchId,
			PlayerIds = data.PlayerIds,
			StageName = data.StageName,
		}
		Players.LocalPlayer.PlayerGui:SetAttribute("Watching", true)
		self:Follow(view)
		self:UpdateIsolation()
	end
end

function Controller:DropView(view)
	for id, other in self.Views do
		if other == view then
			self.Views[id] = nil
		end
	end
	view:EndFight()
end

-- The watched match's next round: close the previous round's view first (it gives the normal camera back),
-- then enter the new one, all in one frame, so the shot never leaves the arena.
function Controller:Follow(view)
	local watch = self.Watch
	local old = watch.View
	watch.View, watch.LingerUntil = view, nil
	if old and old ~= view then
		self:DropView(old)
	end
	view:Watch(true)
end

function Controller:StopWatching()
	local watch = self.Watch
	self.Watch = nil
	local view = watch and watch.View
	if view then
		if view.Watching then
			view:Watch(false)
		end
		if view.Lingering then
			self:DropView(view)
		end
	end
	for _, other in self.Views do
		if other.Watching then
			other:Watch(false)
		end
	end
	local pg = Players.LocalPlayer:FindFirstChild("PlayerGui")
	if pg then
		pg:SetAttribute("Watching", false)
	end
	self:UpdateIsolation()
end

-- Hide everyone who isn't in the match we're playing or watching (StageIsolation); show them again after.
function Controller:UpdateIsolation()
	local watch = self.Watch
	local pg = Players.LocalPlayer:FindFirstChild("PlayerGui")
	local own = self.OwnMatch
	if watch then
		Isolation.set({ Keep = watch.PlayerIds, Stage = watch.StageName, HideSelf = Balance.Feel.WatchHidesSelf })
	elseif own and pg and pg:GetAttribute("InMatch") then
		Isolation.set({ Keep = own.PlayerIds, Stage = own.StageName })
	else
		Isolation.set(nil)
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
	local watch = self.Watch
	if watch and watch.LingerUntil and os.clock() > watch.LingerUntil then
		-- The next round never came (missed packet, server hiccup): give the camera back.
		self:StopWatching()
	end
	self:UpdateIsolation()
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
-- Controller and keyboard aiming: the left stick, D-pad, arrows or WASD pull (down = more) and turn, at a steady
-- rate; Space / Enter / A locks. Mouse and touch keep the drag.
local LOCK_ACTION = "GlassClashLock"
local PULL_KEYS = {
	[Enum.KeyCode.Down] = 1,
	[Enum.KeyCode.S] = 1,
	[Enum.KeyCode.Up] = -1,
	[Enum.KeyCode.W] = -1,
}
local TURN_KEYS = {
	[Enum.KeyCode.Right] = 1,
	[Enum.KeyCode.D] = 1,
	[Enum.KeyCode.Left] = -1,
	[Enum.KeyCode.A] = -1,
}

function Controller:StickAim(view, dt)
	local pull, turn = 0, 0
	local dead = Balance.Feel.StickDeadzone
	local pad = Enum.UserInputType.Gamepad1
	for _, input in if UIS:GetGamepadConnected(pad) then UIS:GetGamepadState(pad) else {} do
		if input.KeyCode == Enum.KeyCode.Thumbstick1 then
			if math.abs(input.Position.Y) > dead then
				pull -= input.Position.Y
			end
			if math.abs(input.Position.X) > dead then
				turn += input.Position.X
			end
		end
	end
	for key, sign in { [Enum.KeyCode.DPadDown] = 1, [Enum.KeyCode.DPadUp] = -1 } do
		if UIS:IsGamepadButtonDown(pad, key) then
			pull += sign
		end
	end
	for key, sign in { [Enum.KeyCode.DPadRight] = 1, [Enum.KeyCode.DPadLeft] = -1 } do
		if UIS:IsGamepadButtonDown(pad, key) then
			turn += sign
		end
	end
	if not UIS:GetFocusedTextBox() then
		for key, sign in PULL_KEYS do
			if UIS:IsKeyDown(key) then
				pull += sign
			end
		end
		for key, sign in TURN_KEYS do
			if UIS:IsKeyDown(key) then
				turn += sign
			end
		end
	end
	pull, turn = math.clamp(pull, -1, 1), math.clamp(turn, -1, 1)
	if pull ~= 0 then
		local range = Balance.Motion.AimMax - Balance.Motion.AimMin
		view.Aim = Rules.clampAim(view.Aim + pull * range / Balance.Feel.StickAimSeconds * dt)
	end
	if turn ~= 0 then
		view.Yaw = Rules.clampYaw(view.Yaw + turn * Balance.Motion.AimYawMax / Balance.Feel.StickYawSeconds * dt)
	end
end

-- LOCK keys are bound only while our own aim is open, so Space / A do nothing else then (and never jump).
function Controller:BindLock(on)
	if on == (self.LockBound == true) then
		return
	end
	self.LockBound = on
	if not on then
		CAS:UnbindAction(LOCK_ACTION)
		return
	end
	if UIS.PreferredInput == Enum.PreferredInput.Gamepad then
		GuiService.SelectedObject = nil -- the left stick aims; it must not move a menu selection
	end
	CAS:BindActionAtPriority(
		LOCK_ACTION,
		function(_, state)
			if state ~= Enum.UserInputState.Begin then
				return Enum.ContextActionResult.Sink
			end
			local view = self:Active()
			if view and view.Participant and view.Phase == "Aiming" and not view.Locked then
				view:Lock()
				if view.Hud then
					view.Hud:LockPressed()
				end
			end
			return Enum.ContextActionResult.Sink
		end,
		false,
		Enum.ContextActionPriority.High.Value + 10,
		Enum.KeyCode.Space,
		Enum.KeyCode.Return,
		Enum.KeyCode.ButtonA
	)
end

local Feel = Balance.Feel
function bystanderEvery(view, camera): number
	if view.Viewing or view.Participant or not view.Scene or not camera or ViewCull.off() then
		return 1
	end
	local position = view.Scene.Frame.Position
	if not ViewCull.visible(camera, position, Feel.BystanderCullRadius) then
		return Feel.BystanderOffscreenEvery
	end
	return if (camera.CFrame.Position - position).Magnitude > Feel.BystanderHalfRateDistance then 2 else 1
end

function Controller:Start()
	Remotes.MatchState.OnClientEvent:Connect(function(data)
		if table.find(data.PlayerIds or {}, Players.LocalPlayer.UserId) and data.MatchId then
			self.OwnMatch = { MatchId = data.MatchId, PlayerIds = data.PlayerIds, StageName = data.StageName }
		end
		if data.Phase == "Idle" then
			local watch = self.Watch
			if watch and data.MatchOver and data.MatchId == watch.MatchId then
				self:StopWatching()
			end
			local view = self.Views[data.Id]
			watch = self.Watch
			if view and watch and watch.View == view then
				-- Between rounds: keep this view on screen until the next round's view takes over.
				view.Lingering = true
				watch.LingerUntil = os.clock() + Balance.Feel.WatchRejoinSeconds
			elseif view then
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
				view.OnStopWatching = function(stopped)
					if self.Watch and self.Watch.View == stopped then
						self:StopWatching()
					end
				end
				self.Views[data.Id] = view
			end
			view:State(data)
			local watch = self.Watch
			if watch and watch.View ~= view and data.ArenaId == watch.ArenaId and not view.Participant then
				if data.MatchId == watch.MatchId then
					self:Follow(view)
				else
					-- A new match in that arena: ours ended without us hearing.
					self:StopWatching()
				end
			end
		end
		self:UpdateIsolation()
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
			drag.Distance = delta.Magnitude
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
			local drag = view.Drag
			view.Drag = nil
			local distance = drag.Distance or 0
			if distance >= Balance.Feel.AimReleasePixels and view.Phase == "Aiming" and not view.Locked then
				view:Lock()
				if view.Hud then
					view.Hud:LockPressed()
				end
			end
		end
	end)
	UIS.WindowFocusReleased:Connect(function()
		local v = self:Active()
		if v then
			v.Drag = nil
		end
	end)
	Players.LocalPlayer.CharacterRemoving:Connect(function()
		self:StopWatching()
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
				if self.Watch then
					self:StopWatching()
				end
			elseif attribute == "InMatch" then
				self.OwnMatch = nil
			end
			self:UpdateIsolation()
		end)
	end
	RunService:BindToRenderStep("GlassClashFight", Enum.RenderPriority.Camera.Value + 1, function(frameDt)
		local profile = self.Profile
		local started = profile and os.clock()
		local active = self:Active()
		local camera = workspace.CurrentCamera
		for _, view in self.Views do
			-- Bystander fights render less often when far or off screen; the skipped time is handed to the next
			-- render, so the swing, events and finishers stay on time. Yours and watched fights render every frame.
			view.PendingDt = (view.PendingDt or 0) + frameDt
			view.RenderTick = (view.RenderTick or 0) + 1
			if view.RenderTick % bystanderEvery(view, camera) ~= 0 then
				continue
			end
			local dt = view.PendingDt
			view.PendingDt = 0
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
		local aiming = active ~= nil
			and active.Participant
			and active.Phase == "Aiming"
			and not active.Locked
			and active.Hud ~= nil
		self:BindLock(aiming)
		if aiming and not active.Drag then
			self:StickAim(active, frameDt)
		end
		-- After rendering, so prompt bookkeeping can never stall the fights.
		self:UpdatePrompts(frameDt)
		if profile then
			local spent = os.clock() - started
			profile.Frames += 1
			profile.Total += spent
			profile.Max = math.max(profile.Max, spent)
			profile.Dt += frameDt
			profile.MaxDt = math.max(profile.MaxDt, frameDt)
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
			if command == "Watch" then
				-- Studio-only: the same as triggering an arena's Watch prompt (arg = arena id, nil to stop).
				if arg == nil then
					self:StopWatching()
					return true
				end
				self:StartWatching(arg)
				return self.Watch ~= nil
			end
			if command == "Watching" then
				local watch = self.Watch
				return watch
					and {
						ArenaId = watch.ArenaId,
						MatchId = watch.MatchId,
						ViewId = watch.View and watch.View.Data and watch.View.Data.Id,
						Lingering = watch.View and watch.View.Lingering == true,
						Isolated = Isolation.active(),
					}
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
