-- Manually launched, disposable Studio-only continuous-loop playtest. Never required by Main or a controller.
local Lab = {}
function Lab.start()
	assert(game:GetService("RunService"):IsStudio(), "Loop Lab is private to Studio")
	if Lab.Stop then
		Lab.Stop()
	end
	local RS, Players = game:GetService("ReplicatedStorage"), game:GetService("Players")
	local player, camera = Players.LocalPlayer, workspace.CurrentCamera
	local C, B = require(RS.Shared.Config.LoopLab), require(RS.Shared.Config.Balance)
	local G, Formula = require(RS.Shared.Config.Glassies), require(RS.Shared.Formula)
	local client = player.PlayerScripts.Client
	local Kit = require(client.UI.Components.MatchKit)
	local Theme = require(client.UI.Theme)
	local Item = require(client.UI.Components.ItemPresentation)
	local Scene = require(client.Presentation.FightScene)
	local Shatter = setmetatable({}, { __index = require(client.Controllers.ShatterController) })
	Shatter:Init()
	local remote = RS:WaitForChild("LoopLabRuntime"):WaitForChild("Action")
	local gui = Kit.gui("LoopLab", 100)
	local feedback = require(script.Parent.LoopLabFeedback).new(gui)
	local Playback = require(script.Parent.LoopLabPlayback)
	local playback
	local saved =
		{ Type = camera.CameraType, Subject = camera.CameraSubject, Fov = camera.FieldOfView, Frame = camera.CFrame }
	local connections, hidden = {}, {}
	local hiddenEffects = {}
	local mode, selected, packet, scene, seed = "B", C.Roster[1], nil, nil, nil
	local aim, yaw, drag = B.Motion.AimDefault, 0, nil
	local origin = player.Character:GetPivot().Position + Vector3.new(0, 160, 0)
	local frame = CFrame.new(origin)
	local title = Kit.label(gui, "Title", "PRIVATE LOOP LAB", UDim2.fromScale(0.6, 0.07), UDim2.fromScale(0.2, 0.12))
	local status = Kit.label(gui, "Status", "Choose a glassy", UDim2.fromScale(0.8, 0.06), UDim2.fromScale(0.1, 0.67))
	local hp = Kit.label(gui, "Health", "", UDim2.fromScale(0.8, 0.06), UDim2.fromScale(0.1, 0.22))
	local roles = Kit.label(
		gui,
		"Roles",
		"",
		UDim2.fromScale(0.9, 0.05),
		UDim2.fromScale(0.05, 0.285),
		{ Font = Theme.Fonts.Body, Small = true, MaxSize = 16 }
	)
	local note = Kit.label(
		gui,
		"Private",
		"STUDIO TEST - NO COINS OR PROGRESS SAVED",
		UDim2.fromScale(0.9, 0.04),
		UDim2.fromScale(0.05, 0.94),
		{ Font = Theme.Fonts.Body, Small = true, MaxSize = 14 }
	)
	local choose = Kit.frame(gui, "Choose", UDim2.fromScale(0.84, 0.4), UDim2.fromScale(0.08, 0.28))
	local shoot = Kit.gem(gui, "Release", "RELEASE", "emerald", UDim2.fromScale(0.28, 0.12), UDim2.fromScale(0.5, 0.84))
	shoot.Visible = false
	local function connect(signal, callback)
		table.insert(connections, signal:Connect(callback))
	end
	local function buttonInput(button, callback)
		local hit = Instance.new("TextButton")
		hit.Name, hit.Text, hit.BackgroundTransparency = "HitArea", "", 1
		hit.AnchorPoint, hit.Position, hit.Size =
			Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), UDim2.fromScale(1, 1)
		hit.ZIndex, hit.Parent = button.ZIndex + 10, button
		local minimum = Instance.new("UISizeConstraint")
		minimum.MinSize, minimum.Parent = Vector2.new(44, 44), hit
		connect(hit.Activated, callback)
	end
	local function resetScene()
		feedback:Reset()
		if scene then
			scene:Destroy()
			scene = nil
		end
		seed, packet = nil, nil
		playback = nil
	end
	local function menu(nextMode)
		remote:FireServer("Stop")
		resetScene()
		mode = nextMode
		choose.Visible, shoot.Visible = true, false
		title.Text = "CONTINUOUS GLASS DUELS"
		status.Text, hp.Text = "Choose a glassy", ""
	end
	for i, id in C.Roster do
		local x, y = (i - 1) % 3 / 3, math.floor((i - 1) / 3) / 2
		local slot = Kit.frame(choose, id, UDim2.fromScale(0.31, 0.47), UDim2.fromScale(x, y))
		Item.portrait(slot, "Glassies", id, UDim2.fromScale(0.34, 0.7), UDim2.fromScale(0.02, 0.04), "Portrait")
		local button =
			Kit.gem(slot, "Pick", G.get(id).Name, "aqua", UDim2.fromScale(0.66, 0.62), UDim2.fromScale(0.65, 0.37))
		Kit.label(
			slot,
			"Role",
			C.Roles[id],
			UDim2.fromScale(0.94, 0.2),
			UDim2.fromScale(0.03, 0.76),
			{ Font = Theme.Fonts.Body, Small = true, MaxSize = 14 }
		)
		buttonInput(button, function()
			selected = id
			remote:FireServer("Start", mode, id)
		end)
	end
	local nextChoice = Kit.frame(gui, "NextChoice", UDim2.fromScale(0.86, 0.1), UDim2.fromScale(0.07, 0.80))
	nextChoice.Visible = false
	local short = { "Pop", "Jam", "Prism", "Cup", "Jug", "Ketchup" }
	local choiceButtons, highlighted = {}, nil
	for i, id in C.Roster do
		local button =
			Kit.gem(nextChoice, id, short[i], "sapphire", UDim2.fromScale(0.15, 1), UDim2.fromScale((i - 0.5) / 6, 0.5))
		choiceButtons[id] = button
		buttonInput(button, function()
			remote:FireServer("Switch", "B", id)
		end)
	end
	local exit = Kit.gem(gui, "Exit", "EXIT LAB", "ruby", UDim2.fromScale(0.21, 0.09), UDim2.new(0.87, 0, 0.055, 22))
	local function release()
		if packet and packet.Phase == "Aim" then
			remote:FireServer("Launch", aim, yaw)
		end
	end
	buttonInput(shoot, release)
	connect(remote.OnClientEvent, function(data)
		if data.Seed ~= seed then
			resetScene()
			seed = data.Seed
			playback = Playback.new(B.Feel.InterpolationDelay, C.SnapshotSeconds, B.Feel.SnapshotBuffer)
			local maxima = {
				Formula.stats(G.get(data.Id), {}).HP * C.HpScale,
				Formula.stats(G.get(data.Rival), {}).HP * C.HpScale,
			}
			scene = Scene.new({
				Id = "LoopLab",
				Frame = frame,
				A = { Id = data.Id },
				B = { Id = data.Rival },
				HookPositions = {
					frame:PointToWorldSpace(Vector3.new(-data.HookGap / 2, 0, 0)),
					frame:PointToWorldSpace(Vector3.new(data.HookGap / 2, 0, 0)),
				},
			}, maxima, Shatter)
			scene.OwnFight = true
			scene:SetViewing(true)
			scene:Tag(1, "YOU", Theme.Sides[1])
			local bar = Instance.new("Part")
			bar.Name, bar.Anchored, bar.CanCollide = "LabCrossbar", true, false
			bar.Size, bar.CFrame = Vector3.new(20, 0.6, 0.6), frame
			bar.Material, bar.Color, bar.Parent = Enum.Material.Wood, Color3.fromRGB(150, 99, 53), scene.Root
			local backdrop = Instance.new("Part")
			backdrop.Name, backdrop.Anchored, backdrop.CanCollide = "LabBackdrop", true, false
			backdrop.Size, backdrop.CFrame = Vector3.new(36, 22, 0.2), frame * CFrame.new(0, -7, -5)
			backdrop.Color, backdrop.Material, backdrop.Parent =
				Color3.fromRGB(30, 42, 58), Enum.Material.SmoothPlastic, scene.Root
		end
		packet = data
		playback:push(data.Snapshot, data.Events, os.clock(), data.Phase == "Result")
		gui:SetAttribute("LabGlassy", data.Id)
		gui:SetAttribute("LabSeed", data.Seed)
		gui:SetAttribute("LabPhase", data.Phase)
		roles.Text = "YOU: " .. C.Roles[data.Id] .. "     RIVAL: " .. C.Roles[data.Rival]
		local nextId = data.NextId or data.Id
		if highlighted ~= nextId then
			highlighted = nextId
			for id, button in choiceButtons do
				require(client.UI.Components.StainedGlass).setAsset(
					button.Artwork,
					if id == nextId then "button/gem_emerald" else "button/gem_sapphire"
				)
			end
		end
		note.Text = if data.Phase == "Aim"
			then "ONE LAUNCH - THEN CONTINUOUS PLAY"
			elseif data.NextId then "NEXT GLASS: " .. string.upper(G.get(data.NextId).Name)
			else "SWITCH YOUR NEXT GLASS BELOW - NO PROGRESS SAVED"
		choose.Visible = false
		nextChoice.Visible = data.Phase ~= "Aim"
		shoot.Visible = data.Phase == "Aim"
		require(client.UI.Components.StainedGlass).buttonText(shoot, "RELEASE")
	end)
	local UIS = game:GetService("UserInputService")
	connect(UIS.InputBegan, function(input, processed)
		if not packet or packet.Phase ~= "Aim" then
			return
		end
		if input.KeyCode == Enum.KeyCode.Space then
			release()
		elseif
			not processed
			and (
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			)
		then
			drag = { Input = input, Origin = Vector2.new(input.Position.X, input.Position.Y), Distance = 0 }
		end
	end)
	connect(UIS.InputChanged, function(input)
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
			aim = math.clamp(
				B.Motion.AimMin + delta.Magnitude / B.Feel.AimDragPixels * (B.Motion.AimMax - B.Motion.AimMin),
				B.Motion.AimMin,
				B.Motion.AimMax
			)
			yaw =
				math.clamp(delta.X / B.Feel.AimYawPixels * B.Motion.AimYawMax, -B.Motion.AimYawMax, B.Motion.AimYawMax)
		end
	end)
	connect(UIS.InputEnded, function(input)
		if drag and input == drag.Input then
			local distance = drag.Distance
			drag = nil
			if distance >= B.Feel.AimReleasePixels then
				release()
			end
		end
	end)
	connect(UIS.WindowFocusReleased, function()
		drag = nil
	end)
	local gate = require(client.UI.TouchGate)
	local owner = {}
	gate.acquire(owner)
	local CAS = game:GetService("ContextActionService")
	CAS:BindActionAtPriority(
		"LoopLabMovement",
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
	connect(game:GetService("RunService").RenderStepped, function()
		for _, effect in game.Lighting:GetChildren() do
			if effect:IsA("BlurEffect") or effect:IsA("DepthOfFieldEffect") then
				if hiddenEffects[effect] == nil then
					hiddenEffects[effect] = effect.Enabled
				end
				effect.Enabled = false
			end
		end
		for _, g in player.PlayerGui:GetChildren() do
			if g:IsA("ScreenGui") and g ~= gui then
				if hidden[g] == nil then
					hidden[g] = g.Enabled
				end
				g.Enabled = false
			end
		end
		camera.CameraType, camera.FieldOfView = Enum.CameraType.Scriptable, B.Feel.CameraFieldOfView
		local focus = origin + Vector3.new(0, -6, 0)
		camera.CFrame = CFrame.lookAt(focus + Vector3.new(0, 0, 25), focus)
		if not scene or not packet then
			return
		end
		local snapshot, events = playback:sample(os.clock())
		for side, b in snapshot.B do
			local p = Vector3.new(b[1], b[2], b[3])
			if p.Magnitude > 0 then
				p = p.Unit * B.Motion.StringLength
			end
			if packet.Phase == "Aim" then
				local a, y = if side == 1 then aim else B.Motion.AimDefault, if side == 1 then yaw else 0
				p = Vector3.new(
					(if side == 1 then -1 else 1) * math.sin(a) * math.cos(y),
					-math.cos(a),
					math.sin(a) * math.sin(y)
				) * B.Motion.StringLength
			end
			scene:Pose(side, p, b[7], Vector3.new(b[9], 0, b[10]))
		end
		for _, e in events do
			scene:Event(e, feedback)
		end
		scene:Update(snapshot.R, snapshot.T)
		local h = snapshot.R.Hp
		hp.Text = string.format(
			"%s %d HP     %s %d HP",
			string.upper(G.get(packet.Id).Name),
			math.ceil(h[1]),
			string.upper(G.get(packet.Rival).Name),
			math.ceil(h[2])
		)
		status.Text = if packet.Phase == "Aim"
			then string.format(
				"PULL & RELEASE   %d%%   %ds",
				(aim - B.Motion.AimMin) / (B.Motion.AimMax - B.Motion.AimMin) * 100,
				math.max(0, math.ceil(packet.Deadline - workspace:GetServerTimeNow()))
			)
			elseif packet.Phase == "Result" then (if packet.Winner == 1 then "YOU WIN" else "RIVAL WINS")
				.. " - NEXT DUEL..."
			elseif packet.Phase == "Recover" then packet.LastShot or "CLASH"
			else ""
	end)
	function Lab.Stop()
		remote:FireServer("Stop")
		for _, c in connections do
			c:Disconnect()
		end
		resetScene()
		gui:Destroy()
		CAS:UnbindAction("LoopLabMovement")
		gate.release(owner)
		for g, enabled in hidden do
			if g.Parent then
				g.Enabled = enabled
			end
		end
		for effect, enabled in hiddenEffects do
			if effect.Parent then
				effect.Enabled = enabled
			end
		end
		camera.CameraType, camera.CameraSubject, camera.FieldOfView, camera.CFrame =
			saved.Type, saved.Subject, saved.Fov, saved.Frame
		Lab.Stop = nil
	end
	buttonInput(exit, function()
		Lab.Stop()
	end)
	connect(player.CharacterRemoving, function()
		if Lab.Stop then
			Lab.Stop()
		end
	end)
	menu("B")
	return "Loop Lab client ready"
end
return Lab
