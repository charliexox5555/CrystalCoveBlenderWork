local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CAS = game:GetService("ContextActionService")
local TouchGate = require(script.Parent.Parent.UI.TouchGate)
local RS = game:GetService("ReplicatedStorage")
local Remotes = require(RS.Shared.Remotes)
local Theme = require(script.Parent.Parent.UI.Theme)
local U = require(script.Parent.Parent.UI.Components.Util)
local Motion = require(script.Parent.Parent.UI.Components.Motion)
local CurrencyGain = require(script.Parent.Parent.UI.Components.CurrencyGain)
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
			and not self.Player.PlayerGui:GetAttribute("Queued")
			and not self.Player.PlayerGui:GetAttribute("ResultsOpen")
			and not self.Player.PlayerGui:GetAttribute("Watching")
	end
end

function Controller:PanelOpened()
	self.PanelOpen = true
	TouchGate.acquire(self)
	self.Gui.Enabled = false
end

function Controller:Open(kind)
	local pg = self.Player.PlayerGui
	if
		pg:GetAttribute("InMatch")
		or pg:GetAttribute("Queued")
		or pg:GetAttribute("ResultsOpen")
		or pg:GetAttribute("Watching")
	then
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

-- Wallet display: gains fly icons into the counter (once the HUD is visible), anything else counts directly.
function Controller:ApplyWallet(profile)
	self.Shown = self.Shown or {}
	self.PendingGain = self.PendingGain or {}
	for kind, label in { Coins = self.Currency, Marbles = self.Marbles } do
		local value = if kind == "Coins" then profile.Coins else (profile.Marbles or 0)
		local shown = self.Shown[kind]
		self.Shown[kind] = value
		if shown ~= nil and value > shown then
			-- Keep the label on the old number until the icons land; hidden HUD (queue, match, results) waits.
			self.PendingGain[kind] = (self.PendingGain[kind] or 0) + (value - shown)
		elseif value == shown and self.PendingGain[kind] then
		-- A repeat snapshot with the same balance must not cancel a gain that is waiting for the HUD.
		else
			self.PendingGain[kind] = nil
			Motion.countTo(label, value)
		end
	end
	self:FlushGains()
end

function Controller:FlushGains()
	if not self.Gui or not self.Gui.Enabled or not self.PendingGain then
		return
	end
	for kind, amount in self.PendingGain do
		self.PendingGain[kind] = nil
		local label = if kind == "Coins" then self.Currency else self.Marbles
		CurrencyGain.play(kind, amount, label, function()
			Motion.countTo(label, self.Shown[kind])
		end)
	end
end

function Controller:Start()
	local pg = self.Player.PlayerGui
	local hud = LobbyHud.new(function(kind)
		self:Open(kind)
	end)
	self.Gui, self.Currency, self.Hint = hud.Gui, hud.Currency, hud.Hint
	self.Marbles = hud.Marbles
	local function inMatch()
		-- Queued players see only the queue panel: the lobby HUD (currency, shop, PLAY...) is hidden until they leave.
		self.Gui.Enabled = not pg:GetAttribute("InMatch")
			and not pg:GetAttribute("Queued")
			and not pg:GetAttribute("ResultsOpen")
			and not pg:GetAttribute("Watching")
		if not self.Gui.Enabled then
			self:Close()
		else
			-- Coming back from a match/queue/results: any gains waiting while the HUD was hidden play now.
			task.delay(0.5, function()
				self:FlushGains()
			end)
		end
	end
	-- The "step on a pad" hint is noise once you're already standing on one.
	pg:GetAttributeChangedSignal("Queued"):Connect(function()
		self.Hint.Visible = not pg:GetAttribute("Queued")
	end)
	pg:GetAttributeChangedSignal("InMatch"):Connect(inMatch)
	pg:GetAttributeChangedSignal("Queued"):Connect(inMatch)
	pg:GetAttributeChangedSignal("ResultsOpen"):Connect(inMatch)
	pg:GetAttributeChangedSignal("Watching"):Connect(inMatch)
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
		if self.Screen and self.Screen.UpdateProfile then
			self.Screen:UpdateProfile(profile)
		end
		if self.Screen and self.Screen.CosmeticViews then
			self.Screen.Profile = profile
			for _, view in self.Screen.CosmeticViews do
				view:Refresh(profile)
			end
		end
		-- Counts up/down to the new balance instead of snapping.
		self:ApplyWallet(profile)
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
		local initialTab = data.Tab or self.Screen and self.Screen.Pull and self.Screen.Tab or "Featured"
		self:Close()
		self.Screen = Kiln.new(data, function()
			self:Close()
		end, function(count, quote, category, currency)
			Remotes.PullKiln:FireServer(count, quote, category, currency)
		end, function()
			Remotes.RequestKiln:FireServer()
		end, initialTab)
		self.Screen.Profile = self.Profile
		if self.Screen.UpdateProfile then
			self.Screen:UpdateProfile(self.Profile)
		end
		for _, view in self.Screen.CosmeticViews or {} do
			view:Refresh(self.Profile)
		end
		self:PanelOpened()
	end)
	Remotes.CosmeticResult.OnClientEvent:Connect(function(data)
		if self.Screen and self.Screen.Message then
			self.Screen.Message.Text = data.Message
		end
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
			elseif action == "ShopTab" and self.Screen and self.Screen.SelectTab then
				self.Screen:SelectTab(value)
			elseif action == "ShopPool" and self.Screen and self.Screen.ShowPool then
				self.Screen:ShowPool(value)
			elseif action == "RewardsTab" and self.Screen and self.Screen.Select then
				self.Screen:Select(value)
			elseif action == "PreviewKiln" then
				self:Open("Kiln")
				task.delay(0.3, function()
					if self.Screen and self.Screen.Result then
						local results = {}
						local ids = {}
						for _, entry in self.Screen.Data.Odds do
							table.insert(ids, entry.Id)
						end
						for i = 1, if value == 10 then 10 else 1 do
							table.insert(results, {
								Id = ids[(i - 1) % #ids + 1],
								Duplicate = i % 2 == 0,
								Stars = 1,
								Rainbow = i == 3,
								BonusCoins = if i == 6 then 20 else 0,
							})
						end
						self.Screen:Result({
							Results = results,
						})
					end
				end)
			elseif action == "KilnSkip" and self.Screen and self.Screen.Opening then
				self.Screen.Opening:Skip()
			elseif action == "KilnPull" and self.Screen and self.Screen.Pull and not self.Screen.Busy then
				self.Screen.Busy = true
				local category = if type(value) == "table" then value.Category else "Glassies"
				local currency = if type(value) == "table" then value.Currency else "Coins"
				local count = if type(value) == "table" then value.Count else value
				local offer = self.Screen.Data.Crates[category][currency]
				self.Screen.SelectedPoolOdds = offer.Odds
				self.Screen:Pending(category)
				self.Screen.Pull(if count == 10 then 10 else 1, self.Screen.Data.Quote, category, currency)
			elseif action == "KilnCollect" and self.Screen and self.Screen.Opening then
				self.Screen.Opening:Collect()
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
