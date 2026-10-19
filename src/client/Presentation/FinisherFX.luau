-- Finisher shows: client-only, cosmetic, bounded. No Explosion instance, humanoid damage or world physics.
-- The five standard finishers are timed shows (Presentation/Finishers/*, tuning in Config/FinisherShows,
-- design in docs/vfx/FINISHERS_V2.md): gather -> peak -> release -> linger, driven by one Heartbeat clock.
-- Rigs are pooled per finisher and detail level; a rig whose root the caller destroys is simply dropped.
-- Lantern Eclipse is the seasonal show in HollowlightFX and is passed through unchanged.
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local C = require(RS.Shared.Config.RoundCosmetics)
local Shows = require(RS.Shared.Config.FinisherShows)
local Balance = require(RS.Shared.Config.Balance)
local Kit = require(script.Parent.Finishers.Kit)
local FX = {}

local modules = {}
local warned = {}
local function warnOnce(key, message)
	if not warned[key] then
		warned[key] = true
		warn("[FinisherFX] " .. message)
	end
end
-- A show module that is missing or fails to load falls back to Prism Pop, so Play stays clean.
local function module(name)
	local m = modules[name]
	if not m then
		local source = script.Parent:FindFirstChild("Finishers") and script.Parent.Finishers:FindFirstChild(name)
		local ok, result = pcall(function()
			return require(source)
		end)
		if ok and type(result) == "table" then
			m = result
		else
			warnOnce(name, "show " .. name .. " unavailable: " .. tostring(result))
			m = if name ~= "PrismPop" then module("PrismPop") else { build = function() end, step = function() end }
		end
		modules[name] = m
	end
	return m
end

local function showFor(id)
	local show = Shows.Shows[id]
	if show then
		return id, show
	end
	local def = C.ByCategory.Finishers[id] or C.Finishers[1]
	return def.Id, Shows.Shows[def.Id] or Shows.Shows.glass_burst
end

-- Seconds from the show start to its impact beat. FightFinisher starts the show this early so the peak lands
-- on the winner's impact. Lantern Eclipse (and anything unknown) starts at the impact.
function FX.leadIn(id)
	local show = id and Shows.Shows[id]
	return if show then show.PeakAt else 0
end

-- Full length of a show including its tail, for previews that wait for it to finish.
function FX.duration(id)
	if id == "" then
		return 0
	end
	if id == "lantern_eclipse" then
		return Balance.CosmeticPresentation.Eclipse.Duration + 0.6
	end
	local _, show = showFor(id)
	return show.Duration
end

local function setView(rig, origin, orientation)
	local look = (orientation or workspace.CurrentCamera.CFrame).LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	flat = if flat.Magnitude > 0.01 then flat.Unit else Vector3.zAxis
	-- x = screen right, y = up, z = toward the camera; Facing turns a part's Front toward the camera.
	rig.Origin = origin
	rig.View = CFrame.lookAt(origin, origin + flat)
	rig.Facing = rig.View * CFrame.Angles(0, math.pi, 0)
end

local function particleScale(lowDetail)
	local scale = 1
	if lowDetail then
		scale = Shows.LowDetailParticles
	elseif UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		scale = Shows.MobileParticles
	end
	return scale
end

local function frame(rig, show, t)
	rig:BeginFrame()
	local ok, err = pcall(function()
		module(show.Module).step(rig, t, show)
		rig:StepModules(t)
	end)
	if not ok then
		-- A broken frame ends the show quietly instead of erroring every Heartbeat.
		warnOnce(show.Module .. ":step", tostring(err))
		rig.Broken = true
		return
	end
	local moving, cfs = rig.Moving, rig.MovingCF
	if #moving > 0 then
		local world = rig.World
		if world then
			world:BulkMoveTo(moving, cfs, Enum.BulkMoveMode.FireCFrameChanged)
		else
			for i, p in moving do
				p.CFrame = cfs[i]
			end
		end
	end
	for _, entry in rig.Schedule do
		if not entry.Fired and t >= entry.At then
			entry.Fired = true
			entry.Run(rig)
		end
	end
end

-- Pool --------------------------------------------------------------------------------------------------------
local pools = {}
local live = setmetatable({}, { __mode = "k" }) -- show root -> rig, while it plays

local function build(id, show, lowDetail)
	local rig = Kit.rig(id, lowDetail, false)
	rig.Show = show
	rig.Key = id .. (if lowDetail then ":low" else ":full")
	-- Placeholder view until the first play sets the real one.
	setView(rig, Vector3.zero, CFrame.identity)
	local ok, err = pcall(module(show.Module).build, rig, show)
	if not ok then
		warnOnce(show.Module .. ":build", tostring(err))
		rig.Broken = true
	end
	rig.Root.Destroying:Once(function()
		rig.Dead = true
		if rig.Connection then
			rig.Connection:Disconnect()
			rig.Connection = nil
		end
		rig:DropGrade()
	end)
	return rig
end

local function acquire(id, show, lowDetail)
	local list = pools[id .. (if lowDetail then ":low" else ":full")]
	while list and #list > 0 do
		local rig = table.remove(list)
		if not rig.Dead then
			rig:Reset()
			return rig
		end
	end
	return build(id, show, lowDetail)
end

local function release(rig)
	if rig.Connection then
		rig.Connection:Disconnect()
		rig.Connection = nil
	end
	rig:Reset()
	if rig.Dead then
		return
	end
	if rig.Broken then
		rig.Root:Destroy()
		return
	end
	local list = pools[rig.Key]
	if not list then
		list = {}
		pools[rig.Key] = list
	end
	if #list < Shows.PoolPerFinisher then
		rig.Root.Parent = nil
		rig.World = nil
		table.insert(list, rig)
	else
		rig.Root:Destroy()
	end
end

--[[ Plays finisher `id` at `origin` under `parent`. Returns the show's root Instance (its lifetime owner).
	orientation: camera CFrame the show should face (default: the current camera).
	options.Post: allow the Legendary colour grade (fight view only).
	options.Feel: the fight's CombatFeel, for the peak shake/FOV punch (reduced motion handled there).]]
function FX.emit(parent, id, origin, lowDetail, orientation, options)
	if id == "lantern_eclipse" then
		return require(script.Parent.HollowlightFX).emit(parent, origin, lowDetail, orientation)
	end
	local showId, show = showFor(id)
	local opts = options or {}
	local rig = acquire(showId, show, lowDetail == true)
	setView(rig, origin, orientation)
	rig.ParticleScale = particleScale(lowDetail)
	local reduced = false
	pcall(function()
		reduced = require(script.Parent.Parent.UI.Components.Motion).reduced()
	end)
	rig.AllowPost = opts.Post == true and not reduced
	rig.Socket.CFrame = CFrame.new(origin)
	rig.Root.Parent = parent
	rig.World = rig.Root:FindFirstAncestorWhichIsA("WorldRoot")
	live[rig.Root] = rig
	local feel = opts.Feel
	-- Camera beats: the peak by default; Mythic shows add more (`Beats`, e.g. the second peak).
	local beats = show.Beats or { { At = show.PeakAt, Shake = show.Shake, Punch = show.Punch } }
	local fired = {}
	local start = os.clock()
	frame(rig, show, 0)
	rig.Connection = RunService.Heartbeat:Connect(function()
		if rig.Dead or not rig.Root.Parent then
			release(rig)
			return
		end
		local t = os.clock() - start
		if t >= show.Duration or rig.Broken then
			release(rig)
			return
		end
		frame(rig, show, t)
		for i, beat in beats do
			if not fired[i] and t >= beat.At then
				fired[i] = true
				if feel then
					if (beat.Shake or 0) > 0 then
						feel:Shake(beat.Shake)
					end
					if (beat.Punch or 0) ~= 0 then
						feel:Punch(beat.Punch)
					end
				end
			end
		end
	end)
	return rig.Root
end

-- Hands a playing show the shards of the winner's glassy (Emberwing lights them up at its second peak).
function FX.attachShards(root, shards)
	local rig = root and live[root]
	if rig then
		rig.ExternalShards = shards
	end
end

-- Builds a frozen frame of the show into `world` (a WorldModel/Model) for icons and portraits, facing the
-- portrait camera (or `orientation`), at its StillAt beat (or show time `at`, used by QA contact sheets).
-- Returns false for finishers without a standard show.
function FX.still(world, id, orientation, at)
	local show = Shows.Shows[id]
	if not show then
		return false
	end
	local rig = Kit.rig(id, false, true)
	rig.Show = show
	local ok = pcall(module(show.Module).build, rig, show)
	if not ok then
		rig.Root:Destroy()
		return false
	end
	setView(rig, Vector3.zero, orientation or CFrame.lookAt(Vector3.new(4, 2, 10), Vector3.zero))
	rig.Socket.CFrame = CFrame.new()
	rig:Freeze()
	frame(rig, show, at or show.StillAt)
	rig.Root.Parent = world
	return true
end

return FX
