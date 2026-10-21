-- First session on the client (decision 100, docs/design/ONBOARDING.md). The server owns the step (Player attribute
-- OnboardingStep) and grants everything; this controller only shows the way:
--   Welcome: the claim card (StarterGui.WelcomeScreen: one Kiln, x3) -> OPEN -> the 3-card Kiln opening
--   Daily:   Daily Rewards opens with a pointer on today's CLAIM; it closes by itself after the claim
--   Arena:   a chevron beam to the reserved pad; after a while a pointer on PLAY
--   Match:   a pointer on the first CAST
--   Win:     once the results are gone, the claim card again ("YOU WON!", one Kiln) -> OPEN -> the win opening
-- Kids skip reading, so the guidance is pictures and motion only: no hint text. Keep() brings the step's moment back
-- whenever the lobby goes quiet (a closed screen, a reset, a lost opening), so nobody is left with nothing to do.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local CAS = game:GetService("ContextActionService")
local Remotes = require(RS.Shared.Remotes)
local Balance = require(RS.Shared.Config.Balance)
local Motion = require(script.Parent.Parent.UI.Components.Motion)
local GamepadNav = require(script.Parent.Parent.UI.Components.GamepadNav)
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

-- The claim card's Kiln is in the Soon loading tier (decision 111) while the card shows as soon as the loading screen
-- is gone: ask for it first and give it a moment, so the card never opens with an empty slot. A client without the
-- loading module just skips the wait.
local function preload(item, timeout)
	local screen = game.ReplicatedFirst:FindFirstChild("LoadingScreen")
	local module = screen and screen:FindFirstChild("Preload")
	local ok, Preload = pcall(require, module)
	if ok and type(Preload) == "table" then
		pcall(function()
			Preload.await(Preload.want(item), timeout)
		end)
	end
end

-- Steps 1 and 5 ------------------------------------------------------------------------------------------------
-- The claim card (StarterGui.WelcomeScreen): one Kiln and an OPEN button, like claiming any reward. "Welcome" shows x3
-- (the 3 welcome opens); "Win" is the free Kiln open for the first win. OPEN asks the server, which grants and sends
-- the opening.
local CLAIMS = {
	Welcome = { Title = "WELCOME!", Count = "x3", Action = "OpenWelcome" },
	Win = { Title = "YOU WON!", Action = "OpenWin" },
}

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
		-- Free opens show no odds line on the card (creator, 2026-10-20); paid Kiln pulls keep theirs.
		odds.Visible = false
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
			if not open or not gui.Enabled or self.ClaimPending then
				return -- a second tap while the card closes does nothing
			end
			Remotes.OnboardingAction:FireServer(open.Action)
			-- The opening takes the stage next; don't re-offer the card while the server answers.
			self.ClaimPending = os.clock()
			self:HideClaim()
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
	self.ClaimKind, self.ClaimPending = kind, nil
	-- The card is the one thing to do: keyboard / controller walking is held while it is up (touch is gated above).
	CAS:BindActionAtPriority(
		"OnboardingClaim",
		function()
			return Enum.ContextActionResult.Sink
		end,
		false,
		Enum.ContextActionPriority.High.Value,
		Enum.PlayerActions.CharacterForward,
		Enum.PlayerActions.CharacterBackward,
		Enum.PlayerActions.CharacterLeft,
		Enum.PlayerActions.CharacterRight,
		Enum.PlayerActions.CharacterJump
	)
	-- Controller: the one big OPEN button is selected, so A opens.
	if self.ClaimNav then
		self.ClaimNav.Pop()
	end
	self.ClaimNav = GamepadNav.push(gui:FindFirstChild("Panel") or gui, { First = button })
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

-- Puts the claim card away. The lobby stays put away: the opening (or the menu or match that took the screen)
-- owns it next.
function Controller:HideClaim()
	local gui = self.Player.PlayerGui:FindFirstChild("WelcomeScreen")
	CAS:UnbindAction("OnboardingClaim")
	self.ClaimKind = nil
	if self.ClaimNav then
		self.ClaimNav.Pop()
		self.ClaimNav = nil
	end
	local anim = self.ClaimAnim
	self.ClaimAnim = nil
	if gui and gui.Enabled then
		if anim then
			-- The close fades everything; the template's look comes back once it is hidden (the Win claim reuses the
			-- card).
			local restore = Motion.fadeSnapshot(gui:FindFirstChild("Panel"))
			anim.Close(function()
				if not self.ClaimKind then
					gui.Enabled = false
				end
				restore()
			end)
		else
			gui.Enabled = false
		end
	end
end

-- The welcome / win opening (glassies the server already granted). `reveal` = self.Revealing: { Data, Screen,
-- Waiting, Replayed }; Keep plays it again if something closes it before COLLECT.
function Controller:PlayReveal(reveal)
	local lobby = self.Controllers.LobbyController
	if not lobby then
		return
	end
	local data = reveal.Data
	local status = if data.Kind == "Win" then "YOU WON! A FREE KILN OPEN" else "YOUR FIRST GLASSIES!"
	reveal.Waiting = true
	self:WhenFree(function()
		reveal.Waiting = false
		if self.Revealing ~= reveal then
			return
		end
		lobby:Reveal({ Results = data.Results, Status = status }, function()
			self:RevealDone(reveal)
		end)
		reveal.Screen = lobby.Screen
	end)
end

function Controller:RevealDone(reveal)
	if self.Revealing ~= reveal then
		return
	end
	self.Revealing = nil
	Remotes.OnboardingAction:FireServer("Collected") -- funnel: the opening was closed
	if self.Player:GetAttribute("OnboardingStep") == "Daily" then
		self:ShowDaily()
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
	-- Gold chevrons that stream toward the pad (no words: the arena's board already says it is reserved). A Beam lays
	-- its texture's vertical axis along its length with the top at Attachment0, and a positive TextureSpeed scrolls
	-- toward Attachment0, so the pad is Attachment0 and the "^" chevrons point and flow to it.
	local beam = Instance.new("Beam")
	beam.Attachment0, beam.Attachment1 = a1, a0
	beam.Texture, beam.TextureMode, beam.TextureLength =
		UIAssets["onboarding/guide_chevron"] or "", Enum.TextureMode.Static, 2.2
	beam.TextureSpeed = if Motion.reduced() then 0 else 1.2
	beam.Color = ColorSequence.new(Color3.fromHex("#FFC53D"), Color3.fromHex("#FFE9A8"))
	beam.Transparency = NumberSequence.new({ -- fades out at the player's end
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.88, 0.05),
		NumberSequenceKeypoint.new(1, 1),
	})
	beam.Width0, beam.Width1, beam.LightEmission, beam.LightInfluence, beam.FaceCamera = 1.6, 1.6, 0.4, 0, true
	beam.Segments = 24
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

-- Keep it going -----------------------------------------------------------------------------------------------
-- The step's own moment comes back whenever the lobby is quiet, whatever the player did in between (closed Daily
-- Rewards, opened another menu, reset, watched a match, a card lost behind a queue): a new player always has the
-- next thing in front of them. Pictures and motion only, like the rest.
function Controller:Keep()
	local player, pg = self.Player, self.Player.PlayerGui
	local step = player:GetAttribute("OnboardingStep")
	local topbar, lobby = self.Controllers.TopbarController, self.Controllers.LobbyController
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local matchUi = busy(pg) or pg:GetAttribute("Watching")
	local menu = topbar and topbar.Open
	local now = os.clock()
	-- Quiet = in the lobby, nothing open, not walking: the moment a kid is left with nothing to do.
	local panel = lobby and lobby.PanelOpen and not self.ClaimKind and not self.ClaimPending
	if matchUi or menu or panel or self.Revealing or (humanoid and humanoid.MoveDirection.Magnitude > 0.1) then
		self.QuietSince = now
	end
	local quiet = now - (self.QuietSince or now)
	local claim = CLAIMS[step]
	if self.ClaimKind and self.ClaimKind ~= step then
		-- Opened from elsewhere (the server opens it when they try to play): the opening takes over, as after OPEN.
		self.ClaimPending = now
		self:HideClaim()
	elseif self.ClaimKind and (matchUi or menu) then
		-- Settings over the card, or a match took the screen (each puts the lobby away itself): it comes back after.
		self:HideClaim()
	end
	if self.ClaimPending and self.Revealing then
		self.ClaimPending = nil
	elseif self.ClaimPending and now - self.ClaimPending > O.ClaimRetrySeconds then
		self.ClaimPending = nil -- no opening came: give the lobby back (the card comes again if it is still due)
		if lobby and lobby.Gui then
			lobby:Close()
		end
	end
	-- The opening was taken off the stage (a menu, a reset) before COLLECT: play it again once, so the new glassies
	-- are always seen; a second loss just finishes it.
	local reveal = self.Revealing
	if reveal and reveal.Screen and lobby and lobby.Screen ~= reveal.Screen then
		reveal.Screen = nil
		if reveal.Replayed then
			self:RevealDone(reveal)
		else
			reveal.Replayed = true
		end
	end
	if reveal and not reveal.Screen and not reveal.Waiting and not matchUi and not menu then
		self:PlayReveal(reveal)
	end
	local card = pg:FindFirstChild("WelcomeScreen")
	if
		claim
		and card
		and not card.Enabled
		and not self.ClaimKind
		and not self.ClaimPending
		and not self.ClaimLoading
	then
		if not self.Revealing and not matchUi and not menu and not (lobby and lobby.PanelOpen) then
			self:ShowClaim(step)
		end
	end
	local daily = menu and menu.Name == "DailyRewardsScreen"
	if step == "Daily" and not daily and not self.Revealing and quiet >= O.IdleNudgeSeconds then
		self.QuietSince = now
		self:ShowDaily()
	end
	if step == "Arena" then
		if matchUi and self.Guide then
			self:StopArenaGuide() -- watching or queued elsewhere: the beam comes back in the lobby
		elseif not matchUi and not self.Guide and typeof(player:GetAttribute("OnboardingPad")) == "Vector3" then
			self:StartArenaGuide() -- no pad (every arena busy): the PLAY nudge below finds one
		end
	end
	-- PLAY pulses for a still player on the Arena step, and once more right after the tutorial (the second match).
	local after = step == "Done" and self.DoneAt and now - self.DoneAt < O.DoneNudgeSeconds
	if matchUi then
		self.DoneAt = nil -- the next match started: the tutorial's last nudge is spent
	end
	if (step == "Arena" or after) and not matchUi and not self.Hints.play and quiet >= O.IdleNudgeSeconds then
		local hud = pg:FindFirstChild("LobbyHUD")
		local play = hud and hud:FindFirstChild("PlayButton")
		if play then
			self:Hint("play", play, true)
		end
	elseif step ~= "Arena" and not after then
		self:Unhint("play")
	end
end

-- Steps -------------------------------------------------------------------------------------------------------
function Controller:Apply(step, previous)
	if step == "Done" and previous == "Win" then
		self.DoneAt = os.clock() -- the win prize is open: the next nudge points at PLAY (Keep)
	end
	if step ~= "Daily" then
		self:Unhint("daily")
	end
	if step ~= "Arena" then
		self:StopArenaGuide()
	end
	if step == "Welcome" or step == "Win" then
		-- Win waits for the results screen to close (WhenFree).
		self:WhenFree(function()
			self.ClaimLoading = true -- Keep waits for this first show
			preload("asset:Kilns", O.ClaimPreloadSeconds)
			self.ClaimLoading = false
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
	local previous, ready = nil, false
	local function changed()
		local step = player:GetAttribute("OnboardingStep")
		-- Nothing shows under the loading screen: the profile's step can arrive before it is gone.
		if ready and step and step ~= previous then
			local was = previous
			previous = step
			self:Apply(step, was)
		end
	end
	player:GetAttributeChangedSignal("OnboardingStep"):Connect(changed)
	player:GetAttributeChangedSignal("OnboardingPad"):Connect(function()
		-- A new or renewed reservation re-targets the beam; a first one that failed (no free arena) starts it now.
		if player:GetAttribute("OnboardingStep") == "Arena" and (self.Guide or not busy(player.PlayerGui)) then
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
		if type(data) ~= "table" or type(data.Results) ~= "table" then
			return
		end
		self.Revealing = { Data = data }
		self:PlayReveal(self.Revealing)
	end)
	-- The first card waits for the loading screen (ReplicatedFirst LoadingScreen sets ClientLoaded when it is gone;
	-- the cap covers a client without it), then gives the lobby a beat.
	local waited = os.clock()
	while not player:GetAttribute("ClientLoaded") and os.clock() - waited < 45 do
		task.wait(0.1)
	end
	task.wait(0.6)
	ready = true
	changed()
	task.spawn(function()
		while true do
			task.wait(O.KeepCheckSeconds)
			local ok, err = pcall(self.Keep, self)
			if not ok then
				warn("[Onboarding] " .. tostring(err))
				task.wait(5)
			end
		end
	end)
end

return Controller
