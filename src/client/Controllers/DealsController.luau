-- Robux offers on the client (decision 116): the Starter Pack and Daily Glassy tiles on the lobby HUD, their popups,
-- the Starter Pack's one-time auto-open, and the Need Marbles prompt used by match selection and the Shop. State
-- comes from StoreService (DealState); purchases go Deals("Buy", kind) -> intent -> Robux prompt -> receipt.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local Remotes = require(RS.Shared.Remotes)
local Rules = require(RS.Shared.OfferRules)
local Theme = require(script.Parent.Parent.UI.Theme)
local S = require(script.Parent.Parent.UI.Components.StainedGlass)
local Kit = require(script.Parent.Parent.UI.Components.MatchKit)
local Motion = require(script.Parent.Parent.UI.Components.Motion)
local GamepadNav = require(script.Parent.Parent.UI.Components.GamepadNav)
local Presentation = require(script.Parent.Parent.UI.Components.ItemPresentation)

-- A picture that can't be built (an item whose art isn't installed yet) must not break the popup or tile.
local function safe(fn, ...)
	local ok, result = pcall(fn, ...)
	return if ok then result else nil
end
local GuiService = game:GetService("GuiService")
local Controller = {}
-- TV overscan: HUD columns sit this share of the screen further in (ui-audit, Xbox).
local TV_INSET = 0.04
local function starterRight()
	return if GuiService:IsTenFootInterface() then 0.985 - TV_INSET else 0.985
end

local function screens()
	return require(script.Parent.Parent.UI.Screens.DealScreens)
end

function Controller:Init(controllers)
	self.Controllers, self.Player = controllers, Players.LocalPlayer
	self.Listeners = {}
end

-- Other UI (Marbles page, Shop side tile) can follow the state: returns a disconnect function.
function Controller:Watch(fn)
	table.insert(self.Listeners, fn)
	if self.State then
		task.spawn(fn, self.State)
	end
	return function()
		local i = table.find(self.Listeners, fn)
		if i then
			table.remove(self.Listeners, i)
		end
	end
end

function Controller:Now()
	return workspace:GetServerTimeNow() + (self.Offset or 0)
end

-- The pressed button shows "…" until the Robux prompt or a reply arrives (no double prompts).
function Controller:Buy(kind, button)
	if button then
		button.Label.Text = "…"
		Kit.enable(button, false)
		task.delay(4, function()
			if button.Parent and self.State then
				self:Apply(self.State)
			end
		end)
	end
	self.LastBuyButton = button
	Remotes.Deals:FireServer("Buy", kind)
end

function Controller:OpenStarter()
	if not self.State or (self.Popup and not self.Popup.Closed) then
		return
	end
	self.Popup = screens().starter(self.State, self.State.ServerNow or self:Now(), function(kind, button)
		self:Buy(kind, button)
	end, function()
		self:Reapply()
	end)
end

function Controller:OpenDailyGlassy()
	if not self.State or not self.State.DailyGlassy.Visible or (self.Popup and not self.Popup.Closed) then
		return
	end
	self.Popup = screens().dailyGlassy(self.State, self.State.ServerNow or self:Now(), function(kind, button)
		self:Buy(kind, button)
	end, function()
		self:Reapply()
	end)
end

-- A popup closed: put the tiles back as the latest state says (an update may have come in while it was open).
function Controller:Reapply()
	task.defer(function()
		if self.State then
			self:Apply(self.State)
		end
	end)
end

-- Not enough Marbles for `shortfall`: one-tap BUY of the cheapest covering offer. `more` = open the Marble page
-- (nil in a match, where the Shop can't open). `done` runs when the popup closes.
function Controller:NeedMarbles(shortfall, more, done)
	if self.Need and not self.Need.Closed then
		return self.Need
	end
	local held = self.State and self.State.Held or {}
	local suggestion = Rules.suggest(math.max(1, shortfall), self.State and self.State.DailyMarbles, function(pack)
		return held[tostring(pack.ProductId)] ~= nil
	end)
	self.Need = screens().needMarbles(
		shortfall,
		suggestion,
		function(s, button)
			if s.Kind == "DailyMarbles" then
				self:Buy("DailyMarbles", button)
			else
				button.Label.Text = "…"
				Kit.enable(button, false)
				Remotes.BuyMarblePack:FireServer(s.Id)
			end
		end,
		more,
		function()
			self:Reapply()
			if done then
				done()
			end
		end
	)
	return self.Need
end

----------------------------------------------------------------------------------------------------------------------
-- HUD tiles. Desktop / controller: the Daily Glassy tile sits under Inventory. Touch: next to Shop, because the
-- left side under the top third is where the thumbstick appears. The Starter Pack tile sits on the right edge.
local function tile(gui, name, hex, size, text)
	local button = Instance.new("ImageButton")
	button.Name, button.BackgroundTransparency, button.Image = name, 1, ""
	button.AutoButtonColor, button.Selectable = false, true
	button.AnchorPoint, button.Size, button.Parent = Vector2.new(0.5, 0.5), size, gui
	S.aspect(button, 300 / 340)
	local art = Kit.icon(button, "Artwork", "hud/hex_" .. hex, UDim2.fromScale(1, 1), UDim2.fromScale(0.5, 0.5))
	art.AnchorPoint = Vector2.new(0.5, 0.5)
	local plaque =
		Kit.icon(button, "LabelPlaque", "hud/label_plaque", UDim2.fromScale(1, 0.26), UDim2.fromScale(0.5, 0.92))
	plaque.AnchorPoint, plaque.ZIndex = Vector2.new(0.5, 0.5), 4
	local label = Kit.label(plaque, "Label", text, UDim2.fromScale(0.78, 0.76), UDim2.fromScale(0.11, 0.12), {
		Color = Theme.Palette.lead,
		Outline = false,
		MaxSize = 22,
		Small = true,
	})
	label.ZIndex = 5
	local constraint = Instance.new("UISizeConstraint")
	constraint.MinSize, constraint.Parent = Vector2.new(56, 63), button
	Motion.button(button)
	return button
end

function Controller:BuildTiles(hud)
	local nav = hud:WaitForChild("Navigation")
	local inventory = nav:WaitForChild("InventoryButton")
	-- Daily Glassy (creator, 2026-10-22): at the top of the left column, a tap opens the Robux prompt straight away. The
	-- odds sit behind the ODDS button on top of the tile, always visible with it. Roblox's paid random items policy
	-- allows the itemized odds in "a clickable pop-up with an 'Info' or 'Details' icon visible and accessible prior to
	-- purchase" when a descriptive word labels it (docs/design/MONETIZATION.md §4).
	local daily = tile(hud, "DailyGlassyTile", "amethyst", UDim2.fromScale(0.08, 0.19), "Daily")
	local picture = safe(
		Presentation.crate,
		daily,
		"Glassies",
		"Marbles",
		UDim2.fromScale(0.74, 0.62),
		UDim2.fromScale(0.13, 0.1),
		"Picture"
	)
	if picture and picture:IsA("GuiObject") then
		picture.ZIndex = 3
	end
	-- Price as it was first built (creator): the small emerald tag.
	local price = Kit.tag(
		daily,
		"PriceTag",
		utf8.char(0xE002) .. " 9",
		"emerald",
		UDim2.fromScale(0.72, 0.24),
		UDim2.fromScale(0.42, 0.58)
	)
	price.ZIndex = 6
	-- Same tag as before, a little more readable at laptop size (ui-audit: ~8 px text).
	price.Label.UITextSizeConstraint.MinTextSize = 12
	self.DailyPrice = price.Label
	-- ODDS: its own button over the top edge of the tile (a sibling, not a child, so a tap reaches exactly one of
	-- them); a bit larger than a tag so it's easy to hit. Placed with the tile in place().
	local oddsButton = Kit.gem(hud, "DailyOddsButton", "ODDS", "aqua", UDim2.fromOffset(84, 36), UDim2.new())
	oddsButton.UIAspectRatioConstraint:Destroy()
	oddsButton.Label.UITextSizeConstraint.MaxTextSize = 26
	-- Big enough to tap on a phone even where the tile itself is at its minimum size.
	local minimum = Instance.new("UISizeConstraint")
	minimum.MinSize, minimum.Parent = Vector2.new(84, 36), oddsButton
	for _, part in oddsButton:GetDescendants() do
		if part:IsA("GuiObject") then
			part.ZIndex += 6
		end
	end
	oddsButton.ZIndex = 7
	self.DailyTile, self.DailyOddsButton = daily, oddsButton
	daily.Activated:Connect(function()
		self:BuyDaily()
	end)
	oddsButton.Activated:Connect(function()
		self:OpenDailyGlassy()
	end)
	-- Starter Pack: a bigger amber tile on the right edge with the pack's glassy.
	local starter = tile(hud, "StarterTile", "amber", UDim2.fromScale(0.1, 0.24), "Starter")
	local tag = Kit.tag(
		starter,
		"PriceTag",
		utf8.char(0xE002) .. " 49",
		"emerald",
		UDim2.fromScale(0.62, 0.18),
		UDim2.fromScale(0.46, 0.62)
	)
	tag.ZIndex = 6
	local new = Kit.tag(starter, "NewTag", "-%", "ruby", UDim2.fromScale(0.62, 0.17), UDim2.fromScale(-0.08, -0.02))
	new.ZIndex = 6
	self.StarterTile = starter
	starter.Activated:Connect(function()
		self:OpenStarter()
	end)
	-- The Daily tile takes the Shop's old slot and Shop / Inventory move down one step; while the tile is hidden
	-- (bought today, or paid random items restricted) they go back up. Same layout on desktop, touch and console.
	self.Nav = nav
	nav:GetPropertyChangedSignal("Visible"):Connect(function()
		if self.State then
			self:Apply(self.State)
		end
	end)
	local home = nav.Position
	local shop = nav:WaitForChild("ShopButton")
	local inventoryHome = inventory.Position
	local function place()
		local navSize = nav.Size
		local step = navSize.Y.Scale * (inventoryHome.Y.Scale - shop.Position.Y.Scale)
		local shown = daily.Visible
		local responsive = self.Controllers.ResponsiveController
		local touch = if responsive and responsive.Touch
			then responsive:Touch()
			else UIS.TouchEnabled and not UIS.MouseEnabled
		-- Touch: Inventory sits beside Shop instead of under it, so nothing reaches down to the thumbstick.
		inventory.Position = if touch and shown
			then UDim2.new(shop.Position.X.Scale + 1.08, 0, shop.Position.Y.Scale, 0)
			else inventoryHome
		-- TV: the column moves in out of overscan, like the windows ResponsiveController keeps in the safe area.
		local inset = if GuiService:IsTenFootInterface() then TV_INSET else 0
		local x = home.X.Scale + inset
		nav.Position = UDim2.new(x, home.X.Offset, home.Y.Scale + (if shown then step else 0), home.Y.Offset)
		daily.Position = UDim2.fromScale(
			x + navSize.X.Scale * shop.Position.X.Scale,
			home.Y.Scale + navSize.Y.Scale * shop.Position.Y.Scale
		)
		daily.Size = UDim2.fromScale(navSize.X.Scale * shop.Size.X.Scale, navSize.Y.Scale * shop.Size.Y.Scale)
		local w, h = daily.AbsoluteSize.X, daily.AbsoluteSize.Y
		oddsButton.Visible = shown
		oddsButton.Size = UDim2.fromOffset(math.floor(math.max(84, w * 1.0)), math.floor(math.max(36, h * 0.28)))
		oddsButton.Position = UDim2.new(daily.Position.X.Scale, 0, daily.Position.Y.Scale, -math.floor(h * 0.47))
		-- Centre-anchored (Motion keeps buttons on their centre); the aspect constraint sets the real width.
		starter.Position = UDim2.new(starterRight(), -math.floor(starter.AbsoluteSize.X / 2), 0.45, 0)
		starter.Size = UDim2.fromScale(daily.Size.X.Scale * 1.15, daily.Size.Y.Scale * 1.15)
	end
	self.PlaceTiles = place
	daily:GetPropertyChangedSignal("Visible"):Connect(place)
	daily:GetPropertyChangedSignal("AbsoluteSize"):Connect(place)
	-- ResponsiveController grows Navigation on the smallest phones; the tiles follow its size by themselves.
	nav:GetPropertyChangedSignal("Size"):Connect(function()
		task.defer(place)
	end)
	place()
	task.defer(place)
	starter:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		starter.Position = UDim2.new(starterRight(), -math.floor(starter.AbsoluteSize.X / 2), 0.45, 0)
	end)
	UIS.LastInputTypeChanged:Connect(place)
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(place)
end

-- Picture on the Starter tile: the pack's glassy once its icon exists, else the gift.
function Controller:StarterPicture(state)
	local starter = self.StarterTile
	if not starter or starter:FindFirstChild("Picture") then
		return
	end
	local glassy
	for _, item in state.Items or {} do
		if item.Category == "Glassies" then
			glassy = item
		end
	end
	local picture = glassy
		and safe(
			Presentation.portrait,
			starter,
			"Glassies",
			glassy.Id,
			UDim2.fromScale(0.72, 0.6),
			UDim2.fromScale(0.14, 0.12),
			"Picture"
		)
	if not picture then
		picture = Kit.icon(starter, "Picture", "topbar/gift", UDim2.fromScale(0.6, 0.55), UDim2.fromScale(0.2, 0.14))
	end
	if picture:IsA("GuiObject") then
		picture.ZIndex = 3
	end
end

-- One tap on the tile: straight to the Robux prompt (the ODDS button on the tile opens the odds first if wanted).
function Controller:BuyDaily()
	local state = self.State and self.State.DailyGlassy
	if self.DailyBusy or not state or not state.Available then
		return
	end
	self.DailyBusy = true
	self.DailyPrice.Text = "…"
	Remotes.Deals:FireServer("Buy", "DailyGlassy")
	task.delay(4, function()
		if self.DailyBusy and self.State then
			self:Apply(self.State)
		end
	end)
end

function Controller:PopupOpen()
	return (self.Popup ~= nil and not self.Popup.Closed) or (self.Need ~= nil and not self.Need.Closed)
end

-- The tiles follow the lobby HUD's own buttons: hidden while Navigation is (the onboarding claim cards, Kiln reveals,
-- reward screens) and while one of our popups is open (ui-audit, 2026-10-22).
function Controller:HudFree()
	return not self:PopupOpen() and (self.Nav == nil or self.Nav.Visible)
end

function Controller:Apply(view)
	self.State = view
	self.Offset = (view.ServerNow or workspace:GetServerTimeNow()) - workspace:GetServerTimeNow()
	if self.StarterTile then
		local s = view.Starter
		-- DealHidden tells an open popup not to bring the tile back when it closes.
		self.StarterTile:SetAttribute("DealHidden", not s.Visible)
		self.StarterTile.Visible = s.Visible and self:HudFree()
		self:StarterPicture(s)
		local off = self.StarterTile:FindFirstChild("NewTag")
		if off then
			S.tag(off, if s.Value and s.Value.Off > 0 then "-" .. s.Value.Off .. "%" else "NEW", "ruby")
		end
		local dailyState = view.DailyGlassy
		-- Gone once bought until the next 00:00 UTC reset; never shown where paid random items are restricted.
		local showDaily = dailyState.Visible and not dailyState.BoughtToday
		self.DailyTile:SetAttribute("DealHidden", not showDaily)
		self.DailyOddsButton:SetAttribute("DealHidden", not showDaily)
		self.DailyTile.Visible = showDaily and self:HudFree()
		self.DailyBusy = false
		Kit.enable(self.DailyTile, dailyState.Available)
		self.DailyTile.Artwork.ImageTransparency = if dailyState.Available then 0 else 0.35
		self.DailyPrice.Text = if dailyState.Available then utf8.char(0xE002) .. " " .. dailyState.Price else "SOON"
	end
	if self.Popup and not self.Popup.Closed and self.Popup.Render then
		self.Popup.Render(view)
	end
	for _, fn in self.Listeners do
		task.spawn(fn, view)
	end
	self:MaybeAutoOpen()
end

-- The Starter Pack opens by itself at most twice (OfferRules.starterAutoOpen): when the lobby is free, onboarding is
-- done, nothing else is open, and the Daily Rewards auto-open has had its turn.
function Controller:MaybeAutoOpen()
	local view = self.State
	if self.AutoOpening or not view or not view.Starter.AutoOpen or not view.Starter.Available then
		return
	end
	self.AutoOpening = true
	task.spawn(function()
		local pg = self.Player.PlayerGui
		local function free()
			return not (
					pg:GetAttribute("InMatch")
					or pg:GetAttribute("Queued")
					or pg:GetAttribute("ResultsOpen")
					or pg:GetAttribute("Watching")
				)
				and self.Player:GetAttribute("OnboardingStep") == "Done"
				and not GamepadNav.hasMenu()
				and not (self.Popup and not self.Popup.Closed)
				and not (self.Need and not self.Need.Closed)
				and not (self.Controllers.LobbyController and self.Controllers.LobbyController.Screen)
				and self.Player:GetAttribute("ClientLoaded") ~= false
		end
		-- Quiet for 2 s, a beat, and still free at that moment (a menu opened in the beat restarts the wait).
		while true do
			local quiet = 0
			while quiet < 4 do
				task.wait(0.5)
				quiet = if free() then quiet + 1 else 0
			end
			task.wait(1.5)
			if free() then
				break
			end
		end
		self.AutoOpening = false
		if self.State and self.State.Starter.AutoOpen and self.State.Starter.Available then
			Remotes.Deals:FireServer("AutoOpened")
			self:OpenStarter()
		end
	end)
end

function Controller:Start()
	local pg = self.Player:WaitForChild("PlayerGui")
	task.spawn(function()
		local hud = pg:WaitForChild("LobbyHUD", 30)
		if hud then
			self:BuildTiles(hud)
			if self.State then
				self:Apply(self.State)
			end
		end
	end)
	Remotes.DealState.OnClientEvent:Connect(function(view)
		if type(view) == "table" and type(view.Starter) == "table" then
			self:Apply(view)
		end
	end)
	Remotes.StoreResult.OnClientEvent:Connect(function(result)
		if type(result) ~= "table" then
			return
		end
		if
			result.Receipt
			and result.Kind == "Starter"
			and self.Popup
			and self.Popup.Panel
			and not self.Popup.Closed
		then
			screens().celebrate(self.Popup)
		elseif result.Receipt and result.Kind == "DailyGlassy" and self.Popup and not self.Popup.Closed then
			-- The glassy comes out of a Kiln opening right away (OnboardingReveal); get out of its way.
			self.Popup:Close()
		elseif result.Receipt and (result.Kind == "Marbles" or result.Kind == "DailyMarbles") and self.Need then
			local need = self.Need
			if not need.Closed and need.Buy then
				need.Buy.Label.Text = "+" .. tostring(result.Message and result.Message:match("(%d+) Marbles") or "")
				task.delay(1.2, function()
					need:Close()
				end)
			end
		elseif result.Ok == false and self.State then
			self:Apply(self.State)
			if self.Need and not self.Need.Closed and self.Need.Buy then
				self.Need.Buy.Label.Text = "SOON"
			end
		end
	end)
	-- A closed Robux prompt (bought or not) puts the button back.
	game:GetService("MarketplaceService").PromptProductPurchaseFinished:Connect(function(_, _, purchased)
		if not purchased and self.State then
			self:Apply(self.State)
			if self.Need and not self.Need.Closed and self.Need.Buy then
				self.Need:Close()
			end
		end
	end)
	-- Ask until the first state arrives (the server can't answer before the profile has loaded).
	task.spawn(function()
		while not self.State do
			Remotes.Deals:FireServer("Request")
			task.wait(2)
		end
	end)
	-- Tile plaques: the Daily tile counts down to tomorrow once bought; the Starter tile shows its time left in its
	-- last day.
	task.spawn(function()
		while true do
			task.wait(1)
			local view = self.State
			if view and self.DailyTile then
				local now = self:Now()
				local starter = self.StarterTile.LabelPlaque.Label
				local ends = view.Starter.EndsAt
				starter.Text = if ends and ends - now < 86400 then screens().duration(ends - now) else "Starter"
			end
		end
	end)
	-- The day rolls over at 00:00 UTC: ask again so the daily offers come back without a rejoin.
	task.spawn(function()
		while true do
			local wait = 60
			if self.State and self.State.NextReset then
				wait = math.clamp(self.State.NextReset - self:Now() + 2, 5, 600)
			end
			task.wait(wait)
			Remotes.Deals:FireServer("Request")
		end
	end)
end

return Controller
