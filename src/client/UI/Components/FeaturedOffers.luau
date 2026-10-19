-- Featured shop page: four personalized daily offers (3 Robux, 1 Coin), the featured limited
-- bundle banner and one shared reset countdown. Restyles the authored FeaturedPage frames
-- (big art cards via ShopCard, a hero bundle banner); the server (StoreService) owns offers,
-- prices and purchases. Lives in the Shop's CrateViews so the screen steps, refreshes and
-- destroys it with the other shop panels.
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Remotes = require(RS.Shared.Remotes)
local Rules = require(RS.Shared.DailyStoreRules)
local U = require(script.Parent.Util)
local S = require(script.Parent.StainedGlass)
local Theme = require(script.Parent.Parent.Theme)
local Item = require(script.Parent.ItemPresentation)
local Motion = require(script.Parent.Motion)
local Gem = require(script.Parent.GemButton)
local Card = require(script.Parent.ShopCard)
local Featured = {}
Featured.__index = Featured
local categoryNames = { Glassies = "Glassy", Finishers = "Finisher", Rideables = "Flyer" }
-- Hero slots in the bundle banner, back to front: flyer (left), finisher (right), glassy (centre).
local heroSlots = {
	ShowcasePop = { X = 0.75, Size = 0.9, Z = 5 },
	ShowcaseJam = { X = 0.57, Size = 0.72, Z = 4 },
	ShowcasePrism = { X = 0.92, Size = 0.72, Z = 4 },
}
local heroOrder = { "ShowcasePop", "ShowcaseJam", "ShowcasePrism" }
local rarityColours = {
	Common = Theme.Palette.milk,
	Uncommon = Theme.Palette.emeraldLight,
	Rare = Theme.Palette.sapphireLight,
	Epic = Theme.Palette.amethystLight,
	Legendary = Theme.Palette.amberLight,
	Mythic = Theme.Palette.rubyLight,
}
local ROBUX = Card.ROBUX

local function clock(seconds)
	seconds = math.max(0, math.floor(seconds))
	return string.format("%02d:%02d:%02d", seconds // 3600, seconds % 3600 // 60, seconds % 60)
end

local function bob(viewport)
	if Motion.reduced() then
		return
	end
	local base = viewport.Position
	local lift = UDim2.new(base.X.Scale, base.X.Offset, base.Y.Scale - 0.018, base.Y.Offset)
	task.delay(math.random() * 1.2, function()
		if viewport.Parent then
			TweenService:Create(
				viewport,
				TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
				{ Position = lift }
			):Play()
		end
	end)
end

function Featured.new(page, message)
	local self = setmetatable({ Page = page, Message = message, Connections = {}, Cards = {} }, Featured)
	self.Offers = page.DailyOffers
	self.Showcase = page.Showcase
	page.DailyTitle.Text = "DAILY SHOP"
	page.RefreshTimer.Text = ""
	local timerSize = page.RefreshTimer:FindFirstChildOfClass("UITextSizeConstraint")
	if timerSize then
		timerSize.MaxTextSize = 22
	end
	for i = 1, 4 do
		local frame = self.Offers["Offer" .. i]
		for _, child in frame:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local card = Card.new(frame)
		Card.button(card, "soon", "…")
		self.Cards[i] = card
		table.insert(
			self.Connections,
			card.Button.Activated:Connect(function()
				self:Buy(i)
			end)
		)
	end
	self:BuildBanner()
	table.insert(
		self.Connections,
		Remotes.StoreOffers.OnClientEvent:Connect(function(view)
			self:Apply(view)
		end)
	)
	table.insert(
		self.Connections,
		Remotes.StoreResult.OnClientEvent:Connect(function(result)
			if type(result) == "table" and type(result.Message) == "string" then
				self:Say(result.Message)
			end
		end)
	)
	Remotes.RequestStore:FireServer()
	return self
end

-- Limited bundle banner: pill, big title, item line, status; overlapping hero art on the right
-- with View and price buttons in front of it.
function Featured:BuildBanner()
	local show = self.Showcase
	show.Eyebrow.Visible = false
	local pill = U.make("ImageLabel", show, {
		Name = "Pill",
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.03, 0.08),
		Size = UDim2.fromScale(0.4, 0.17),
		ZIndex = 3,
	})
	-- Wide enough for its words at the readable minimum (3.75:1 cut "LIMITED-TIME BUNDLE" to "LIMITED-TIME").
	U.make("UIAspectRatioConstraint", pill, { DominantAxis = Enum.DominantAxis.Height }).AspectRatio = 5.5
	local label = U.text(pill, "Label", "", UDim2.fromScale(0.78, 0.6), UDim2.fromScale(0.11, 0.2), Theme.Fonts.Caption)
	label.ZIndex, label.UITextSizeConstraint.MinTextSize = 4, Theme.TextFit.MinSmall
	label:SetAttribute("FitMin", Theme.TextFit.MinSmall)
	S.tag(pill, "LIMITED TIME", "amethyst")
	show.Title.Position, show.Title.Size = UDim2.fromScale(0.03, 0.27), UDim2.fromScale(0.46, 0.3)
	show.Title.FontFace, show.Title.TextXAlignment = Theme.Fonts.Heading, Enum.TextXAlignment.Left
	show.Title.UITextSizeConstraint.MaxTextSize = 64
	U.make("Frame", show, {
		Name = "Divider",
		BorderSizePixel = 0,
		BackgroundColor3 = Theme.Palette.amethystLight,
		BackgroundTransparency = 0.2,
		Position = UDim2.fromScale(0.03, 0.59),
		Size = UDim2.fromScale(0.42, 0.012),
	})
	show.Description.Position, show.Description.Size = UDim2.fromScale(0.03, 0.63), UDim2.fromScale(0.44, 0.13)
	show.Description.TextXAlignment = Enum.TextXAlignment.Left
	show.Description.UITextSizeConstraint.MaxTextSize = 26
	local status =
		U.text(show, "Status", "", UDim2.fromScale(0.44, 0.11), UDim2.fromScale(0.03, 0.8), Theme.Fonts.Caption)
	status.TextXAlignment, status.TextColor3 = Enum.TextXAlignment.Left, Theme.Palette.amberLight
	status.UITextSizeConstraint.MaxTextSize = 22
	self.BannerStatus = status
	local glint = show:FindFirstChild("Glint")
	if glint then
		glint.AnchorPoint, glint.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(heroSlots.ShowcasePop.X, 0.4)
		glint.Size, glint.ImageTransparency, glint.ZIndex = UDim2.fromScale(0.42, 1.2), 0.3, 2
	end
	for name, slot in heroSlots do
		local viewport = show:FindFirstChild(name)
		if viewport then
			viewport.AnchorPoint = Vector2.new(0.5, 0.5)
			viewport.Position = UDim2.fromScale(slot.X, 0.4)
			viewport.Size = UDim2.fromScale(0.4, slot.Size)
			viewport.ZIndex = slot.Z
			local mark =
				U.text(viewport, "Owned", "", UDim2.fromScale(1, 0.14), UDim2.fromScale(0, 0.84), Theme.Fonts.Caption)
			mark.ZIndex, mark.UITextSizeConstraint.MaxTextSize = slot.Z + 1, Theme.TextSize.Small
			mark.TextColor3 = Theme.Palette.emeraldLight
		end
	end
	local view = Gem.new(show, "View", "VIEW  ›", "Blue", UDim2.fromScale(0.19, 0.24), UDim2.fromScale(0.52, 0.73))
	show.Explore.Visible = false
	local price = Gem.new(show, "Price", "…", "Green", UDim2.fromScale(0.24, 0.24), UDim2.fromScale(0.73, 0.73))
	self.Price = price
	for _, button in { view, price } do
		button.ZIndex = 8
		for _, child in button:GetDescendants() do
			if child:IsA("GuiObject") then
				child.ZIndex = 9
			end
		end
	end
	S.buttonText(price, "…")
	table.insert(
		self.Connections,
		view.Activated:Connect(function()
			self:Preview()
		end)
	)
	table.insert(
		self.Connections,
		price.Activated:Connect(function()
			self:BuyBundle()
		end)
	)
end

function Featured:Say(text)
	if self.Message and self.Page.Visible then
		self.Message.Text = text
	end
end

function Featured:Portrait(parent, name, category, id, size, position)
	local key = category .. ":" .. id
	local existing = parent:FindFirstChild(name)
	if existing and existing:GetAttribute("StoreItem") == key then
		return existing
	end
	size = size or existing and existing.Size
	position = position or existing and existing.Position
	local viewport = Item.portrait(parent, category, id, size, position, name)
	viewport.AnchorPoint = Vector2.new(0.5, 0.5)
	if size and position then
		viewport.Size, viewport.Position = size, position
	end
	viewport:SetAttribute("StoreItem", key)
	bob(viewport)
	return viewport
end

function Featured:Apply(view)
	if type(view) ~= "table" or type(view.Offers) ~= "table" then
		return
	end
	self.View = view
	self.Offset = (view.ServerNow or workspace:GetServerTimeNow()) - workspace:GetServerTimeNow()
	self.Requested = nil
	for i = 1, 4 do
		local card, offer = self.Cards[i], view.Offers[i]
		card.Frame.Visible = offer ~= nil
		local portrait = card.Art:FindFirstChild("Portrait")
		if offer and offer.Empty then
			card.Name.Text = "Back tomorrow"
			Card.pill(card.Rarity, nil)
			Card.accent(card, Theme.Palette.slate)
			if portrait then
				portrait.Visible = false
			end
		elseif offer then
			local def = Item.definition(offer.Category, offer.Id)
			local viewport = self:Portrait(
				card.Art,
				"Portrait",
				offer.Category,
				offer.Id,
				UDim2.fromScale(0.86, 0.86),
				UDim2.fromScale(0.5, 0.44)
			)
			viewport.Visible, viewport.ZIndex = true, 3
			card.Name.Text = def and def.Name or offer.Id
			local band = if offer.ValueBand == "Featured" then " ★" else ""
			-- Rarity only: the portrait and the shop tabs already say what kind of item it is, and
			-- "UNCOMMON FINISHER" can't fit a corner pill at a readable size.
			Card.pill(card.Rarity, string.upper(offer.Rarity) .. band, S.Rarity[offer.Rarity] or "milk")
			Card.accent(card, rarityColours[offer.Rarity] or Theme.Palette.milk)
		end
	end
	self:Refresh()
	if not self.Entered then
		-- First fill: the four offers and the bundle banner pop in one after another.
		self.Entered = true
		local cards = {}
		for i = 1, 4 do
			if view.Offers[i] then
				table.insert(cards, self.Cards[i].Frame)
			end
		end
		table.insert(cards, self.Showcase)
		Motion.stagger(cards)
	end
	if view.Message then
		self:Say(view.Message)
	end
end

-- Owned/sold state from the live profile; prices and availability from the server view.
function Featured:Refresh()
	local view = self.View
	if not view then
		return
	end
	local profile = self.Profile or {}
	for i = 1, 4 do
		local card, offer = self.Cards[i], view.Offers[i]
		if not offer then
			continue
		end
		if offer.Empty then
			Card.button(card, "sold", "SOLD OUT")
			Card.pill(card.Corner, nil)
			continue
		end
		local owned = Rules.owns(profile, offer.Category, offer.Id)
		if offer.Purchased then
			Card.button(card, "sold", "SOLD OUT")
		elseif offer.Currency == "Coins" then
			Card.button(card, "coins", offer.Price .. " COINS")
		elseif offer.Available and offer.RobuxPrice then
			Card.button(card, "robux", ROBUX .. " " .. offer.RobuxPrice)
		else
			Card.button(card, "soon", "COMING SOON")
		end
		Card.pill(card.Corner, if owned > 0 then "OWNED ×" .. owned else nil, "emerald")
	end
	local bundle
	for _, entry in view.Bundles or {} do
		if entry.Featured then
			bundle = entry
			break
		end
	end
	self.Bundle = bundle
	self.Showcase.Visible = bundle ~= nil
	if not bundle then
		return
	end
	local kinds, ownedCount = {}, 0
	for index, item in bundle.Items do
		table.insert(kinds, categoryNames[item.Category] or item.Category)
		local owned = Rules.owns(profile, item.Category, item.Id)
		ownedCount += if owned > 0 then 1 else 0
		local slotName = heroOrder[index]
		if slotName and self.Showcase:FindFirstChild(slotName) then
			local viewport = self:Portrait(self.Showcase, slotName, item.Category, item.Id)
			local mark = viewport:FindFirstChild("Owned")
			if mark then
				mark.Text = if owned > 0 then "OWNED" else ""
			end
		end
	end
	self.Showcase.Title.Text = bundle.Name
	self.Showcase.Description.Text = table.concat(kinds, " + ")
	local allOwned = ownedCount == #bundle.Items
	self.BannerStatus.Text = (bundle.Tagline or "Limited time")
		.. (if ownedCount > 0 then " · " .. ownedCount .. " of " .. #bundle.Items .. " owned" else "")
	local price = self.Price
	local gem, text = "sapphire", "COMING SOON"
	if allOwned then
		gem, text = "sapphire", "OWNED"
	elseif bundle.Available and bundle.RobuxPrice then
		gem, text = "emerald", ROBUX .. " " .. bundle.RobuxPrice
	end
	S.setAsset(price.Artwork, "button/gem_" .. gem)
	S.buttonText(price, text)
	price.Label.TextTransparency = if gem == "sapphire" then 0.25 else 0
end

function Featured:Buy(slot)
	local view = self.View
	local offer = view and view.Offers[slot]
	if not offer or offer.Empty then
		return
	end
	if offer.Purchased then
		self:Say("Sold out for you today. New offers at the reset")
	elseif offer.Currency == "Coins" then
		if (self.Coins or 0) < offer.Price then
			self:Say("Need " .. (offer.Price - (self.Coins or 0)) .. " more coins")
			return
		end
		self:Say("Buying…")
		Remotes.BuyStoreOffer:FireServer(slot, offer.Id, view.Day)
	elseif offer.Available then
		Remotes.BuyStoreOffer:FireServer(slot, offer.Id, view.Day)
	else
		self:Say("Robux offers open soon")
	end
end

function Featured:Preview()
	local bundle = self.Bundle
	local screens = script.Parent.Parent:FindFirstChild("Screens")
	local module = screens and screens:FindFirstChild("BundlePreview")
	if not bundle or not module then
		self:Say("Preview coming soon")
		return
	end
	local ok, preview = pcall(require, module)
	if ok and type(preview) == "table" and type(preview.open) == "function" then
		preview.open(bundle.Id)
	else
		self:Say("Preview coming soon")
	end
end

function Featured:BuyBundle()
	local bundle = self.Bundle
	if not bundle then
		return
	end
	if bundle.AllOwned then
		self:Say("You own the whole " .. bundle.Name)
	elseif bundle.Available then
		Remotes.BuyStoreBundle:FireServer(bundle.Id)
	else
		self:Say("The " .. bundle.Name .. " opens soon")
	end
end

-- CrateViews interface: Wallet (profile/coins changed), Step (countdown), Destroy.
function Featured:Wallet(data)
	self.Coins = data and data.Coins or self.Coins
	self:Refresh()
end
function Featured:SetProfile(profile)
	self.Profile = profile
	self:Refresh()
end
function Featured:Step()
	local view = self.View
	if not view or not view.NextReset then
		return
	end
	local remaining = view.NextReset - (workspace:GetServerTimeNow() + (self.Offset or 0))
	if remaining > 0 then
		self.Page.RefreshTimer.Text = "Refreshes in " .. clock(remaining)
		return
	end
	self.Page.RefreshTimer.Text = "Refreshing…"
	local now = os.clock()
	if not self.Requested or now - self.Requested > 3 then
		self.Requested = now
		Remotes.RequestStore:FireServer()
	end
end
function Featured:Destroy()
	for _, connection in self.Connections do
		connection:Disconnect()
	end
	self.Connections = {}
end
return Featured
