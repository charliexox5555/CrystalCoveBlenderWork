-- Daily Rewards, Playtime Rewards and Codes screens (decisions 99, 115). The server's retention view arrives with
-- every profile snapshot (DataService, Retention = RetentionRules.view); play time ticks locally between snapshots.
-- Daily claims and codes go to RetentionService; it answers on RetentionResult. Playtime gifts collect themselves on
-- the server, which sends RetentionResult { Auto = true } so a small RewardToast shows what came in. Daily Rewards
-- opens by itself once per join when today's reward is ready, outside onboarding and never over a match, a queue,
-- results or another menu. A ready Daily reward shows as a red count on the top bar gift (TopbarController:SetNotice).
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Remotes = require(RS.Shared.Remotes)
local Daily = require(script.Parent.Parent.UI.Screens.DailyRewards)
local Playtime = require(script.Parent.Parent.UI.Screens.PlaytimeRewards)
local Codes = require(script.Parent.Parent.UI.Screens.CodesPanel)
local ClaimFx = require(script.Parent.Parent.UI.Components.ClaimFx)
local RewardToast = require(script.Parent.Parent.UI.Components.RewardToast)
local Visuals = require(script.Parent.Parent.UI.Screens.RewardVisuals)
local UIAssets = require(RS.Shared.Config.UIAssets)
local Balance = require(RS.Shared.Config.Balance)
local Theme = require(script.Parent.Parent.UI.Theme)
local Controller = {}

local TICK = 0.25

function Controller:Init(controllers)
	self.Controllers, self.Player = controllers, Players.LocalPlayer
end

-- Remember which cell was claimed so the server's answer can celebrate it, and let the coins burst out of it.
function Controller:Claiming(cell, kind, color)
	self.Pending = { Cell = cell, Kind = kind, Color = color, At = os.clock() }
	local lobby = self.Controllers.LobbyController
	if lobby then
		lobby.GainOrigin = { Position = ClaimFx.center(cell), At = os.clock() }
	end
end

-- Today's play time: the server's value plus time since that snapshot, capped at the last gift.
function Controller:PlaySeconds()
	local view = self.View
	if not view then
		return 0
	end
	local gifts = view.Gifts or {}
	local cap = if #gifts > 0 then gifts[#gifts].Seconds else 0
	return math.min(cap, view.PlaytimeSeconds + math.floor(os.clock() - self.ViewAt))
end

function Controller:Refresh()
	local view = self.View
	if not view or not view.Calendar then
		return
	end
	local now = workspace:GetServerTimeNow()
	local seconds = self:PlaySeconds()
	if self.Daily and self.Daily.Gui.Enabled then
		self.Daily:Render(view.Calendar, now)
	end
	if self.Playtime and self.Playtime.Gui.Enabled then
		self.Playtime:Render(view.Gifts, seconds)
	end
	local topbar = self.Controllers.TopbarController
	if topbar and topbar.SetNotice then
		topbar:SetNotice("Daily", if view.Calendar.ClaimedToday then 0 else 1)
		topbar:SetNotice("Playtime", 0) -- gifts collect themselves (decision 115)
	end
end

-- The toast for a gift that collected itself: one picture + amount per part of the bundle, then the playtime clock.
function Controller:Collected(reward)
	local chips = {}
	if reward.Coins then
		table.insert(chips, { Image = UIAssets["icon/coin"], Text = "+" .. reward.Coins })
	end
	if reward.Xp then
		table.insert(chips, { Image = UIAssets["icon/xp"], Text = "+" .. reward.Xp })
	end
	if reward.Pull then
		table.insert(chips, { Image = Visuals.icon({ Pull = reward.Pull }), Text = "+" .. (reward.Pulls or 1) })
	end
	RewardToast.show(chips, UIAssets["topbar/playtime"])
end

-- Daily Rewards opens by itself once per join when today's reward is ready (decision 115). Waits for the loading
-- screen and the first retention view; skips players still in onboarding (its Daily step opens the screen itself)
-- and waits for a quiet lobby: no match, queue, results, menu or panel. Gives up after AutoOpenWaitSeconds.
function Controller:AutoOpenDaily()
	local player, pg = self.Player, self.Player:WaitForChild("PlayerGui")
	local cfg = Balance.Retention
	local start = os.clock()
	while os.clock() - start < cfg.AutoOpenWaitSeconds do
		task.wait(0.5)
		local view = self.View
		local step = player:GetAttribute("OnboardingStep")
		if not player:GetAttribute("ClientLoaded") or not view or not view.Calendar then
			continue
		end
		if view.Calendar.ClaimedToday or (step ~= nil and step ~= "Done") then
			return
		end
		local topbar, lobby = self.Controllers.TopbarController, self.Controllers.LobbyController
		local busy = pg:GetAttribute("InMatch")
			or pg:GetAttribute("Queued")
			or pg:GetAttribute("ResultsOpen")
			or pg:GetAttribute("Watching")
			or (topbar and topbar.Open)
			or (lobby and (lobby.PanelOpen or lobby.Screen))
		if busy then
			self.QuietSince = nil
		elseif not self.QuietSince then
			self.QuietSince = os.clock()
		elseif os.clock() - self.QuietSince >= cfg.AutoOpenQuietSeconds then
			if topbar and topbar.OpenScreen then
				topbar:OpenScreen("DailyRewardsScreen")
			end
			return
		end
	end
end

function Controller:Bind(pg)
	local function screen(name)
		return pg:WaitForChild(name, 30)
	end
	local daily, playtime, codes = screen("DailyRewardsScreen"), screen("PlaytimeRewardsScreen"), screen("CodesScreen")
	if daily then
		self.Daily = Daily.bind(daily, function(cell)
			self:Claiming(cell, "Daily", Theme.Palette.amberLight)
			Remotes.ClaimRetention:FireServer("Daily")
		end)
		daily:GetPropertyChangedSignal("Enabled"):Connect(function()
			self:Refresh()
		end)
	end
	if playtime then
		self.Playtime = Playtime.bind(playtime, function(id, cell)
			self:Claiming(cell, "Gift", Theme.Palette.aquaLight)
			Remotes.ClaimRetention:FireServer("Gift", id)
		end)
		playtime:GetPropertyChangedSignal("Enabled"):Connect(function()
			self:Refresh()
		end)
	end
	if codes then
		self.Codes = Codes.bind(codes, function(code)
			Remotes.RedeemCode:FireServer(code)
		end)
	end
end

function Controller:Start()
	local pg = self.Player:WaitForChild("PlayerGui")
	Remotes.ProfileSnapshot.OnClientEvent:Connect(function(profile)
		if type(profile) == "table" and type(profile.Retention) == "table" then
			self.View, self.ViewAt = profile.Retention, os.clock()
			self:Refresh()
		end
	end)
	Remotes.RetentionResult.OnClientEvent:Connect(function(data)
		if data.Auto and data.Ok and type(data.Reward) == "table" then
			task.spawn(function()
				-- Gifts reached in an earlier session arrive right after joining: wait for the loading screen.
				local waited = os.clock()
				while not self.Player:GetAttribute("ClientLoaded") and os.clock() - waited < 45 do
					task.wait(0.25)
				end
				self:Collected(data.Reward)
			end)
			return
		end
		if data.Kind == "Code" and self.Codes then
			self.Codes:Result(data.Ok == true, data.Message)
			return
		end
		local pending = self.Pending
		if pending and pending.Kind == data.Kind and os.clock() - pending.At < 5 and pending.Cell.Parent then
			self.Pending = nil
			if data.Ok then
				ClaimFx.celebrate(pending.Cell, data.Reward, pending.Color)
			else
				ClaimFx.refuse(pending.Cell)
			end
		end
	end)
	self:Bind(pg)
	task.spawn(function()
		self:AutoOpenDaily()
	end)
	task.spawn(function()
		while true do
			task.wait(TICK)
			self:Refresh()
		end
	end)
end

return Controller
