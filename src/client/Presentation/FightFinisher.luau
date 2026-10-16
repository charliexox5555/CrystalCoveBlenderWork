-- Cosmetic sequence only: never damages a Humanoid or changes server hearts/rewards.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local Feel = require(RS.Shared.Config.Balance).Feel
local Finish = {}
local FinisherFX = require(script.Parent.FinisherFX)
local Cosmetics = require(RS.Shared.Config.RoundCosmetics)
local Audio = require(RS.Shared.Config.Audio)
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

function Finish:Impact()
	local scene = self.Scene
	local finishers = scene.Data.Finishers
	local def = Cosmetics.ByCategory.Finishers[finishers and finishers[3 - self.Loser] or "glass_burst"]
		or Cosmetics.Finishers[1]
	scene:Sound(Audio[def.Sound], self.Winner.Body)
	FinisherFX.emit(
		scene.Root,
		finishers and finishers[3 - self.Loser] or "glass_burst",
		self.Target,
		not scene.Viewing
	)
	local color = self.Winner.Body.Color
	self.Winner.Trail.Enabled = false
	self.Winner.Pivot = self.Winner.Model:GetPivot()
	scene.Shatter:Break(self.Winner, scene.Root)
	local avatar = scene.Viewing and self:Avatar()
	if avatar then
		local flash = Instance.new("Highlight")
		flash.Name, flash.Adornee = "GlassyImpact", avatar
		flash.FillColor, flash.OutlineColor = color, color
		flash.FillTransparency, flash.OutlineTransparency = 0.7, 0.1
		flash.Parent = scene.Root
		TweenService
			:Create(flash, TweenInfo.new(Feel.FinisherImpactSeconds), { FillTransparency = 1, OutlineTransparency = 1 })
			:Play()
		Debris:AddItem(flash, Feel.FinisherImpactSeconds)
	end
	local random = Random.new()
	for _, original in avatar and avatar:GetDescendants() or {} do
		if original:IsA("BasePart") and original.Name ~= "HumanoidRootPart" and original.Transparency < 1 then
			-- Toy glass fragments echo the shattered glassy without killing the actual character.
			for _ = 1, 2 do
				local shard = Instance.new("Part")
				shard.Name, shard.Material, shard.Color = "AvatarGlassShard", Enum.Material.Glass, color
				shard.Size = original.Size * 0.4
				shard.CFrame = original.CFrame * CFrame.new(random:NextNumber(-0.3, 0.3), 0, 0)
				shard.Transparency, shard.CanCollide, shard.CanTouch, shard.CanQuery = 0.15, false, false, false
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
	local rise = math.clamp(t / Feel.FinisherRiseSeconds, 0, 1)
	local fly = math.clamp((t - Feel.FinisherRiseSeconds) / Feel.FinisherFlySeconds, 0, 1)
	local pose = self.Start:Lerp(self.Lift, 1 - (1 - rise) ^ 3)
	if fly > 0 then
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
