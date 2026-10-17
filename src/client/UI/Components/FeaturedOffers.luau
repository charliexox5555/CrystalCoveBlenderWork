-- Featured shop page: four personalized daily offers (3 Robux, 1 Coin), the featured limited
-- bundle and one shared reset countdown. Drives the authored FeaturedPage cards; the server
-- (StoreService) owns offers, prices and purchases. Lives in the Shop's CrateViews so the
-- screen steps, refreshes and destroys it with the other shop panels.
local RS = game:GetService("ReplicatedStorage")
local Remotes = require(RS.Shared.Remotes)
local Rules = require(RS.Shared.DailyStoreRules)
local U = require(script.Parent.Util)
local S = require(script.Parent.StainedGlass)
local Theme = require(script.Parent.Parent.Theme)
local Item = require(script.Parent.ItemPresentation)
local Motion = require(script.Parent.Motion)
local TweenService = game:GetService("TweenService")
local Featured = {}
Featured.__index = Featured
local categoryNames = { Glassies = "GLASSY", Finishers = "FINISHER", Rideables = "FLYER" }
local showcaseSlots = { "ShowcasePop", "ShowcaseJam", "ShowcasePrism" }
local ROBUX = utf8.char(0xE002)

local function clock(seconds)
	seconds = math.max(0, math.floor(seconds))
	return string.format("%02d:%02d:%02d", seconds // 3600, seconds % 3600 // 60, seconds % 60)
end

function Featured.new(page, message)
	local self = setmetatable({ Page = page, Message = message, Connections = {}, Portraits = {} }, Featured)
	self.Offers = page.DailyOffers
	self.Showcase = page.Showcase
	self.Default = {}
	for _, object in { self.Offers, self.Showcase } do
		self.Default[object] = { Position = object.Position, Size = object.Size }
	end
	for i = 1, 4 do
		local card = self.Offers["Offer" .. i]
		self.Default[card] = { Position = card.Position, Size = card.Size }
		card.ItemName.Text = ""
		S.buttonText(card.Price, "LOADING…")
		-- The authored placeholders ship disabled (Active = false), which swallows every click.
		card.Price.Active, card.Price.Selectable = true, true
		local tag = U.make("ImageLabel", card, {
			Name = "Tag",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0.035),
			Size = UDim2.fromScale(0.86, 0.1),
			ZIndex = 3,
		})
		-- The tag art keeps its own 3.75:1 shape; the box matches it so the text sits inside the pill.
		U.make("UIAspectRatioConstraint", tag, { AspectRatio = 3.75, DominantAxis = Enum.DominantAxis.Height })
		local label =
			U.text(tag, "Label", "", UDim2.fromScale(0.74, 0.62), UDim2.fromScale(0.13, 0.19), Theme.Fonts.Caption)
		label.ZIndex, label.UITextSizeConstraint.MaxTextSize = 4, Theme.TextSize.Small
		label.UITextSizeConstraint.MinTextSize = 1
		local status =
			U.text(card, "Status", "", UDim2.fromScale(0.88, 0.07), UDim2.fromScale(0.06, 0.585), Theme.Fonts.Caption)
		status.ZIndex, status.UITextSizeConstraint.MaxTextSize = 3, Theme.TextSize.Small
		status.TextColor3 = Theme.Palette.amberLight
		table.insert(
			self.Connections,
			card.Price.Activated:Connect(function()
				self:Buy(i)
			end)
		)
	end
	for _, name in showcaseSlots do
		local slot = self.Showcase:FindFirstChild(name)
		if slot then
			local mark =
				U.text(slot, "Owned", "", UDim2.fromScale(1, 0.16), UDim2.fromScale(0, 0.86), Theme.Fonts.Caption)
			mark.ZIndex, mark.UITextSizeConstraint.MaxTextSize = 4, Theme.TextSize.Small
			mark.TextColor3 = Theme.Palette.emeraldLight
		end
	end
	-- The template's glow sits behind the first portrait (the Hollowlight lantern), not the flyer.
	local glint, first = self.Showcase:FindFirstChild("Glint"), self.Showcase:FindFirstChild(showcaseSlots[1])
	if glint and first then
		glint.AnchorPoint, glint.Position = Vector2.new(0.5, 0.5), first.Position
		glint.Size, glint.ImageTransparency = UDim2.fromScale(0.3, 0.9), 0.35
	end
	self.Showcase.Eyebrow.Text = "FEATURED COLLECTION · LIMITED"
	self.Showcase.Title.Text = "Loading…"
	self.Showcase.Description.Text = ""
	S.buttonText(self.Showcase.Explore, "LOADING…")
	self.Showcase.Explore.Active, self.Showcase.Explore.Selectable = true, true
	-- VIEW opens the fullscreen bundle preview (Screens/BundlePreview) once that module exists.
	local view = require(script.Parent.GemButton).new(
		self.Showcase,
		"View",
		"VIEW",
		"Purple",
		UDim2.fromScale(0.15, 0.2),
		UDim2.fromScale(0.43, 0.75)
	)
	table.insert(
		self.Connections,
		view.Activated:Connect(function()
			self:Preview()
		end)
	)
	table.insert(
		self.Connections,
		self.Showcase.Explore.Activated:Connect(function()
			self:BuyBundle()
		end)
	)
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
	table.insert(
		self.Connections,
		page:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			self:Layout()
		end)
	)
	self:Layout()
	Remotes.RequestStore:FireServer()
	return self
end

function Featured:Say(text)
	if self.Message and self.Page.Visible then
		self.Message.Text = text
	end
end

-- Portrait phones get a 2x2 grid; short landscape phones give the cards more height.
function Featured:Layout()
	local size = self.Page.AbsoluteSize
	if size.X <= 1 then
		return
	end
	local narrow, short = size.X < 520, size.Y < 300
	for object, default in self.Default do
		object.Position, object.Size = default.Position, default.Size
	end
	if narrow then
		self.Offers.Size = UDim2.fromScale(0.96, 0.6)
		self.Showcase.Position, self.Showcase.Size = UDim2.fromScale(0.02, 0.715), UDim2.fromScale(0.96, 0.275)
		for i = 1, 4 do
			local card = self.Offers["Offer" .. i]
			local col, row = (i - 1) % 2, (i - 1) // 2
			card.Position = UDim2.fromScale(col * 0.515, row * 0.515)
			card.Size = UDim2.fromScale(0.485, 0.485)
		end
	elseif short then
		self.Offers.Size = UDim2.fromScale(0.96, 0.56)
		self.Showcase.Position, self.Showcase.Size = UDim2.fromScale(0.02, 0.68), UDim2.fromScale(0.96, 0.31)
	end
end

function Featured:Portrait(parent, name, category, id)
	local key = category .. ":" .. id
	local existing = parent:FindFirstChild(name)
	if existing and existing:GetAttribute("StoreItem") == key then
		return existing
	end
	local slot = existing
	local size = slot and slot.Size or UDim2.fromScale(0.78, 0.6)
	local position = slot and slot.Position or UDim2.fromScale(0.5, 0.34)
	local viewport = Item.portrait(parent, category, id, size, position, name)
	viewport:SetAttribute("StoreItem", key)
	-- Gentle bob so the offer art feels alive; each portrait gets its own phase.
	if not Motion.reduced() then
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
		local card, offer = self.Offers["Offer" .. i], view.Offers[i]
		card.Visible = offer ~= nil
		if offer and offer.Empty then
			card.ItemName.Text = "Sold out today"
			S.tag(card.Tag, categoryNames[offer.Category] or "", "slate")
			card.Status.Text = ""
			card.Portrait.Visible = false
		elseif offer then
			local def = Item.definition(offer.Category, offer.Id)
			card.Portrait.Visible = true
			self:Portrait(card, "Portrait", offer.Category, offer.Id)
			card.ItemName.Text = def and def.Name or offer.Id
			local band = if offer.ValueBand == "Featured" then " ★" else ""
			S.tag(card.Tag, string.upper(offer.Rarity) .. band, S.Rarity[offer.Rarity] or "milk")
		end
	end
	self:Refresh()
	if not self.Entered then
		-- First fill: the four offers and the bundle card pop in one after another.
		self.Entered = true
		local cards = {}
		for i = 1, 4 do
			if view.Offers[i] then
				table.insert(cards, self.Offers["Offer" .. i])
			end
		end
		table.insert(cards, self.Showcase)
		Motion.stagger(cards)
	end
	if view.Message then
		self:Say(view.Message)
	end
end

-- Owned/afford state from the live profile; prices and availability from the server view.
function Featured:Refresh()
	local view = self.View
	if not view then
		return
	end
	local profile = self.Profile or {}
	for i = 1, 4 do
		local card, offer = self.Offers["Offer" .. i], view.Offers[i]
		if not offer then
			continue
		end
		local owned = if offer.Empty then 0 else Rules.owns(profile, offer.Category, offer.Id)
		local text, gem, dim
		if offer.Empty then
			text, gem, dim = "CHECK TOMORROW", "sapphire", true
		elseif offer.Purchased then
			text, gem, dim = "BOUGHT", "emerald", true
		elseif offer.Currency == "Coins" then
			text, gem = offer.Price .. " COINS", "amber"
			dim = (self.Coins or 0) < offer.Price
		elseif offer.Available and offer.RobuxPrice then
			text, gem, dim = ROBUX .. " " .. offer.RobuxPrice, "emerald", false
		else
			text, gem, dim = "COMING SOON", "sapphire", true
		end
		S.buttonText(card.Price, text)
		S.setAsset(card.Price.Artwork, "button/gem_" .. gem)
		card.Price.Label.TextTransparency = if dim then 0.3 else 0
		card.Price.Artwork.ImageTransparency = if dim then 0.25 else 0
		local kind = categoryNames[offer.Category] or ""
		card.Status.Text = if offer.Empty
			then ""
			elseif owned > 0 then kind .. " · OWNED ×" .. owned .. (if offer.Purchased then "" else " · +1 COPY")
			else kind .. " · NEW FOR YOU"
		card.Status.TextColor3 = if owned > 0 then Theme.Palette.emeraldLight else Theme.Palette.amberLight
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
	local names, ownedCount = {}, 0
	for index, item in bundle.Items do
		local def = Item.definition(item.Category, item.Id)
		table.insert(names, def and def.Name or item.Id)
		local owned = Rules.owns(profile, item.Category, item.Id)
		ownedCount += if owned > 0 then 1 else 0
		local slotName = showcaseSlots[index]
		local slot = slotName and self.Showcase:FindFirstChild(slotName)
		if slot then
			local viewport = self:Portrait(self.Showcase, slotName, item.Category, item.Id)
			local mark = slot:FindFirstChild("Owned")
			if mark and mark.Parent ~= viewport then
				mark.Parent = viewport
			end
			mark = viewport:FindFirstChild("Owned")
			if mark then
				mark.Text = if owned > 0 then "OWNED" else ""
			end
		end
	end
	self.Showcase.Title.Text = bundle.Name
	self.Showcase.Description.Text = table.concat(names, " · ")
		.. "\n"
		.. ownedCount
		.. " of "
		.. #bundle.Items
		.. " owned"
	local allOwned = ownedCount == #bundle.Items
	local text = if allOwned
		then "COLLECTION OWNED"
		elseif bundle.Available and bundle.RobuxPrice then "GET SET · " .. ROBUX .. " " .. bundle.RobuxPrice
		else "COMING SOON"
	S.buttonText(self.Showcase.Explore, text)
	local dim = allOwned or not bundle.Available
	self.Showcase.Explore.Label.TextTransparency = if dim then 0.3 else 0
	S.setAsset(self.Showcase.Explore.Artwork, if dim then "button/gem_sapphire" else "button/gem_amber")
end

function Featured:Buy(slot)
	local view = self.View
	local offer = view and view.Offers[slot]
	if not offer or offer.Empty then
		return
	end
	if offer.Purchased then
		self:Say("Already bought today. New offers at the reset")
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
		self.Page.RefreshTimer.Text = "New offers in " .. clock(remaining)
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
