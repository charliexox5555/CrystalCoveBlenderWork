-- Manually launched Studio-only relaunch slice. Never required by Main or a controller.
local Gauntlet = {}

function Gauntlet.start()
	assert(game:GetService("RunService"):IsStudio(), "The Gauntlet slice is private to Studio")
	if Gauntlet.Stop then
		Gauntlet.Stop()
	end
	local RS, Players = game:GetService("ReplicatedStorage"), game:GetService("Players")
	local UIS = game:GetService("UserInputService")
	local player, camera = Players.LocalPlayer, workspace.CurrentCamera
	local G, B = require(RS.Shared.Config.Gauntlet), require(RS.Shared.Config.Balance)
	local Cracks = require(RS.Shared.Config.BuddyCracks)
	local Rules = require(RS.Shared.GauntletRules)
	local client = player.PlayerScripts.Client
	local Kit = require(client.UI.Components.MatchKit)
	local Theme = require(client.UI.Theme)
	local Glass = require(client.UI.Components.StainedGlass)
	local Scene = require(client.Presentation.FightScene)
	local Shatter = setmetatable({}, { __index = require(client.Controllers.ShatterController) })
	Shatter:Init()
	local Rig = require(script.Parent.GauntletRig)
	local Stage = require(script.Parent.GauntletStage)
	local Playback = require(script.Parent.LoopLabPlayback)
	local remote = RS:WaitForChild("GauntletRuntime"):WaitForChild("Action")
	local gui = Kit.gui("Gauntlet", 100)
	local feedback = require(script.Parent.LoopLabFeedback).new(gui)

	local saved =
		{ Type = camera.CameraType, Subject = camera.CameraSubject, Fov = camera.FieldOfView, Frame = camera.CFrame }
	local connections, hidden, hiddenEffects = {}, {}, {}
	local packet, scene, seed, playback, rigs = nil, nil, nil, nil, {}
	local settledSeed, pulledOnce = nil, false
	local aim, yaw, drag = B.Motion.AimDefault, 0, nil
	local origin = player.Character:GetPivot().Position + Vector3.new(0, 160, 0)
	local frame = CFrame.new(origin)
	local stage = Stage.new(frame, G.HookGap)

	local function connect(signal, callback)
		table.insert(connections, signal:Connect(callback))
	end

	local function panel(parent, name, size, position, anchor, color, transparency)
		local p = Kit.frame(parent, name, size, position, anchor)
		p.BackgroundTransparency, p.BackgroundColor3 = transparency or 0.15, color or Color3.fromHex("#120D24")
		local corner = Instance.new("UICorner")
		corner.CornerRadius, corner.Parent = UDim.new(0.18, 0), p
		return p
	end

	local function bar(parent, name, size, position, tint, rightAligned)
		local track = panel(parent, name, size, position, nil, Color3.fromHex("#0B0816"), 0)
		local stroke = Instance.new("UIStroke")
		stroke.Thickness, stroke.Color, stroke.Parent = 2, Color3.fromHex("#F4EFE2"), track
		local fill =
			panel(track, "Fill", UDim2.fromScale(1, 1), UDim2.fromScale(if rightAligned then 1 else 0, 0), nil, tint, 0)
		fill.AnchorPoint = Vector2.new(if rightAligned then 1 else 0, 0)
		return track, fill
	end

	local function portrait(parent, name, size, position, anchor)
		local image = Instance.new("ImageLabel")
		image.Name, image.Size, image.Position = name, size, position
		image.AnchorPoint, image.BackgroundTransparency = anchor or Vector2.zero, 1
		image.ScaleType = Enum.ScaleType.Fit
		image.Parent = parent
		return image
	end

	local function clickable(button, callback)
		local hit = Instance.new("TextButton")
		hit.Name, hit.Text, hit.BackgroundTransparency = "HitArea", "", 1
		hit.AnchorPoint, hit.Position, hit.Size =
			Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), UDim2.fromScale(1, 1)
		hit.ZIndex, hit.Parent = button.ZIndex + 10, button
		local minimum = Instance.new("UISizeConstraint")
		minimum.MinSize, minimum.Parent = Vector2.new(44, 44), hit
		connect(hit.Activated, callback)
		return hit
	end

	-- Both fighters' cards keep a fixed job: who, how much glass is left, what its power does.
	local function fighterCard(name, x, rightAligned)
		local card = Kit.frame(gui, name, UDim2.fromScale(0.34, 0.2), UDim2.fromScale(x, 0.035))
		local icon = portrait(
			card,
			"Icon",
			UDim2.fromScale(0.3, 1),
			UDim2.fromScale(if rightAligned then 1 else 0, 0),
			Vector2.new(if rightAligned then 1 else 0, 0)
		)
		local tx = if rightAligned then 0 else 0.3
		local title = Kit.label(
			card,
			"Name",
			"",
			UDim2.fromScale(0.7, 0.34),
			UDim2.fromScale(tx, 0),
			{ MaxSize = 30, XAlign = if rightAligned then Enum.TextXAlignment.Right else Enum.TextXAlignment.Left }
		)
		local track, fill =
			bar(card, "Glass", UDim2.fromScale(0.7, 0.2), UDim2.fromScale(tx, 0.36), Color3.new(1, 1, 1), rightAligned)
		local power = Kit.label(card, "Power", "", UDim2.fromScale(0.7, 0.24), UDim2.fromScale(tx, 0.6), {
			Font = Theme.Fonts.Body,
			Small = true,
			MaxSize = 17,
			XAlign = if rightAligned then Enum.TextXAlignment.Right else Enum.TextXAlignment.Left,
		})
		return { Card = card, Icon = icon, Title = title, Track = track, Fill = fill, Power = power }
	end
	local you = fighterCard("You", 0.015, false)
	local rival = fighterCard("Rival", 0.645, true)

	-- Shard pips under the rival: the reason this fight matters.
	local pips = Kit.frame(rival.Card, "Pips", UDim2.fromScale(0.7, 0.2), UDim2.fromScale(0, 0.84))
	local pipLayout = Instance.new("UIListLayout")
	pipLayout.FillDirection, pipLayout.HorizontalAlignment =
		Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Right
	pipLayout.Padding, pipLayout.Parent = UDim.new(0, 5), pips
	local pipLabel = Kit.label(
		pips,
		"Label",
		"",
		UDim2.new(0, 96, 1, 0),
		nil,
		{ Small = true, MaxSize = 15, Font = Theme.Fonts.Body }
	)
	pipLabel.LayoutOrder = -1
	local pipParts = {}
	for i = 1, 5 do
		local pip = Instance.new("Frame")
		pip.Name, pip.Size = "Pip" .. i, UDim2.new(1, 0, 1, 0)
		pip.SizeConstraint = Enum.SizeConstraint.RelativeYY
		pip.Rotation, pip.LayoutOrder = 45, i
		pip.BorderSizePixel = 0
		local stroke = Instance.new("UIStroke")
		stroke.Thickness, stroke.Color, stroke.Parent = 2, Color3.fromHex("#F4EFE2"), pip
		pip.Parent = pips
		pipParts[i] = pip
	end

	-- Centre top: hearts and how far this run has gone.
	local hud = Kit.frame(gui, "Run", UDim2.fromScale(0.26, 0.13), UDim2.fromScale(0.37, 0.03))
	local hearts = Kit.hearts(hud, "Hearts", G.Hearts, UDim2.fromScale(1, 0.56), UDim2.fromScale(0, 0))
	hearts:FindFirstChildWhichIsA("UIListLayout").HorizontalAlignment = Enum.HorizontalAlignment.Center
	local rung = Kit.label(hud, "Rung", "", UDim2.fromScale(1, 0.44), UDim2.fromScale(0, 0.56), { MaxSize = 26 })

	local coins = Kit.label(gui, "Coins", "", UDim2.fromScale(0.16, 0.06), UDim2.fromScale(0.015, 0.92), {
		MaxSize = 24,
		XAlign = Enum.TextXAlignment.Left,
		Color = Color3.fromHex("#FFD65C"),
	})

	-- Centre message: one instruction at a time, under eight words.
	local headline =
		Kit.label(gui, "Headline", "", UDim2.fromScale(0.7, 0.13), UDim2.fromScale(0.15, 0.2), { MaxSize = 64 })
	local subline = Kit.label(gui, "Subline", "", UDim2.fromScale(0.7, 0.06), UDim2.fromScale(0.15, 0.33), {
		Font = Theme.Fonts.Body,
		MaxSize = 24,
	})

	-- Your glassies: tap one to bring it to the next fight. The fight on screen is never interrupted.
	local tray = Kit.frame(gui, "Tray", UDim2.fromScale(0.62, 0.15), UDim2.fromScale(0.19, 0.83))
	local trayLayout = Instance.new("UIListLayout")
	trayLayout.FillDirection, trayLayout.HorizontalAlignment =
		Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Center
	trayLayout.Padding, trayLayout.SortOrder, trayLayout.Parent = UDim.new(0.012, 0), Enum.SortOrder.LayoutOrder, tray
	local slots = {}
	for i, id in G.Roster do
		local slot = panel(tray, id, UDim2.new(1, 0, 1, 0), UDim2.new(), nil, Color3.fromHex("#1D1538"), 0.05)
		slot.SizeConstraint, slot.LayoutOrder, slot.Visible = Enum.SizeConstraint.RelativeYY, i, false
		local stroke = Instance.new("UIStroke")
		stroke.Thickness, stroke.Color, stroke.Parent = 2, Color3.fromHex("#4A3B74"), slot
		portrait(slot, "Icon", UDim2.fromScale(0.9, 0.9), UDim2.fromScale(0.05, 0.05)).Image = G.Icons[id]
		local chip = Kit.label(slot, "Strong", "STRONG", UDim2.fromScale(1, 0.3), UDim2.fromScale(0, 0.72), {
			Small = true,
			MaxSize = 15,
			Color = Color3.fromHex("#7DFF6A"),
		})
		chip.Visible = false
		clickable(slot, function()
			remote:FireServer("Switch", id)
		end)
		slots[id] = { Frame = slot, Stroke = stroke, Chip = chip }
	end

	-- Unlock reveal: the biggest moment in the loop, and the only thing on screen while it lasts.
	local reveal = panel(
		gui,
		"Reveal",
		UDim2.fromScale(0.46, 0.66),
		UDim2.fromScale(0.27, 0.17),
		nil,
		Color3.fromHex("#120D24"),
		0.04
	)
	reveal.Visible, reveal.ZIndex = false, 50
	local revealIcon = portrait(reveal, "Icon", UDim2.fromScale(0.6, 0.58), UDim2.fromScale(0.2, 0.14))
	revealIcon.ZIndex = 51
	local revealTitle =
		Kit.label(reveal, "Title", "NEW GLASS!", UDim2.fromScale(0.9, 0.15), UDim2.fromScale(0.05, 0.02), {
			MaxSize = 54,
			Color = Color3.fromHex("#FFD65C"),
		})
	local revealName =
		Kit.label(reveal, "Name", "", UDim2.fromScale(0.9, 0.12), UDim2.fromScale(0.05, 0.72), { MaxSize = 44 })
	local revealPower = Kit.label(reveal, "Power", "", UDim2.fromScale(0.9, 0.1), UDim2.fromScale(0.05, 0.85), {
		Font = Theme.Fonts.Body,
		MaxSize = 24,
	})
	revealTitle.ZIndex, revealName.ZIndex, revealPower.ZIndex = 51, 51, 51

	-- End of a run: what you got, and one button.
	local over = panel(
		gui,
		"RunOver",
		UDim2.fromScale(0.5, 0.7),
		UDim2.fromScale(0.25, 0.15),
		nil,
		Color3.fromHex("#120D24"),
		0.03
	)
	over.Visible, over.ZIndex = false, 60
	local overTitle =
		Kit.label(over, "Title", "RUN OVER", UDim2.fromScale(0.9, 0.18), UDim2.fromScale(0.05, 0.04), { MaxSize = 54 })
	local overStats =
		Kit.label(over, "Stats", "", UDim2.fromScale(0.9, 0.12), UDim2.fromScale(0.05, 0.2), { MaxSize = 30 })
	local overGoal = Kit.label(over, "Goal", "", UDim2.fromScale(0.9, 0.1), UDim2.fromScale(0.05, 0.56), {
		Font = Theme.Fonts.Body,
		MaxSize = 24,
		Color = Color3.fromHex("#FFD65C"),
	})
	overTitle.ZIndex, overStats.ZIndex, overGoal.ZIndex = 61, 61, 61
	local overIcons = {}
	for i = 1, 3 do
		local icon = portrait(
			over,
			"New" .. i,
			UDim2.fromScale(0.2, 0.26),
			UDim2.fromScale(0.5 + (i - 2) * 0.22, 0.42),
			Vector2.new(0.5, 0.5)
		)
		icon.ZIndex, icon.Visible = 61, false
		overIcons[i] = icon
	end
	local again =
		Kit.gem(over, "Again", "PLAY AGAIN", "emerald", UDim2.fromScale(0.62, 0.22), UDim2.fromScale(0.5, 0.78))
	again.ZIndex = 62
	clickable(again, function()
		remote:FireServer("Begin")
	end)

	local function destroyScene()
		feedback:Reset()
		if scene then
			scene:Destroy()
			scene = nil
		end
		rigs, playback, packet = {}, nil, nil
	end

	local function setPips(have, needed, owned)
		pips.Visible = not owned
		pipLabel.Text = "COLLECT"
		for i, pip in pipParts do
			pip.Visible = i <= needed
			pip.BackgroundColor3 = if i <= have then Color3.fromHex("#FFD65C") else Color3.fromHex("#0B0816")
		end
	end

	local function showOutcome(data)
		local o = data.Outcome
		local won = o.Won
		if rigs[1] and rigs[2] then
			rigs[if won then 1 else 2]:Win()
		end
		local name = string.upper(G.Names[o.Rival])
		if o.Unlocked then
			revealIcon.Image, revealName.Text = G.Icons[o.Unlocked], string.upper(G.Names[o.Unlocked])
			revealPower.Text = G.Powers[o.Unlocked]
			task.delay(G.BeatSeconds * 0.55, function()
				if reveal.Parent then
					reveal.Visible = true
					headline.Text, subline.Text = "", ""
					Kit.popIn(reveal)
					task.delay(G.UnlockSeconds + G.BeatSeconds * 0.3, function()
						if reveal.Parent then
							reveal.Visible = false
						end
					end)
				end
			end)
			headline.Text, subline.Text = "SHATTERED!", ""
		elseif won then
			headline.Text = "SHATTERED!"
			subline.Text = if o.Shards > 0
				then string.format("+%d %s SHARD   %d / %d", o.Shards, name, o.Progress, o.Needed)
				else "+" .. o.Coins .. " COINS"
		elseif o.Over then
			headline.Text, subline.Text = "SHATTERED...", ""
		else
			headline.Text = "HEART LOST"
			local counter
			for _, id in G.Roster do
				if data.Collection.Owned[id] and Rules.isCounter(id, o.Rival) then
					counter = id
					break
				end
			end
			subline.Text = if counter and counter ~= data.Selected
				then "TAP " .. string.upper(G.Names[counter]) .. " - IT BEATS " .. name
				else "REMATCH!"
		end
	end

	local function refreshHud(data)
		local run, c = data.Run, data.Collection
		Glass.hearts(hearts, run.Hearts, G.Hearts)
		rung.Text = "SMASHED " .. run.Wins .. (if c.Best > 0 then "   BEST " .. c.Best else "")
		coins.Text = c.Coins .. " COINS"
		local upcoming = if data.Outcome then run.Rival else data.Rival
		for id, slot in slots do
			local owned = c.Owned[id] == true
			slot.Frame.Visible = owned
			local chosen = data.Selected == id
			slot.Stroke.Color = if chosen then Color3.fromHex("#FFD65C") else Color3.fromHex("#4A3B74")
			slot.Stroke.Thickness = if chosen then 4 else 2
			slot.Chip.Visible = owned and Rules.isCounter(id, upcoming)
		end
		stage:SetOwned(c.Owned)
		you.Icon.Image, rival.Icon.Image = G.Icons[data.Id], G.Icons[data.Rival]
		you.Title.Text, rival.Title.Text = string.upper(G.Names[data.Id]), string.upper(G.Names[data.Rival])
		you.Power.Text, rival.Power.Text = G.Powers[data.Id], G.Powers[data.Rival]
		you.Fill.BackgroundColor3 = Color3.fromHex(G.Fill[data.Id])
		rival.Fill.BackgroundColor3 = Color3.fromHex(G.Fill[data.Rival])
		setPips(c.Shards[data.Rival] or 0, c.Needed, c.Owned[data.Rival] == true)
		over.Visible = data.RunOver == true
		if data.RunOver then
			overStats.Text = string.format("SMASHED %d    BEST %d    +%d COINS", run.Wins, c.Best, run.Coins)
			local left = #G.Roster
			for _ in c.Owned do
				left -= 1
			end
			local closest, most = nil, 0
			for id, shards in c.Shards do
				if shards > most then
					closest, most = id, shards
				end
			end
			overGoal.Text = if closest
				then string.format(
					"%s IS %d SHARD%s AWAY",
					string.upper(G.Names[closest]),
					c.Needed - most,
					if c.Needed - most == 1 then "" else "S"
				)
				elseif left > 0 then left .. " MORE GLASS TO COLLECT"
				else "SHELF COMPLETE!"
			overTitle.Text = if #run.Unlocked > 0 then "NEW GLASS!" else "RUN OVER"
			for i, icon in overIcons do
				local id = run.Unlocked[i]
				icon.Visible = id ~= nil
				icon.Position = UDim2.fromScale(0.5 + (i - (#run.Unlocked + 1) / 2) * 0.22, 0.42)
				icon.Image = if id then G.Icons[id] else ""
			end
			headline.Text, subline.Text = "", ""
		end
	end

	local function release()
		if packet and packet.Phase == "Aim" then
			pulledOnce = true
			remote:FireServer("Launch", aim, yaw)
		end
	end

	connect(remote.OnClientEvent, function(data)
		if data.Seed ~= seed then
			destroyScene()
			seed = data.Seed
			settledSeed = nil
			headline.Text, subline.Text = "", ""
			playback = Playback.new(B.Feel.InterpolationDelay, G.SnapshotSeconds, B.Feel.SnapshotBuffer)
			scene = Scene.new({
				Id = "Gauntlet",
				Frame = frame,
				Library = RS.Assets[G.Library],
				A = { Id = data.Id },
				B = { Id = data.Rival },
				HookPositions = {
					frame:PointToWorldSpace(Vector3.new(-data.HookGap / 2, 0, 0)),
					frame:PointToWorldSpace(Vector3.new(data.HookGap / 2, 0, 0)),
				},
			}, data.MaxHp, Shatter)
			scene.OwnFight = true
			scene:SetViewing(true)
			for side, f in scene.Fighters do
				f.CrackPaths = Cracks[f.Id] or {}
				rigs[side] = Rig.new(f)
				if f.Health then
					f.Health.Enabled = false -- the cards and the liquid level already show this
				end
			end
		end
		local first = packet == nil
		packet = data
		playback:push(data.Snapshot, data.Events, os.clock(), data.Phase == "Result")
		gui:SetAttribute("Phase", data.Phase)
		gui:SetAttribute("Rung", data.Run.Rung)
		gui:SetAttribute("Hearts", data.Run.Hearts)
		local owned = 0
		for _ in data.Collection.Owned do
			owned += 1
		end
		gui:SetAttribute("Owned", owned)
		gui:SetAttribute("RunOver", data.RunOver == true)
		if data.Outcome and settledSeed ~= data.Seed then
			settledSeed = data.Seed
			showOutcome(data)
		end
		refreshHud(data)
		if data.Phase == "Aim" then
			headline.Text = "PULL BACK & LET GO"
			subline.Text = if first or not pulledOnce then "DRAG ANYWHERE, THEN RELEASE" else "SPACE OR DRAG"
		elseif not data.Outcome and headline.Text ~= "" then
			headline.Text, subline.Text = "", ""
			if scene then
				scene:HideGhost()
			end
		end
	end)

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
		"GauntletMovement",
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

	local displayed = { 1, 1 }
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
		camera.CameraType, camera.FieldOfView = Enum.CameraType.Scriptable, 44
		local focus = origin + Vector3.new(0, -6.6, 0)
		camera.CFrame = CFrame.lookAt(focus + Vector3.new(0, 0.6, 21.5), focus)
		if not scene or not packet or not playback then
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
			-- Faces are the point of v5: keep the string twist from turning them away from the camera.
			scene:Pose(side, p, math.clamp(b[7] * 0.3, -0.45, 0.45), Vector3.new(b[9], 0, b[10]))
		end
		for _, e in events do
			scene:Event(e, feedback)
			if e.Type == "Hit" then
				for _, rig in rigs do
					rig:Hurt()
				end
			end
		end
		scene:Update(snapshot.R, snapshot.T)
		local maxima = packet.MaxHp
		for side, rig in rigs do
			local fraction = snapshot.R.Hp[side] / maxima[side]
			rig:Update(fraction)
			displayed[side] += (math.clamp(fraction, 0, 1) - displayed[side]) * 0.2
		end
		you.Fill.Size = UDim2.fromScale(displayed[1], 1)
		rival.Fill.Size = UDim2.fromScale(displayed[2], 1)
		if packet.Phase == "Aim" then
			scene:GhostPath(aim, yaw, 1)
		end
	end)

	function Gauntlet.Stop()
		remote:FireServer("Stop")
		for _, c in connections do
			c:Disconnect()
		end
		destroyScene()
		stage:Destroy()
		gui:Destroy()
		CAS:UnbindAction("GauntletMovement")
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
		Gauntlet.Stop = nil
	end
	connect(player.CharacterRemoving, function()
		if Gauntlet.Stop then
			Gauntlet.Stop()
		end
	end)
	remote:FireServer("Begin")
	return "Gauntlet client ready"
end

return Gauntlet
