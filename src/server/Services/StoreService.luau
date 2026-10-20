-- Daily Featured store: per-player/day offers, Coin purchases and the Robux receipt path.
-- Rules live in DailyStoreRules. This service is the game's single ProcessReceipt owner; Robux
-- offers stay unavailable until Config/DailyStore has product IDs and prices.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local MarketplaceService = game:GetService("MarketplaceService")
local RS = game:GetService("ReplicatedStorage")
local Remotes = require(RS.Shared.Remotes)
local D = require(RS.Shared.Config.DailyStore)
local Rules = require(RS.Shared.DailyStoreRules)
local Glassies = require(RS.Shared.Config.Glassies)
local Guard = require(script.Parent.Parent.Util.RemoteGuard)
local Assets = require(script.Parent.Parent.Util.AssetCatalog)
local Schema = require(script.Parent.Parent.Data.ProfileSchema)
local Spend = require(script.Parent.Parent.Data.LeaderboardRules)
local Service = {}

function Service:Init(services)
	self.Services, self.Guard, self.DevOffset = services, Guard.new(), 0
end

-- Server UTC clock. Studio mock sessions may shift it to check the reset boundary.
function Service:Now()
	return os.time() + self.DevOffset
end

function Service:Catalog()
	return Rules.catalog(function(category, id)
		if category == "Glassies" then
			local def = Glassies.ById[id]
			return def ~= nil and Assets.has(def.Asset or id) == true
		end
		return Assets.cosmetic(category, id) ~= nil
	end)
end

function Service:Grant(data)
	local now = os.time()
	return function(category, id)
		return Schema.grantItem(data, category, id, now)
	end
end

function Service:Send(player, message)
	local data = self.Services.DataService:Get(player)
	if not data then
		return
	end
	local now = self:Now()
	Rules.today(data, player.UserId, now, self:Catalog())
	local view = Rules.view(data, now)
	view.ServerNow = workspace:GetServerTimeNow() + self.DevOffset
	view.Message = message
	Remotes.StoreOffers:FireClient(player, view)
	return view
end

-- Save and wait until the saved copy satisfies `check` (or time out).
function Service:SaveAndWait(player, check)
	local entry = self.Services.DataService.Profiles[player]
	if not entry then
		return false
	end
	local profile = entry.Profile
	local saved = false
	local connection = profile.OnAfterSave:Connect(function(last)
		saved = saved or check(last or profile.LastSavedData)
	end)
	profile:Save()
	local stop = os.clock() + D.ReceiptSaveTimeoutSeconds
	while not saved and os.clock() < stop and profile:IsActive() do
		task.wait(0.1)
	end
	connection:Disconnect()
	return saved
end

function Service:BuyOffer(player, slot, id, day)
	if not self.Guard:Allow(player, "Buy", D.PurchaseRateSeconds) then
		return
	end
	local data = self.Services.DataService:Get(player)
	if not data then
		return
	end
	if self.Services.MatchService and self.Services.MatchService.ByPlayer[player] then
		self:Send(player, "Finish your match first")
		return
	end
	if type(slot) ~= "number" or slot % 1 ~= 0 or slot < 1 or slot > #D.Slots then
		return
	end
	if type(id) ~= "string" or #id > 40 or type(day) ~= "number" or day ~= day then
		return
	end
	local now = self:Now()
	local store = Rules.today(data, player.UserId, now, self:Catalog())
	local offer = store.Offers[slot]
	if offer and offer.Currency == "Robux" then
		self:Prompt(player, "Offer", { Slot = slot, Id = id, Day = day })
		return
	end
	local ok, result = Rules.buyCoins(data, slot, id, day, now, self:Grant(data))
	if not ok then
		Remotes.StoreResult:FireClient(player, { Ok = false, Message = result })
		self:Send(player, result)
		return
	end
	self.Services.DataService:Sync(player)
	self.Services.DataService.Profiles[player].Profile:Save()
	Remotes.StoreResult:FireClient(player, {
		Ok = true,
		Slot = slot,
		Category = result.Offer.Category,
		Id = result.Offer.Id,
		Price = result.Price,
		Grant = result.Grant,
	})
	self:Send(player, if result.Grant and result.Grant.Duplicate then "Bought! Extra copy added" else "Bought!")
end

function Service:BuyBundle(player, bundleId)
	if not self.Guard:Allow(player, "Buy", D.PurchaseRateSeconds) then
		return
	end
	if type(bundleId) ~= "string" or #bundleId > 64 then
		return
	end
	self:Prompt(player, "Bundle", { Id = bundleId })
end

function Service:BuyPack(player, packId)
	if not self.Guard:Allow(player, "Buy", D.PurchaseRateSeconds) then
		return
	end
	if type(packId) ~= "string" or #packId > 32 then
		return
	end
	self:Prompt(player, "Marbles", { Id = packId })
end

-- Persist the exact offer intent before prompting so delayed receipts honor what was shown.
function Service:Prompt(player, kind, ref)
	local data = self.Services.DataService:Get(player)
	if not data then
		return
	end
	local ok, intent = Rules.beginIntent(data, kind, ref, self:Now())
	if not ok then
		Remotes.StoreResult:FireClient(player, { Ok = false, Message = intent })
		self:Send(player, intent)
		return
	end
	local key = tostring(intent.ProductId)
	local persisted = self:SaveAndWait(player, function(last)
		return last and last.Store and last.Store.Intents and last.Store.Intents[key] ~= nil
	end)
	if not persisted then
		Rules.cancelIntent(data, intent.ProductId)
		self:Send(player, "The store is busy. Try again")
		return
	end
	MarketplaceService:PromptProductPurchase(player, intent.ProductId)
end

function Service:ProcessReceipt(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local stop = os.clock() + 10
	local data = self.Services.DataService:Get(player)
	while not data and player.Parent == Players and os.clock() < stop do
		task.wait(0.25)
		data = self.Services.DataService:Get(player)
	end
	if not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local status, applied = Rules.applyReceipt(data, receipt, os.time(), self:Grant(data))
	if status == "Granted" then
		-- Robux spent for the supporter boards (decision 101). "Granted" happens once per PurchaseId, and the total
		-- is saved together with the processed receipt below.
		Spend.recordSpend(data, Spend.receiptRobux(receipt), os.time())
	end
	if status == "NoIntent" then
		warn("[GlassClash] receipt without a store intent: " .. tostring(receipt.ProductId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local purchaseId = receipt.PurchaseId
	local saved = self:SaveAndWait(player, function(last)
		return last and last.ProcessedReceipts and last.ProcessedReceipts[purchaseId] ~= nil
	end)
	if status == "Granted" then
		self.Services.DataService:Sync(player)
		local kind = applied and applied.Intent.Kind
		local message = if kind == "Marbles"
			then "Thank you! " .. applied.Intent.Marbles .. " Marbles added"
			else "Thank you! Your items are in your Inventory"
		Remotes.StoreResult:FireClient(player, { Ok = true, Receipt = true, Kind = kind, Message = message })
		self:Send(player, message)
	end
	return if saved then Enum.ProductPurchaseDecision.PurchaseGranted else Enum.ProductPurchaseDecision.NotProcessedYet
end

function Service:Start()
	Remotes.RequestStore.OnServerEvent:Connect(function(player)
		if self.Guard:Allow(player, "Request", D.RequestRateSeconds) then
			self:Send(player)
		end
	end)
	Remotes.BuyStoreOffer.OnServerEvent:Connect(function(player, slot, id, day)
		self:BuyOffer(player, slot, id, day)
	end)
	Remotes.BuyStoreBundle.OnServerEvent:Connect(function(player, bundleId)
		self:BuyBundle(player, bundleId)
	end)
	Remotes.BuyMarblePack.OnServerEvent:Connect(function(player, packId)
		self:BuyPack(player, packId)
	end)
	MarketplaceService.ProcessReceipt = function(receipt)
		return self:ProcessReceipt(receipt)
	end
	-- Game passes (none on sale yet): record the price once per pass for the supporter boards.
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		local data = purchased and self.Services.DataService:Get(player)
		if not data or type(passId) ~= "number" then
			return
		end
		local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, passId, Enum.InfoType.GamePass)
		local price = ok and type(info) == "table" and info.PriceInRobux
		if price and Spend.recordPass(data, passId, price, os.time()) then
			self.Services.DataService:Sync(player)
		end
	end)
	MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, productId, purchased)
		local player = Players:GetPlayerByUserId(userId)
		local data = player and self.Services.DataService:Get(player)
		if data and not purchased then
			Rules.cancelIntent(data, productId)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		self.Guard:Remove(player)
	end)
	if RunService:IsStudio() then
		local dev = Instance.new("BindableFunction")
		dev.Name = "StoreDev"
		dev.OnInvoke = function(command, player, a, b, c)
			if command == "View" then
				return self:Send(player)
			elseif command == "Buy" then
				self.Guard:Remove(player)
				self:BuyOffer(player, a, b, c)
				return self:Send(player)
			elseif command == "Offset" and self.Services.DataService.Mock and type(a) == "number" then
				self.DevOffset = a
				return self:Now()
			elseif command == "Prompt" then
				-- a = slot number, a bundle id, or "pack:<id>"; opens Studio's free test-purchase dialog.
				self.Guard:Remove(player)
				if type(a) == "string" and a:sub(1, 5) == "pack:" then
					self:BuyPack(player, a:sub(6))
				elseif type(a) == "string" then
					self:BuyBundle(player, a)
				else
					local view = self:Send(player)
					local offer = view and view.Offers[a]
					self:BuyOffer(player, a, offer and offer.Id, view and view.Day)
				end
				local data = self.Services.DataService:Get(player)
				return data and data.Store.Intents
			elseif command == "Receipt" and self.Services.DataService.Mock then
				local decision = self:ProcessReceipt({ PlayerId = player.UserId, ProductId = a, PurchaseId = b })
				return decision.Name
			elseif command == "Required" then
				return Rules.requiredProducts(self:Catalog())
			end
			return nil
		end
		dev.Parent = game.ServerStorage
	end
end

return Service
