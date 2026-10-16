-- Original Blender actors + native particles. No damage, avatar hiding or world physics.
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local FX = {}

function FX.pressure(parent, position)
	local seasonal = RS.Assets:FindFirstChild("Seasonal")
	local source = seasonal and seasonal:FindFirstChild("Hollowlight")
	if not source then
		return
	end
	local socket = source.HollowlightPrototype.Origin:Clone()
	socket.CFrame, socket.Parent = CFrame.new(position), parent
	local lifetime = 0
	for _, obj in socket:GetDescendants() do
		if obj:IsA("ParticleEmitter") then
			obj.Enabled = false
			if obj.Name == "ChargeWisps" or obj.Name == "LanternPressure" then
				obj:Emit(obj:GetAttribute("BurstCount"))
				lifetime = math.max(lifetime, obj.Lifetime.Max)
			end
		elseif obj:IsA("Beam") then
			obj.Enabled = false
		end
	end
	game:GetService("Debris"):AddItem(socket, lifetime)
	return socket
end

function FX.create(parent, origin, lowDetail, orientation)
	local seasonal = RS.Assets:FindFirstChild("Seasonal")
	local source = seasonal and seasonal:FindFirstChild("Hollowlight")
	if not source then
		return nil
	end
	local root = Instance.new("Folder")
	root.Name = "Finisher_lantern_eclipse"
	root:SetAttribute("CosmeticOnly", true)
	local model = source.lantern_eclipse:Clone()
	model.Parent = root
	local kit = source.HollowlightPrototype:Clone()
	kit.Parent = root
	local basis = CFrame.new(origin) * (orientation or CFrame.identity).Rotation
	kit.Origin.CFrame = basis
	local art = kit:GetAttributes()
	local duration = art.DurationSeconds
	local state =
		{ Root = root, Parts = {}, Emitters = {}, Beams = {}, WispHeads = {}, Duration = duration, Stopped = false }
	local linger = 0
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") then
			local actor = p.Name:match("Wisp(%d)") or p.Name:match("WispFace(%d)") or p.Name:match("WispTail(%d)")
			if lowDetail and ((actor and actor ~= "0") or p.Name:match("Spiral[12]") or p.Name == "InnerHalo") then
				p:Destroy()
			else
				local center = actor and source.lantern_eclipse["Wisp" .. actor].Position
				table.insert(
					state.Parts,
					{ Part = p, Pose = p.CFrame, Size = p.Size, Alpha = p.Transparency, Center = center }
				)
				if p.Name:match("^Wisp%d$") then
					table.insert(state.WispHeads, p)
				end
			end
		end
	end
	for _, obj in kit:GetDescendants() do
		if obj:IsA("ParticleEmitter") then
			obj.Enabled = false
			linger = math.max(linger, obj.Lifetime.Max)
			table.insert(state.Emitters, { Emitter = obj, At = obj:GetAttribute("PhaseStart"), Fired = false })
		elseif obj:IsA("Beam") then
			obj.Enabled = false
			table.insert(state.Beams, obj)
		end
	end
	state.Lifetime = duration + linger
	function state:Destroy()
		if self.Stopped then
			return
		end
		self.Stopped = true
		if self.Connection then
			self.Connection:Disconnect()
		end
		if self.DestroyConnection then
			self.DestroyConnection:Disconnect()
		end
		self.Root:Destroy()
	end
	function state:Step(elapsed)
		if self.Stopped then
			return
		end
		if not root.Parent or elapsed >= self.Lifetime then
			self:Destroy()
			return
		end
		local converge = math.clamp((elapsed - art.ConvergeStart) / (art.ReleaseAt - art.ConvergeStart), 0, 1)
		local release = math.clamp((elapsed - art.ReleaseAt) / (duration - art.ReleaseAt), 0, 1)
		local fade = math.clamp((elapsed - art.FadeAt) / (duration - art.FadeAt), 0, 1)
		for _, entry in self.Parts do
			local p, pose, scale = entry.Part, entry.Pose, 1
			local alpha = entry.Alpha + (1 - entry.Alpha) * fade
			if entry.Center then
				local center = entry.Center
				local radius = 1 - converge * (1 - art.ConvergeRadius) + release * release * (art.ScatterRadius - 1)
				local rotation = CFrame.Angles(0, elapsed * math.pi, 0)
				local position = rotation:VectorToWorldSpace(center * Vector3.new(radius, 1, radius))
				position += Vector3.yAxis * (math.sin(elapsed * math.pi * 2) * art.WispBob + release * art.WispRise)
				pose = CFrame.new(position) * rotation * CFrame.new(-center) * entry.Pose
			elseif p.Name:find("Halo") then
				scale = art.RingStartScale + converge * (1 - art.RingStartScale) + release * (art.RingEndScale - 1)
				pose = CFrame.new(entry.Pose.Position * scale) * entry.Pose.Rotation
			elseif p.Name:find("Spiral") then
				scale = 1 - converge * (1 - art.SpiralConvergeScale) + release * (art.SpiralEndScale - 1)
				pose = CFrame.Angles(0, -elapsed * math.pi, 0)
					* CFrame.new(entry.Pose.Position * scale)
					* entry.Pose.Rotation
			else
				scale = art.CoreStartScale + converge * (1 - art.CoreStartScale) + release * (art.CoreEndScale - 1)
				pose = CFrame.new(entry.Pose.Position * scale) * entry.Pose.Rotation
				alpha = math.max(alpha, math.clamp(release * art.CoreFadeSpeed, 0, 1))
			end
			p.CFrame, p.Size, p.Transparency = basis * pose, entry.Size * scale, alpha
		end
		for _, entry in self.Emitters do
			if not entry.Fired and elapsed >= entry.At then
				entry.Fired = true
				entry.Emitter:Emit(
					math.max(
						1,
						math.floor(
							entry.Emitter:GetAttribute("BurstCount")
								/ (if lowDetail then art.ReducedParticleDivisor else 1)
						)
					)
				)
			end
		end
		for i, beam in self.Beams do
			beam.Enabled = not lowDetail
				and elapsed >= beam:GetAttribute("PhaseStart")
				and elapsed < beam:GetAttribute("PhaseEnd")
			local head = self.WispHeads[i]
			if head then
				beam.Attachment0.WorldPosition = basis.Position + Vector3.yAxis
				beam.Attachment1.WorldPosition = head.Position
			end
		end
	end
	state.DestroyConnection = root.Destroying:Connect(function()
		state.Stopped = true
		if state.Connection then
			state.Connection:Disconnect()
		end
		state.DestroyConnection:Disconnect()
	end)
	root.Parent = parent
	state:Step(0)
	return state
end

function FX.emit(parent, origin, lowDetail, orientation)
	local state = FX.create(parent, origin, lowDetail, orientation)
	if not state then
		return nil
	end
	local start = os.clock()
	state.Connection = RunService.Heartbeat:Connect(function()
		state:Step(os.clock() - start)
	end)
	return state.Root
end

return FX
