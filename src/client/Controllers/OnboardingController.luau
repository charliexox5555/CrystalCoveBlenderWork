-- First session on the client (decision 100, docs/design/ONBOARDING.md). The server owns the step (Player attribute
-- OnboardingStep) and grants everything; this controller only shows the way:
--   Welcome: the claim card (StarterGui.WelcomeScreen: one Kiln, x3) -> OPEN -> the 3-card Kiln opening
--   Daily:   Daily Rewards opens with a pointer on today's CLAIM; it closes by itself after the claim
--   Arena:   a chevron beam to the reserved pad; after a while a pointer on PLAY
--   Match:   a pointer on the first CAST
-- Kids skip reading, so the guidance is pictures and motion only: no hint text.
--   Win:     once the results are gone, the claim card again ("YOU WON!", one Kiln) -> OPEN -> the win opening
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Remotes = require(RS.Shared.Remotes)
local Balance = require(RS.Shared.Config.Balance)
local Motion = require(script.Parent.Parent.UI.Components.Motion)
local Hint = require(script.Parent.Parent.UI.Components.Hint)
local StainedGlass = require(script.Parent.Parent.UI.Components.StainedGlass)
local Item = require(script.Parent.Parent.UI.Components.ItemPresentation)
local UIAssets = require(RS.Shared.Config.UIAssets)
local Controller = {}
local O = Balance.Onboarding

function Controller:Init(controllers)
	self.Controllers, self.Player = controllers, Players.LocalPlayer
	self.Hints = {}
end

function Controller:Hint(key, target, bump)
	self:Unhint(key)
	if target then
		self.Hints[key] = Hint.point(target, nil, bump)
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

-- Steps 1 and 5 ------------------------------------------------------------------------------------------------
-- The claim card (StarterGui.WelcomeScreen): one Kiln and an OPEN button, like claiming any reward. "Welcome" shows x3
-- (the 3 welcome opens); "Win" is the free Kiln open for the first win. OPEN asks the server, which grants and sends
-- the opening.
local CLAIMS = {
	Welcome = { Title = "WELCOME!", Count = "x3", Action = "OpenWelcome" },
	Win = { Title = "YOU WON!", Action = "OpenWin" },
}

local function claimOdds(kind)
	if kind == "Win" then
		return string.format(
			"RARE %d%% · EPIC %d%%",
			math.round(O.WinPullOdds.Rare * 100),
			math.round(O.WinPullOdds.Epic * 100)
		)
	end
	return "1 COMMON · 1 UNCOMMON · 1 RARE (100%)"
end

function Controller:ShowClaim(kind)
	local claim = CLAIMS[kind]
	local pg = self.Player.PlayerGui
	local gui = pg:WaitForChild("WelcomeScreen", 30)
	if not claim or not gui or gui.Enabled or self.Player:GetAttribute("OnboardingStep") ~= kind then
		return
	end
	StainedGlass.bindSlices(gui)
	local title, odds = gui:FindFirstChild("Title", true), gui:FindFirstChild("Odds", true)
	if title then
		title.Text = claim.Title
	end
	if odds then
		odds.Text = claimOdds(kind)
	end
	-- The Coin Kiln in the claim slot, framed like the shop's (the authored Kiln viewport is the editable stand-in).
	local reward = gui:FindFirstChild("Reward", true)
	local slot = reward and reward:FindFirstChild("Kiln")
	if slot and not slot:GetAttribute("Framed") then
		local ok = pcall(Item.crate, reward, "Glassies", "Coins", slot.Size, slot.Position, "Kiln")
		slot:SetAttribute("Framed", ok)
	end
	local count = reward and reward:FindFirstChild("Count", true)
	if count then
		count.Text, count.Visible = claim.Count or "", claim.Count ~= nil
	end
	local button = gui:FindFirstChild("OpenButton", true)
	if button and not self.ClaimWired then
		self.ClaimWired = true
		button.Activated:Connect(function()
			local open = CLAIMS[self.Player:GetAttribute("OnboardingStep")]
			if not open or not gui.Enabled then
				return
			end
			Remotes.OnboardingAction:FireServer(open.Action)
			local anim = self.ClaimAnim
			self.ClaimAnim = nil
			if anim then
				-- The close fades everything; the template's look comes back once it is hidden (the Win claim
				-- reuses the card).
				local restore = Motion.fadeSnapshot(gui:FindFirstChild("Panel"))
				anim.Close(function()
					gui.Enabled = false
					restore()
				end)
			else
				gui.Enabled = false
			end
		end)
	end
	-- A clean stage: only the wallet stays on screen behind the card.
	local lobby = self.Controllers.LobbyController
	if lobby and lobby.Gui then
		lobby:Close()
		lobby:PanelOpened()
		lobby:ShowWallet()
	end
	gui.Enabled = true
	self.ClaimAnim = Motion.windowIn(gui, gui:FindFirstChild("Panel"))
	-- One big button needs no pointer: it pulses, and the glow behind the Kiln turns.
	local glow = reward and reward:FindFirstChild("Glow")
	task.spawn(function()
		local last = 0
		while gui.Enabled and self.Player:GetAttribute("OnboardingStep") == kind do
			if glow and not Motion.reduced() then
				glow.Rotation = (glow.Rotation + 0.4) % 360
			end
			if button and os.clock() - last > 0.9 then
				last = os.clock()
				Motion.bump(button, 0.07)
			end
			task.wait()
		end
	end)
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
				self:Hint("daily", cell:FindFirstChild("ClaimButton"), true)
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
	-- Gold chevrons that stream toward the pad (no words: the arena's board already says it is reserved).
	local beam = Instance.new("Beam")
	beam.Attachment0, beam.Attachment1 = a0, a1
	beam.Texture, beam.TextureMode, beam.TextureLength =
		UIAssets["onboarding/guide_chevron"] or "", Enum.TextureMode.Static, 2.2
	beam.TextureSpeed = if Motion.reduced() then 0 else 1.2
	beam.Color = ColorSequence.new(Color3.fromHex("#FFC53D"), Color3.fromHex("#FFE9A8"))
	beam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.12, 0.05),
		NumberSequenceKeypoint.new(1, 0),
	})
	beam.Width0, beam.Width1, beam.LightEmission, beam.LightInfluence, beam.FaceCamera = 1.6, 1.6, 0.4, 0, true
	beam.CurveSize0, beam.Segments = 3, 24
	beam.Parent = marker
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
			self:Hint("play", play, true)
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
			local cast = pg:FindFirstChild("CastButton")
			local castRoot = cast and cast:FindFirstChildWhichIsA("Frame")
			if castRoot and castRoot.Visible and not castShown then
				castShown = true
				self:Hint("cast", castRoot)
				task.delay(4, function()
					self:Unhint("cast")
				end)
			end
			task.wait(0.2)
		end
		self:Unhint("cast")
		self.MatchWatch = false
	end)
end

-- Steps -------------------------------------------------------------------------------------------------------
function Controller:Apply(step, previous)
	if step ~= "Daily" then
		self:Unhint("daily")
	end
	if step ~= "Arena" then
		self:StopArenaGuide()
	end
	if step == "Welcome" or step == "Win" then
		-- Win waits for the results screen to close (WhenFree).
		self:WhenFree(function()
			self:ShowClaim(step)
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
				Remotes.OnboardingAction:FireServer("Collected") -- funnel: the opening was closed
				if player:GetAttribute("OnboardingStep") == "Daily" then
					self:ShowDaily()
				end
			end)
		end)
	end)
	-- The first card waits for the loading screen (ReplicatedFirst LoadingScreen sets ClientLoaded when it is gone;
	-- the cap covers a client without it), then gives the lobby a beat.
	local waited = os.clock()
	while not player:GetAttribute("ClientLoaded") and os.clock() - waited < 45 do
		task.wait(0.1)
	end
	task.wait(0.6)
	changed()
end

return Controller
