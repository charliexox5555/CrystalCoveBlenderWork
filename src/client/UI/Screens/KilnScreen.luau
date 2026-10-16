local Window = require(script.Parent.Parent.Components.Window)
local Opening = require(script.Parent.Parent.Components.KilnOpening)
local Screen = {}
Screen.__index = Screen
function Screen.new(data, close, pull, refresh, initialTab)
	local self =
		setmetatable({ Data = data, Pull = pull, Refresh = refresh, Close = close, Closed = false, Serial = 0 }, Screen)
	self.Tab = initialTab or "Featured"
	self:Odds(data)
	return self
end
function Screen:Page(name, title)
	for _, view in self.CosmeticViews or {} do
		view:Destroy()
	end
	self.CosmeticViews = nil
	self.Serial += 1
	if self.Opening then
		self.Opening:Destroy()
		self.Opening = nil
	end
	require(script.Parent.ShopPools).destroy(self)
	if self.Window then
		self.Window:Destroy()
	end
	self.Window = Window.new(name, title, self.Close)
	return self.Window.Content
end
function Screen:Odds(data)
	self:OpeningHud(false)
	require(script.Parent.ShopContent).bind(self, data)
end
function Screen:OpeningHud(show)
	local hud = game.Players.LocalPlayer.PlayerGui:FindFirstChild("LobbyHUD")
	if not hud then
		return
	end
	if show then
		if self.HudRestore == nil then
			self.HudRestore = hud.Enabled
			self.HudVisibility = {}
			for _, name in { "PlayButton", "Hint" } do
				local object = hud:FindFirstChild(name)
				if object then
					self.HudVisibility[object] = object.Visible
					object.Visible = false
				end
			end
		end
		hud.Enabled = true
	elseif self.HudRestore ~= nil then
		hud.Enabled, self.HudRestore = self.HudRestore, nil
		for object, visible in self.HudVisibility do
			if object.Parent then
				object.Visible = visible
			end
		end
		self.HudVisibility = nil
	end
end
function Screen:Pending()
	local c = self:Page("KilnRevealScreen", "THE KILN")
	self:OpeningHud(true)
	self.Waiting = true
	self.Message = nil
	c.Reels.Visible, c.KilnStage.Visible, c.Rewards.Visible = false, false, false
	c.Skip.Visible, c.Collect.Visible = false, false
	c.Status.Text = "WARMING THE KILN…"
end
function Screen:Result(data)
	if self.Closed then
		return
	end
	if data.Error then
		self.Busy = false
		if self.Waiting then
			self.Waiting = false
			self:Odds(self.Data)
		end
		if self.Message then
			self.Message.Text = data.Error
		end
		return
	end
	if type(data.Results) ~= "table" or (#data.Results ~= 1 and #data.Results ~= 10) then
		return
	end
	-- A duplicate delivery can neither restart the animation nor produce another grant.
	if self.Opening or (data.Quote and self.LastQuote == data.Quote) then
		return
	end
	self.LastQuote = data.Quote
	self.Waiting = false
	self.Results = data.Results
	-- Retire the Shop immediately; the opening owns a different full-screen GUI.
	if self.Window then
		self.Window.Gui.Enabled = false
	end
	self:Page("KilnRevealScreen", "THE KILN")
	self:OpeningHud(true)
	self.Opening = Opening.new(self.Window, data.Results, self.Data.Odds, self.Close)
end
function Screen:Step(dt)
	if self.Opening then
		self.Opening:Step(dt)
	end
end
function Screen:Destroy()
	for _, view in self.CosmeticViews or {} do
		view:Destroy()
	end
	self.CosmeticViews = nil
	self.Closed = true
	self:OpeningHud(false)
	if self.Opening then
		self.Opening:Destroy()
		self.Opening = nil
	end
	require(script.Parent.ShopPools).destroy(self)
	self.Window:Destroy()
end
return Screen
