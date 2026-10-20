-- The client's SoundGroup tree for the Settings volume sliders (decision 99):
--   SoundService.GlassClashMaster  (Master slider)
--     ├ MusicMaster                 (Music slider; MusicController's tracks and duck group)
--     └ GlassClashSFX               (SFX slider; every other game sound)
-- Nested SoundGroups multiply, so Master scales both. Any Sound that plays without a SoundGroup is routed into SFX
-- (fight, power, finisher, UI, lobby and crate sounds are created in many places).
local SoundService = game:GetService("SoundService")
local Groups = {}

local function group(name, parent)
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("SoundGroup") then
		return existing
	end
	local made = Instance.new("SoundGroup")
	made.Name, made.Volume, made.Parent = name, 1, parent
	return made
end

function Groups.master(): SoundGroup
	return group("GlassClashMaster", SoundService)
end

function Groups.music(): SoundGroup
	return group("MusicMaster", Groups.master())
end

function Groups.sfx(): SoundGroup
	return group("GlassClashSFX", Groups.master())
end

-- Routes ungrouped sounds (now and later) under the given roots into SFX. Music tracks already have a group.
function Groups.route(roots: { Instance })
	local sfx = Groups.sfx()
	local function adopt(object)
		if object:IsA("Sound") and object.SoundGroup == nil then
			object.SoundGroup = sfx
		elseif object:IsA("SoundGroup") and object.Parent == SoundService and object.Name ~= "GlassClashMaster" then
			object.Parent = sfx -- e.g. UiAudio's UiSounds group
		end
	end
	local connections = {}
	for _, root in roots do
		for _, object in root:GetDescendants() do
			adopt(object)
		end
		table.insert(connections, root.DescendantAdded:Connect(adopt))
	end
	return connections
end

return Groups
