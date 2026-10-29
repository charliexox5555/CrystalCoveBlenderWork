-- PLAY AGAIN after a match (decision 124). 43% of new players collected their first-win prize and never started a
-- second match, because a match ends in the lobby with nothing on screen. When your match ends this shows one big
-- button that requeues you (your last arena, or the nearest free one; ArenaService:Replay). After the tutorial
-- match it waits for the win prize to be collected. It hides when pressed, when you queue or play some other way,
-- when a menu opens, or after Balance.Match.PlayAgainSeconds. While it shows, the PlayerGui attribute
-- PlayAgainShown is set so the onboarding's PLAY nudge stays quiet and the Starter Pack offer waits its turn.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Remotes = require(RS.Shared.Remotes)
local Balance = require(RS.Shared.Config.Balance)
local Screen = require(script.Parent.Parent.UI.Screens.PlayAgain)
local GamepadNav = require(script.Parent.Parent.UI.Components.GamepadNav)
local Controller = {}

function Controller:Init(controllers)
	self.Controllers = controllers
	self.Player = Players.LocalPlayer
	self.Pending = false
end

-- Anything else on screen that the button must not cover or compete with.
function Controller:Busy(): boolean
	local pg = self.Player.PlayerGui
	if self.Player:GetAttribute("ClientLoaded") ~= true then
		return true
	end
	if
		pg:GetAttribute("InMatch")
		or pg:GetAttribute("Queued")
		or pg:GetAttribute("Watching")
		or pg:GetAttribute("ResultsOpen")
	then
		return true
	end
	-- The first-match win prize card comes first (OnboardingStep "Win" until it is collected).
	if self.Player:GetAttribute("OnboardingStep") == "Win" then
		return true
	end
	local lobby, topbar = self.Controllers.LobbyController, self.Controllers.TopbarController
	-- GamepadNav knows every open window and card (shop, deals, claim cards...).
	return (lobby and lobby.PanelOpen) or (topbar and topbar.Open) or GamepadNav.hasMenu(self.Screen.Gui) or false
end

function Controller:LobbyPlay(on)
	local hud = self.Player.PlayerGui:FindFirstChild("LobbyHUD")
	local play = hud and hud:FindFirstChild("PlayButton")
	if play then
		play.Visible = on
	end
	local hint = hud and hud:FindFirstChild("Hint")
	if hint then
		hint.Visible = on
	end
end

function Controller:Hide()
	self.Pending, self.ShownAt = false, nil
	self.Screen:Hide()
	self:LobbyPlay(true)
	self.Player.PlayerGui:SetAttribute("PlayAgainShown", false)
end

function Controller:Step()
	if not self.Pending then
		return
	end
	local now = os.clock()
	if self:Busy() then
		if self.ShownAt then
			-- Queued or in a match now (or a menu opened): its job is done or it waits for the menu.
			if self.Player.PlayerGui:GetAttribute("Queued") or self.Player.PlayerGui:GetAttribute("InMatch") then
				self:Hide()
			else
				self.Screen:Hide()
				self:LobbyPlay(true)
				self.Player.PlayerGui:SetAttribute("PlayAgainShown", false)
				self.ShownAt = nil
			end
		end
		return
	end
	if now < self.ReadyAt then
		return
	end
	if not self.ShownAt then
		self.ShownAt = now
		self.Screen:Update(self.Profile, self.Player:GetAttribute("OnboardingRewardGlassy"))
		self.Screen:Show()
		self:LobbyPlay(false)
		self.Player.PlayerGui:SetAttribute("PlayAgainShown", true)
	elseif now - self.ShownAt > Balance.Match.PlayAgainSeconds then
		self:Hide()
	end
end

function Controller:Start()
	self.Screen = Screen.new(function()
		if not self.ShownAt then
			return
		end
		self:Hide()
		Remotes.RequestRematch:FireServer()
	end, function()
		self:Hide()
	end)
	Remotes.ProfileSnapshot.OnClientEvent:Connect(function(profile)
		self.Profile = profile
		self.Screen:Update(profile, self.Player:GetAttribute("OnboardingRewardGlassy"))
	end)
	local function rewardReady()
		if self.Player:GetAttribute("OnboardingRewardGlassy") then
			self.Pending = true
			self.ReadyAt = os.clock() + Balance.Match.PlayAgainDelaySeconds
		end
	end
	self.Player:GetAttributeChangedSignal("OnboardingRewardGlassy"):Connect(rewardReady)
	rewardReady()
	Remotes.MatchResult.OnClientEvent:Connect(function()
		-- A beat after the match ends, so the last heart pop and the lobby camera land first.
		self.Pending, self.ShownAt = true, nil
		self.ReadyAt = os.clock() + Balance.Match.PlayAgainDelaySeconds
	end)
	self.Player.CharacterRemoving:Connect(function()
		if self.Pending then
			self:Hide()
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.2)
			self:Step()
		end
	end)
end

return Controller
