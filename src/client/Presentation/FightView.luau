local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
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
	self.Snapshots, self.Events = {}, {}
	local playerModule = self.Player:WaitForChild("PlayerScripts"):FindFirstChild("PlayerModule")
	self.Controls = playerModule and require(playerModule):GetControls()
end

function Controller:EndFight()
	if self.Viewing then
		CAS:UnbindAction("FightMovement")
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
	if self.Scene then
		self.Scene:Destroy()
		self.Scene = nil
	end
	if self.Hud then
		self.Hud:Destroy()
		self.Hud = nil
	end
	if self.OldCamera then
		local camera = workspace.CurrentCamera
		camera.CameraType, camera.CameraSubject, camera.FieldOfView =
			self.OldCamera.Type, self.OldCamera.Subject, self.OldCamera.FOV
		self.OldCamera = nil
		if self.Controls then
			self.Controls:Enable()
		end
		GuiService.TouchControlsEnabled = self.OldTouchControls
	end
	self.Data, self.Snapshots, self.Events, self.Drag, self.RenderTime = nil, {}, {}, nil, 0
	self.FinalTime, self.SlowUntil, self.HoldUntil, self.ShakeUntil = nil, nil, nil, nil
	self.Locked, self.Focus, self.LastCountdown = false, nil, nil
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
	self.Side = table.find(data.PlayerIds or {}, self.Player.UserId)
		or (if data.UserId == self.Player.UserId then 1 else 0)
	self.Participant = self.Side > 0
	self.Viewing = self.Participant or data.Spectate
	if self.Viewing then
		self.HiddenGuis = {}
		for _, gui in workspace.Lobby.Arenas:GetDescendants() do
			if gui:IsA("BillboardGui") and gui.Name == "ArenaStatus" then
				self.HiddenGuis[gui] = gui.Enabled
				gui.Enabled = false
			end
		end
		self.Hidden = {}
		for _, part in self.Player.Character and self.Player.Character:GetDescendants() or {} do
			if part:IsA("BasePart") then
				self.Hidden[part] = part.LocalTransparencyModifier
				part.LocalTransparencyModifier = 1
			end
		end
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
		self.Hud = Hud.new(data, maxima, function()
			self:Lock()
		end)
		if self.Controls then
			self.Controls:Disable()
		end
		self.OldTouchControls = GuiService.TouchControlsEnabled
		GuiService.TouchControlsEnabled = false
		local camera = workspace.CurrentCamera
		self.OldCamera = { Type = camera.CameraType, Subject = camera.CameraSubject, FOV = camera.FieldOfView }
		camera.CameraType, camera.FieldOfView = Enum.CameraType.Scriptable, Feel.CameraFieldOfView
		self.CameraPose = nil
	end
	if data.Snapshot then
		self:Snapshot(data.Snapshot)
		self.RenderTime = math.max(0, data.Snapshot.T - Feel.InterpolationDelay)
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
		self.Hud.Hearts = data.Hearts
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
		self.Hud:Phase(data.Phase, if data.Phase == "Aiming" then "PULL BACK" else "")
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
	self.Hud.Lock.Text = "LOCKED"
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

function Controller:Event(e)
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
	if e.Type == "Hit" then
		self.ShakeUntil = now + Feel.ShakeSeconds
		local damage =
			math.max(e.Damage[1] / self.Scene.Fighters[1].Stats.MaxHP, e.Damage[2] / self.Scene.Fighters[2].Stats.MaxHP)
		self.ShakePower = math.clamp(damage / 0.3, 0, 1) * Feel.ShakeMax
		if e.Speed >= Balance.Fight.RefSpeed * Feel.BigHitSpeed and not self.FinalTime then
			self.HoldUntil = now + Feel.HitstopSeconds
		end
	elseif e.Type == "Shatter" then
		self.Phase = "RoundEnd"
		self.ShakeUntil, self.ShakePower = now + Feel.ShakeSeconds, Feel.ShakeMax
		if self.Viewing then
			self.Post = Instance.new("ColorCorrectionEffect")
			self.Post.Name = "FightShatterFlash"
			self.Post.Brightness = 0.5
			self.Post.Parent = Lighting
			TweenService:Create(self.Post, TweenInfo.new(0.2), { Brightness = 0 }):Play()
		end
	end
end

function Controller:Render(dt)
	if not self.Data then
		return
	end
	local newest = self.Snapshots[#self.Snapshots]
	if not self.Viewing and newest and workspace:GetServerTimeNow() - newest.SentAt > 1 and #self.Events == 0 then
		return
	end
	local time, now = workspace:GetServerTimeNow(), os.clock()
	local data = self.Data
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
				self.Hud:Aim(self.Aim, self.Yaw, Rules.isPerfect(self.Aim, data.SweetSpot))
				self.Scene:GhostPath(self.Aim, self.Yaw, self.Side > 0 and self.Side or 1)
			else
				local n = math.max(1, math.ceil((data.ReleaseAt or time) - time))
				self.Hud.Headline.Text = tostring(n)
			end
		end
	elseif #self.Snapshots > 0 then
		local buffer = self.Snapshots
		local latest = buffer[#buffer]
		local target =
			math.max(0, latest.T + math.min(time - latest.SentAt, 1 / Feel.SnapshotRate) - Feel.InterpolationDelay)
		if self.FinalTime then
			target = math.min(self.FinalTime, target + Feel.InterpolationDelay)
		end
		local rate = 1.25
		if self.FinalTime and self.RenderTime >= self.FinalTime - Feel.InterpolationDelay then
			if not self.SlowUntil then
				self.SlowUntil = now + Feel.SlowMotionSeconds
			end
			if now < self.SlowUntil then
				rate = Feel.SlowMotionRate
			end
		end
		if not self.HoldUntil or now >= self.HoldUntil then
			self.RenderTime = math.min(target, self.RenderTime + dt * rate)
		end
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
		self.Scene:Update(r, self.RenderTime)
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
		if self.Hud and self.Phase == "Fighting" and self.RenderTime < 0.8 then
			self.Hud.Headline.Text = "LET GO!"
		elseif self.Hud and self.Phase == "Fighting" and self.Hud.Headline.Text == "LET GO!" then
			self.Hud.Headline.Text = ""
		end
	end
	if self.Viewing then
		self:Camera(dt, now)
	end
end

function Controller:Camera(dt, now)
	local camera = workspace.CurrentCamera
	local center = self.Data.Frame.Position - Vector3.yAxis * (M.StringLength + M.BodyCenter * M.GlassyScale)
	local action = (self.Scene.Fighters[1].Body.Position + self.Scene.Fighters[2].Body.Position) / 2
	local focus = center:Lerp(action, Feel.CameraFollow) + Vector3.yAxis * Feel.CameraFocusHeight
	self.Focus = self.Focus and self.Focus:Lerp(focus, 1 - math.exp(-dt * Feel.CameraSmooth)) or focus
	local aspect = camera.ViewportSize.X / math.max(1, camera.ViewportSize.Y)
	local scale = math.max(1, Feel.CameraMinimumAspect / aspect)
	local offset = self.Data.Frame:VectorToWorldSpace(
		Vector3.new(Feel.CameraSide, Feel.CameraHeight, Feel.CameraDistance)
	) * scale
	local final = self.FinalTime and self.RenderTime >= self.FinalTime - Feel.InterpolationDelay
	if final then
		offset = self.Data.Frame:VectorToWorldSpace(Vector3.new(0, Feel.CameraHeight * 0.35, Feel.CameraDistance * 0.8))
			* scale
	end
	local target = CFrame.lookAt(self.Focus + offset, self.Focus)
	self.CameraPose = if final or not self.CameraPose
		then target
		else self.CameraPose:Lerp(target, 1 - math.exp(-dt * Feel.CameraSmooth))
	local shake = Vector3.zero
	if self.ShakeUntil and now < self.ShakeUntil then
		local magnitude = self.ShakePower * (self.ShakeUntil - now) / Feel.ShakeSeconds
		shake = Vector3.new(math.sin(now * 93), math.cos(now * 111), 0) * magnitude
	end
	camera.CFrame = self.CameraPose * CFrame.new(shake)
	for gui in self.HiddenGuis or {} do
		if gui.Parent then
			gui.Enabled = false
		end
	end
	-- Fade only supports that actually occlude a glassy, and restore them when the shot clears.
	self.FadedLegs = self.FadedLegs or {}
	local stand = self.Scene.Fighters[1].Hook.Parent.Parent
	for _, leg in stand:GetChildren() do
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
