-- Original placeholder kiosks/boards. Adds missing objects only; preserves all manual decor.
assert(not game:GetService("RunService"):IsRunning(), "Install lobby props in Edit mode")
local lobby = workspace.Lobby
local root = lobby:FindFirstChild("GlassClashProps") or Instance.new("Folder")
root.Name, root.Parent = "GlassClashProps", lobby
local Theme = require(game.StarterPlayer.StarterPlayerScripts.Client.UI.Theme)
local added = {}
local function part(model, name, size, position, color)
	local p = Instance.new("Part")
	p.Name, p.Size, p.Position = name, size, position
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, true
	p.Material, p.Color = Enum.Material.SmoothPlastic, Color3.fromHex(color)
	p.Parent = model
	return p
end
local function text(parent, name, copy, size, position)
	local t = Instance.new("TextLabel")
	t.Name, t.Text, t.Size, t.Position = name, copy, size, position
	t.BackgroundTransparency, t.TextColor3, t.TextScaled = 1, Theme.Colors.Text, true
	t.FontFace = Theme.Fonts.Heading
	t.Parent = parent
	return t
end
local function face(body)
	local gui = Instance.new("SurfaceGui")
	gui.Name, gui.Face = "Display", Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(900, 700)
	gui.Parent = body
	return gui
end
for _, spec in
	{
		{ "MatchWins", "MATCH WINS", lobby.Spots.LeaderboardWins.Position },
		{ "Shatters", "SHATTERS", lobby.Spots.LeaderboardStreak.Position },
		{ "Trophies", "TROPHIES", Vector3.new(28, 0.05, 21) },
	}
do
	local name = "Leaderboard_" .. spec[1]
	if root:FindFirstChild(name) then
		continue
	end
	local model = Instance.new("Model")
	model.Name = name
	model:SetAttribute("GeneratedBy", "GlassClashRetention")
	local position = spec[3]
	local body = part(model, "Board", Vector3.new(9, 7, 0.5), position + Vector3.new(0, 4.8, 0), "1E2A6E")
	part(model, "Foot", Vector3.new(7, 0.5, 2), position + Vector3.new(0, 0.25, 0), "6FE3FF")
	part(model, "Post", Vector3.new(0.8, 2, 0.8), position + Vector3.new(0, 1, 0), "314678")
	local gui = face(body)
	text(gui, "Title", spec[2], UDim2.fromScale(0.92, 0.16), UDim2.fromScale(0.04, 0.03))
	local entries =
		text(gui, "Entries", "Clash to make the board!", UDim2.fromScale(0.9, 0.73), UDim2.fromScale(0.05, 0.23))
	entries.FontFace = Theme.Fonts.Body
	entries.TextYAlignment = Enum.TextYAlignment.Top
	model.PrimaryPart, model.Parent = body, root
	table.insert(added, name)
end
for _, spec in
	{
		{ "DailyKiosk", "DAILY REWARDS", "Quests", lobby.Spots.Daily.Position },
		{ "CodesKiosk", "CODES", "Codes", lobby.Spots.Codes.Position },
	}
do
	if root:FindFirstChild(spec[1]) then
		continue
	end
	local model = Instance.new("Model")
	model.Name = spec[1]
	model:SetAttribute("GeneratedBy", "GlassClashRetention")
	local body = part(model, "Body", Vector3.new(4, 3, 2), spec[4] + Vector3.new(0, 1.8, 0), "314678")
	part(model, "Top", Vector3.new(4.4, 0.5, 2.4), spec[4] + Vector3.new(0, 3.55, 0), "FFD166")
	text(face(body), "Title", spec[2], UDim2.fromScale(0.9, 0.8), UDim2.fromScale(0.05, 0.1))
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name, prompt.ActionText, prompt.ObjectText = "OpenRewards", "Open", spec[2]
	prompt.RequiresLineOfSight, prompt.MaxActivationDistance = false, 9
	prompt:SetAttribute("RewardTab", spec[3])
	prompt.Parent = body
	model.PrimaryPart, model.Parent = body, root
	table.insert(added, spec[1])
end
return { Added = added, Root = root:GetFullName() }
