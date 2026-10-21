-- Player profiles (decision 104). The top bar's Profile button opens your own profile; tapping another player in the
-- lobby pops a bubble with their headshot, and tapping the bubble (or a leaderboard row) opens theirs. Every
-- profile is read-only (UI/Screens/ProfileScreen). Other players' data comes from RequestPlayerProfile.
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RS = game:GetService("ReplicatedStorage")
local Remotes = require(RS.Shared.Remotes)
local UIAssets = require(RS.Shared.Config.UIAssets)
local ProfileScreen = require(script.Parent.Parent.UI.Screens.ProfileScreen)
local LoadGate = require(script.Parent.Parent.LoadGate)
local Controller = {}

local SCREEN = "ProfileScreen"
local TAP_SECONDS, TAP_PIXELS = 0.35, 14 -- a tap, not a camera drag
local BUBBLE_SECONDS = 4
local REQUEST_SECONDS = 1.1 -- client-side spacing; the server rate-limits too (Balance.Levels.ViewRateSeconds)

function Controller:Init(controllers)
	self.Controllers, self.Player = controllers, Players.LocalPlayer
	self.LastRequest = -math.huge
end

local function busy(pg)
	return pg:GetAttribute("InMatch")
		or pg:GetAttribute("Queued")
		or pg:GetAttribute("ResultsOpen")
		or pg:GetAttribute("Watching")
end

function Controller:SelfData()
	local profile = self.Profile or {}
	return {
		UserId = self.Player.UserId,
		Name = self.Player.DisplayName,
		Self = true,
		Level = profile.Level,
		Stats = profile.Stats,
		Glassies = profile.Glassies,
		Cosmetics = profile.Cosmetics,
	}
end

function Controller:Refresh()
	if not self.Screen or not self.Gui.Enabled then
		return
	end
	self.Screen:Show(self.Target or self:SelfData())
end

function Controller:OpenScreen()
	local topbar = self.Controllers.TopbarController
	if self.Gui.Enabled then
		self:Refresh()
	elseif topbar then
		topbar:OpenScreen(SCREEN)
	end
end

-- Opens a player's profile: yours straight away, anyone else's once the server answers.
function Controller:OpenPlayer(userId)
	if type(userId) ~= "number" or userId < 1 then
		return
	end
	if userId == self.Player.UserId then
		self.Target = nil
		self:OpenScreen()
		return
	end
	if os.clock() - self.LastRequest < REQUEST_SECONDS and self.Pending == userId then
		return
	end
	self.LastRequest, self.Pending = os.clock(), userId
	Remotes.RequestPlayerProfile:FireServer(userId)
end

function Controller:Received(data)
	if type(data) ~= "table" or data.UserId ~= self.Pending then
		return
	end
	self.Pending = nil
	if data.Missing or busy(self.Player.PlayerGui) then
		return
	end
	local view = data.View or {}
	self.Target = {
		UserId = data.UserId,
		Name = data.Name or "Player",
		Self = false,
		Level = view.Level,
		Stats = view.Stats,
		Glassies = view.Glassies,
		Cosmetics = view.Cosmetics,
	}
	self:OpenScreen()
end

-- Lobby bubble -------------------------------------------------------------------------------------------------
function Controller:HideBubble()
	if self.Bubble then
		self.Bubble:Destroy()
		self.Bubble = nil
	end
end

function Controller:ShowBubble(player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not head then
		return
	end
	self:HideBubble()
	local gui = Instance.new("BillboardGui")
	gui.Name, gui.Adornee, gui.AlwaysOnTop, gui.ResetOnSpawn = "ProfileBubble", head, true, false
	gui.Size, gui.StudsOffset, gui.MaxDistance = UDim2.fromScale(3, 3.3), Vector3.new(0, 3, 0), 80
	local button = Instance.new("ImageButton")
	button.Name, button.Image, button.BackgroundTransparency = "Bubble", UIAssets["screens/profile/bubble_profile"], 1
	button.AnchorPoint, button.Position, button.Size =
		Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), UDim2.fromScale(1, 1)
	button.Parent = gui
	local shot = Instance.new("ImageLabel")
	shot.Name, shot.BackgroundTransparency = "Headshot", 1
	shot.Image = ("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150"):format(math.max(1, player.UserId))
	shot.AnchorPoint, shot.Position, shot.Size =
		Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.42), UDim2.fromScale(0.64, 0.58)
	local corner = Instance.new("UICorner")
	corner.CornerRadius, corner.Parent = UDim.new(0.5, 0), shot
	shot.Parent = button
	local scale = Instance.new("UIScale")
	scale.Scale, scale.Parent = 0.4, button
	gui.Parent = self.Player.PlayerGui
	TweenService:Create(scale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()
	local userId = player.UserId
	button.Activated:Connect(function()
		self:HideBubble()
		self:OpenPlayer(userId)
	end)
	self.Bubble = gui
	task.delay(BUBBLE_SECONDS, function()
		if self.Bubble == gui then
			self:HideBubble()
		end
	end)
end

-- A short tap on another player's avatar (not a camera drag, not on UI).
function Controller:Tapped(position)
	local pg = self.Player.PlayerGui
	if busy(pg) or (self.Gui and self.Gui.Enabled) then
		return
	end
	local camera = workspace.CurrentCamera
	local ray = camera:ScreenPointToRay(position.X, position.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { self.Player.Character }
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 250, params)
	local model = hit and hit.Instance:FindFirstAncestorOfClass("Model")
	while model and not model:FindFirstChildOfClass("Humanoid") do
		model = model:FindFirstAncestorOfClass("Model")
	end
	local player = model and Players:GetPlayerFromCharacter(model)
	if player and player ~= self.Player then
		self:ShowBubble(player)
	elseif self.Bubble then
		self:HideBubble()
	end
end

function Controller:WatchTaps()
	local start = {}
	UIS.InputBegan:Connect(function(input, processed)
		local kind = input.UserInputType
		if processed or (kind ~= Enum.UserInputType.MouseButton1 and kind ~= Enum.UserInputType.Touch) then
			return
		end
		start[input] = { At = os.clock(), Position = Vector2.new(input.Position.X, input.Position.Y) }
	end)
	UIS.InputEnded:Connect(function(input)
		local began = start[input]
		start[input] = nil
		if not began then
			return
		end
		local position = Vector2.new(input.Position.X, input.Position.Y)
		if os.clock() - began.At <= TAP_SECONDS and (position - began.Position).Magnitude <= TAP_PIXELS then
			self:Tapped(position)
		end
	end)
end

-- Leaderboard rows ---------------------------------------------------------------------------------------------
function Controller:HookRow(row)
	if not row:IsA("Frame") or not row.Name:match("^Row%d+$") or row:FindFirstChild("ProfileTap") then
		return
	end
	local button = Instance.new("TextButton")
	button.Name, button.Text, button.BackgroundTransparency, button.AutoButtonColor = "ProfileTap", "", 1, false
	button.Size, button.ZIndex = UDim2.fromScale(1, 1), 20
	button.Parent = row
	button.Activated:Connect(function()
		if not busy(self.Player.PlayerGui) then
			self:OpenPlayer(row:GetAttribute("UserId"))
		end
	end)
end

function Controller:WatchBoards()
	local lobby = workspace:WaitForChild("Lobby", 60)
	local props = lobby and lobby:WaitForChild("GlassClashProps", 60)
	if not props then
		return
	end
	local function consider(object)
		if object.Name:match("^Row%d+$") and object:FindFirstAncestor("Display") then
			local board = object:FindFirstAncestorWhichIsA("Model")
			if board and board.Name:match("^Leaderboard_") then
				self:HookRow(object)
			end
		end
	end
	for _, object in props:GetDescendants() do
		consider(object)
	end
	props.DescendantAdded:Connect(consider)
end

function Controller:Start()
	Remotes.ProfileSnapshot.OnClientEvent:Connect(function(profile)
		self.Profile = profile
		local loader = LoadGate.loader()
		if loader then
			loader.owned(profile) -- your glassies and equipped cosmetics load before the rest (Config/LoadTiers)
		end
		if not self.Target then
			self:Refresh()
		end
	end)
	Remotes.PlayerProfile.OnClientEvent:Connect(function(data)
		self:Received(data)
	end)
	task.spawn(self.WatchBoards, self)
	self:WatchTaps()
	local pg = self.Player:WaitForChild("PlayerGui")
	for _, name in { "InMatch", "Queued", "Watching" } do
		pg:GetAttributeChangedSignal(name):Connect(function()
			if pg:GetAttribute(name) then
				self:HideBubble()
			end
		end)
	end
	local gui = pg:WaitForChild(SCREEN, 60)
	if not gui then
		warn("[GlassClash] ProfileScreen missing from StarterGui (run tools/studio/build_profile_screen.luau)")
		return
	end
	self.Gui, self.Screen = gui, ProfileScreen.new(gui)
	gui:GetPropertyChangedSignal("Enabled"):Connect(function()
		if gui.Enabled then
			self:HideBubble()
			self:Refresh()
		else
			self.Target = nil -- next open from the top bar is your own profile
		end
	end)
	-- The top bar button always means "my profile", even while someone else's is open.
	local topbar = self.Controllers.TopbarController
	for _ = 1, 100 do
		if topbar and topbar.Icons and topbar.Icons.Profile then
			break
		end
		task.wait(0.1)
	end
	local entry = topbar and topbar.Icons and topbar.Icons.Profile
	if entry then
		entry.Icon.selected:Connect(function()
			if self.Target then
				self.Target = nil
				self:Refresh()
			end
		end)
	end
	Remotes.RequestProfile:FireServer()
	if game:GetService("RunService"):IsStudio() then
		-- Studio-only test hook: open someone's profile, show a bubble, read what is on screen.
		local dev = Instance.new("BindableFunction")
		dev.Name = "ProfileClientDev"
		dev.OnInvoke = function(command, arg)
			if command == "Open" then
				self:OpenPlayer(arg)
				return true
			elseif command == "Bubble" then
				local player = Players:GetPlayerByUserId(arg)
				if player then
					self:ShowBubble(player)
				end
				return self.Bubble ~= nil
			elseif command == "Tab" then
				self.Screen:SelectTab(arg)
				return true
			end
			return { Open = gui.Enabled, Target = self.Target and self.Target.UserId, Tab = self.Screen.Tab }
		end
		dev.Parent = self.Player:WaitForChild("PlayerScripts")
	end
end

return Controller
