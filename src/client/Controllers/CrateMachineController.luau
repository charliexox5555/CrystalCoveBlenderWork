-- Lobby ambience for placed Crate Machines (models tagged "CrateMachine" in Workspace).
-- Client-only: machines near the local player idle-animate and get a pooled light + sparkle emitter;
-- far machines are restored to their authored pose and their effects go back to the pool.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local Config = require(RS.Shared.Config.CrateMachines)
local W = Config.World

local Controller = {}
local active = {}
local pool = {}

local function takeEffects()
	local fx = table.remove(pool)
	if fx then
		return fx
	end
	local light = Instance.new("PointLight")
	light.Name, light.Range, light.Brightness, light.Shadows =
		"CrateMachineLight", W.LightRange, W.LightBrightness, false
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "CrateMachineSparkle"
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Rate = W.SparkleRate
	emitter.Lifetime = NumberRange.new(0.6, 1.2)
	emitter.Speed = NumberRange.new(0.4, 1.2)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	emitter.LightEmission, emitter.LockedToPart = 1, true
	return { Light = light, Emitter = emitter }
end

local function deactivate(model)
	local entry = active[model]
	if not entry then
		return
	end
	active[model] = nil
	entry.Machine:Destroy()
	if entry.Effects then
		entry.Effects.Light.Parent, entry.Effects.Emitter.Parent = nil, nil
		table.insert(pool, entry.Effects)
	end
end

local function activate(model)
	if active[model] or not model:IsA("Model") or not model:IsDescendantOf(workspace) then
		return
	end
	local Machine = require(script.Parent.Parent.Presentation.CrateMachine)
	local entry = { Machine = Machine.new(model) }
	local core = model:FindFirstChild("RevealCore")
	if core and core:IsA("BasePart") then
		local fx = takeEffects()
		fx.Light.Color, fx.Emitter.Color = core.Color, ColorSequence.new(core.Color, Color3.new(1, 1, 1))
		fx.Light.Parent = core
		fx.Emitter.Parent = core:FindFirstChild("LaunchPoint") or core
		entry.Effects = fx
	end
	active[model] = entry
end

local function scan()
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	for _, model in CollectionService:GetTagged(Config.Tag) do
		if model:IsA("Model") and model:IsDescendantOf(workspace) then
			local near = root ~= nil and (model:GetPivot().Position - root.Position).Magnitude <= W.ActiveDistance
			if near then
				activate(model)
			else
				deactivate(model)
			end
		end
	end
end

function Controller:Start()
	CollectionService:GetInstanceRemovedSignal(Config.Tag):Connect(deactivate)
	RunService.RenderStepped:Connect(function(dt)
		dt = math.min(dt, 0.1)
		for model, entry in active do
			if model.Parent then
				entry.Machine:Step(dt)
			else
				deactivate(model)
			end
		end
	end)
	while true do
		scan()
		task.wait(W.ScanSeconds)
	end
end

return Controller
