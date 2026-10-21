-- Item icon source data (docs/testing/viewports/REPORT.md). Two steps through the MCP execute_luau tool; results are
-- returned as JSON (the MCP caps one result near 100k characters, so long results are kept in _G and read in
-- slices: `return string.sub(_G.__vpParts, 1, 90000)`, then 90001-180000, ...).
--
-- 1. Studio Play, Client datamodel, with MODE = "parts": builds every portrait exactly as the game does
--    (GlassyPortrait / CosmeticPortrait / ItemPresentation.crate, live) and records its parts, colours, materials and
--    camera. Save the joined slices as assets/icons/items/source/portraits.json ({"items": [...]}).
-- 2. Studio Edit with MODE = "fingerprints" (EditableMesh is blocked in Play by the place's security setting): the
--    triangle count and bounds of every MeshId under ReplicatedStorage.Assets, matched to the repo FBX index
--    (tools/blender/index_fbx_meshes.py) into assets/icons/items/source/mesh_map.json. Run it again until it reports
--    every mesh done; each call works for ~25 s.
local MODE = MODE or "parts"
local H = game:GetService("HttpService")
local RS = game:GetService("ReplicatedStorage")

if MODE == "fingerprints" then
	local AS = game:GetService("AssetService")
	if not _G.__vpList then
		local seen, list = {}, {}
		for _, p in RS.Assets:GetDescendants() do
			local shard = p.Parent and p.Parent.Name == "Shards"
			if p:IsA("MeshPart") and not shard and not p:GetFullName():find("CombatReleasePreview") then
				local id = p.MeshId:match("%d+")
				if id and not seen[id] then
					seen[id] = true
					table.insert(list, { id, p.MeshId, p.MeshSize, p.Name })
				end
			end
		end
		_G.__vpList, _G.__vpCursor, _G.__vpFP = list, 1, {}
	end
	local list, t0 = _G.__vpList, os.clock()
	while _G.__vpCursor <= #list and os.clock() - t0 < 25 do
		local e = list[_G.__vpCursor]
		local ok, em = pcall(function()
			return AS:CreateEditableMeshAsync(Content.fromUri(e[2]))
		end)
		if ok then
			local lo, hi = Vector3.one * 1e9, Vector3.one * -1e9
			for _, v in em:GetVertices() do
				local p = em:GetPosition(v)
				lo, hi = lo:Min(p), hi:Max(p)
			end
			local d = hi - lo -- mesh units are centimetres (studs x 100)
			_G.__vpFP[e[1]] = { #em:GetVertices(), #em:GetFaces(), d.X, d.Y, d.Z, e[3].X, e[3].Y, e[3].Z, e[4] }
			em:Destroy()
		else
			_G.__vpFP[e[1]] = { "fail", tostring(em):sub(1, 60) }
		end
		_G.__vpCursor += 1
	end
	_G.__vpFPJson = H:JSONEncode(_G.__vpFP)
	return string.format("%d / %d meshes; JSON %d chars in _G.__vpFPJson", _G.__vpCursor - 1, #list, #_G.__vpFPJson)
end

local Players = game:GetService("Players")
local Client = Players.LocalPlayer.PlayerScripts.Client
local GP = require(Client.UI.Components.GlassyPortrait)
local CP = require(Client.UI.Components.CosmeticPortrait)
local IP = require(Client.UI.Components.ItemPresentation)

local function list(category)
	local ids = {}
	if category == "Glassies" then
		for _, def in require(RS.Shared.Config.Glassies).List do
			table.insert(ids, def.Id)
		end
	elseif category == "Machines" then
		for _, kind in { "Glassies", "Finishers", "Rideables" } do
			for _, currency in { "Coins", "Marbles" } do
				table.insert(ids, kind .. ":" .. currency)
			end
		end
	else
		for id in require(RS.Shared.Config.RoundCosmetics).ByCategory[category] do
			table.insert(ids, id)
		end
		if category == "Rideables" then
			table.insert(ids, "no_flyer")
		end
		table.sort(ids)
	end
	return ids
end

local function r(x)
	return math.round(x * 1e5) / 1e5
end
local function cf(c)
	local t = { c:GetComponents() }
	for i, v in t do
		t[i] = r(v)
	end
	return t
end

local output = { items = {}, meshIds = {}, report = {} }
local function dump(category, id, key)
	-- A real 512 px slot (in a disabled ScreenGui, so idle animations stay at rest) lets the camera fits run.
	local screen = Players.LocalPlayer.PlayerGui:FindFirstChild("PortraitDump") or Instance.new("ScreenGui")
	screen.Name, screen.Enabled, screen.Parent = "PortraitDump", false, Players.LocalPlayer.PlayerGui
	local holder = Instance.new("Frame")
	holder.Size, holder.Parent = UDim2.fromOffset(512, 512), screen
	task.wait()
	local vp
	if category == "Glassies" then
		vp = GP.new(holder, id, UDim2.fromScale(1, 1), UDim2.new(), nil, true)
	elseif category == "Machines" then
		local kind, currency = id:match("(%w+):(%w+)")
		vp = IP.crate(holder, kind, currency, UDim2.fromScale(1, 1), UDim2.new(), nil, nil, true)
		task.wait()
		require(Client.Presentation.CrateFraming).fit(vp)
	else
		vp = CP.new(holder, category, id, UDim2.fromScale(1, 1), UDim2.new(), nil, true)
	end
	local parts = {}
	for _, p in vp:FindFirstChildOfClass("WorldModel"):GetDescendants() do
		if p:IsA("BasePart") and p.Transparency < 1 then
			local e = {
				name = p.Name,
				cls = p.ClassName,
				cf = cf(p.CFrame),
				size = { r(p.Size.X), r(p.Size.Y), r(p.Size.Z) },
				color = p.Color:ToHex(),
				mat = p.Material.Name,
				tr = r(p.Transparency),
				refl = r(p.Reflectance),
			}
			if p:IsA("MeshPart") then
				e.mesh = p.MeshId:match("%d+")
				output.meshIds[e.mesh] = true
			elseif p:IsA("Part") then
				e.shape = p.Shape.Name
			end
			local special = p:FindFirstChildOfClass("SpecialMesh")
			if special then
				e.special = {
					type = special.MeshType.Name,
					scale = { special.Scale.X, special.Scale.Y, special.Scale.Z },
					offset = { special.Offset.X, special.Offset.Y, special.Offset.Z },
				}
			end
			table.insert(parts, e)
		end
	end
	local cam = vp.CurrentCamera
	table.insert(output.items, {
		key = key,
		category = category,
		id = id,
		camera = cam and cf(cam.CFrame),
		fov = cam and cam.FieldOfView,
		parts = parts,
	})
	holder:Destroy()
	return #parts
end

for _, category in { "Glassies", "Rideables", "Finishers", "Machines" } do
	for _, id in list(category) do
		local key = string.lower(category) .. "_" .. id:gsub(":", "_")
		local ok, n = pcall(dump, category, id, key)
		table.insert(output.report, key .. "=" .. tostring(n))
		task.wait()
	end
end
local ids = {}
for id in output.meshIds do
	table.insert(ids, id)
end
output.meshIds = ids
_G.__vpParts = H:JSONEncode(output)
return #_G.__vpParts .. " chars in _G.__vpParts"
