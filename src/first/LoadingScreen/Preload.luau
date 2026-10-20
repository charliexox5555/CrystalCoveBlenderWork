--!strict
-- What the loading screen preloads, and how. Each job is one ContentProvider:PreloadAsync call (an Instance preloads
-- everything under it); a few workers run jobs side by side so a slow asset never blocks the rest, and progress is
-- jobs finished / jobs total.
--   1. Every UI image id in Shared.Config.UIAssets (batches of 24)
--   2. Every StarterGui screen template (one job each)
--   3. ReplicatedStorage.Assets: each glassy, flyer, finisher, crate, Kiln, machine, VFX and world-kit model
--   4. Whatever lobby the player has streamed in around the spawn
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local Preload = {}

local SKIP_ASSETS = { CombatReleasePreview = true } -- review-only models, never shown to players
local WORKERS = 4

function Preload.jobs(): { { any } }
	local jobs: { { any } } = {}
	-- 1. UI images.
	local shared = ReplicatedStorage:WaitForChild("Shared", 20)
	local config = shared and shared:WaitForChild("Config", 10)
	local module = config and config:WaitForChild("UIAssets", 10)
	if module and module:IsA("ModuleScript") then
		local ok, assets = pcall(require, module)
		if ok and type(assets) == "table" then
			local batch = {}
			for _, id in assets do
				if type(id) == "string" and id:match("^rbxassetid://%d+") then
					table.insert(batch, id)
					if #batch == 24 then
						table.insert(jobs, batch)
						batch = {}
					end
				end
			end
			if #batch > 0 then
				table.insert(jobs, batch)
			end
		end
	end
	-- 2. Screen templates.
	for _, gui in StarterGui:GetChildren() do
		if gui:IsA("ScreenGui") then
			table.insert(jobs, { gui })
		end
	end
	-- 3. Models and effects.
	local assets = ReplicatedStorage:WaitForChild("Assets", 20)
	if assets then
		for _, folder in assets:GetChildren() do
			if not SKIP_ASSETS[folder.Name] then
				local children = folder:GetChildren()
				if #children == 0 then
					table.insert(jobs, { folder })
				end
				for _, child in children do
					table.insert(jobs, { child })
				end
			end
		end
	end
	-- 4. The streamed-in lobby around the player.
	for _, child in workspace:GetChildren() do
		if
			not (child:IsA("Terrain") or child:IsA("Camera"))
			and not game:GetService("Players"):GetPlayerFromCharacter(child)
		then
			table.insert(jobs, { child })
		end
	end
	return jobs
end

-- Runs `jobs`; `progress(done, total)` after each. Returns when every job has finished (failed assets count as done).
function Preload.run(jobs: { { any } }, progress: (number, number) -> ())
	local total, done, nextJob = #jobs, 0, 1
	local finished = Instance.new("BindableEvent")
	if total == 0 then
		progress(0, 0)
		return
	end
	local function worker()
		while nextJob <= total do
			local job = jobs[nextJob]
			nextJob += 1
			pcall(ContentProvider.PreloadAsync, ContentProvider, job)
			done += 1
			progress(done, total)
			if done == total then
				finished:Fire()
			end
		end
	end
	for _ = 1, math.min(WORKERS, total) do
		task.spawn(worker)
	end
	if done < total then
		finished.Event:Wait()
	end
	finished:Destroy()
end

return Preload
