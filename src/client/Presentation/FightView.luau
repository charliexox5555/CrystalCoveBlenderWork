local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TouchGate = require(script.Parent.Parent.UI.TouchGate)
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local CAS = game:GetService("ContextActionService")
local Balance = require(RS.Shared.Config.Balance)
local Formula = require(RS.Shared.Formula)
local Glassies = require(RS.Shared.Config.Glassies)
local Rules = require(RS.Shared.FightRules)
local Remotes = require(RS.Shared.Remotes)
local Scene = require(script.Parent.Parent.Presentation.FightScene)
local Hud = require(script.Parent.Parent.UI.Screens.FightHud)
local Orbit = require(script.Parent.FightOrbit)
local FinisherCamera = require(script.Parent.FinisherCamera)
local MatchCamera = require(script.Parent.MatchCamera)
local CombatFeel = require(script.Parent.CombatFeel)
local Theme = require(script.Parent.Parent.UI.Theme)
local Audio = require(RS.Shared.Config.Audio)
local M, Feel = Balance.Motion, Balance.Feel
local Controller = {}

local function vec(b, index)
	return Vector3.new(b[index], b[index + 1], b[index + 2])
end
local function pull(aim, yaw, side)
	return Vector3.new(
		(if side == 1 then -1 else 1) * math.sin(aim) * math.cos(yaw),
		-math.cos(aim),
		math.sin(aim) * math.sin(yaw)
	) * M.StringLength
end

local function crossesBox(box, origin, target)
	local o = box.CFrame:PointToObjectSpace(origin)
	local d = box.CFrame:VectorToObjectSpace(target - origin)
	local half = box.Size / 2
	local lo, hi = 0, 1
	for _, axis in { "X", "Y", "Z" } do
		if math.abs(d[axis]) < 0.0001 then
			if math.abs(o[axis]) > half[axis] then
				return false
			end
		else
			local a, b = (-half[axis] - o[axis]) / d[axis], (half[axis] - o[axis]) / d[axis]
			lo, hi = math.max(lo, math.min(a, b)), math.min(hi, math.max(a, b))
			if lo > hi then
				return false
			end
		end
	end
	return true
end
local function hermite(a, b, t, duration)
	local p, q = vec(a, 1), vec(b, 1)
	local v, w = vec(a, 4), vec(b, 4)
	local t2, t3 = t * t, t * t * t
	return p * (2 * t3 - 3 * t2 + 1)
		+ v * duration * (t3 - 2 * t2 + t)
		+ q * (-2 * t3 + 3 * t2)
		+ w * duration * (t3 - t2)
end

function Controller.new(controllers)
	local self = setmetatable({}, { __index = Controller })
	self:Init(controllers)
	return self
end

function Controller:Init(controllers)
	self.Shatter, self.Player = controllers.ShatterController, Players.LocalPlayer
	self.MatchController = controllers.MatchController
	self.Snapshots, self.Events = {}, {}
	local playerModule = self.Player:WaitForChild("PlayerScripts"):FindFirstChild("PlayerModule")
	self.Controls = playerModule and require(playerModule):GetControls()
end

-- Restores everything EnterView took over: movement, character visibility, arena signs, HUD, camera.
function Controller:ExitView()
	if self.Orbit then
		self.Orbit:Destroy()
		self.Orbit = nil
	end
	for effect, enabled in self.SunRays or {} do
		if effect.Parent then
			effect.Enabled = enabled
		end
	end
	self.SunRays = nil
	if self.Scene then
		self.Scene:SetViewing(false)
	end
	if self.Viewing then
		CAS:UnbindAction("FightMovement")
		CAS:UnbindAction("StopWatching")
	end
	for part, value in self.Hidden or {} do
		if part.Parent then
			part.LocalTransparencyModifier = value
		end
	end
	self.Hidden = {}
	for gui, enabled in self.HiddenGuis or {} do
		if gui.Parent then
			local active = gui:GetAttribute("ArenaActive")
			gui.Enabled = if active ~= nil then active else enabled
		end
	end
	self.HiddenGuis = {}
	if self.Hud then
		self.Hud:Destroy()
		self.Hud = nil
	end
	if self.OldCamera then
		local camera = workspace.CurrentCamera
		local old = self.OldCamera
		if old.Type == Enum.CameraType.Scriptable then
			-- Captured from another fight view mid-handover; hand back the normal follow camera instead.
			local humanoid = self.Player.Character and self.Player.Character:FindFirstChildOfClass("Humanoid")
			old = { Type = Enum.CameraType.Custom, Subject = humanoid or old.Subject, FOV = 70 }
		end
		camera.CameraType, camera.CameraSubject, camera.FieldOfView = old.Type, old.Subject, old.FOV
		self.OldCamera = nil
		if self.Controls then
			self.Controls:Enable()
		end
		TouchGate.release(self)
	end
end

function Controller:EndFight()
	if self.Watching then
		self.Player.PlayerGui:SetAttribute("Watching", false)
	end
	self:ExitView()
	if self.Feel then
		self.Feel:Destroy()
		self.Feel = nil
	end
	if self.Scene then
		self.Scene:Destroy()
		self.Scene = nil
	end
	self.KOQueue = {}
	self.Viewing, self.Watching = false, false
	self.Data, self.Snapshots, self.Events, self.Drag, self.RenderTime = nil, {}, {}, nil, 0
	self.FinalTime, self.FinalSide, self.SlowUntil, self.LastSnapshotWall = nil, nil, nil, nil
	self.Locked, self.Focus, self.LastCountdown = false, nil, nil
	self.ShatterShown, self.PendingHearts, self.PendingAt, self.Settling = false, nil, nil, nil
	if self.Post then
		self.Post:Destroy()
		self.Post = nil
	end
end

function Controller:Begin(data)
	self:EndFight()
	self.Data, self.Aim, self.Yaw, self.RenderTime = data, M.AimDefault, 0, 0
	local maxima =
		{ Formula.stats(Glassies.get(data.A.Id), data.A).HP, Formula.stats(Glassies.get(data.B.Id), data.B).HP }
	self.Scene = Scene.new(data, maxima, self.Shatter)
	self.Feel = CombatFeel.new(self)
	self.Scene.Feel = self.Feel
	for side, dead in data.DeadSides or {} do
		if dead then
			self.Scene:HideBroken(side)
		end
	end
	self.Side = table.find(data.PlayerIds or {}, self.Player.UserId)
		or (if data.UserId == self.Player.UserId then 1 else 0)
	self.Participant = self.Side > 0
	self.Viewing = self.Participant or data.Spectate
	self.Maxima = maxima
	for _, fighter in self.Scene.Fighters do
		fighter.LowDetail = not self.Viewing
	end
	if self.Viewing then
		self:EnterView()
	end
	if data.Snapshot then
		self:Snapshot(data.Snapshot)
		self.RenderTime = math.max(0, data.Snapshot.T - Feel.InterpolationDelay)
	end
end

-- Takes over camera, movement and HUD for a participant, a dev spectate fight or a player who chose Watch.
function Controller:EnterView()
	local data = self.Data
	self.Scene:SetViewing(true)
	-- Outward shots can face the sunset; keep rays from washing out glass and billboards.
	self.SunRays = {}
	for _, effect in Lighting:GetChildren() do
		if effect:IsA("SunRaysEffect") then
			self.SunRays[effect], effect.Enabled = effect.Enabled, false
		end
	end
	self.HiddenGuis = {}
	for _, gui in workspace.Lobby.Arenas:GetDescendants() do
		if gui:IsA("BillboardGui") and gui.Name == "ArenaStatus" then
			self.HiddenGuis[gui] = gui.Enabled
			gui.Enabled = false
		end
	end
	self.Hidden = {}
	CAS:BindActionAtPriority(
		"FightMovement",
		function()
			return Enum.ContextActionResult.Sink
		end,
		false,
		Enum.ContextActionPriority.High.Value,
		Enum.PlayerActions.CharacterForward,
		Enum.PlayerActions.CharacterBackward,
		Enum.PlayerActions.CharacterLeft,
		Enum.PlayerActions.CharacterRight,
		Enum.PlayerActions.CharacterJump
	)
	self.Hud = Hud.new(
		data,
		self.Maxima,
		function()
			self:Lock()
		end,
		if self.Participant
			then nil
			else function()
				self:Watch(false)
			end
	)
	if not self.Participant then
		CAS:BindActionAtPriority("StopWatching", function(_, state)
			if state == Enum.UserInputState.Begin then
				self:Watch(false)
			end
			return Enum.ContextActionResult.Sink
		end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.Escape, Enum.KeyCode.ButtonB)
	end
	-- Ownership is shown by the editable player billboards.
	if self.Controls then
		self.Controls:Disable()
	end
	TouchGate.acquire(self)
	local camera = workspace.CurrentCamera
	-- If the queue/selection camera is holding the shot, take over its saved normal-camera state so the
	-- player's own camera is what comes back when the fight ends.
	self.OldCamera = MatchCamera.handoff()
		or { Type = camera.CameraType, Subject = camera.CameraSubject, FOV = camera.FieldOfView }
	camera.CameraType, camera.FieldOfView = Enum.CameraType.Scriptable, Feel.CameraFieldOfView
	self.CameraPose = nil
	self.Orbit = Orbit.new(self)
	if self.Hud and self.Data.Hearts then
		self.Hud.Hearts = self.Data.Hearts
	end
	if self.Hud and self.Phase then
		self.Hud:Phase(self.Phase, "")
	end
end

-- Spectate a nearby fight on request, without rebuilding its scene or losing its snapshot buffer.
function Controller:Watch(on)
	if not self.Scene or self.Participant or on == self.Watching then
		return
	end
	self.Player.PlayerGui:SetAttribute("Watching", on)
	if on then
		self.Watching, self.Viewing = true, true
		local latest = self.Snapshots[#self.Snapshots]
		for side, fighter in self.Scene.Fighters do
			fighter.LowDetail = false
			-- Build the cracks the low-detail view skipped, without replaying the crack sound.
			if latest and (fighter.CrackStage or 0) > 0 and not fighter.Broken then
				fighter.CrackStage = 0
				self.Shatter:SetCracks(fighter, latest.R.Hp[side], fighter.Stats.MaxHP)
			end
		end
		self:EnterView()
	else
		self:ExitView()
		self.Watching, self.Viewing = false, false
		for _, fighter in self.Scene.Fighters do
			fighter.LowDetail = true
		end
		if self.OnStopWatching then
			self.OnStopWatching(self)
		end
	end
end

function Controller:State(data)
	if data.Phase == "Idle" then
		if self.Data and data.Id == self.Data.Id then
			self:EndFight()
		end
		return
	end
	if not self.Data or self.Data.Id ~= data.Id then
		self:Begin(data)
	end
	self.Data = data
	if self.Hud and data.Hearts then
		-- RoundEnd reaches us before the interpolated shatter plays; don't spoil it by popping a heart early.
		if data.Phase == "RoundEnd" and not self.ShatterShown then
			self.PendingHearts, self.PendingAt = data.Hearts, os.clock()
		else
			self.Hud.Hearts = data.Hearts
		end
	end
	self.Phase = data.Phase
	if data.Phase ~= "Aiming" then
		self.Scene:HideGhost()
		self.Drag = nil
	end
	if data.Snapshot then
		self:Snapshot(data.Snapshot)
	end
	if self.Hud then
		self.Hud:Phase(data.Phase, if data.Phase == "Aiming" and self.Participant then "PULL BACK" else "")
	end
end

function Controller:Snapshot(snapshot)
	if not self.Data or snapshot.Id and snapshot.Id ~= self.Data.Id then
		return
	end
	snapshot.SentAt = snapshot.SentAt or workspace:GetServerTimeNow()
	local received = os.clock()
	if self.LastSnapshotWall and received - self.LastSnapshotWall > 1 then
		self.RenderTime = math.max(0, snapshot.T - Feel.InterpolationDelay)
		self.Events = {}
	end
	self.LastSnapshotWall = received
	local buffer = self.Snapshots
	local inserted = false
	for i, old in buffer do
		if math.abs(old.T - snapshot.T) < 0.00001 then
			buffer[i] = snapshot
			inserted = true
			break
		end
		if old.T > snapshot.T then
			table.insert(buffer, i, snapshot)
			inserted = true
			break
		end
	end
	if not inserted then
		table.insert(buffer, snapshot)
	end
	while #buffer > Feel.SnapshotBuffer do
		table.remove(buffer, 1)
	end
end

function Controller:Lock()
	if not self.Participant or self.Phase ~= "Aiming" or self.Locked then
		return
	end
	self.Locked = true
	self.Drag = nil
	require(script.Parent.Parent.UI.Components.StainedGlass).buttonText(self.Hud.Lock, "LOCKED")
	if Rules.isPerfect(self.Aim, self.Data.SweetSpot) then
		self.Hud:Banner(self.Side, "PERFECT!", Color3.fromHex("#FFE45C"))
		self.Scene.Fighters[self.Side].Glints:Emit(20)
	end
	Remotes.SetAim:FireServer(self.Aim, self.Yaw)
end

function Controller:Queue(packet)
	if not self.Data or packet.Id ~= self.Data.Id then
		return
	end
	packet.Snapshot.SentAt = packet.SentAt
	self:Snapshot(packet.Snapshot)
	for _, e in packet.Events do
		if e.Type == "Shatter" then
			self.FinalTime = e.Time
			self.FinalSide = e.Side
		end
		table.insert(self.Events, e)
	end
end

-- The final blow holds the frame for a beat (CombatFeel.KO) before the shatter and finisher play.
function Controller:HoldKO(e)
	if e.KOHeld or not self.Feel then
		return false
	end
	e.KOHeld = true
	local hold = self.Feel:KO(e, os.clock())
	if hold <= 0 then
		return false
	end
	self.KOQueue = self.KOQueue or {}
	table.insert(self.KOQueue, { Event = e, At = os.clock() + hold })
	return true
end

function Controller:Event(e)
	if e.Type == "Shatter" and self:HoldKO(e) then
		return
	end
	if self.Hud then
		self.Hud.Gui:SetAttribute("LastEvent", e.Type)
		self.Hud.Gui:SetAttribute("Last" .. e.Type, e.Time)
		if e.Type == "Power" then
			self.Hud.Gui:SetAttribute("PowerMissed", e.Missed == true)
		end
		if e.Type == "Hit" then
			self.Hud.Gui:SetAttribute("HitSpeed", e.Speed)
		end
	end
	self.Scene:Event(e, self.Hud)
	local now = os.clock()
	local feel = self.Feel
	if e.Type == "Hit" then
		feel:Hit(e, now)
	elseif e.Type == "PerfectRelease" then
		feel:Perfect(e, now)
	elseif e.Type == "CastContact" then
		if e.Missed then
			feel:PowerMiss(e.Side)
		elseif e.Blocked then
			feel:Block(e.Target or (e.Side and 3 - e.Side), now)
		else
			feel:PowerLand(e.Target or (e.Side and 3 - e.Side), now)
		end
	elseif e.Type == "SignatureContact" then
		feel:PowerLand(e.Target or (e.Side and 3 - e.Side), now)
	elseif e.Type == "SignatureBlock" then
		feel:Block(e.Side, now)
	elseif e.Type == "Power" then
		if e.Missed then
			feel:PowerMiss(e.Side)
		elseif e.Id == "beam" or e.Id == "freeze" then
			feel:PowerLand(e.Side and 3 - e.Side, now)
		end
	elseif
		e.Type == "SignatureReady"
		or e.Type == "ReadyCancel"
		or e.Type == "CastStart"
		or e.Type == "SignatureArmed"
	then
		feel:Cast(e, now)
	elseif e.Type == "Shatter" then
		self.Phase = "RoundEnd"
		self.FinisherCameraFrom = self.CameraPose
		if self.Orbit then
			self.Orbit.Yaw, self.Orbit.Target = 0, 0
		end
		self.Scene:StartFinisher(e.Side, now)
		-- Round-win beat on the survivor as it rises (the finisher shatters it before ShowRoundResult).
		feel:Victory(3 - e.Side, now)
		if self.Viewing then
			-- A double KO can emit two Shatters; keep one owned flash for cleanup.
			self.Post = self.Post or Instance.new("ColorCorrectionEffect")
			self.Post.Name = "FightShatterFlash"
			self.Post.Brightness = 0.5
			self.Post.Parent = Lighting
			TweenService:Create(self.Post, TweenInfo.new(0.2), { Brightness = 0 }):Play()
		end
	end
end

function Controller:ShowRoundResult()
	if self.ShatterShown then
		return
	end
	self.ShatterShown = true
	if self.Hud and self.PendingHearts then
		self.Hud.Hearts = self.PendingHearts
	end
	self.PendingHearts = nil
	local winner = self.FinalSide and self.Scene and self.Scene.Fighters[3 - self.FinalSide]
	if winner and not winner.Broken then
		winner.Glints:Emit(Feel.VictoryGlints)
	end
	if self.Participant and self.MatchController and self.Data then
		self.MatchController:ShatterShown(self.Data.Id)
	end
end

-- The server stops simulating at the shatter. Let the survivor swing down to rest locally instead of
-- freezing mid-air for the whole round-end beat.
function Controller:Settle(latest, dt)
	if not self.Settling then
		self.Settling = {}
		for side = 1, 2 do
			local b = latest.B[side]
			self.Settling[side] =
				{ P = vec(b, 1), V = vec(b, 4), Twist = b[7], Spin = b[8], Tilt = Vector3.new(b[9], 0, b[10]) }
		end
	end
	dt = math.min(dt, 1 / 20)
	local gravity = Vector3.new(0, -M.Gravity, 0)
	local decay = math.exp(-Feel.SettleDamping * dt)
	for side, s in self.Settling do
		local dir = s.P.Unit
		local v = s.V + (gravity - dir * gravity:Dot(dir)) * dt
		v = (v - dir * v:Dot(dir)) * decay
		s.P, s.V = (s.P + v * dt).Unit * M.StringLength, v
		s.Spin *= decay
		s.Twist = s.Twist * math.exp(-M.TwistStiffness * 0.5 * dt) + s.Spin * dt
		s.Tilt *= math.exp(-M.TumbleDamping * dt)
		self.Scene:Pose(side, s.P, s.Twist, s.Tilt)
	end
end

-- Fights out of snapshot range get no motion. Rather than freeze mid-swing, show a cheap distant clash
-- that reads as "a fight is on" from the path, and hide the loser once the server says who won.
function Controller:FarIdle()
	if not self.Scene then
		return
	end
	local t = os.clock() * Feel.FarSwingSpeed + (self.Data.ArenaId or 0)
	if self.Phase == "Fighting" then
		local theta = Feel.FarSwingCenter + Feel.FarSwingAngle * math.sin(t)
		for side = 1, 2 do
			local toward = if side == 1 then 1 else -1
			local p = Vector3.new(toward * math.sin(theta), -math.cos(theta), 0.12 * math.sin(t * 0.7 + side))
			self.Scene:Pose(side, p * M.StringLength, 0, Vector3.zero)
		end
	elseif self.Phase == "RoundEnd" and self.Data.RoundWinner then
		local loser = 3 - self.Data.RoundWinner
		if not self.Scene.Fighters[loser].Broken then
			self.Scene:HideBroken(loser)
		end
		local p = Vector3.new(0.05 * math.sin(t), -1, 0) * M.StringLength
		self.Scene:Pose(self.Data.RoundWinner, p, 0, Vector3.zero)
	end
end

function Controller:Render(dt)
	if not self.Data then
		return
	end
	if
		self.PendingHearts
		and not self.Scene.Finisher
		and os.clock() - self.PendingAt > Feel.FinisherFallbackSeconds
	then
		-- Late/missing final event: hide the dead glass and still release the authoritative hearts.
		if self.Data.RoundWinner then
			self.Scene:HideBroken(3 - self.Data.RoundWinner)
		end
		self:ShowRoundResult()
	end
	local newest = self.Snapshots[#self.Snapshots]
	if not self.Viewing and newest and workspace:GetServerTimeNow() - newest.SentAt > 1 and #self.Events == 0 then
		self:FarIdle()
		return
	end
	local time, now = workspace:GetServerTimeNow(), os.clock()
	local data = self.Data
	if self.Feel then
		self.Feel:Step(dt, now)
	end
	if self.Phase == "Aiming" or self.Phase == "Countdown" then
		for side, setup in { data.A, data.B } do
			local aim = if side == self.Side
					and self.Participant
					and self.Phase == "Aiming"
				then self.Aim
				else setup.Aim or M.AimDefault
			local yaw = if side == self.Side
					and self.Participant
					and self.Phase == "Aiming"
				then self.Yaw
				else setup.AimYaw or 0
			if side ~= self.Side and self.Phase == "Aiming" then
				aim, yaw = M.AimMin, 0
			end
			self.Scene:Pose(side, pull(aim, yaw, side), 0, Vector3.zero)
		end
		if self.Hud then
			if self.Phase == "Aiming" then
				if self.Participant then
					self.Hud:Aim(self.Aim, self.Yaw, Rules.isPerfect(self.Aim, data.SweetSpot))
					self.Scene:GhostPath(self.Aim, self.Yaw, self.Side)
				end
			else
				local n = math.max(1, math.ceil((data.ReleaseAt or time) - time))
				self.Hud.Headline.Text = tostring(n)
				if self.LastCountdown ~= n then
					-- A rising tick per count builds the tension before release.
					self.LastCountdown = n
					self.Hud:Beat()
					self.Scene:Sound(
						Audio.Clink,
						(self.Scene.Fighters[self.Side] or self.Scene.Fighters[1]).Body,
						1.9 + (3 - n) * 0.18,
						0.22
					)
				end
			end
		end
	elseif #self.Snapshots > 0 then
		local buffer = self.Snapshots
		local latest = buffer[#buffer]
		local target =
			math.max(0, latest.T + math.min(time - latest.SentAt, 1 / Feel.SnapshotRate) - Feel.InterpolationDelay)
		if not self.Viewing and time - latest.SentAt > 1 then
			-- Finish the final reliable event before a distant arena goes static.
			target = latest.T
		end
		if self.FinalTime then
			target = math.min(self.FinalTime, target + Feel.InterpolationDelay)
		end
		-- Hitstop holds the render clock, then it catches up smoothly (never a jump; see CombatFeel:Rate).
		local rate = self.Feel:Rate(now, target - self.RenderTime)
		if self.FinalTime and self.RenderTime >= self.FinalTime - Feel.InterpolationDelay then
			if not self.SlowUntil then
				self.SlowUntil = now + Feel.SlowMotionSeconds
			end
			if now < self.SlowUntil then
				rate = Feel.SlowMotionRate
			end
		end
		self.RenderTime = math.min(target, self.RenderTime + dt * rate)
		local left, right = buffer[1], latest
		for i = 1, #buffer - 1 do
			if buffer[i].T <= self.RenderTime and buffer[i + 1].T >= self.RenderTime then
				left, right = buffer[i], buffer[i + 1]
				break
			end
		end
		if self.RenderTime >= latest.T then
			left = latest
		end
		local duration = right.T - left.T
		local alpha = if duration > 0 then math.clamp((self.RenderTime - left.T) / duration, 0, 1) else 0
		for side = 1, 2 do
			local a, b = left.B[side], right.B[side]
			local p = if duration > 0 then hermite(a, b, alpha, duration) else vec(a, 1)
			p = p.Unit * M.StringLength
			self.Scene:Pose(
				side,
				p,
				a[7] + (b[7] - a[7]) * alpha,
				Vector3.new(a[9] + (b[9] - a[9]) * alpha, 0, a[10] + (b[10] - a[10]) * alpha)
			)
		end
		local r = {
			Hp = {},
			Power = {},
			Frozen = left.R.Frozen,
			Shield = left.R.Shield,
			Rage = left.R.Rage,
			Pump = left.R.Pump,
			Slam = left.R.Slam,
			Effect = left.R.Effect,
		}
		for side = 1, 2 do
			r.Hp[side] = left.R.Hp[side] + (right.R.Hp[side] - left.R.Hp[side]) * alpha
			r.Power[side] = left.R.Power[side] + (right.R.Power[side] - left.R.Power[side]) * alpha
		end
		if self.FinalTime and self.ShatterShown and self.RenderTime >= self.FinalTime - 0.0001 then
			self:Settle(latest, dt * rate)
		end
		self.Scene:Update(r, self.RenderTime)
		self.Feel:Update(r, now)
		if self.Hud then
			self.Hud:Update(r)
		end
		local pending = {}
		for _, e in self.Events do
			if e.Time <= self.RenderTime + 0.0001 then
				self:Event(e)
			else
				table.insert(pending, e)
			end
		end
		self.Events = pending
		local held = {}
		for _, item in self.KOQueue or {} do
			if now >= item.At then
				self:Event(item.Event)
			else
				table.insert(held, item)
			end
		end
		self.KOQueue = held
		if self.Hud and self.Phase == "Fighting" and self.RenderTime < 0.8 then
			if self.Hud.Headline.Text ~= "LET GO!" then
				self.Hud:Beat()
				self.Scene:Sound(
					Audio.Whoosh,
					(self.Scene.Fighters[self.Side] or self.Scene.Fighters[1]).Body,
					0.85,
					0.32,
					0.5
				)
			end
			self.Hud.Headline.Text = "LET GO!"
		elseif self.Hud and self.Phase == "Fighting" and self.Hud.Headline.Text == "LET GO!" then
			self.Hud.Headline.Text = ""
		end
	end
	if self.Scene.Finisher and self.Scene.Finisher:Step(now) then
		self:ShowRoundResult()
	end
	if self.Viewing then
		self:Camera(dt, now)
	end
end

function Controller:Camera(dt, now)
	local camera = workspace.CurrentCamera
	if camera.CameraType ~= Enum.CameraType.Scriptable then
		camera.CameraType = Enum.CameraType.Scriptable
	end
	local center = self.Scene.Frame.Position - Vector3.yAxis * (M.StringLength + M.BodyCenter * M.GlassyScale)
	local action = (self.Scene.Fighters[1].Body.Position + self.Scene.Fighters[2].Body.Position) / 2
	local focus = center:Lerp(action, Feel.CameraFollow) + Vector3.yAxis * Feel.CameraFocusHeight
	self.Focus = self.Focus and self.Focus:Lerp(focus, 1 - math.exp(-dt * Feel.CameraSmooth)) or focus
	local aspect = camera.ViewportSize.X / math.max(1, camera.ViewportSize.Y)
	local scale = math.max(1, Feel.CameraMinimumAspect / aspect)
	local offset = self.Scene.Frame:VectorToWorldSpace(
		Vector3.new(Feel.CameraSide, Feel.CameraHeight, Feel.CameraDistance * (self.Data.CameraFacing or 1))
	) * scale
	local yaw = if self.Orbit then self.Orbit:Step(dt) else 0
	local normal = CFrame.lookAt(self.Focus + offset, self.Focus)
	offset = CFrame.fromAxisAngle(Vector3.yAxis, yaw):VectorToWorldSpace(offset)
	local target = CFrame.lookAt(self.Focus + offset, self.Focus)
	if self.Scene.Finisher then
		self.Scene.CameraFocus = self.Focus
		target = FinisherCamera.pose(self.Scene.Finisher, normal, self.FinisherCameraFrom or normal, now)
	end
	self.CameraPose = target
	-- Kick, shake and FOV punch sit on top of the orbit/finisher pose; the pose itself is never changed.
	local offset, fov = CFrame.identity, 0
	if self.Feel then
		offset, fov = self.Feel:Camera(now)
	end
	camera.CFrame = self.CameraPose * offset
	camera.FieldOfView = Feel.CameraFieldOfView + fov
	for gui in self.HiddenGuis or {} do
		if gui.Parent then
			gui.Enabled = false
		end
	end
	-- Fade only supports that actually occlude a glassy, and restore them when the shot clears.
	self.FadedLegs = self.FadedLegs or {}
	local stand = self.Scene:GetStand()
	for _, leg in stand and stand:GetChildren() or {} do
		if leg:IsA("BasePart") and leg.Name:find("Leg") then
			local blocked = false
			for _, fighter in self.Scene.Fighters do
				if crossesBox(leg, camera.CFrame.Position, fighter.Body.Position) then
					blocked = true
				end
			end
			if self.Hidden[leg] == nil then
				self.Hidden[leg] = leg.LocalTransparencyModifier
			end
			leg.LocalTransparencyModifier = if blocked then Feel.OccludedLegTransparency else self.Hidden[leg]
		end
	end
end

return Controller
