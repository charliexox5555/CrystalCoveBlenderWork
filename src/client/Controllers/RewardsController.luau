-- Daily Rewards, Playtime Rewards and Codes screens (decision 99). The server's retention view arrives with every
-- profile snapshot (DataService, Retention = RetentionRules.view); play time ticks locally between snapshots.
-- Claims and codes go to RetentionService; it answers on RetentionResult. Claimable rewards show as red counts on the
-- top bar gift and its rows (TopbarController:SetNotice).
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Remotes = require(RS.Shared.Remotes)
local Daily = require(script.Parent.Parent.UI.Screens.DailyRewards)
local Playtime = require(script.Parent.Parent.UI.Screens.PlaytimeRewards)
local Codes = require(script.Parent.Parent.UI.Screens.CodesPanel)
local ClaimFx = require(script.Parent.Parent.UI.Components.ClaimFx)
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
	local ready = 0
	for _, gift in view.Gifts do
		if not gift.Claimed and seconds >= gift.Seconds then
			ready += 1
		end
	end
	local topbar = self.Controllers.TopbarController
	if topbar and topbar.SetNotice then
		topbar:SetNotice("Daily", if view.Calendar.ClaimedToday then 0 else 1)
		topbar:SetNotice("Playtime", ready)
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
		while true do
			task.wait(TICK)
			self:Refresh()
		end
	end)
end

return Controller
