-- Lobby Featured Collection showcase and capsule opening stands (Workspace.FeaturedShowcase, built by
-- tools/studio/build_featured_showcase.luau). Client-only and cosmetic: riders wearing the local player's
-- avatar, the looping Lantern Eclipse demo, example flyers/finishers and prompts that open the shop on the
-- right page. Each section builds when the camera comes close and is fully torn down when it leaves.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local S = require(RS.Shared.Config.Showcase)
local Cosmetics = require(RS.Shared.Config.RoundCosmetics)
local Presentation = script.Parent.Parent.Presentation
local RidePose = require(Presentation.RidePose)
local RideMotion = require(Presentation.RideMotion)
local FinisherFX = require(Presentation.FinisherFX)
local FinisherAudio = require(Presentation.FinisherAudio)
local Controller = {}

local D = S.Demo
local CYCLE = D.IdleSeconds + D.RiseSeconds + D.FlySeconds + D.AfterSeconds
local TAU = math.pi * 2
local random = Random.new()

local function still(model)
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false
		end
	end
	return model
end

local function rideSource(id)
	local def = Cosmetics.ByCategory.Rideables[id]
	if def and def.AssetBundle then
		local seasonal = RS.Assets:FindFirstChild("Seasonal")
		local bundle = seasonal and seasonal:FindFirstChild(def.AssetBundle)
		return bundle and bundle:FindFirstChild(def.AssetName)
	end
	return RS.Assets.Rideables:FindFirstChild(id)
end

local function lowQuality()
	local ok, level = pcall(function()
		return UserSettings():GetService("UserGameSettings").SavedQualityLevel.Value
	end)
	return ok and level > 0 and level <= 3
end

local function ease(x)
	x = math.clamp(x, 0, 1)
	return 1 - (1 - x) ^ 3
end

local function bezier(a, b, c, t)
	return a:Lerp(b, t):Lerp(b:Lerp(c, t), t)
end

-- A display ride, optionally carrying a copy of the player's avatar in the ride's pose.
-- Motion is the shared Presentation/RideMotion, so displays match matches.
local Ride = {}
Ride.__index = Ride

function Ride.new(parent, id, base, avatar, launch)
	local source = rideSource(id)
	if not source then
		return nil
	end
	local model = still(source:Clone())
	model.Name = "Showcase_" .. id
	model:PivotTo(base)
	local self = setmetatable({ Model = model }, Ride)
	self.Motion = RideMotion.new(model, base, { Id = id, Seed = base.Position.X + base.Position.Z })
	if launch then
		self.Motion:Launch(launch, false)
	end
	model.Parent = parent
	if avatar then
		self.Npc = avatar:Clone()
		self.Npc.Parent = parent
		self.Pose = RidePose.new(self.Npc, model:GetAttribute("PoseId") or id)
	end
	return self
end

function Ride:Step(time, base, near)
	local pose = self.Motion:Step(time, base, near)
	if self.Pose and self.Npc.Parent then
		self.Pose:Lean(self.Motion.Bank, self.Motion.Pitch)
		local rootPose = pose * CFrame.new(0, self.Pose.Height or 0, 0)
		self.Npc:PivotTo(rootPose)
		self.Pose:PlaceAnchored(rootPose)
	end
end

function Ride:Destroy()
	if self.Pose then
		self.Pose:Destroy()
	end
	if self.Npc then
		self.Npc:Destroy()
	end
	self.Motion:Destroy()
	self.Model:Destroy()
end

function Controller:Init(controllers)
	self.Controllers, self.Player = controllers, Players.LocalPlayer
	self.Sections = {}
end

-- A local copy of the player's character: scripts, sounds and tools stripped, root anchored so the
-- RidePose joints drive the rest. Rebuilt whenever the avatar (re)loads.
function Controller:RefreshAvatar()
	local character = self.Player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then
		return
	end
	local archivable = character.Archivable
	character.Archivable = true
	local ok, copy = pcall(character.Clone, character)
	character.Archivable = archivable
	if not ok or not copy then
		return
	end
	for _, obj in copy:GetDescendants() do
		if obj:IsA("LuaSourceContainer") or obj:IsA("Sound") or obj:IsA("Tool") or obj:IsA("ForceField") then
			obj:Destroy()
		elseif obj:IsA("BasePart") then
			obj.Anchored, obj.CanCollide, obj.CanTouch, obj.CanQuery, obj.Massless = false, false, false, false, true
		end
	end
	local human = copy:FindFirstChildOfClass("Humanoid")
	if not human then
		copy:Destroy()
		return
	end
	human.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	human.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	human.BreakJointsOnDeath, human.EvaluateStateMachine = false, false
	copy.HumanoidRootPart.Anchored = true
	copy.Name = "ShowcaseAvatar"
	if self.Avatar then
		self.Avatar:Destroy()
	end
	self.Avatar = copy
	-- Riders already on display swap to the new look.
	for _, section in self.Sections do
		if section.Active and section.UsesAvatar then
			section:Teardown()
		end
	end
end

-- Opens the shop through LobbyController, then switches to `tab` once the screen arrives.
function Controller:OpenShop(tab)
	local lobby = self.Controllers.LobbyController
	if not lobby then
		return
	end
	lobby:Open("Kiln")
	self.PendingTab, self.PendingUntil = tab, os.clock() + S.ShopWaitSeconds
end

-- Opens the fullscreen bundle preview (UI/Screens/BundlePreview); false if it is unavailable.
function Controller:OpenBundle(bundleId)
	local screens = script.Parent.Parent:FindFirstChild("UI") and script.Parent.Parent.UI:FindFirstChild("Screens")
	local module = screens and screens:FindFirstChild("BundlePreview")
	local ok, preview = pcall(require, module)
	if not (module and ok and type(preview) == "table" and type(preview.open) == "function") then
		return false
	end
	preview.open(bundleId)
	return true
end

function Controller:Prompt(parent, conf)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ShowcasePrompt"
	prompt.ActionText, prompt.ObjectText = conf.ActionText, conf.ObjectText
	prompt.MaxActivationDistance, prompt.RequiresLineOfSight, prompt.HoldDuration = S.PromptDistance, false, 0
	prompt.Parent = parent
	prompt.Triggered:Connect(function()
		if not (conf.Bundle and self:OpenBundle(conf.Bundle)) then
			self:OpenShop(conf.Tab)
		end
	end)
	return prompt
end

local function sectionFolder(name)
	local folder = Instance.new("Folder")
	folder.Name = "Showcase_" .. name
	folder:SetAttribute("CosmeticOnly", true)
	folder.Parent = workspace
	return folder
end

local function toggleEmitters(list, on)
	for _, effect in list do
		effect.Enabled = on
	end
end

local function invisible(name, cf, parent)
	local p = Instance.new("Part")
	p.Name, p.Transparency, p.Size, p.CFrame = name, 1, Vector3.one * 0.2, cf
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false
	p.Parent = parent
	return p
end

-- ── Stage: carriage rider, Hollowlight glassy and the finisher demo ─────────────────────────────
local function buildDemo(folder, anchors)
	local source = RS.Assets.Glassies:FindFirstChild(S.Featured.Glassy)
	if not source then
		return nil
	end
	local glassy = still(source:Clone())
	glassy.Name = "DemoGlassy"
	glassy:ScaleTo(D.GlassyScale)
	local hook = anchors.DemoHook.CFrame
	local hang = hook * CFrame.new(0, -D.StringLength, 0)
	glassy:PivotTo(hang)
	local body = glassy:FindFirstChild("Body")
	local demo = {
		Model = glassy,
		Body = body,
		Hook = hook,
		Hang = hang,
		Arc = anchors.DemoArc.Position,
		Target = anchors.DemoTarget.Position,
		Visible = {},
		Shards = {},
		Start = os.clock(),
	}
	demo.PivotFromBody = body.CFrame:ToObjectSpace(glassy:GetPivot())
	for _, p in glassy:GetDescendants() do
		if p:IsA("BasePart") then
			if p.Parent.Name == "Shards" then
				table.insert(
					demo.Shards,
					{ Part = p, Alpha = p.Transparency, Rest = glassy:GetPivot():ToObjectSpace(p.CFrame) }
				)
				p.Transparency = 1
			else
				table.insert(demo.Visible, { Part = p, Alpha = p.Transparency })
			end
		end
	end
	-- String from the hook to the hang point, and a short trail for the flight.
	local hookPart = invisible("HookPoint", demo.Hook, folder)
	local a0 = Instance.new("Attachment")
	a0.Parent = hookPart
	local a1 = Instance.new("Attachment")
	a1.CFrame, a1.Parent = demo.PivotFromBody, body
	local cord = Instance.new("Beam")
	cord.Name, cord.Attachment0, cord.Attachment1 = "String", a0, a1
	cord.Width0, cord.Width1, cord.FaceCamera, cord.Segments = 0.07, 0.07, true, 1
	cord.Color, cord.LightInfluence = ColorSequence.new(Color3.fromHex("1F1830")), 1
	cord.Parent = hookPart
	demo.String = cord
	local t0, t1 = Instance.new("Attachment"), Instance.new("Attachment")
	t0.Position, t1.Position = Vector3.new(0, 0.5, 0), Vector3.new(0, -0.5, 0)
	t0.Parent, t1.Parent = body, body
	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1, trail.Enabled = t0, t1, false
	trail.Lifetime, trail.LightEmission, trail.FaceCamera = 0.25, 1, true
	trail.Color = ColorSequence.new(Color3.fromHex("FFAA55"), Color3.fromHex("63EFBC"))
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.Parent = body
	demo.Trail = trail
	-- Positional audio source at the target; the stage plays the impact a little quieter.
	local emitter = invisible("DemoAudio", CFrame.new(demo.Target), folder)
	emitter.ChildAdded:Connect(function(sound)
		if sound:IsA("Sound") then
			sound.Volume *= S.AudioVolume
		end
	end)
	demo.Emitter = emitter
	glassy.Parent = folder
	return demo
end

local function resetDemo(demo, folder)
	if demo.Owner then
		demo.Owner:Destroy()
	end
	demo.Owner = Instance.new("Folder")
	demo.Owner.Name, demo.Owner.Parent = "DemoCycle", folder
	demo.Impacted, demo.ShardStart = false, nil
	demo.Trail.Enabled = false
	demo.Model:PivotTo(demo.Hang)
	local pivot = demo.Model:GetPivot()
	for _, shard in demo.Shards do
		shard.Part.CFrame, shard.Part.Transparency = pivot * shard.Rest, 1
	end
end

function Controller:Impact(demo, distance)
	demo.Impacted = true
	demo.Trail.Enabled = false
	local center = demo.Body.Position
	for _, entry in demo.Visible do
		entry.Part.Transparency = 1
	end
	for _, shard in demo.Shards do
		local out = shard.Part.Position - center
		out = if out.Magnitude > 0.01 then out.Unit else Vector3.yAxis
		shard.Start, shard.Part.Transparency = shard.Part.CFrame, shard.Alpha
		shard.Velocity = (out + Vector3.new(0, 0.6, 0)) * D.ShardSpeed * random:NextNumber(0.6, 1.1)
		shard.Spin = Vector3.new(random:NextNumber(-8, 8), random:NextNumber(-8, 8), random:NextNumber(-8, 8))
	end
	demo.ShardStart = os.clock()
	local low = lowQuality() or distance > S.FullDetailDistance
	FinisherFX.emit(demo.Owner, S.Featured.Finisher, demo.Target, low)
	local pg = self.Player:FindFirstChildOfClass("PlayerGui")
	if distance <= S.AudioDistance and not (pg and pg:GetAttribute("InMatch")) then
		FinisherAudio.phase(demo.Owner, S.Featured.Finisher, "Burst", demo.Emitter, { Quiet = true })
	end
end

function Controller:StepDemo(demo, now, distance, folder)
	local elapsed = now - demo.Start
	local index = math.floor(elapsed / CYCLE)
	local t = elapsed - index * CYCLE
	if index ~= demo.Cycle then
		demo.Cycle = index
		resetDemo(demo, folder)
	end
	local flyEnd = D.IdleSeconds + D.RiseSeconds + D.FlySeconds
	if t < D.IdleSeconds then
		-- Swinging on the hook; fades back in at the start of each loop.
		local sway = math.sin(now * D.SwayHz * TAU) * D.SwayAngle
		demo.Model:PivotTo(demo.Hook * CFrame.Angles(sway, 0, sway * 0.5) * CFrame.new(0, -D.StringLength, 0))
		local fade = math.clamp(t / D.RespawnSeconds, 0, 1)
		for _, entry in demo.Visible do
			entry.Part.Transparency = entry.Alpha + (1 - entry.Alpha) * (1 - fade)
		end
		demo.String.Enabled = true
	elseif t < flyEnd then
		demo.String.Enabled = false
		local rest = demo.Hang * demo.PivotFromBody:Inverse()
		local lifted = rest.Position + Vector3.yAxis * D.RiseHeight
		local bodyCFrame
		if t < D.IdleSeconds + D.RiseSeconds then
			local rise = ease((t - D.IdleSeconds) / D.RiseSeconds)
			bodyCFrame = CFrame.new(rest.Position:Lerp(lifted, rise)) * rest.Rotation * CFrame.Angles(0, rise * 2, 0)
		else
			demo.Trail.Enabled = true
			local fly = (t - D.IdleSeconds - D.RiseSeconds) / D.FlySeconds
			local f = fly * fly
			bodyCFrame = CFrame.new(bezier(lifted, demo.Arc, demo.Target, f))
				* rest.Rotation
				* CFrame.Angles(f * D.FlySpin * 0.4, 2 + f * D.FlySpin, 0)
		end
		demo.Model:PivotTo(bodyCFrame * demo.PivotFromBody)
	elseif not demo.Impacted then
		self:Impact(demo, distance)
	end
	if demo.ShardStart then
		local k = now - demo.ShardStart
		local fade = math.clamp((k / D.ShardSeconds - 0.6) / 0.4, 0, 1)
		for _, shard in demo.Shards do
			if k >= D.ShardSeconds then
				shard.Part.Transparency = 1
			else
				local position = shard.Start.Position
					+ shard.Velocity * k
					- Vector3.yAxis * (0.5 * D.ShardGravity * k * k)
				shard.Part.CFrame = CFrame.new(position)
					* shard.Start.Rotation
					* CFrame.Angles(shard.Spin.X * k, shard.Spin.Y * k, shard.Spin.Z * k)
				shard.Part.Transparency = shard.Alpha + (1 - shard.Alpha) * fade
			end
		end
		if k >= D.ShardSeconds then
			demo.ShardStart = nil
		end
	end
end

function Controller:StageSection(root)
	-- Anchors live inside Stage so the demo follows when the stage is moved.
	local stage = root:WaitForChild("Stage")
	local anchors = stage:FindFirstChild("Anchors") or root:WaitForChild("Anchors")
	local section = { Center = stage:GetPivot().Position, UsesAvatar = true }
	local emitters = {}
	for _, obj in stage:GetDescendants() do
		if obj:GetAttribute("ShowcaseEmitter") then
			table.insert(emitters, obj)
		end
	end
	local plaque = stage:FindFirstChild("PlaqueFlyer")
	local point = plaque and plaque:FindFirstChild("PromptPoint")
	if point then
		self:Prompt(point, S.FeaturedPrompt)
	end
	self.Countdown = stage:FindFirstChild("Countdown", true)
	function section.Build()
		section.Active = true
		section.Folder = sectionFolder("Stage")
		local spot = anchors.CarriageSpot.CFrame
		section.Carriage = Ride.new(section.Folder, S.Featured.Flyer, spot, self.Avatar)
		local source = RS.Assets.Glassies:FindFirstChild(S.Featured.Glassy)
		if source then
			local glassy = still(source:Clone())
			local shards = glassy:FindFirstChild("Shards")
			if shards then
				shards:Destroy()
			end
			glassy:ScaleTo(S.Glassy.Scale)
			glassy.Name, glassy.Parent = "ShowcaseGlassy", section.Folder
			section.Glassy = glassy
		end
		section.Demo = buildDemo(section.Folder, anchors)
	end
	function section.Teardown()
		section.Active = false
		if section.Carriage then
			section.Carriage:Destroy()
		end
		toggleEmitters(emitters, false)
		section.EmittersOn = false
		section.Folder:Destroy()
		section.Carriage, section.Glassy, section.Demo = nil, nil, nil
	end
	function section.Step(_, now, distance)
		local near = distance <= S.EmitterDistance
		if section.EmittersOn ~= near then
			section.EmittersOn = near
			toggleEmitters(emitters, near)
		end
		if section.Carriage then
			local yaw = math.sin(now * S.Carriage.YawHz * TAU) * S.Carriage.YawSway
			section.Carriage:Step(now, anchors.CarriageSpot.CFrame * CFrame.Angles(0, yaw, 0), near)
		end
		if section.Glassy then
			local G = S.Glassy
			section.Glassy:PivotTo(
				anchors.GlassySpot.CFrame
					* CFrame.new(0, math.sin(now * G.BobHz * TAU) * G.Bob, 0)
					* CFrame.Angles(0, now * G.SpinSpeed, 0)
			)
		end
		if section.Demo then
			self:StepDemo(section.Demo, now, distance, section.Folder)
		end
	end
	return section
end

-- ── Flyers display: example rides with the player's avatar aboard ───────────────────────────────
function Controller:FlyersSection(root)
	local display = root:WaitForChild("FlyersDisplay")
	local section = { Center = display:GetPivot().Position, UsesAvatar = true, Slots = {} }
	local R = S.FlyerRotation
	-- Every flyer with installed art, in catalog order (seasonal ones included).
	local ids = {}
	for _, def in Cosmetics.catalog("Rideables") do
		if rideSource(def.Id) then
			table.insert(ids, def.Id)
		end
	end
	local function flash(slot)
		local ring = invisible(
			"SwapRing",
			slot.Spot * CFrame.new(0, 0.4 - slot.Spot.Y, 0) * CFrame.Angles(0, 0, math.rad(90)),
			section.Folder
		)
		ring.Shape, ring.Material, ring.Color, ring.Transparency =
			Enum.PartType.Cylinder, Enum.Material.Neon, Color3.fromHex(R.FlashColor), 0.2
		ring.Size = Vector3.new(0.12, 1, 1)
		TweenService
			:Create(ring, TweenInfo.new(R.TransitionSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = Vector3.new(0.12, R.FlashSize, R.FlashSize),
				Transparency = 1,
			})
			:Play()
		Debris:AddItem(ring, R.TransitionSeconds)
	end
	function section.Build()
		section.Active = true
		section.Folder = sectionFolder("Flyers")
		section.Slots = {}
		local now = os.clock()
		for i = 1, R.Slots do
			local spot = display:FindFirstChild("RiderSpot" .. i)
			if spot then
				-- Slots start spread through the list and swap half a cycle apart.
				table.insert(section.Slots, {
					Spot = spot.CFrame,
					Index = math.floor((i - 1) * #ids / R.Slots),
					Next = now + (i - 1) * R.Seconds / R.Slots,
					Phase = i * 1.7,
				})
			end
		end
	end
	function section.Teardown()
		section.Active = false
		for _, slot in section.Slots do
			for _, ride in { slot.Ride, slot.Leaving } do
				if ride then
					ride:Destroy()
				end
			end
		end
		section.Folder:Destroy()
		section.Slots = {}
	end
	function section.Step(_, now, distance)
		local near = distance <= S.EmitterDistance
		for _, slot in section.Slots do
			if now >= slot.Next and #ids > 0 then
				-- Swap: the current flyer zooms up and away, the next one drops onto the pad.
				if slot.Leaving then
					slot.Leaving:Destroy()
				end
				slot.Leaving, slot.LeftAt = slot.Ride, now
				slot.Index = slot.Index % #ids + 1
				slot.Ride, slot.Born, slot.Next =
					Ride.new(section.Folder, ids[slot.Index], slot.Spot, self.Avatar, now), now, now + R.Seconds
				if near then
					flash(slot)
				end
			end
			local sway = CFrame.Angles(0, math.sin(now * S.RiderYawHz * TAU + slot.Phase) * S.RiderYawSway, 0)
			if slot.Leaving then
				local t = (now - slot.LeftAt) / R.TransitionSeconds
				if t >= 1 then
					slot.Leaving:Destroy()
					slot.Leaving = nil
				else
					local lift = t * t
					slot.Leaving:Step(
						now,
						slot.Spot * CFrame.new(0, lift * R.LeaveRise, -lift * R.LeaveForward) * sway,
						near
					)
				end
			end
			if slot.Ride then
				local arrive = ease((now - slot.Born) / R.TransitionSeconds)
				local drop = CFrame.new(0, (1 - arrive) * R.ArriveDrop, 0)
					* CFrame.Angles(0, (1 - arrive) * R.ArriveSpin, 0)
				slot.Ride:Step(now, slot.Spot * drop * sway, near)
			end
		end
	end
	return section
end

-- ── Capsule bay: machine (or placeholder), shop prompt and floating examples per stand ──────────
function Controller:BaySection(root)
	local bay = root:WaitForChild("CapsuleBay")
	local section = { Center = bay:GetPivot().Position, Stands = {} }
	local emitters = {}
	for _, stand in bay:GetChildren() do
		local category = stand:GetAttribute("Category")
		local conf = category and S.Stands[category]
		if not conf then
			continue
		end
		local entry =
			{ Model = stand, Category = category, Spot = stand:WaitForChild("ExampleSpot").CFrame, Next = 0, Index = 0 }
		-- The build script places the crate-machines template as "Machine"; otherwise a placeholder.
		local machine = stand:FindFirstChild("Machine") or stand:FindFirstChild("MachinePlaceholder")
		local point = machine and machine:FindFirstChild("PromptPoint", true)
		for _, obj in stand:GetDescendants() do
			if obj:GetAttribute("ShowcaseEmitter") then
				table.insert(emitters, obj)
			end
		end
		if point then
			self:Prompt(point, conf)
		end
		table.insert(section.Stands, entry)
	end
	function section.Build()
		section.Active = true
		section.Folder = sectionFolder("CapsuleBay")
		for _, entry in section.Stands do
			entry.Next, entry.Index = 0, 0
		end
	end
	function section.Teardown()
		section.Active = false
		toggleEmitters(emitters, false)
		section.EmittersOn = false
		for _, entry in section.Stands do
			if entry.Ride then
				entry.Ride:Destroy()
				entry.Ride = nil
			end
		end
		section.Folder:Destroy()
	end
	local flyers = { S.Featured.Flyer }
	function section.Step(_, now, distance)
		local near = distance <= S.EmitterDistance
		if section.EmittersOn ~= near then
			section.EmittersOn = near
			toggleEmitters(emitters, near)
		end
		for _, entry in section.Stands do
			if entry.Category == "Finishers" then
				if now >= entry.Next then
					entry.Next = now + S.FinisherExampleSeconds
					entry.Index = entry.Index % #S.ExampleFinishers + 1
					if distance <= S.EmitterDistance then
						FinisherFX.emit(section.Folder, S.ExampleFinishers[entry.Index], entry.Spot.Position, true)
					end
				end
			elseif S.FlyerStandExample then
				if now >= entry.Next then
					entry.Next, entry.Born = now + S.FlyerExampleSeconds, now
					entry.Index = entry.Index % #flyers + 1
					if entry.Ride then
						entry.Ride:Destroy()
					end
					entry.Ride = Ride.new(section.Folder, flyers[entry.Index], entry.Spot, nil)
				end
				if entry.Ride then
					-- Each new flyer swoops up into place, then turns slowly.
					local rise = (1 - ease((now - entry.Born) / S.FlyerExampleRise)) * S.FlyerExampleDrop
					local spin = CFrame.Angles(0, now * S.FlyerExampleSpin, 0)
					entry.Ride:Step(now, entry.Spot * CFrame.new(0, -rise, 0) * spin, near)
				end
			end
		end
	end
	return section
end

function Controller:UpdateCountdown()
	if not self.Countdown then
		return
	end
	local ok, store = pcall(require, RS.Shared.Config.DailyStore)
	local endsAt
	for _, bundle in ok and store.Bundles or {} do
		if bundle.Id == S.Featured.BundleId then
			endsAt = bundle.EndsAt
		end
	end
	local left = if type(endsAt) == "number" then endsAt - workspace:GetServerTimeNow() else nil
	if left and left > 0 then
		local days, hours, minutes = left // 86400, left % 86400 // 3600, left % 3600 // 60
		self.Countdown.Text = if days > 0
			then string.format("ENDS IN %dd %dh", days, hours)
			else string.format("ENDS IN %dh %02dm", hours, minutes)
	else
		self.Countdown.Text = S.Featured.LimitedText
	end
end

function Controller:Start()
	local root = workspace:WaitForChild("FeaturedShowcase", 30)
	if not root then
		return
	end
	self.Player.CharacterAppearanceLoaded:Connect(function()
		self:RefreshAvatar()
	end)
	if self.Player.Character and self.Player:HasAppearanceLoaded() then
		self:RefreshAvatar()
	end
	for _, build in { self.StageSection, self.FlyersSection, self.BaySection } do
		local ok, section = pcall(build, self, root)
		if ok then
			table.insert(self.Sections, section)
		else
			warn("[GlassClash] Showcase section failed: " .. tostring(section))
		end
	end
	local pg = self.Player:WaitForChild("PlayerGui")
	local nextCountdown = 0
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now >= nextCountdown then
			nextCountdown = now + 1
			self:UpdateCountdown()
			-- Appearance can finish loading before this controller starts listening.
			if not self.Avatar and self.Player.Character and self.Player:HasAppearanceLoaded() then
				self:RefreshAvatar()
			end
		end
		if self.PendingTab then
			local screen = self.Controllers.LobbyController and self.Controllers.LobbyController.Screen
			if screen and screen.Pull and screen.SelectTab then
				screen:SelectTab(self.PendingTab)
				self.PendingTab = nil
			elseif now > self.PendingUntil then
				self.PendingTab = nil
			end
		end
		local away = pg:GetAttribute("InMatch") or pg:GetAttribute("Watching")
		local camera = workspace.CurrentCamera.CFrame.Position
		for _, section in self.Sections do
			local distance = (camera - section.Center).Magnitude
			local reach = if section.Active then S.ActiveDistance + S.Hysteresis else S.ActiveDistance
			local want = not away and distance <= reach
			if want ~= (section.Active == true) then
				if want then
					section.Build()
				else
					section.Teardown()
				end
			end
			if section.Active then
				section.Step(section, now, distance)
			end
		end
	end)
end

return Controller
