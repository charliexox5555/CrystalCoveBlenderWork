-- Tiered contact beat: flash core, star spokes, expanding rings, glass chips, glints and an optional light pulse.
-- Parts and emitters are pooled per fight (under the LocalFight_ folder), so a long fight never churns instances.
-- Tier tables live in Config/CombatFeel.Tiers; `emit` keeps the old strong/normal call used by CombatEffects.
local TweenService = game:GetService("TweenService")
local RS = game:GetService("ReplicatedStorage")
local VFX = require(RS.Shared.Config.Balance).CombatVFX
local FeelConfig = require(RS.Shared.Config.CombatFeel)
local Budget = FeelConfig.Budget
local Impact = {}
local pools = setmetatable({}, { __mode = "k" })
local PARK = CFrame.new(0, -10000, 0)

local function fightRoot(root)
	local node = root
	while node and node.Parent and node.Parent ~= workspace do
		node = node.Parent
	end
	return node or root
end

local function bare(p)
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = true, false, false, false, false
	p.Transparency, p.CFrame = 1, PARK
	return p
end

local function pool(root, assets)
	local key = fightRoot(root)
	local p = pools[key]
	if p and p.Folder.Parent then
		return p
	end
	local folder = Instance.new("Folder")
	folder.Name = "ImpactPool"
	folder:SetAttribute("Pooled", true)
	folder.Parent = key
	local anchor = bare(Instance.new("Part"))
	anchor.Name, anchor.Size, anchor.Parent = "ImpactEmitters", Vector3.one * 0.05, folder
	local chips = assets.Particles.GlassChips:Clone()
	chips.Rate, chips.Parent = 0, anchor
	local glints = assets.Particles.ContactGlint:Clone()
	glints.Rate, glints.Parent = 0, anchor
	local light = Instance.new("PointLight")
	light.Brightness, light.Range, light.Shadows, light.Parent = 0, 10, false, anchor
	p = {
		Folder = folder,
		Assets = assets,
		Anchor = anchor,
		Chips = chips,
		Glints = glints,
		Light = light,
		Free = { Spoke = {}, Ring = {}, Flash = {} },
		Caps = { Spoke = Budget.PoolSpokes, Ring = Budget.PoolRings, Flash = Budget.PoolFlashes },
	}
	pools[key] = p
	return p
end

local function take(p, kind)
	local part = table.remove(p.Free[kind])
	if part and part.Parent then
		return part
	end
	if kind == "Ring" then
		part = bare(p.Assets.Meshes.Ring:Clone())
		part.Material = Enum.Material.Neon
	else
		part = bare(Instance.new("Part"))
		part.Material = Enum.Material.Neon
		if kind == "Flash" then
			part.Shape = Enum.PartType.Ball
		end
	end
	part.Name = "Impact" .. kind
	part.Parent = p.Folder
	return part
end

-- Return to the pool after its tween; extras beyond the cap are destroyed instead.
local function release(p, kind, part, seconds)
	task.delay(seconds, function()
		if not part.Parent or not p.Folder.Parent then
			return
		end
		part.Transparency, part.CFrame = 1, PARK
		if #p.Free[kind] < p.Caps[kind] then
			table.insert(p.Free[kind], part)
		else
			part:Destroy()
		end
	end)
end

-- opts: Color (Color3, overrides tier colour), LowDetail, Particles (0..1 count scale).
function Impact.tier(root, assets, origin, tier, opts)
	opts = opts or {}
	local p = pool(root, assets)
	local color = opts.Color or Color3.fromHex(tier.Color)
	local low = opts.LowDetail == true
	local seconds = tier.Seconds
	local info = TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	-- Shapes stay solid for most of the beat, then fade fast (readable on bright sky and small screens).
	local fade = TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	local basis = workspace.CurrentCamera.CFrame.Rotation
	origin -= workspace.CurrentCamera.CFrame.LookVector * (opts.Front or FeelConfig.FrontStuds)
	local spokes = if low then math.min(tier.Spokes, 4) else tier.Spokes
	local spin = math.random() * math.pi
	for i = 1, spokes do
		local angle = spin + i / spokes * math.pi * 2
		local dir = basis:VectorToWorldSpace(Vector3.new(math.cos(angle), math.sin(angle), 0))
		local length = tier.SpokeLength * (if i % 2 == 0 then 0.7 else 1)
		local s = take(p, "Spoke")
		s.Color = if i % 2 == 0 then color else Color3.new(1, 1, 1)
		local width = tier.SpokeWidth or 0.1
		s.Size = Vector3.new(width, width, length)
		s.Transparency = 0
		s.CFrame = CFrame.lookAt(origin + dir * length / 2, origin + dir * tier.Spread)
		TweenService:Create(s, info, {
			CFrame = s.CFrame + dir * tier.Spread,
			Size = Vector3.new(width * 0.25, width * 0.25, 0.15),
		}):Play()
		TweenService:Create(s, fade, { Transparency = 1 }):Play()
		release(p, "Spoke", s, seconds + 0.05)
	end
	for i = 1, (if low then math.min(tier.Rings, 1) else tier.Rings) do
		local ring = take(p, "Ring")
		ring.Color, ring.Transparency = color, 0.05
		ring.Size = assets.Meshes.Ring.Size * VFX.ImpactRingStart
		ring.CFrame = CFrame.new(origin) * basis * CFrame.Angles(if i == 2 then math.pi / 2 else 0, 0, 0)
		TweenService:Create(ring, info, {
			Size = assets.Meshes.Ring.Size * tier.RingEnd * (if i == 2 then 0.8 else 1),
		}):Play()
		TweenService:Create(ring, fade, { Transparency = 1 }):Play()
		release(p, "Ring", ring, seconds + 0.05)
	end
	if tier.Flash > 0 then
		local flash = take(p, "Flash")
		flash.Color, flash.Transparency = Color3.new(1, 1, 1), 0
		flash.Size, flash.CFrame = Vector3.one * 0.25, CFrame.new(origin)
		TweenService:Create(flash, TweenInfo.new(seconds * 0.7, Enum.EasingStyle.Quart), {
			Size = Vector3.one * tier.Flash,
			Transparency = 1,
		}):Play()
		release(p, "Flash", flash, seconds)
	end
	local scale = opts.Particles or 1
	p.Anchor.CFrame = CFrame.new(origin)
	if not low then
		local chips = math.floor(tier.Chips * scale + 0.5)
		if chips > 0 then
			p.Chips.Color = ColorSequence.new(color)
			p.Chips:Emit(chips)
		end
		if tier.Light > 0 and opts.Light ~= false then
			p.Light.Color, p.Light.Brightness = color, tier.Light
			TweenService:Create(p.Light, TweenInfo.new(seconds), { Brightness = 0 }):Play()
		end
	end
	local glints = math.floor(tier.Glints * scale * (if low then 0.5 else 1) + 0.5)
	if glints > 0 then
		p.Glints.Color = ColorSequence.new(Color3.new(1, 1, 1), color)
		p.Glints:Emit(glints)
	end
end

-- Legacy call (signature contacts and guard blocks from CombatEffects).
function Impact.emit(root, assets, origin, color, strong, lowDetail)
	Impact.tier(root, assets, origin, FeelConfig.Tiers[if strong then "Smash" else "Solid"], {
		Color = color,
		LowDetail = lowDetail,
		Light = false,
	})
end

return Impact
