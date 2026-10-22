-- Studio-only power VFX preview (workstream E). Stages one kit's real event sequence (Ready -> cast -> release ->
-- contact) on a local FightScene up in the sky, through the real CombatEffects pipeline, at any speed. Presentation
-- only: no match, remote or server state. Driven from tools/studio/preview_power_vfx.luau through the MCP in
-- Play / Client.
--   kit:  a release kit id, or "Cleanup" (destroys the preview and hands the camera back).
--   opts: { Slow = 1 (time scale divisor), Stop = seconds (freeze the clock there), Manual = true, Miss = false,
--           Foe = "jam", Ready = 1.1 (seconds Ready before the cast), Low = false (LowDetail), Hp = 0.5 }
-- Returns the staged timeline (event types and times) so captures can be aimed at a beat.
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local ARMS = { contact = true, slow_contact = true, mark_contact = true, armed_contact = true, drain_contact = true }
local SELF = { heal = "Heal", boost = "Boost", mirror = "Mirror" }

local function cleanup()
	RunService:UnbindFromRenderStep("PowerVFXPreview")
	for _, old in workspace:GetChildren() do
		if old.Name == "LocalFight_PowerPreview" then
			old:Destroy()
		end
	end
	local state = _G.PowerVFXPreviewState
	for gui in state and state.Hidden or {} do
		gui.Enabled = true
	end
	if state and state.Scene and state.Scene.Combat then
		pcall(function()
			state.Scene.Combat:Destroy()
		end)
	end
	_G.PowerVFXPreviewState = nil
end

local function arr(v)
	return { v.X, v.Y, v.Z }
end

-- Builds the event list for one kit from its Balance numbers. Times are seconds from the preview start.
local function timeline(id, kit, opts, frame, posAt)
	local events = {}
	local function add(t, e)
		e.Time, e.Side, e.Kit = t, e.Side or 1, id
		table.insert(events, e)
	end
	local readyAt, castAt = 0.3, 0.3 + (opts.Ready or 1.1)
	local Cast = require(RS.Shared.Config.Balance).CombatRelease.Cast
	local shape = kit.Shape
	if id == "hollowlight" then
		for i = 1, 3 do
			add(0.3 + i * 0.5, { Type = "SignatureStatus", Kind = "Seed", Target = 2, Count = i, Seconds = 6 })
		end
		castAt = 2.3
		add(castAt, { Type = "CastStart", CastId = 9, Windup = kit.Windup, Shape = "bloom", Pulses = 3 })
		return events, castAt
	end
	local arm = ARMS[shape] == true
	local brew = if kit.Cycle then (opts.Brew or 3) else nil
	if opts.Rebirth and kit.Rebirth then
		kit = table.clone(kit)
		for key, value in kit.Rebirth do
			kit[key] = value
		end
		shape = kit.Shape
	end
	add(readyAt, {
		Type = "SignatureReady",
		ReadyId = 1,
		AutoAt = readyAt + Cast.AutoSeconds,
		Seconds = Cast.AutoSeconds,
		Shape = shape,
		Arm = arm,
		Brew = brew,
		Next = if brew then brew % 3 + 1 else nil,
	})
	if arm then
		add(castAt, { Type = "SignatureArmed", Seconds = Cast.ArmedSeconds, Manual = opts.Manual, Shape = shape })
		local hit = castAt + 0.9
		local point = arr(frame:PointToObjectSpace((posAt(1, hit) + posAt(2, hit)) / 2))
		if opts.Miss then
			add(castAt + Cast.ArmedSeconds, { Type = "SignatureStatus", Kind = "ArmedFade" })
		elseif shape == "contact" or shape == "armed_contact" or shape == "drain_contact" then
			add(hit, { Type = "SignatureContact", CastId = 7, Shape = shape, Point = point })
			if shape == "drain_contact" then
				add(hit + 0.02, { Type = "SignatureStatus", Kind = "Drain", Target = 2, Amount = 0.5 })
			end
		elseif shape == "slow_contact" then
			add(hit, { Type = "SignatureStatus", Kind = "Slow", Target = 2, Seconds = kit.StatusSeconds })
		elseif shape == "mark_contact" then
			add(hit, { Type = "SignatureStatus", Kind = "Mark", Target = 2, Seconds = kit.StatusSeconds })
			add(hit + 1.8, { Type = "SignatureContact", Shape = "splat", Point = point })
		end
		return events, castAt
	end
	if shape == "echo_contact" then
		local point = arr(frame:PointToObjectSpace(posAt(2, castAt)))
		add(castAt - 0.4, { Type = "SignatureStatus", Kind = "Echo", Point = point, Seconds = kit.StoreSeconds })
		shape = "projectile"
	end
	local windup = kit.Windup + (kit.Hold or 0)
	add(castAt, {
		Type = "CastStart",
		CastId = 1,
		Windup = windup,
		Shape = shape,
		ReleaseAt = castAt + windup,
		Pulses = kit.Pulses,
		Manual = opts.Manual,
		Held = true,
		Brew = brew,
		Rebirth = if opts.Rebirth and kit.Then then true else nil,
	})
	local rel = castAt + windup
	if shape == "guard" then
		add(rel, { Type = "CastRelease", CastId = 1, Shape = shape, Duration = kit.Duration })
		if not opts.Miss then
			add(rel + 0.7, { Type = "SignatureBlock", Side = 1, Amount = 5 })
			if kit.Riposte then
				local r = kit.Riposte
				local at = rel + 0.72
				add(at, {
					Type = "CastStart",
					CastId = 2,
					Windup = r.Windup,
					Shape = "pulse",
					Riposte = true,
					ReleaseAt = at + r.Windup,
				})
				add(at + r.Windup, {
					Type = "CastRelease",
					CastId = 2,
					Shape = "pulse",
					Origin = arr(frame:PointToObjectSpace(posAt(1, at + r.Windup))),
					Direction = arr(frame:VectorToObjectSpace((posAt(2, at) - posAt(1, at)).Unit)),
					Range = r.Range,
					Duration = r.Duration,
				})
				add(at + r.Windup + 0.15, {
					Type = "CastContact",
					CastId = 2,
					Target = 2,
					Pulse = 1,
					Missed = false,
					Amount = 3,
					Point = arr(frame:PointToObjectSpace(posAt(2, at + 0.3))),
				})
			end
		end
		return events, castAt
	end
	if SELF[shape] then
		add(
			rel,
			{ Type = "CastRelease", CastId = 1, Shape = shape, Duration = kit.Duration, PierceGuard = kit.PierceGuard }
		)
		add(rel, { Type = "SignatureStatus", Kind = SELF[shape], Amount = 6, Seconds = kit.Duration })
		if kit.PierceGuard and not opts.Miss then
			add(rel + 0.7, { Type = "SignatureStatus", Kind = "Pierce", Target = 2 })
		end
		return events, castAt
	end
	local origin = posAt(1, rel)
	local target = posAt(2, rel + 0.15)
	local dir = (target - origin).Unit
	local zoneAt = nil
	if shape == "zone" then
		zoneAt = if kit.At == "foe_predicted"
			then posAt(2, rel + (kit.Delay or 0))
			elseif kit.At == "self_lead" then posAt(1, rel + 0.25)
			else origin
	end
	add(rel, {
		Type = "CastRelease",
		CastId = 1,
		Shape = shape,
		Point = if zoneAt then arr(frame:PointToObjectSpace(zoneAt)) else nil,
		Kind = kit.Look,
		Delay = kit.Delay,
		Plane = kit.Plane,
		Origin = arr(frame:PointToObjectSpace(origin)),
		Direction = arr(frame:VectorToObjectSpace(dir)),
		Range = kit.Range,
		Radius = kit.Radius,
		Arc = kit.Arc,
		Duration = kit.Duration,
		Pulses = kit.Pulses,
		Path = kit.Path,
	})
	local pulses = kit.Pulses or 1
	for i = 1, pulses do
		local at = if shape == "zone"
			then rel + (kit.Delay or 0) + (if opts.Miss then kit.Duration else 0.9)
			elseif shape == "ray" then rel + 0.02
			elseif shape == "projectile" or shape == "volley" then rel + kit.Duration * (if kit.Path
					== "return"
				then (if i == 1 then 0.3 else 0.85)
				else 0.45)
			else rel + kit.Duration * (i - 0.5) / pulses
		local hitAt = posAt(2, at)
		add(at, {
			Type = "CastContact",
			CastId = 1,
			Target = 2,
			Pulse = i,
			Missed = opts.Miss == true,
			Amount = if opts.Miss then 0 else 4,
			Point = if opts.Miss then nil else arr(frame:PointToObjectSpace(hitAt)),
		})
		-- Ranged statuses on the first landed pulse (decision 115): Whiskers' tangle, Midnight's sleepy mark and
		-- its wake-up bonk on the next clash.
		if i == 1 and not opts.Miss then
			if kit.Slow then
				add(at, { Type = "SignatureStatus", Kind = "Slow", Target = 2, Seconds = kit.StatusSeconds })
			end
			if kit.MarkDamage then
				local seconds = kit.MarkSeconds or kit.StatusSeconds
				add(at, { Type = "SignatureStatus", Kind = "Mark", Target = 2, Seconds = seconds })
				add(at + math.min(1.8, seconds - 0.2), {
					Type = "SignatureContact",
					Shape = "splat",
					Point = arr(frame:PointToObjectSpace(posAt(2, at + 1.8))),
				})
			end
		end
	end
	return events, castAt
end

return function(kitId: string?, opts: { [string]: any }?)
	if not RunService:IsStudio() then
		return "studio only"
	end
	cleanup()
	if kitId == "Cleanup" then
		local camera = workspace.CurrentCamera
		camera.CameraType = Enum.CameraType.Custom
		camera.FieldOfView = 70
		return "cleaned"
	end
	opts = opts or {}
	local id = kitId or "pop"
	local SLOW = opts.Slow or 1
	local client = Players.LocalPlayer.PlayerScripts.Client
	local Balance = require(RS.Shared.Config.Balance)
	local M, Feel = Balance.Motion, Balance.Feel
	local kit = Balance.CombatRelease.Kits[id]
	assert(kit, "unknown kit " .. tostring(id))
	local Scene = require(client.Presentation.FightScene)
	local Shatter = require(client.Controllers.ShatterController)
	Shatter:Init()
	local camera = workspace.CurrentCamera
	local root = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	local look = Vector3.new(0, 0, -1)
	local origin = (if root then root.Position else Vector3.new(0, 60, 0)) + Vector3.yAxis * 140
	local frame = CFrame.lookAt(origin, origin + look)
	local scene = Scene.new({
		Id = "PowerPreview",
		Frame = frame,
		A = { Id = id },
		B = { Id = opts.Foe or (if id == "jam" then "prism" else "jam") },
	}, { 100, 100 }, Shatter)
	scene.Muted = opts.Sound ~= true
	scene:SetViewing(true)
	for _, f in scene.Fighters do
		f.LowDetail = opts.Low == true
	end
	local L = M.StringLength
	local w = math.pi * 2 / 1.8
	local function pendulum(side, t)
		local phi = (opts.Lean or -0.12) + (opts.Swing or 0.22) * math.sin(w * t)
		local x = math.sin(phi) * (if side == 1 then 1 else -1)
		return Vector3.new(x, -math.cos(phi), math.sin(w * t * 0.5) * 0.08 * (if side == 1 then 1 else -1)).Unit * L
	end
	local function posAt(side, t)
		local hook = scene.Fighters[side].Hook.WorldPosition
		return hook + frame:VectorToWorldSpace(pendulum(side, t)) - Vector3.yAxis * M.BodyCenter * M.GlassyScale
	end
	local events, castAt = timeline(id, kit, opts, frame, posAt)
	table.sort(events, function(a, b)
		return a.Time < b.Time
	end)
	local state = { Scene = scene, T = 0, Next = 1, Events = events, Fired = {}, Hidden = {} }
	for _, gui in Players.LocalPlayer.PlayerGui:GetChildren() do
		if gui:IsA("ScreenGui") and gui.Enabled and opts.Hud ~= true then
			gui.Enabled = false
			state.Hidden[gui] = true
		end
	end
	_G.PowerVFXPreviewState = state
	local hp = (opts.Hp or 0.5) * scene.Fighters[1].Stats.MaxHP
	local statuses = { { 0, 0, 0, 0 }, { 0, 0, 0, 0 } }
	local center = frame.Position - Vector3.yAxis * (L + M.BodyCenter * M.GlassyScale)
	local focus = center + Vector3.yAxis * Feel.CameraFocusHeight
	local aspect = camera.ViewportSize.X / math.max(1, camera.ViewportSize.Y)
	local scale = math.max(1, Feel.CameraMinimumAspect / aspect) * (opts.Zoom or 1)
	local offset = frame:VectorToWorldSpace(Vector3.new(Feel.CameraSide, Feel.CameraHeight, Feel.CameraDistance))
		* scale
	local last = os.clock()
	RunService:BindToRenderStep("PowerVFXPreview", Enum.RenderPriority.Camera.Value + 2, function()
		local now = os.clock()
		local dt = math.min(now - last, 0.1)
		last = now
		if not opts.Stop or state.T < opts.Stop then
			state.T = math.min(state.T + dt / SLOW, opts.Stop or math.huge)
		end
		local t = state.T
		for side = 1, 2 do
			scene:Pose(side, pendulum(side, t), 0, Vector3.zero)
		end
		while state.Next <= #events and events[state.Next].Time <= t do
			local e = events[state.Next]
			state.Next += 1
			table.insert(state.Fired, e.Type)
			if e.Type == "SignatureStatus" and e.Kind == "Slow" then
				statuses[2][2] = e.Time + e.Seconds
			elseif e.Type == "SignatureStatus" and e.Kind == "Mark" then
				statuses[2][4] = e.Time + e.Seconds
			elseif e.Type == "SignatureStatus" and (e.Kind == "Boost" or e.Kind == "Mirror") then
				statuses[1][if e.Kind == "Boost" then 3 else 1] = e.Time + e.Seconds
			elseif e.Type == "CastRelease" and e.Shape == "guard" then
				statuses[1][1] = e.Time + e.Duration
			elseif e.Type == "SignatureBlock" then
				statuses[1][1] = 0
			end
			scene:Event(e, nil)
		end
		local charge = math.clamp(t / math.max(0.01, castAt), 0, 1)
		local r = {
			Hp = { hp, scene.Fighters[2].Stats.MaxHP * 0.8 },
			Power = { if t < castAt then charge else 0, 0.3 },
			Frozen = { false, false },
			Shield = { false, false },
			Rage = { false, false },
			Slam = { false, false },
			Pump = { false, false },
			Effect = {},
		}
		for side = 1, 2 do
			r.Effect[side] = {}
			for i, untilTime in statuses[side] do
				r.Effect[side][i] = math.max(0, untilTime - t)
			end
		end
		scene:Update(r, t)
		local mid = (scene.Fighters[1].Body.Position + scene.Fighters[2].Body.Position) / 2
		local aim = focus:Lerp(mid, Feel.CameraFollow)
		camera.CameraType = Enum.CameraType.Scriptable
		camera.FieldOfView = Feel.CameraFieldOfView
		camera.CFrame = CFrame.lookAt(aim + offset, aim)
	end)
	local list = {}
	for _, e in events do
		table.insert(list, string.format("%.2f %s%s", e.Time, e.Type, if e.Kind then "/" .. e.Kind else ""))
	end
	return table.concat(list, "; ")
end
