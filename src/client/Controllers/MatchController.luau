local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TouchGate = require(script.Parent.Parent.UI.TouchGate)
local CAS = game:GetService("ContextActionService")
local RS = game:GetService("ReplicatedStorage")
local Remotes = require(RS.Shared.Remotes)
local Screens = require(script.Parent.Parent.UI.Screens.MatchScreens)
local U = require(script.Parent.Parent.UI.Components.Util)
local Theme = require(script.Parent.Parent.UI.Theme)
local Controller = {}

function Controller:Init(controllers)
	self.Controllers = controllers
	self.Player, self.Pending = Players.LocalPlayer, {}
	self.ResultsOwner = {}
end

function Controller:CloseScreen()
	TouchGate.release(self.ResultsOwner)
	self.Player.PlayerGui:SetAttribute("ResultsOpen", false)
	if self.Screen then
		self.Screen:Destroy()
		self.Screen = nil
	end
end

function Controller:Movement(locked)
	if locked and not self.Locked and self.Controllers.LobbyController then
		self.Controllers.LobbyController:Close()
	end
	self.Player.PlayerGui:SetAttribute("InMatch", locked)
	if locked and not self.Locked then
		self.Locked = true
		TouchGate.acquire(self)
		CAS:BindActionAtPriority(
			"MatchMovement",
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
	elseif not locked and self.Locked then
		self.Locked = false
		CAS:UnbindAction("MatchMovement")
		TouchGate.release(self)
	end
end

function Controller:Notice(text)
	if self.NoticeGui then
		self.NoticeGui:Destroy()
	end
	local gui = U.screen("MatchNotice", 30)
	local label = U.text(gui, "Notice", text, UDim2.fromScale(0.8, 0.1), UDim2.fromScale(0.1, 0.75), Theme.Fonts.Body)
	label.TextColor3 = Theme.Colors.Highlight
	self.NoticeGui = gui
	task.delay(3, function()
		if gui.Parent then
			gui:Destroy()
		end
	end)
end

function Controller:State(data)
	if data.Phase == "Notice" then
		self:Notice(data.Text)
		return
	end
	if data.Phase == "Queue" then
		self.Player.PlayerGui:SetAttribute("Queued", true)
		self:CloseScreen()
		self:Movement(false)
		self.Screen = Screens.queue(data, function()
			Remotes.LeaveQueue:FireServer()
		end)
		return
	elseif data.Phase == "QueueLeft" then
		self.Player.PlayerGui:SetAttribute("Queued", false)
		if self.Screen and self.Screen.Gui.Name == "QueuePanel" then
			self:CloseScreen()
		end
		return
	end
	local side = table.find(data.PlayerIds or {}, self.Player.UserId)
	if not side then
		return
	end
	self.MatchId, self.Side = data.MatchId, side
	self.Player.PlayerGui:SetAttribute("Queued", false)
	if data.Phase == "Rolling" then
		self:CloseScreen()
		self:Movement(true)
		self.Screen = Screens.roll(data, function(id)
			Remotes.PickGlassy:FireServer(id)
		end, function()
			Remotes.Reroll:FireServer()
		end)
		local key = data.MatchId .. ":" .. data.Round
		if self.Pending[key] then
			self.Screen:Offers(self.Pending[key])
		end
	elseif data.Phase == "Aiming" or data.Phase == "Countdown" or data.Phase == "Fighting" then
		self:CloseScreen()
		self:Movement(true)
	elseif data.Phase == "RoundEnd" then
		self:CloseScreen()
		-- The fight view owns the finisher and heart beat; there is no result overlay.
	end
end

-- Called by the participant's fight view once the final blow has been rendered.
function Controller:ShatterShown(fightId)
	self.LastShatter = fightId
	if self.Screen and self.Screen.Gui.Name == "RoundEnd" and self.Screen.Data.Id == fightId then
		self.Screen:Reveal()
	end
end

function Controller:Result(data)
	self:CloseScreen()
	self:Movement(false)
	self.Pending = {}
	-- Rewards still arrive through ProfileSnapshot. Return directly to the lobby.
end

function Controller:Start()
	if RunService:IsStudio() then
		local dev = Instance.new("BindableFunction")
		dev.Name = "MatchClientDev"
		dev.OnInvoke = function(action)
			if action == "DismissResults" and self.Screen and self.Screen.Gui.Name == "ResultsScreen" then
				self:CloseScreen()
			end
		end
		dev.Parent = self.Player.PlayerScripts
	end
	Remotes.MatchState.OnClientEvent:Connect(function(data)
		self:State(data)
	end)
	Remotes.RollOffers.OnClientEvent:Connect(function(data)
		local key = data.MatchId .. ":" .. data.Round
		self.Pending[key] = data
		if
			self.Screen
			and self.Screen.Gui.Name == "RollScreen"
			and self.Screen.Data.MatchId == data.MatchId
			and self.Screen.Data.Round == data.Round
		then
			self.Screen:Offers(data)
		end
	end)
	Remotes.MatchResult.OnClientEvent:Connect(function(data)
		self:Result(data)
	end)
	self.Player.CharacterRemoving:Connect(function()
		self:CloseScreen()
		self:Movement(false)
	end)
	RunService.RenderStepped:Connect(function()
		if self.Screen then
			self.Screen:Render(workspace:GetServerTimeNow())
		end
	end)
end

return Controller
