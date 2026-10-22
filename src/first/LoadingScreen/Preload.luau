--!strict
-- What the client preloads, and when (decision 111). Shared.Config.LoadTiers lists it in three tiers:
--   Essential  behind the loading screen (its jobs are the progress bar)
--   Soon       held until the screen closes (release()), then two at a time
--   Later      one at a time with a gap; everything not listed elsewhere
-- Each job is one ContentProvider:PreloadAsync call. Jobs sit in lanes (Urgent > Essential > Soon > Later); a lane
-- only starts work when every lane above it has nothing waiting. want(name) moves a screen's (or a PlayerGui
-- attribute's) items into the Urgent lane, so opening the Shop early loads the Shop first. Client controllers can
-- require this module (game.ReplicatedFirst.LoadingScreen.Preload): want, hint, owned, await.
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

type Job = {
	Key: string,
	Lane: string,
	Tier: string,
	Targets: { any },
	State: string, -- "queued" | "running" | "done"
	Started: number?,
	Seconds: number?,
	Failed: number,
	Retry: boolean?,
}

local Preload = {}

local LANES = { "Urgent", "Essential", "Soon", "Later" }
local RANK = { Urgent = 1, Essential = 2, Soon = 3, Later = 4 }
local FONTS = { -- Theme.Fonts (client UI/Theme isn't loaded yet)
	Font.new("rbxasset://fonts/families/DenkOne.json"),
	Font.new("rbxasset://fonts/families/Nunito.json", Enum.FontWeight.Heavy),
	Font.new("rbxasset://fonts/families/Nunito.json", Enum.FontWeight.ExtraBold),
}

local player = Players.LocalPlayer
local config: any = nil
local uiAssets: { [string]: string } = {}
local queues: { [string]: { Job } } = { Urgent = {}, Essential = {}, Soon = {}, Later = {} }
local running: { [string]: number } = { Urgent = 0, Essential = 0, Soon = 0, Later = 0 }
local jobs: { [string]: Job } = {}
local owner: { [any]: Job } = {} -- asset id / Instance -> the job that loads it
local released = false
local wake = Instance.new("BindableEvent")
local dispatching = false
local started = os.clock()
local stats = { Essential = { 0, 0 }, Soon = { 0, 0 }, Later = { 0, 0 } } -- jobs done, jobs total per tier
local tierDoneAt: { [string]: number } = {}
local tierQueued: { [string]: boolean } = {} -- every item of the tier has been resolved and queued
local ownedNames: { [string]: string } = {} -- model name -> Assets folder, from the profile

Preload.Report = {} :: { Job }

-- Resolving items -------------------------------------------------------------------------------------------------

local function configModule(name: string): any
	local shared = ReplicatedStorage:WaitForChild("Shared", 20)
	local folder = shared and shared:WaitForChild("Config", 10)
	local module = folder and folder:WaitForChild(name, 10)
	if not (module and module:IsA("ModuleScript")) then
		return nil
	end
	local ok, value = pcall(require, module)
	return if ok then value else nil
end

local function assetsFolder(): Instance?
	return ReplicatedStorage:WaitForChild("Assets", 20)
end

-- Every rbxassetid string in a config table; anims = only those under R15 / R6 / Animation keys, else the others.
local function scanIds(
	value: any,
	anims: boolean,
	out: { string },
	seen: { [string]: boolean },
	key: any?,
	depth: number
)
	if depth > 8 then
		return
	end
	if type(value) == "string" then
		local isAnim = key == "R15" or key == "R6" or key == "Animation"
		if isAnim == anims and value:match("^rbxassetid://%d+") and not seen[value] then
			seen[value] = true
			table.insert(out, value)
		end
	elseif type(value) == "table" then
		local keys = {}
		for k in value do
			table.insert(keys, k)
		end
		table.sort(keys, function(a, b)
			return tostring(a) < tostring(b)
		end)
		for _, k in keys do
			scanIds(value[k], anims, out, seen, k, depth + 1)
		end
	end
end

local function makeInstances(className: string, property: string, ids: { string }): { Instance }
	local list = {}
	for _, id in ids do
		local object = Instance.new(className);
		(object :: any)[property] = id
		table.insert(list, object)
	end
	return list
end

-- Images go in as ImageLabels: a bare id string reports Failure and restarts its fetch (seen in Studio, 2026-10-21),
-- an ImageLabel reports the real status. Each id gets one label, so jobs and the owner table dedupe by label.
local imageLabels: { [string]: ImageLabel } = {}
local function images(ids: { string }): { Instance }
	local list = {}
	for _, id in ids do
		local label = imageLabels[id]
		if not label then
			label = Instance.new("ImageLabel")
			label.Image = id
			imageLabels[id] = label
		end
		table.insert(list, label)
	end
	return list
end

local function batches(prefix: string, targets: { any }): { { any } }
	local units, size = {}, config.BatchSize
	for i = 1, #targets, size do
		table.insert(
			units,
			{ prefix .. "#" .. (i // size + 1), table.move(targets, i, math.min(#targets, i + size - 1), 1, {}) }
		)
	end
	return units
end

local function spawnCenter(): Vector3?
	local character = player.Character
	local waited = os.clock()
	while not character and os.clock() - waited < config.CharacterWait do
		task.wait(0.1)
		character = player.Character
	end
	local root = character and character:WaitForChild("HumanoidRootPart", 2)
	if root and root:IsA("BasePart") then
		return root.Position
	end
	local spawn = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	return spawn and spawn.Position
end

local function worldRoots(): { Instance }
	local roots = {}
	for _, child in workspace:GetChildren() do
		if not (child:IsA("Terrain") or child:IsA("Camera") or Players:GetPlayerFromCharacter(child)) then
			table.insert(roots, child)
		end
	end
	return roots
end

-- An item -> units { key, targets }. Targets are what PreloadAsync gets (ids or Instances).
local function resolve(item: string): { { any } }
	local kind, arg = item:match("^(%w+):(.*)$")
	kind = kind or item
	arg = arg or ""
	local units = {}
	if kind == "fonts" then
		local labels = {}
		for _, face in FONTS do
			local label = Instance.new("TextLabel")
			label.FontFace, label.Text = face, "Aa"
			table.insert(labels, label)
		end
		table.insert(units, { "fonts", labels })
	elseif kind == "ui" then
		local keys = {}
		for key, id in uiAssets do
			if key:sub(1, #arg) == arg and type(id) == "string" and id:match("^rbxassetid://%d+") then
				table.insert(keys, key)
			end
		end
		table.sort(keys)
		local ids = {}
		for _, key in keys do
			table.insert(ids, uiAssets[key])
		end
		units = batches(item, images(ids))
	elseif kind == "id" then
		table.insert(units, { item, images({ arg }) })
	elseif kind == "screen" then
		for _, gui in StarterGui:GetChildren() do
			if gui:IsA("ScreenGui") and (arg == "" or gui.Name == arg) then
				table.insert(units, { "screen:" .. gui.Name, { gui } })
			end
		end
	elseif kind == "asset" then
		local root = assetsFolder()
		local folderName, childName = arg:match("^([^/]*)/?(.*)$")
		for _, folder in root and root:GetChildren() or {} do
			if (folderName == "" or folder.Name == folderName) and not config.SkipAssets[folder.Name] then
				for _, child in folder:GetChildren() do
					if childName == "" or child.Name == childName then
						table.insert(units, { "asset:" .. folder.Name .. "/" .. child.Name, { child } })
					end
				end
			end
		end
	elseif kind == "rs" then
		local child = ReplicatedStorage:FindFirstChild(arg)
		if child then
			table.insert(units, { item, { child } })
		end
	elseif kind == "images" or kind == "sounds" or kind == "anims" then
		-- "images:ItemIcons/Small/pop" walks into the config table; "images:ItemIcons" takes all of it.
		local segments = string.split(arg, "/")
		local value = configModule(segments[1])
		for i = 2, #segments do
			value = if type(value) == "table" then value[segments[i]] else nil
		end
		local ids = {}
		scanIds(value, kind == "anims", ids, {}, nil, 0)
		local targets: { any } = images(ids)
		if kind == "sounds" then
			targets = makeInstances("Sound", "SoundId", ids)
		elseif kind == "anims" then
			targets = makeInstances("Animation", "AnimationId", ids)
		end
		units = batches(item, targets)
	elseif kind == "spawn" then
		local center = spawnCenter()
		if center then
			-- StreamingEnabled: ask for the spawn area first, then preload what came in.
			pcall(player.RequestStreamAroundAsync, player, center, 4)
			local near, radius = {}, config.SpawnRadius
			for _, root in worldRoots() do
				for _, object in root:GetDescendants() do
					if object:IsA("BasePart") and (object.Position - center).Magnitude <= radius then
						table.insert(near, object)
					end
				end
			end
			for i = 1, #near, 200 do
				table.insert(
					units,
					{ "spawn#" .. (i // 200 + 1), table.move(near, i, math.min(#near, i + 199), 1, {}) }
				)
			end
		end
	elseif kind == "lobby" then
		for _, root in worldRoots() do
			table.insert(units, { "lobby:" .. root.Name, { root } })
		end
	elseif kind == "owned" then
		local root = assetsFolder()
		local names = {}
		for name in ownedNames do
			table.insert(names, name)
		end
		table.sort(names)
		for _, name in names do
			local folder = root and root:FindFirstChild(ownedNames[name])
			local model = folder and folder:FindFirstChild(name)
			if model then
				table.insert(units, { "asset:" .. ownedNames[name] .. "/" .. name, { model } })
			end
			-- And its pictures (HintItems), so the hand's cards show at once.
			local category = (config.HintCategories or {})[ownedNames[name]]
			for _, template in config.HintItems or {} do
				if category or not template:find("{category}", 1, true) then
					local filled = template:gsub("{name}", name):gsub("{category}", category or "")
					for _, unit in resolve(filled) do
						table.insert(units, unit)
					end
				end
			end
		end
	end
	return units
end

-- Queueing --------------------------------------------------------------------------------------------------------

local function count(job: Job, field: number, delta: number)
	local tier = stats[job.Tier]
	if tier then
		tier[field] += delta
	end
end

local function promote(job: Job, lane: string)
	if job.State ~= "queued" or RANK[lane] >= RANK[job.Lane] then
		return
	end
	local queue = queues[job.Lane]
	local index = table.find(queue, job)
	if index then
		table.remove(queue, index)
	end
	job.Lane = lane
	table.insert(queues[lane], if lane == "Urgent" then 1 else #queues[lane] + 1, job)
end

local dispatch: () -> () -- defined below

-- Adds `item` to `lane` (or moves its waiting jobs up to it). Returns the jobs that cover it.
local function enqueue(item: string, lane: string, tier: string): { Job }
	local covered = {}
	for _, unit in resolve(item) do
		local key, targets = unit[1], unit[2]
		local existing = jobs[key]
		if existing then
			promote(existing, lane)
			table.insert(covered, existing)
			continue
		end
		local fresh = {}
		for _, target in targets do
			local holder = owner[target]
			if holder then
				promote(holder, lane)
				if not table.find(covered, holder) then
					table.insert(covered, holder)
				end
			else
				table.insert(fresh, target)
			end
		end
		if #fresh > 0 then
			local job: Job = { Key = key, Lane = lane, Tier = tier, Targets = fresh, State = "queued", Failed = 0 }
			jobs[key] = job
			for _, target in fresh do
				owner[target] = job
			end
			count(job, 2, 1)
			table.insert(queues[lane], if lane == "Urgent" then 1 else #queues[lane] + 1, job)
			table.insert(covered, job)
		end
	end
	dispatch()
	return covered
end

local function checkTier(tier: string)
	local counts = stats[tier]
	if not counts or tierDoneAt[tier] or not tierQueued[tier] or counts[1] < counts[2] then
		return
	end
	tierDoneAt[tier] = os.clock() - started
	if released and tierDoneAt.Soon and tierDoneAt.Later then
		player:SetAttribute("LoadStage", "Done")
	end
end

local function finished(job: Job)
	count(job, 1, 1)
	checkTier(job.Tier)
	wake:Fire()
end

local function run(job: Job)
	job.State = "running"
	running[job.Lane] += 1
	local t0 = os.clock()
	job.Started = t0 - started
	local failedIds = 0
	pcall(ContentProvider.PreloadAsync, ContentProvider, job.Targets, function(contentId, status)
		if status == Enum.AssetFetchStatus.Failure and contentId ~= "" then
			failedIds += 1
		end
	end)
	job.Seconds = os.clock() - t0
	job.Failed = failedIds
	job.State = "done"
	table.insert(Preload.Report, job)
	local lane = job.Lane
	if failedIds > 0 and not job.Retry then
		-- One more try in the background (a failed fetch is never retried by PreloadAsync itself).
		task.delay(config.RetryDelay, function()
			local retry: Job = {
				Key = job.Key .. "#retry",
				Lane = "Later",
				Tier = "Retry",
				Targets = job.Targets,
				State = "queued",
				Failed = 0,
				Retry = true,
			}
			jobs[retry.Key] = retry
			table.insert(queues.Later, retry)
			dispatch()
		end)
	end
	finished(job)
	local gap = config.Lanes[lane].Gap
	if lane == "Later" then
		local gui = player:FindFirstChildOfClass("PlayerGui")
		if gui and gui:GetAttribute("InMatch") then
			gap = config.Lanes.Later.BusyGap
		end
	end
	if gap > 0 then
		task.wait(gap)
	end
	running[lane] -= 1
	wake:Fire()
end

-- The next job to start, or nil: the first lane with anything waiting decides (lower lanes wait their turn).
local function nextJob(): Job?
	for _, lane in LANES do
		local queue = queues[lane]
		if #queue > 0 then
			if (lane == "Soon" or lane == "Later") and not released then
				return nil
			end
			if running[lane] >= config.Lanes[lane].Workers then
				return nil
			end
			return table.remove(queue, 1)
		end
	end
	return nil
end

function dispatch()
	if dispatching or not config then
		return
	end
	dispatching = true
	task.spawn(function()
		while true do
			local job = nextJob()
			if job then
				task.spawn(run, job)
				continue
			end
			local idle = true
			for _, lane in LANES do
				if #queues[lane] > 0 or running[lane] > 0 then
					idle = false
				end
			end
			if idle then
				break
			end
			wake.Event:Wait()
		end
		dispatching = false
	end)
end

-- Keep-warm holder ------------------------------------------------------------------------------------------------
-- Roblox drops a preloaded image that nothing shows: "preloaded but invisible ImageLabels are treated as unused and
-- garbage-collected" (Roblox staff, DevForum "ContentProvider doesn't preload ImageLabels", 2026-02-06), worst on
-- phones with little memory. So the pictures the next screen needs (LoadTiers.KeepWarm) stay parented here: on
-- screen, 8 px, 99% transparent, behind every other GUI. One label per image, counted per set that wants it.
local warmGui: ScreenGui? = nil
local warmLabels: { [string]: { Label: ImageLabel, Count: number } } = {}
local warmSets: { [string]: { string } } = {}

local function warmHolder(): ScreenGui
	if warmGui and warmGui.Parent then
		return warmGui
	end
	local gui = Instance.new("ScreenGui")
	gui.Name, gui.ResetOnSpawn, gui.DisplayOrder, gui.IgnoreGuiInset = "LoadWarm", false, -1000, true
	gui.Parent = player:WaitForChild("PlayerGui")
	warmGui = gui
	return gui
end

-- Keeps the images of `items` warm under the name `set` (replacing what that set held before).
function Preload.keepWarm(set: string, items: { string })
	if not config or (RunService:IsStudio() and workspace:GetAttribute("LoadNoWarm")) then
		return
	end
	local ids, seen = {}, {}
	for _, item in items do
		local ok, units = pcall(resolve, item)
		for _, unit in if ok then units else {} do
			for _, target in unit[2] do
				if typeof(target) == "Instance" and target:IsA("ImageLabel") and not seen[target.Image] then
					seen[target.Image] = true
					if #ids < config.KeepWarmMax then
						table.insert(ids, target.Image)
					end
				end
			end
		end
	end
	local holder = warmHolder()
	for _, id in ids do
		local entry = warmLabels[id]
		if not entry then
			local label = Instance.new("ImageLabel")
			label.Name, label.Image, label.BackgroundTransparency = "Warm", id, 1
			label.Size, label.ImageTransparency = UDim2.fromOffset(8, 8), 0.99
			label.Parent = holder
			entry = { Label = label, Count = 0 }
			warmLabels[id] = entry
		end
		entry.Count += 1
	end
	local previous = warmSets[set]
	warmSets[set] = ids
	if previous then
		Preload.coolDown(set, previous)
	end
end

-- Lets a set's images go again (after a short overlap, so a set handing over to the next one never drops them).
function Preload.coolDown(set: string, ids: { string }?)
	local list = ids or warmSets[set]
	if not ids then
		warmSets[set] = nil
	end
	if not list then
		return
	end
	task.delay(config.KeepWarmLinger, function()
		for _, id in list :: { string } do
			local entry = warmLabels[id]
			if entry then
				entry.Count -= 1
				if entry.Count <= 0 then
					entry.Label:Destroy()
					warmLabels[id] = nil
				end
			end
		end
	end)
end

-- Public ----------------------------------------------------------------------------------------------------------

-- Loads the config and queues every tier. Essential starts at once; Soon and Later wait for release().
function Preload.start()
	config = configModule("LoadTiers")
	Preload.ConfigAt = os.clock() - started
	if not config then
		warn("[GlassClash] LoadTiers config missing; nothing preloaded")
		tierDoneAt.Essential = os.clock() - started -- let the screen close
		return
	end
	uiAssets = configModule("UIAssets") or {}
	Preload.watch()
	-- One bad item (a renamed folder, a broken config) must not stop the rest or hold the screen.
	local function add(item: string, tier: string)
		local ok, err = pcall(enqueue, item, tier, tier)
		if not ok then
			warn("[GlassClash] preload item " .. item .. " failed: " .. tostring(err))
		end
	end
	-- Studio A/B switch (workspace attribute LoadNoLater): skip the Later tier to compare memory and frame times.
	local noLater = RunService:IsStudio() and workspace:GetAttribute("LoadNoLater") == true
	for _, tier in config.Order do
		for _, item in if noLater and tier == "Later" then {} else config.Tiers[tier] do
			add(item, tier)
		end
		if tier == "Later" and not noLater then
			-- Anything no tier listed (new UI images, screens, models, the rest of the lobby) goes last.
			for _, item in { "ui:", "screen:", "asset:", "lobby" } do
				add(item, "Later")
			end
		end
		tierQueued[tier] = true
		checkTier(tier)
	end
end

-- Essential jobs done / total (the loading bar).
function Preload.progress(): (number, number)
	return stats.Essential[1], stats.Essential[2]
end

function Preload.essentialDone(): boolean
	return tierDoneAt.Essential ~= nil
end

-- The loading screen is gone: Soon and Later may start.
function Preload.release()
	released = true
	player:SetAttribute("LoadStage", if tierDoneAt.Soon and tierDoneAt.Later then "Done" else "Background")
	dispatch()
	wake:Fire()
end

-- Moves an on-demand group (a screen name or PlayerGui attribute in LoadTiers.OnDemand) or a single item to the front.
function Preload.want(name: string): { Job }
	if not config then
		return {}
	end
	local covered = {}
	for _, item in config.OnDemand[name] or (if name:find(":") then { name } else {}) do
		for _, job in enqueue(item, "Urgent", "Urgent") do
			table.insert(covered, job)
		end
	end
	return covered
end

-- Any glassy / flyer / finisher named anywhere in `payload` (keys or values) jumps to `lane` (default Urgent).
function Preload.hint(payload: any, lane: string?): { Job }
	local covered = {}
	if not config then
		return covered
	end
	local root = assetsFolder()
	local seen = {}
	local function visit(value: any, depth: number)
		if type(value) == "string" then
			if seen[value] then
				return
			end
			seen[value] = true
			for _, folderName in config.HintFolders do
				local folder = root and root:FindFirstChild(folderName)
				if folder and folder:FindFirstChild(value) then
					local items = { "asset:" .. folderName .. "/" .. value }
					local category = (config.HintCategories or {})[folderName]
					for _, template in config.HintItems or {} do
						if category or not template:find("{category}", 1, true) then
							local filled = template:gsub("{name}", value):gsub("{category}", category or "")
							table.insert(items, filled)
						end
					end
					for _, item in items do
						for _, job in enqueue(item, lane or "Urgent", lane or "Urgent") do
							table.insert(covered, job)
						end
					end
				end
			end
		elseif type(value) == "table" and depth < 4 then
			for k, v in value do
				visit(k, depth + 1)
				visit(v, depth + 1)
			end
		end
	end
	visit(payload, 0)
	return covered
end

-- A ProfileSnapshot: remembers what the player owns ("owned" item) and moves it up to Soon.
function Preload.owned(profile: any)
	if not config or type(profile) ~= "table" then
		return
	end
	local root = assetsFolder()
	local function note(value: any)
		if type(value) ~= "string" or ownedNames[value] then
			return
		end
		for _, folderName in config.HintFolders do
			local folder = root and root:FindFirstChild(folderName)
			if folder and folder:FindFirstChild(value) then
				ownedNames[value] = folderName
				return
			end
		end
	end
	for id in type(profile.Glassies) == "table" and profile.Glassies or {} do
		note(id)
	end
	local cosmetics = profile.Cosmetics
	if type(cosmetics) == "table" then
		for key, value in cosmetics do
			if type(key) == "string" and key:match("^Equipped") then
				note(value)
			end
		end
	end
	enqueue("owned", "Soon", "Soon")
end

-- Waits (up to `timeout` seconds) until the jobs from want / hint are done. Returns true if they all finished.
function Preload.await(covered: { Job }, timeout: number?): boolean
	local deadline = os.clock() + (timeout or 10)
	while os.clock() < deadline do
		local done = true
		for _, job in covered do
			if job.State ~= "done" then
				done = false
			end
		end
		if done then
			return true
		end
		task.wait()
	end
	return false
end

-- On-demand triggers that need no other code: screens opening, PlayerGui attributes, remote payloads.
function Preload.watch()
	task.spawn(function()
		local gui = player:WaitForChild("PlayerGui")
		local function screen(child: Instance)
			if not (child:IsA("ScreenGui") and config.OnDemand[child.Name]) then
				return
			end
			if child.Enabled then
				Preload.want(child.Name)
			end
			child:GetPropertyChangedSignal("Enabled"):Connect(function()
				if child.Enabled then
					Preload.want(child.Name)
				end
			end)
		end
		for _, child in gui:GetChildren() do
			screen(child)
		end
		gui.ChildAdded:Connect(screen)
		-- KeepWarm sets: Always from the start, the others while their PlayerGui attribute is true.
		for name, items in config.KeepWarm or {} do
			if name == "Always" then
				Preload.keepWarm(name, items)
				continue
			end
			local function update()
				if gui:GetAttribute(name) then
					Preload.keepWarm(name, items)
				elseif warmSets[name] then
					Preload.coolDown(name)
				end
			end
			gui:GetAttributeChangedSignal(name):Connect(update)
			update()
		end
		for name in config.OnDemand do
			gui:GetAttributeChangedSignal(name):Connect(function()
				if gui:GetAttribute(name) then
					Preload.want(name)
				end
			end)
		end
	end)
	-- Remote listeners connect only after the screen closes, once the controllers have theirs: a RemoteEvent hands
	-- events queued before any listener to the first one that connects, and that must stay a controller.
	task.spawn(function()
		while not released do
			task.wait(0.2)
		end
		local shared = ReplicatedStorage:FindFirstChild("Shared")
		local module = shared and shared:FindFirstChild("Remotes")
		local ok, remotes = pcall(require, module :: any)
		if not ok or type(remotes) ~= "table" then
			return
		end
		for _, name in config.HintRemotes do
			local remote = remotes[name]
			if remote then
				remote.OnClientEvent:Connect(function(payload)
					Preload.hint(payload)
				end)
			end
		end
		if remotes.ProfileSnapshot then
			remotes.ProfileSnapshot.OnClientEvent:Connect(Preload.owned)
		end
	end)
end

-- Seconds since start when each tier finished, plus job counts (Studio report; LOADING_SCREEN.md).
function Preload.summary(): string
	local parts = {}
	for _, tier in { "Essential", "Soon", "Later" } do
		table.insert(
			parts,
			string.format(
				"%s %d/%d %s",
				tier,
				stats[tier][1],
				stats[tier][2],
				tostring(tierDoneAt[tier] and string.format("%.2fs", tierDoneAt[tier]) or "-")
			)
		)
	end
	return string.format("config %.2fs | ", Preload.ConfigAt or -1) .. table.concat(parts, " | ")
end

-- Studio only: the per-job timings as attributes on this module, readable from the MCP / command bar.
function Preload.publishReport()
	if not RunService:IsStudio() then
		return
	end
	local rows = {}
	for _, job in Preload.Report do
		table.insert(
			rows,
			string.format(
				"%.3f|%.3f|%s|%s|%s|%d|%d",
				job.Started or 0,
				job.Seconds or 0,
				job.Tier,
				job.Lane,
				job.Key,
				#job.Targets,
				job.Failed
			)
		)
	end
	script:SetAttribute("Summary", Preload.summary())
	script:SetAttribute("Jobs", table.concat(rows, "\n"))
end

return Preload
