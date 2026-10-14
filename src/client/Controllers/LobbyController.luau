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
	end
end

function Controller:PanelOpened()
	self.PanelOpen = true
	TouchGate.acquire(self)
	self.Gui.Enabled = false
end

function Controller:Open(kind)
	if self.Player.PlayerGui:GetAttribute("InMatch") then
		return
	end
	self:Close()
	if kind == "Kiln" then
		Remotes.RequestKiln:FireServer()
	elseif self.Profile then
		self.Screen = Collection.new(kind == "Index", self.Profile, function()
			self:Close()
		end)
		self:PanelOpened()
	end
end

function Controller:Start()
	local pg = self.Player.PlayerGui
	self.Gui = U.make(
		"ScreenGui",
		pg,
		{ Name = "LobbyHUD", ResetOnSpawn = false, ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets, DisplayOrder = 5 }
	)
	local money = Panel.new(self.Gui, "Currency", UDim2.fromOffset(260, 44), UDim2.new(1, -270, 0, 6), true)
	self.Currency =
		U.text(money, "Balances", "Loading...", UDim2.fromScale(0.94, 1), UDim2.fromScale(0.03, 0), Theme.Fonts.Body)
	for i, kind in { "Kiln", "Glassies", "Index" } do
		local button = Button.new(
			self.Gui,
			kind,
			kind:upper(),
			"Blue",
			UDim2.fromOffset(112, 44),
			UDim2.fromOffset(8 + (i - 1) * 120, 58)
		)
		button.Activated:Connect(function()
			self:Open(kind)
		end)
	end
	self.Hint = U.text(
		self.Gui,
		"Hint",
		"Step on a glowing pad to clash!",
		UDim2.new(0.8, 0, 0, 28),
		UDim2.new(0.1, 0, 0, 108),
		Theme.Fonts.Caption
	)
	local function inMatch()
		self.Gui.Enabled = not pg:GetAttribute("InMatch")
		if not self.Gui.Enabled then
			self:Close()
		end
	end
	pg:GetAttributeChangedSignal("InMatch"):Connect(inMatch)
	inMatch()
	Remotes.ProfileSnapshot.OnClientEvent:Connect(function(profile)
		self.Profile = profile
		self.Currency.Text = "COINS " .. profile.Coins .. "   •   TROPHIES " .. profile.Trophies
		if self.Screen and self.Screen.Refresh and self.Screen.Index ~= nil then
			self.Screen:Refresh(profile)
		end
	end)
	Remotes.KilnOdds.OnClientEvent:Connect(function(data)
		if pg:GetAttribute("InMatch") then
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
		if self.Screen and self.Screen.Result then
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
