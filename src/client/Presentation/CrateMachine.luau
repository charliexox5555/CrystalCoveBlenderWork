-- Animates a Crate Machine v2 model (Burst Dome / Cloud Globe) wherever it is: inside a ViewportFrame
-- WorldModel (shop preview, opening stage) or placed in the lobby. Client-only, CFrame-driven, no physics.
-- Parts describe their own motion with attributes set by tools/studio/install_crate_machines_v2.luau:
--   Idle = "Spin" | "Orbit" | "Swirl" | "Bob" | "Blink" | "Crank", SpinAxis (Vector3), SpinSpeed, Lid (bool).
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local Config = require(RS.Shared.Config.CrateMachines)
local O, I = Config.Opening, Config.Idle

local Machine = {}
Machine.__index = Machine

local WHITE = Color3.new(1, 1, 1)
local viewports = setmetatable({}, { __mode = "k" })

function Machine.isMachine(model: Instance?): boolean
	return model ~= nil and model:IsA("Model") and model:GetAttribute("CrateMachineVersion") ~= nil
end

function Machine.template(category: string, currency: string): Model?
	local folder = RS:FindFirstChild("Assets") and RS.Assets:FindFirstChild("CrateMachines")
	local model = folder and folder:FindFirstChild(Config.templateName(category, currency))
	return if model and model:IsA("Model") then model else nil
end

function Machine.new(model: Model)
	local base = model:GetPivot()
	local core = model:FindFirstChild("RevealCore") :: BasePart?
	local chamber = model:FindFirstChild("GlassChamber") :: BasePart?
	local lid = model:FindFirstChild("RevealLid") :: BasePart?
	local self = setmetatable({
		Model = model,
		Base = base,
		Core = core,
		Parts = {},
		Time = 0,
		Charge = 0,
		Release = 0,
		Shaking = false,
	}, Machine)
	self.CoreRel = if core then base:PointToObjectSpace(core.Position) else Vector3.zero
	self.ChamberRel = if chamber then base:PointToObjectSpace(chamber.Position) else self.CoreRel
	self.LidRel = if lid then base:PointToObjectSpace(lid.Position) else self.CoreRel
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") and p.Name ~= "Root" then
			local idle = p:GetAttribute("Idle")
			table.insert(self.Parts, {
				Part = p,
				Rel = base:ToObjectSpace(p.CFrame),
				Idle = idle,
				Axis = (p:GetAttribute("SpinAxis") or Vector3.yAxis).Unit,
				Speed = p:GetAttribute("SpinSpeed")
					or (if idle == "Swirl" then I.SwirlSpeed elseif idle == "Orbit" then I.OrbitSpeed else 0),
				Lid = p:GetAttribute("Lid") == true,
				Color = p.Color,
				Size = p.Size,
				Angle = 0,
				Moves = idle ~= nil or p:GetAttribute("Lid") == true or p == core,
			})
		end
	end
	return self
end

-- charge: 0..1 anticipation, release: 0..1 lid opening/reveal. Both 0 = plain idle.
function Machine:SetOpening(charge: number, release: number)
	self.Charge, self.Release = math.clamp(charge, 0, 1), math.clamp(release, 0, 1)
end

function Machine:Reset()
	self:SetOpening(0, 0)
	self:Step(0)
end

function Machine:Step(dt: number)
	self.Time += dt
	local t, charge, release = self.Time, self.Charge, self.Release
	-- Contents race during anticipation and settle back once the lid is open.
	local energy = 1 + charge * (1 - release * 0.75) * O.SpinBoost
	local shakeAmount = O.ShakeStuds * charge * (1 - release)
	local shake = CFrame.identity
	if shakeAmount > 0.001 then
		shake = CFrame.new(
			math.noise(t * 23, 1.3) * shakeAmount * 2,
			math.noise(t * 23, 5.1) * shakeAmount,
			math.noise(t * 23, 9.7) * shakeAmount * 2
		)
	end
	local writeAll = shakeAmount > 0.001 or self.Shaking
	self.Shaking = shakeAmount > 0.001
	local lift = release ^ 0.55 * O.LidLiftStuds
	local lidPose = CFrame.new(self.LidRel + Vector3.yAxis * lift)
		* CFrame.Angles(0, release * O.LidTurns * math.pi * 2, math.sin(release * math.pi) * 0.25)
		* CFrame.new(-self.LidRel)
	local glow = charge * (1 - release)
	local flash = math.sin(math.clamp(release * 1.6, 0, 1) * math.pi)
	local base = self.Base * shake
	for _, e in self.Parts do
		if not (e.Moves or writeAll) then
			continue
		end
		local rel, idle = e.Rel, e.Idle
		local boost = if e.Lid then energy + release * O.PropellerBoost else energy
		e.Angle += dt * e.Speed * boost
		if idle == "Spin" then
			rel = CFrame.new(rel.Position) * CFrame.fromAxisAngle(e.Axis, e.Angle) * rel.Rotation
		elseif idle == "Orbit" or idle == "Swirl" then
			local center = if idle == "Orbit" then self.CoreRel else self.ChamberRel
			local wobble = if idle == "Swirl"
				then CFrame.Angles(math.sin(t * 0.7) * 0.06 * energy, 0, 0)
				else CFrame.identity
			rel = CFrame.new(center) * CFrame.Angles(0, e.Angle, 0) * wobble * CFrame.new(-center) * rel
		elseif idle == "Bob" then
			rel = rel + Vector3.yAxis * math.sin(t * I.BobSpeed * energy) * I.BobStuds
		elseif idle == "Crank" then
			local angle = t * I.CrankIdleSpeed + charge * O.CrankTurns * math.pi * 2
			rel = CFrame.new(rel.Position) * CFrame.fromAxisAngle(e.Axis, angle) * rel.Rotation
		elseif idle == "Blink" then
			e.Part.Color = e.Color:Lerp(WHITE, (math.sin(t * I.BlinkSpeed * energy) + 1) * 0.3)
		end
		if e.Lid then
			rel = lidPose * rel
		end
		if e.Part == self.Core then
			local pulse = (math.sin(t * I.PulseSpeed) + 1) * 0.04
			e.Part.Size = e.Size * (1 + pulse + O.CoreGrow * glow + flash * 0.35)
			e.Part.Color = e.Color:Lerp(WHITE, math.clamp(glow * 0.8 + flash, 0, 1))
		end
		e.Part.CFrame = base * rel
	end
end

function Machine:Destroy()
	for _, e in self.Parts do
		if e.Part.Parent then
			e.Part.CFrame, e.Part.Color, e.Part.Size = self.Base * e.Rel, e.Color, e.Size
		end
	end
	table.clear(self.Parts)
end

-- Runs the idle loop for a machine shown in a ViewportFrame until the viewport is removed.
function Machine.attachViewport(viewport: ViewportFrame, model: Model)
	local old = viewports[viewport]
	if old then
		old.Connection:Disconnect()
	end
	local machine = Machine.new(model)
	local gui = viewport:FindFirstAncestorWhichIsA("LayerCollector")
	machine.Connection = RunService.RenderStepped:Connect(function(dt)
		if not viewport.Parent or not model.Parent then
			machine.Connection:Disconnect()
			viewports[viewport] = nil
			return
		end
		gui = gui or viewport:FindFirstAncestorWhichIsA("LayerCollector")
		if viewport.Visible and viewport.AbsoluteSize.X > 0 and (not gui or gui.Enabled) then
			machine:Step(math.min(dt, 0.1))
		end
	end)
	viewports[viewport] = machine
	return machine
end

function Machine.forViewport(viewport: Instance)
	return viewports[viewport]
end

return Machine
