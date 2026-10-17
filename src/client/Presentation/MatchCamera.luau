-- Steady arena-middle camera for the time a player is queued or choosing glassies.
-- It uses the fight camera's resting pose, so the hand-off to the fight view is seamless: the fight view calls
-- handoff() to take over the saved normal-camera state, and stop() gives the normal camera back.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local Balance = require(RS.Shared.Config.Balance)
local M, Feel = Balance.Motion, Balance.Feel
local MatchCamera = {}

local state = nil -- { Frame, Facing, Saved, Connection, Blend }
local hidden = {} -- arena boards switched off while choosing glassies

-- The world boards sit right where the selection title goes; hide them during selection and give them back after.
local function showBoards()
	for gui in hidden do
		if gui.Parent then
			local active = gui:GetAttribute("ArenaActive")
			gui.Enabled = if active ~= nil then active else true
		end
	end
	table.clear(hidden)
end
local function hideBoards()
	local lobby = workspace:FindFirstChild("Lobby")
	local arenas = lobby and lobby:FindFirstChild("Arenas")
	for _, gui in if arenas then arenas:GetDescendants() else {} do
		if gui:IsA("BillboardGui") and gui.Name == "ArenaStatus" and gui.Enabled then
			hidden[gui] = true
			gui.Enabled = false
		end
	end
end

local function find(tag, id)
	for _, object in CollectionService:GetTagged(tag) do
		if object:GetAttribute("ArenaId") == id then
			return object
		end
	end
	return nil
end

-- Same frame the server builds in FightService:Geometry, so side/facing match the fight camera exactly.
local function arenaFrame(id)
	local stand = find("ArenaStand", id)
	local bar = stand and stand:FindFirstChild("Crossbar")
	local hookA, hookB = bar and bar:FindFirstChild("HookA"), bar and bar:FindFirstChild("HookB")
	if not hookA or not hookB then
		return nil
	end
	local firstPad
	for _, pad in CollectionService:GetTagged("QueuePad") do
		if pad:GetAttribute("ArenaId") == id and pad:GetAttribute("Side") == "A" then
			firstPad = pad
		end
	end
	local a, b = hookA.WorldPosition, hookB.WorldPosition
	if firstPad and (b - firstPad.Position).Magnitude < (a - firstPad.Position).Magnitude then
		a, b = b, a
	end
	local x = Vector3.new(b.X - a.X, 0, b.Z - a.Z).Unit
	local frame = CFrame.fromMatrix((a + b) / 2, x, Vector3.yAxis, x:Cross(Vector3.yAxis))
	local lobby = workspace:FindFirstChild("Lobby")
	local spawn = lobby and lobby:FindFirstChild("SpawnLocation")
	local inward = if spawn then spawn.Position - frame.Position else frame.ZVector
	return frame, if inward:Dot(frame.ZVector) >= 0 then 1 else -1
end

local function pose(camera)
	local frame, facing = state.Frame, state.Facing
	local center = frame.Position - Vector3.yAxis * (M.StringLength + M.BodyCenter * M.GlassyScale)
	local focus = center + Vector3.yAxis * Feel.CameraFocusHeight
	local aspect = camera.ViewportSize.X / math.max(1, camera.ViewportSize.Y)
	local scale = math.max(1, Feel.CameraMinimumAspect / aspect)
	local offset = frame:VectorToWorldSpace(
		Vector3.new(Feel.CameraSide, Feel.CameraHeight, Feel.CameraDistance * facing)
	) * scale
	return CFrame.lookAt(focus + offset, focus)
end

function MatchCamera.active()
	return state ~= nil
end

-- Moves the camera to the arena middle (smoothly) and keeps it there. Safe to call again while held.
function MatchCamera.start(arenaId, hideArenaBoards)
	if hideArenaBoards then
		hideBoards()
	end
	if state or type(arenaId) ~= "number" then
		return state ~= nil
	end
	local frame, facing = arenaFrame(arenaId)
	local camera = workspace.CurrentCamera
	if not frame or not camera then
		return false
	end
	state = {
		Frame = frame,
		Facing = facing,
		Saved = { Type = camera.CameraType, Subject = camera.CameraSubject, FOV = camera.FieldOfView },
		From = camera.CFrame,
		FromFov = camera.FieldOfView,
		Blend = 0,
	}
	camera.CameraType = Enum.CameraType.Scriptable
	state.Connection = RunService.RenderStepped:Connect(function(dt)
		local current = workspace.CurrentCamera
		if not current then
			return
		end
		if current.CameraType ~= Enum.CameraType.Scriptable then
			current.CameraType = Enum.CameraType.Scriptable
		end
		state.Blend = math.min(1, state.Blend + dt / 0.55)
		local t = 1 - (1 - state.Blend) ^ 3
		current.CFrame = state.From:Lerp(pose(current), t)
		if state.Blend < 1 or not state.FovDone then
			-- Only drive the FOV during the blend, so a menu's own FOV nudge is never fought afterwards.
			current.FieldOfView = state.FromFov + (Feel.CameraFieldOfView - state.FromFov) * t
			state.FovDone = state.Blend >= 1
		end
	end)
	return true
end

-- The fight view takes the camera over: returns the saved normal-camera state and stops our loop without
-- restoring, so the shot never flickers back to the follow camera in between.
function MatchCamera.handoff()
	if not state then
		return nil
	end
	local saved = state.Saved
	state.Connection:Disconnect()
	state = nil
	showBoards()
	return saved
end

-- Gives the normal follow camera back (leaving the queue, match end, character removed).
function MatchCamera.stop()
	showBoards()
	local saved = MatchCamera.handoff()
	local camera = workspace.CurrentCamera
	if not saved or not camera then
		return
	end
	local humanoid = game:GetService("Players").LocalPlayer.Character
		and game:GetService("Players").LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
	local keep = saved.Type ~= Enum.CameraType.Scriptable
	camera.CameraType = if keep then saved.Type else Enum.CameraType.Custom
	camera.CameraSubject = if keep then saved.Subject else (humanoid or saved.Subject)
	camera.FieldOfView = if keep then saved.FOV else 70
end

return MatchCamera
