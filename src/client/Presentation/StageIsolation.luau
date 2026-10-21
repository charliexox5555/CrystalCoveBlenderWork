-- While you're in a match or watching one, everyone who isn't part of it is hidden on your screen only, so
-- nobody walking into the arena gets in the shot: other players' characters (parts, accessories, decals,
-- nameplates, effects) and other matches' rides. Both fighters and their own stage stay visible (the finisher
-- flies to the losing avatar). Separate from the "Hide Others' Cosmetics" setting.
local Players = game:GetService("Players")
local Isolation = {}

local EFFECTS = {
	"ParticleEmitter",
	"Trail",
	"Beam",
	"Light",
	"Fire",
	"Smoke",
	"Sparkles",
	"Highlight",
	"BillboardGui",
	"SurfaceGui",
}

local current = nil -- { Key, Keep, Stage, HideSelf, Connections }
local roots = {} -- [Instance] = { Saved = {[Instance] = value}, Connections = {} }

local function hide(item, saved)
	if saved[item] ~= nil then
		return
	end
	if item:IsA("BasePart") or item:IsA("Decal") then
		saved[item], item.LocalTransparencyModifier = item.LocalTransparencyModifier, 1
	elseif item:IsA("Humanoid") then
		saved[item], item.DisplayDistanceType = item.DisplayDistanceType, Enum.HumanoidDisplayDistanceType.None
	else
		for _, class in EFFECTS do
			if item:IsA(class) then
				saved[item], item.Enabled = item.Enabled, false
				return
			end
		end
	end
end

local function restore(item, value)
	if not item.Parent then
		return
	end
	if item:IsA("BasePart") or item:IsA("Decal") then
		item.LocalTransparencyModifier = value
	elseif item:IsA("Humanoid") then
		item.DisplayDistanceType = value
	else
		item.Enabled = value
	end
end

local function release(root)
	local entry = roots[root]
	if not entry then
		return
	end
	roots[root] = nil
	for _, connection in entry.Connections do
		connection:Disconnect()
	end
	for item, value in entry.Saved do
		restore(item, value)
	end
end

local function hideRoot(root)
	if roots[root] or not root.Parent then
		return
	end
	local entry = { Saved = {}, Connections = {} }
	roots[root] = entry
	hide(root, entry.Saved)
	for _, item in root:GetDescendants() do
		hide(item, entry.Saved)
	end
	-- Accessories, flyers and effects can arrive after the character (streaming, avatar loading).
	table.insert(
		entry.Connections,
		root.DescendantAdded:Connect(function(item)
			if roots[root] == entry then
				hide(item, entry.Saved)
			end
		end)
	)
	table.insert(
		entry.Connections,
		root.AncestryChanged:Connect(function()
			if not root:IsDescendantOf(workspace) then
				-- Gone (respawn, match stage cleaned up): forget it without touching its pieces.
				for _, connection in entry.Connections do
					connection:Disconnect()
				end
				roots[root] = nil
			end
		end)
	)
end

local function shouldHide(player)
	if player == Players.LocalPlayer then
		return current.HideSelf
	end
	return not current.Keep[player.UserId]
end

local function watchPlayer(player)
	local function onCharacter(character)
		if current and shouldHide(player) then
			hideRoot(character)
		end
	end
	if player.Character then
		onCharacter(player.Character)
	end
	table.insert(current.Connections, player.CharacterAdded:Connect(onCharacter))
end

local function isOtherStage(child)
	-- Without a known stage of our own, leave every stage alone rather than risk hiding our fighters' rides.
	return current.Stage ~= nil
		and child:IsA("Folder")
		and child.Name:match("^MatchStage_") ~= nil
		and child.Name ~= current.Stage
end

function Isolation.active()
	return current ~= nil
end

-- spec = { Keep = { userId, ... }, Stage = "MatchStage_<id>"?, HideSelf = boolean } to hide everyone else; nil to
-- show everything again. Calling it again with the same spec does nothing, so it is cheap to call often.
function Isolation.set(spec)
	local key = nil
	if spec then
		local ids = {}
		for _, id in spec.Keep or {} do
			-- 0 is a bot side. Studio test players have negative ids, so only 0 is skipped.
			if type(id) == "number" and id ~= 0 then
				table.insert(ids, id)
			end
		end
		table.sort(ids)
		key = table.concat(ids, ",") .. "|" .. tostring(spec.Stage) .. "|" .. tostring(spec.HideSelf == true)
		spec = { Keep = ids, Stage = spec.Stage, HideSelf = spec.HideSelf == true }
	end
	if (current and current.Key) == key then
		return
	end
	if current then
		for _, connection in current.Connections do
			connection:Disconnect()
		end
		current = nil
		for root in roots do
			release(root)
		end
	end
	if not spec then
		return
	end
	local keep = {}
	for _, id in spec.Keep do
		keep[id] = true
	end
	current = { Key = key, Keep = keep, Stage = spec.Stage, HideSelf = spec.HideSelf, Connections = {} }
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	table.insert(current.Connections, Players.PlayerAdded:Connect(watchPlayer))
	for _, child in workspace:GetChildren() do
		if isOtherStage(child) then
			hideRoot(child)
		end
	end
	table.insert(
		current.Connections,
		workspace.ChildAdded:Connect(function(child)
			-- Stages are named when created; check after the frame they're parented in.
			task.defer(function()
				if current and child.Parent == workspace and isOtherStage(child) then
					hideRoot(child)
				end
			end)
		end)
	)
end

return Isolation
