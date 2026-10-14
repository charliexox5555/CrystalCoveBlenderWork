local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CAS = game:GetService("ContextActionService")
local TouchGate = require(script.Parent.Parent.UI.TouchGate)
local RS = game:GetService("ReplicatedStorage")
local Remotes = require(RS.Shared.Remotes)
local Theme = require(script.Parent.Parent.UI.Theme)
local U = require(script.Parent.Parent.UI.Components.Util)
local Panel = require(script.Parent.Parent.UI.Components.Panel)
local Button = require(script.Parent.Parent.UI.Components.Button)
local Collection = require(script.Parent.Parent.UI.Screens.CollectionScreen)
local Kiln = require(script.Parent.Parent.UI.Screens.KilnScreen)
local LobbyHud = require(script.Parent.Parent.UI.Screens.LobbyHud)
local Rewards = require(script.Parent.Parent.UI.Screens.RewardsScreen)
local Controller = {}

function Controller:Init(controllers)
	self.Controllers, self.Player = controllers, Players.LocalPlayer
end

function Controller:Close()
	if self.Screen then
		self.Screen:Destroy()
		self.Screen = nil
	end
	if self.PanelOpen then
		TouchGate.release(self)
		self.PanelOpen = false
	end
	if self.Gui then
		self.Gui.Enabled = not self.Player.PlayerGui:GetAttribute("InMatch")
			and not self.Player.PlayerGui:GetAttribute("ResultsOpen")
	end
end

function Controller:PanelOpened()
	self.PanelOpen = true
	TouchGate.acquire(self)
	self.Gui.Enabled = false
end

function Controller:Open(kind)
	if self.Player.PlayerGui:GetAttribute("InMatch") or self.Player.PlayerGui:GetAttribute("ResultsOpen") then
		return
	end
	self:Close()
	if kind == "Kiln" then
		Remotes.RequestKiln:FireServer()
	elseif kind == "Rewards" and self.Profile and self.Profile.Retention then
		self.Screen = Rewards.new(self.Profile, function()
			self:Close()
		end, function(action, id)
			Remotes.ClaimRetention:FireServer(action, id)
		end, function(code)
			Remotes.RedeemCode:FireServer(code)
		end)
		self:PanelOpened()
	elseif self.Profile then
		self.Screen = Collection.new(kind == "Index", self.Profile, function()
			self:Close()
		end)
		self:PanelOpened()
	end
end

function Controller:Start()
	local pg = self.Player.PlayerGui
	local hud = LobbyHud.new(function(kind)
		self:Open(kind)
	end)
	self.Gui, self.Currency, self.Hint = hud.Gui, hud.Currency, hud.Hint
	local function inMatch()
		self.Gui.Enabled = not pg:GetAttribute("InMatch") and not pg:GetAttribute("ResultsOpen")
		if not self.Gui.Enabled then
			self:Close()
		end
	end
	-- The "step on a pad" hint is noise once you're already standing on one.
	pg:GetAttributeChangedSignal("Queued"):Connect(function()
		self.Hint.Visible = not pg:GetAttribute("Queued")
	end)
	pg:GetAttributeChangedSignal("InMatch"):Connect(inMatch)
	pg:GetAttributeChangedSignal("ResultsOpen"):Connect(inMatch)
	inMatch()
	Remotes.ProfileSnapshot.OnClientEvent:Connect(function(profile)
		local changed = false
		for id, owned in profile.Glassies do
			local previous = self.Profile and self.Profile.Glassies[id]
			if not previous or previous.Count ~= owned.Count or previous.Rainbow ~= owned.Rainbow then
				changed = true
				break
			end
		end
		self.Profile = profile
		self.Currency.Text = "COINS " .. profile.Coins .. "   •   TROPHIES " .. profile.Trophies
		if
			self.Screen
			and self.Screen.Refresh
			and (self.Screen.Selected ~= nil or (self.Screen.Index ~= nil and changed))
		then
			self.Screen:Refresh(profile)
		end
	end)
	Remotes.RetentionResult.OnClientEvent:Connect(function(data)
		if data.Open then
			self:Open("Rewards")
			if self.Screen and self.Screen.Select then
				self.Screen:Select(data.Open)
			end
			return
		end
		if self.Screen and self.Screen.Selected then
			self.Screen:Result(data)
		elseif data.Ok then
			self.Controllers.MatchController:Notice(data.Message)
		end
	end)
	Remotes.KilnOdds.OnClientEvent:Connect(function(data)
		if pg:GetAttribute("InMatch") or pg:GetAttribute("ResultsOpen") then
			return
		end
		self:Close()
		self.Screen = Kiln.new(data, function()
			self:Close()
		end, function(count, quote)
			Remotes.PullKiln:FireServer(count, quote)
		end, function()
			Remotes.RequestKiln:FireServer()
		end)
		self:PanelOpened()
	end)
	Remotes.KilnResult.OnClientEvent:Connect(function(data)
		if self.Screen and self.Screen.Pull and self.Screen.Result then
			self.Screen:Result(data)
		end
	end)
	CAS:BindAction("CloseLobbyPanel", function(_, state)
		if state == Enum.UserInputState.Begin and self.Screen then
			self:Close()
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.Escape, Enum.KeyCode.ButtonB)
	RunService.RenderStepped:Connect(function(dt)
		if self.Screen and self.Screen.Step then
			self.Screen:Step(dt)
		end
	end)
	Remotes.RequestProfile:FireServer()
	if RunService:IsStudio() then
		local dev = U.make("BindableFunction", self.Player.PlayerScripts, { Name = "LobbyClientDev" })
		dev.OnInvoke = function(action, value)
			if action == "Open" then
				self:Open(value)
			elseif action == "Detail" and self.Screen and self.Screen.Detail then
				self.Screen:Detail(value)
			elseif action == "Close" then
				self:Close()
			elseif action == "RewardsTab" and self.Screen and self.Screen.Select then
				self.Screen:Select(value)
			elseif action == "PreviewKiln" then
				self:Open("Kiln")
				task.delay(0.3, function()
					if self.Screen and self.Screen.Result then
						self.Screen:Result({
							Results = {
								{ Id = "pop", Duplicate = true, Stars = 1, Rainbow = false, BonusCoins = 0 },
								{ Id = "jam", Duplicate = false, Stars = 0, Rainbow = false, BonusCoins = 0 },
							},
						})
					end
				end)
			elseif action == "PreviewMatch" then
				self:Close()
				self.Screen = require(script.Parent.Parent.Dev.UIPreview).new(value)
				self:PanelOpened()
			elseif action == "Inspect" then
				return {
					Profile = self.Profile,
					Screen = self.Screen and self.Screen.Window.Gui.Name,
					HUD = self.Gui.Enabled,
				}
			end
		end
	end
end
return Controller
