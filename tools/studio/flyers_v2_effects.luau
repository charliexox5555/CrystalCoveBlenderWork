-- Ride effects on the current (v2) flyer meshes, until the v3 meshes are uploaded (FLYERS_V3.md).
-- Edit mode only, through the Studio MCP, with tools/studio/flyer_effects.luau prepended.
-- Backs up each template once to ServerStorage.FlyersBeforeV3, removes effects from an earlier run of
-- this script (attribute FlyersV2FX), then adds attachments + the shared EFFECTS. Positions are in the
-- template's pivot space (contact point at the origin, nose toward -Z), measured from the v2 meshes.
assert(not game:GetService("RunService"):IsRunning(), "Install in Edit")
local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")
local backups = SS:FindFirstChild("FlyersBeforeV3")
if not backups then
	backups = Instance.new("Folder")
	backups.Name, backups.Parent = "FlyersBeforeV3", SS
end

local V2 = {
	skyboard = {
		Parts = { Rail = "SculptedRails", Deck = "Deck" },
		Attachments = {
			TrailR0 = { "Rail", 1.55, 0.05, 2.55 },
			TrailR1 = { "Rail", 1.55, -0.3, 2.55 },
			TrailL0 = { "Rail", -1.55, 0.05, 2.55 },
			TrailL1 = { "Rail", -1.55, -0.3, 2.55 },
			PodF = { "Deck", 0, -0.75, -1.1 },
			PodB = { "Deck", 0, -0.75, 1.5 },
			Wake = { "Deck", 0, 0.25, -3.2 },
			Launch = { "Deck", 0, -0.9, 0 },
		},
	},
	cloud_cushion = {
		Parts = { CloudBody = "SculptedCloud", RainbowButter = "Rainbow1" },
		Attachments = {
			Trail0 = { "RainbowButter", 0.12, -0.6, 4.1 },
			Trail1 = { "RainbowButter", 0.12, -1.05, 4.1 },
			Wisps = { "CloudBody", 0, -1.25, 0.3 },
			Wake = { "CloudBody", 0, -0.3, -2.5 },
			Launch = { "CloudBody", 0, -1.35, 0 },
		},
	},
	rocket_skiff = {
		Parts = { TailFin_L = "SweptFins", TailFin_R = "SweptFins", Hull = "Hull" },
		Attachments = {
			Exhaust_L = { "Hull", -1.95, -0.48, 3.7 },
			Exhaust_R = { "Hull", 1.95, -0.48, 3.7 },
			FinTrailL0 = { "TailFin_L", -2.8, 0.75, 2.45 },
			FinTrailL1 = { "TailFin_L", -2.8, 0.45, 2.45 },
			FinTrailR0 = { "TailFin_R", 2.8, 0.75, 2.45 },
			FinTrailR1 = { "TailFin_R", 2.8, 0.45, 2.45 },
			Wake = { "Hull", 0, -0.2, -3.7 },
			Launch = { "Hull", 0, -1.1, 0 },
		},
	},
	prism_ray = {
		Parts = { Wing_L = "WingL", Wing_R = "WingR", Body = "Body", Tail = "Tail" },
		Attachments = {
			WingTipL0 = { "Wing_L", -3.95, -0.05, 1.3 },
			WingTipL1 = { "Wing_L", -3.75, -0.3, 1.6 },
			WingTipR0 = { "Wing_R", 3.95, -0.05, 1.3 },
			WingTipR1 = { "Wing_R", 3.75, -0.3, 1.6 },
			PrismGlow = { "Tail", 0.04, 0.1, 4.45 },
			Wake = { "Body", 0, 0, -3.2 },
			Launch = { "Body", 0, -1.0, 0 },
		},
	},
}

local report = {}
for id, spec in V2 do
	local model = RS.Assets.Rideables:FindFirstChild(id)
	assert(model and model:GetAttribute("Version") == 2, id .. " is not the v2 template")
	if not backups:FindFirstChild(id) then
		model:Clone().Parent = backups
	end
	for _, d in model:GetDescendants() do
		if d:GetAttribute("FlyersV2FX") then
			d:Destroy()
		end
	end
	local pivot = model:GetPivot()
	local P, A = {}, {}
	for role, name in spec.Parts do
		P[role] = assert(model:FindFirstChild(name), id .. "." .. name)
	end
	for name, a in spec.Attachments do
		local part = P[a[1]]
		local att = Instance.new("Attachment")
		att.Name = name
		att.Position = part.CFrame:PointToObjectSpace(pivot:PointToWorldSpace(Vector3.new(a[2], a[3], a[4])))
		att:SetAttribute("FlyersV2FX", true)
		att.Parent = part
		A[name] = att
	end
	local before = #model:GetDescendants()
	EFFECTS[id](P, A)
	for _, d in model:GetDescendants() do
		if d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Light") then
			d:SetAttribute("FlyersV2FX", true)
		end
	end
	model:SetAttribute("RideFXVersion", 3)
	report[id] = #model:GetDescendants() - before
end
return report
