-- Cosmetic sequence only: never damages a Humanoid or changes server hearts/rewards.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local Feel = require(RS.Shared.Config.Balance).Feel
local Finish = {}
local FinisherFX = require(script.Parent.FinisherFX)
local Cosmetics = require(RS.Shared.Config.RoundCosmetics)
local Shows = require(RS.Shared.Config.FinisherShows)
local FinisherAudio = require(script.Parent.FinisherAudio)
local LocalSettings = require(script.Parent.Parent.LocalSettings)
Finish.__index = Finish

function Finish.new(scene, loser, now)
	local winner = scene.Fighters[3 - loser]
	scene:HideGhost()
	if winner.Broken then
		return nil
	end
	winner.Finishing = true
	winner.Health.Enabled = false
	winner.Beam.Enabled, winner.Highlight.Enabled = false, false
	winner.Bubble.Transparency = 1
	winner.Glints.Rate = 0
	winner.Glints:Emit(Feel.VictoryGlints)
	local start = winner.Model:GetPivot()
	local positions = if scene.Viewing then scene.Data.AvatarPositions else scene.Data.HeartPositions
	local target = (positions and positions[loser] or scene.Fighters[loser].Body.Position) + Vector3.yAxis
	return setmetatable({
		Scene = scene,
		Loser = loser,
		Winner = winner,
		At = now,
		Start = start,
		Lift = start + Vector3.yAxis * Feel.FinisherRiseHeight,
		Target = target,
	}, Finish)
end

function Finish:Avatar()
	local data = self.Scene.Data
	local id = data.PlayerIds and data.PlayerIds[self.Loser]
	local player = id and id > 0 and Players:GetPlayerByUserId(id)
	if player then
		return player.Character
	end
	local folder = data.StageName and workspace:FindFirstChild(data.StageName)
	return folder and folder:FindFirstChild("Bot" .. self.Loser)
end

function Finish:Id()
	local data = self.Scene.Data
	-- Hide Others' Cosmetics (decision 99): another player's win plays the basic glass break, no show.
	local winnerId = data.PlayerIds and data.PlayerIds[3 - self.Loser]
	if LocalSettings.hideOthers() and winnerId ~= Players.LocalPlayer.UserId then
		return ""
	end
	local finishers = data.Finishers
	local id = finishers and finishers[3 - self.Loser]
	-- Catalog finishers, plus any id with a show (Studio QA can send shows that aren't in the catalog).
	if id and (Cosmetics.ByCategory.Finishers[id] or Shows.Shows[id]) then
		return id
	end
	-- "" = nothing equipped (decision 95): the winner still flies in and breaks, with no show.
	if id == "" then
		return ""
	end
	return Cosmetics.Finishers[1].Id
end

-- Rise/Fly cues follow the winner; the burst cue sits at the impact point. Only your own fight plays them
-- (creator note): finishers in other arenas, spectated fights and the lobby stay silent.
function Finish:Cue(phase, emitter)
	local scene = self.Scene
	if not scene.Muted and scene.OwnFight then
		FinisherAudio.phase(scene.Root, self:Id(), phase, emitter, { Quiet = not scene.Viewing })
	end
end

-- Starts the finisher show at the impact point. Standard shows start FinisherFX.leadIn seconds before the
-- winner lands so their gather plays during the flight and their peak lands on the impact.
function Finish:StartShow()
	if self.ShowStarted then
		return
	end
	self.ShowStarted = true
	local scene = self.Scene
	local id = self:Id()
	local anchor = Instance.new("Part")
	anchor.Name, anchor.Size, anchor.Transparency = "FinisherAudio", Vector3.one * 0.1, 1
	anchor.Anchored, anchor.CanCollide, anchor.CanTouch, anchor.CanQuery = true, false, false, false
	anchor.Position, anchor.Parent = self.Target, scene.Root
	Debris:AddItem(anchor, math.max(Feel.FinisherFallbackSeconds, FinisherFX.duration(id) + 1.2))
	if id == "" then
		return
	end
	self:Cue("Burst", anchor)
	self.ShowRoot = FinisherFX.emit(scene.Root, id, self.Target, not scene.Viewing, nil, {
		Post = scene.Viewing,
		Feel = if scene.Viewing then scene.Feel else nil,
	})
end

function Finish:Impact()
	local scene = self.Scene
	self:StartShow()
	local color = self.Winner.Body.Color
	self.Winner.Trail.Enabled = false
	self.Winner.Pivot = self.Winner.Model:GetPivot()
	local before = {}
	for _, shard in scene.Shatter.Shards or {} do
		before[shard] = true
	end
	scene.Shatter:Break(self.Winner, scene.Root)
	local fresh = {}
	for _, shard in scene.Shatter.Shards or {} do
		if not before[shard] then
			table.insert(fresh, shard)
		end
	end
	FinisherFX.attachShards(self.ShowRoot, fresh)
	local avatar = scene.Viewing and self:Avatar()
	if avatar then
		local flash = Instance.new("Highlight")
		flash.Name, flash.Adornee = "GlassyImpact", avatar
		flash.FillColor, flash.OutlineColor = color, color
		-- Outline only: a fill coated the whole character in a see-through "glass copy" (creator note 2026-10-20).
		flash.FillTransparency, flash.OutlineTransparency = 1, 0.1
		flash.Parent = scene.Root
		TweenService
			:Create(flash, TweenInfo.new(Feel.FinisherImpactSeconds), { FillTransparency = 1, OutlineTransparency = 1 })
			:Play()
		Debris:AddItem(flash, Feel.FinisherImpactSeconds)
	end
	local random = Random.new()
	for _, original in avatar and avatar:GetDescendants() or {} do
		if original:IsA("BasePart") and original.Name ~= "HumanoidRootPart" and original.Transparency < 1 then
			-- Small toy chips echo the shattered glassy without killing the actual character. Matte on purpose: big Glass
			-- blocks over each body part kept reflecting while they faded and read as a ghost copy of the glass.
			do
				local shard = Instance.new("Part")
				shard.Name, shard.Material, shard.Color = "AvatarGlassShard", Enum.Material.SmoothPlastic, color
				shard.Reflectance, shard.CastShadow = 0, false
				local edge = math.clamp(math.min(original.Size.X, original.Size.Y, original.Size.Z) * 0.35, 0.15, 0.45)
				shard.Size = Vector3.new(edge, edge * 0.6, edge)
				shard.CFrame = original.CFrame
					* CFrame.new(random:NextNumber(-0.3, 0.3), 0, 0)
					* CFrame.Angles(random:NextNumber(0, 6.28), random:NextNumber(0, 6.28), 0)
				shard.Transparency, shard.CanCollide, shard.CanTouch, shard.CanQuery = 0.1, false, false, false
				shard.Parent = scene.Root
				shard.AssemblyLinearVelocity = Vector3.new(
					random:NextNumber(-1, 1),
					random:NextNumber(0.3, 1),
					random:NextNumber(-1, 1)
				) * Feel.ShardSpeed
				shard.AssemblyAngularVelocity = Vector3.one * Feel.ShardSpin
				TweenService:Create(shard, TweenInfo.new(Feel.FinisherImpactSeconds), { Transparency = 1 }):Play()
				Debris:AddItem(shard, Feel.FinisherImpactSeconds)
			end
		end
	end
	scene:Heart(self.Loser)
end

function Finish:Step(now)
	if self.Done then
		return false
	end
	local t = now - self.At - Feel.FinisherPause
	if t < 0 then
		return false
	end
	if not self.RiseCued then
		self.RiseCued = true
		self:Cue("Rise", self.Winner.Body)
	end
	local rise = math.clamp(t / Feel.FinisherRiseSeconds, 0, 1)
	local fly = math.clamp((t - Feel.FinisherRiseSeconds) / Feel.FinisherFlySeconds, 0, 1)
	local pose = self.Start:Lerp(self.Lift, 1 - (1 - rise) ^ 3)
	local landsIn = Feel.FinisherRiseSeconds + Feel.FinisherFlySeconds - t
	if landsIn <= FinisherFX.leadIn(self:Id()) then
		self:StartShow()
	end
	if fly > 0 then
		if not self.FlyCued then
			self.FlyCued = true
			self:Cue("Fly", self.Winner.Body)
		end
		self.Winner.Trail.Enabled = true
		local destination = CFrame.new(self.Target) * self.Lift.Rotation
		pose = self.Lift:Lerp(destination, fly * fly * fly)
	end
	self.Winner.Model:PivotTo(pose)
	if fly >= 1 then
		self.Done = true
		self:Impact()
		return true
	end
	return false
end

function Finish:Destroy()
	-- All impact effects belong to Scene.Root; the real avatar is never modified.
end
return Finish
