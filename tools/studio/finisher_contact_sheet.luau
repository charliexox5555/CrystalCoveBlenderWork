-- Edit-mode QA (Studio MCP execute_luau, then screen_capture): lays out frozen frames of one finisher show at
-- several beats, high in the sky, using fresh clones of the Rojo modules (Edit-mode require caches go stale).
-- Set `_G.FinisherSheet = { Id = "starfall", Times = {...} }` before running; returns camera position/target for
-- screen_capture. Run again with `_G.FinisherSheet = { Clear = true }` to remove everything it built.
local RS = game:GetService("ReplicatedStorage")
local Client = game:GetService("StarterPlayer").StarterPlayerScripts.Client
local args = _G.FinisherSheet or {}
local old = workspace:FindFirstChild("FinisherContactSheet")
if old then
	old:Destroy()
end
local temp = game:GetService("ServerStorage"):FindFirstChild("FinisherSheetModules")
if temp then
	temp:Destroy()
end
if args.Clear then
	return "cleared"
end

-- Fresh module copies: FinisherFX + Finishers/* + FinisherShows, rewired to each other.
temp = Instance.new("Folder")
temp.Name = "FinisherSheetModules"
local fx = Client.Presentation.FinisherFX:Clone()
fx.Parent = temp
local shows = Client.Presentation.Finishers:Clone()
shows.Parent = temp
local config = RS.Shared.Config.FinisherShows:Clone()
config.Name = "FinisherShowsCopy"
config.Parent = temp
local function rewire(module)
	module.Source = module.Source
		:gsub("require%(RS%.Shared%.Config%.FinisherShows%)", "require(script.Parent.Parent.FinisherShowsCopy)")
		:gsub("require%(script%.Parent%.Finishers%.Kit%)", "require(script.Parent.Finishers.Kit)")
end
rewire(fx)
fx.Source =
	fx.Source:gsub("require%(script%.Parent%.Parent%.FinisherShowsCopy%)", "require(script.Parent.FinisherShowsCopy)")
for _, m in shows:GetChildren() do
	rewire(m)
end
temp.Parent = game:GetService("ServerStorage")
local FX = require(fx)
local Shows = require(config)

local id = args.Id or "glass_burst"
local show = Shows.Shows[id]
local times = args.Times
if not times then
	times =
		{ 0.12, show.PeakAt * 0.7, show.PeakAt - 0.02, show.PeakAt + 0.12, show.PeakAt + 0.45, show.Duration - 0.45 }
end
local spacing = args.Spacing or 20
local base = args.Base or Vector3.new(0, 600, 0)
local sheet = Instance.new("Model")
sheet.Name = "FinisherContactSheet"
local look = CFrame.lookAt(Vector3.new(0, 3, 30), Vector3.zero)
for i, t in times do
	local frame = Instance.new("Model")
	frame.Name = string.format("%s_t%.2f", id, t)
	frame.Parent = sheet
	assert(FX.still(frame, id, look, t))
	local offset = Vector3.new((i - (#times + 1) / 2) * spacing, 0, 0)
	frame.WorldPivot = CFrame.new()
	frame:PivotTo(CFrame.new(base + offset))
	-- A small stand-in avatar so the scale against a player reads in the frame.
	local stand = Instance.new("Part")
	stand.Name = "AvatarScale"
	stand.Anchored, stand.CanCollide = true, false
	stand.Size = Vector3.new(2, 5, 1)
	stand.Color = Color3.fromRGB(120, 120, 130)
	stand.Transparency = 0.6
	stand.CFrame = CFrame.new(base + offset - Vector3.yAxis * 1.5)
	stand.Parent = frame
end
sheet.Parent = workspace
local width = #times * spacing
return {
	Camera = { base.X, base.Y + 2, base.Z + width * 0.62 },
	Target = { base.X, base.Y, base.Z },
	Frames = #times,
}
