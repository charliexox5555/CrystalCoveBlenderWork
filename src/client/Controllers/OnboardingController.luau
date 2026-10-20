-- First session on the client (decision 100, docs/design/ONBOARDING.md). The server owns the step (Player attribute
-- OnboardingStep) and grants everything; this controller only shows the way:
--   Welcome: the welcome card (StarterGui.WelcomeScreen) -> OPEN -> the 3-card Kiln opening
--   Daily:   Daily Rewards opens with a pointer on today's CLAIM; it closes by itself after the claim
--   Arena:   a guide beam to the reserved pad; after a while PLAY pulses with "Press PLAY!"
--   Match:   a pointer on the cards ("Tap a glassy!") and on the first CAST ("Tap CAST to fire your power!")
--   Done:    the first-win Kiln opening plays once the results are gone
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Remotes = require(RS.Shared.Remotes)
local Balance = require(RS.Shared.Config.Balance)
local Motion = require(script.Parent.Parent.UI.Components.Motion)
local Hint = require(script.Parent.Parent.UI.Components.Hint)
local StainedGlass = require(script.Parent.Parent.UI.Components.StainedGlass)
local Controller = {}
local O = Balance.Onboarding

function Controller:Init(controllers)
	self.Controllers, self.Player = controllers, Players.LocalPlayer
	self.Hints = {}
end

function Controller:Hint(key, target, text, bump)
	self:Unhint(key)
	if target then
		self.Hints[key] = Hint.point(target, text, bump)
	end
end

function Controller:Unhint(key)
	if self.Hints[key] then
		self.Hints[key]:Destroy()
		self.Hints[key] = nil
	end
end

local function busy(pg)
	return pg:GetAttribute("InMatch") or pg:GetAttribute("Queued") or pg:GetAttribute("ResultsOpen")
end

-- Waits until the lobby is free for a full-screen moment (no match, queue or results).
function Controller:WhenFree(fn)
	local pg = self.Player:WaitForChild("PlayerGui")
	task.spawn(function()
		while busy(pg) do
			task.wait(0.25)
		end
		fn()
	end)
end

-- Step 1 ------------------------------------------------------------------------------------------------------
function Controller:ShowWelcome()
	local pg = self.Player.PlayerGui
	local gui = pg:WaitForChild("WelcomeScreen", 30)
	if not gui or gui.Enabled then
		return
	end
	StainedGlass.bindSlices(gui)
	local button = gui:FindFirstChild("OpenButton", true)
	if button and not self.WelcomeWired then
		self.WelcomeWired = true
		button.Activated:Connect(function()
			if self.Player:GetAttribute("OnboardingStep") ~= "Welcome" then
				return
			end
			self:Unhint("welcome")
			Remotes.OnboardingAction:FireServer("OpenWelcome")
			local anim = self.WelcomeAnim
			self.WelcomeAnim = nil
			if anim then
				anim.Close(function()
					gui.Enabled = false
				end)
			else
				gui.Enabled = false
			end
		end)
	end
	gui.Enabled = true
	self.WelcomeAnim = Motion.windowIn(gui, gui:FindFirstChild("Panel"))
	if button then
		self:Hint("welcome", button, nil, true)
	end
end

-- Step 2 ------------------------------------------------------------------------------------------------------
function Controller:ShowDaily()
	local topbar = self.Controllers.TopbarController
	if not topbar then
		return
	end
	topbar:OpenScreen("DailyRewardsScreen")
	local pg = self.Player.PlayerGui
	local gui = pg:FindFirstChild("DailyRewardsScreen")
	task.delay(0.5, function()
		if not gui or self.Player:GetAttribute("OnboardingStep") ~= "Daily" then
			return
		end
		for _, cell in gui:FindFirstChild("Days", true) and gui:FindFirstChild("Days", true):GetChildren() or {} do
			if cell:GetAttribute("State") == "Today" then
				self:Hint("daily", cell:FindFirstChild("ClaimButton"), "Claim your first reward!", true)
			end
		end
	end)
end

-- Step 3 ------------------------------------------------------------------------------------------------------
function Controller:StopArenaGuide()
	if self.Guide then
		self.Guide:Destroy()
		self.Guide = nil
	end
	self:Unhint("play")
	self.GuideSerial = (self.GuideSerial or 0) + 1
end

function Controller:StartArenaGuide()
	self:StopArenaGuide()
	local pad = self.Player:GetAttribute("OnboardingPad")
	local character = self.Player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if typeof(pad) ~= "Vector3" or not root then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "OnboardingGuide"
	local marker = Instance.new("Part")
	marker.Name, marker.Anchored, marker.CanCollide, marker.CanQuery, marker.CanTouch =
		"PadMarker", true, false, false, false
	marker.Transparency, marker.Size, marker.Position = 1, Vector3.one, pad + Vector3.yAxis * 1.5
	marker.Parent = folder
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Name, a0.Parent = "OnboardingGuideStart", root
	a1.Parent = marker
	local beam = Instance.new("Beam")
	beam.Attachment0, beam.Attachment1 = a0, a1
	beam.Color = ColorSequence.new(Color3.fromHex("#FFD98A"), Color3.fromHex("#9BF3F8"))
	beam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.6),
		NumberSequenceKeypoint.new(0.15, 0.15),
		NumberSequenceKeypoint.new(1, 0),
	})
	beam.Width0, beam.Width1, beam.LightEmission, beam.FaceCamera = 0.5, 1.2, 1, true
	beam.CurveSize0, beam.Segments = 6, 24
	beam.Parent = marker
	-- "YOUR ARENA" over the pad.
	local sign = Instance.new("BillboardGui")
	sign.Size, sign.StudsOffset, sign.AlwaysOnTop = UDim2.fromScale(8, 1.6), Vector3.new(0, 4, 0), true
	sign.Parent = marker
	local text = Instance.new("TextLabel")
	text.Size, text.BackgroundTransparency, text.Text = UDim2.fromScale(1, 1), 1, "YOUR ARENA"
	text.FontFace, text.TextScaled, text.TextColor3 =
		require(script.Parent.Parent.UI.Theme).Fonts.Heading, true, Color3.fromHex("#FFD98A")
	local stroke = Instance.new("UIStroke")
	stroke.Color, stroke.Thickness = Color3.fromHex("#1F1830"), 3
	stroke.Parent = text
	text.Parent = sign
	folder.Parent = workspace
	self.Guide = {
		Destroy = function()
			folder:Destroy()
			a0:Destroy()
		end,
	}
	-- Not there yet after a while: PLAY pulses (it goes to the reserved arena).
	local serial = self.GuideSerial
	task.delay(O.PlayHintSeconds, function()
		if self.GuideSerial ~= serial or self.Player:GetAttribute("OnboardingStep") ~= "Arena" then
			return
		end
		local hud = self.Player.PlayerGui:FindFirstChild("LobbyHUD")
		local play = hud and hud:FindFirstChild("PlayButton")
		if play then
			self:Hint("play", play, "Press PLAY!", true)
		end
	end)
end

-- Step 4 ------------------------------------------------------------------------------------------------------
function Controller:WatchMatch()
	local pg = self.Player.PlayerGui
	if self.MatchWatch then
		return
	end
	self.MatchWatch = true
	local castShown = false
	task.spawn(function()
		while self.Player:GetAttribute("OnboardingStep") == "Match" do
			local roll = pg:FindFirstChild("RollScreen")
			local cards = roll and roll.Enabled and roll:FindFirstChild("Cards", true)
			if cards and not self.Hints.cards then
				self:Hint("cards", cards, "Tap a glassy!")
			elseif not cards and self.Hints.cards then
				self:Unhint("cards")
			end
			local cast = pg:FindFirstChild("CastButton")
			local castRoot = cast and cast:FindFirstChildWhichIsA("Frame")
			if castRoot and castRoot.Visible and not castShown then
				castShown = true
				self:Hint("cast", castRoot, "Tap CAST to fire your power!")
				task.delay(4, function()
					self:Unhint("cast")
				end)
			end
			task.wait(0.2)
		end
		self:Unhint("cards")
		self:Unhint("cast")
		self.MatchWatch = false
	end)
end

-- Steps -------------------------------------------------------------------------------------------------------
function Controller:Apply(step, previous)
	if step ~= "Welcome" then
		self:Unhint("welcome")
	end
	if step ~= "Daily" then
		self:Unhint("daily")
	end
	if step ~= "Arena" then
		self:StopArenaGuide()
	end
	if step == "Welcome" then
		self:WhenFree(function()
			self:ShowWelcome()
		end)
	elseif step == "Daily" and previous ~= "Welcome" and not self.Revealing then
		-- Rejoined on this step. (Coming from Welcome, the opening's COLLECT opens Daily Rewards.)
		self:WhenFree(function()
			self:ShowDaily()
		end)
	elseif step == "Arena" then
		if previous == "Daily" then
			-- The claim celebration plays, then the screen closes by itself.
			task.delay(O.DailyCloseSeconds, function()
				local topbar = self.Controllers.TopbarController
				if topbar and topbar.Open and topbar.Open.Name == "DailyRewardsScreen" then
					topbar:CloseMenu()
				end
				self:StartArenaGuide()
			end)
		else
			self:WhenFree(function()
				self:StartArenaGuide()
			end)
		end
	elseif step == "Match" then
		self:WatchMatch()
	end
end

function Controller:Start()
	local player = self.Player
	player:WaitForChild("PlayerGui")
	local previous = nil
	local function changed()
		local step = player:GetAttribute("OnboardingStep")
		if step and step ~= previous then
			local was = previous
			previous = step
			self:Apply(step, was)
		end
	end
	player:GetAttributeChangedSignal("OnboardingStep"):Connect(changed)
	player:GetAttributeChangedSignal("OnboardingPad"):Connect(function()
		if player:GetAttribute("OnboardingStep") == "Arena" and self.Guide then
			self:StartArenaGuide()
		end
	end)
	player.CharacterAdded:Connect(function()
		if player:GetAttribute("OnboardingStep") == "Arena" then
			task.wait(1)
			self:StartArenaGuide()
		end
	end)
	Remotes.OnboardingReveal.OnClientEvent:Connect(function(data)
		local lobby = self.Controllers.LobbyController
		if not lobby or type(data) ~= "table" then
			return
		end
		self.Revealing = true
		local status = if data.Kind == "Win" then "YOU WON! A FREE KILN OPEN" else "YOUR FIRST GLASSIES!"
		self:WhenFree(function()
			lobby:Reveal({ Results = data.Results, Status = status }, function()
				self.Revealing = false
				if player:GetAttribute("OnboardingStep") == "Daily" then
					self:ShowDaily()
				end
			end)
		end)
	end)
	-- Give the lobby a moment to load before the first card.
	task.wait(2)
	changed()
end

return Controller
