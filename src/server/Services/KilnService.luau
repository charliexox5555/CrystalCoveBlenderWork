local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Balance = require(RS.Shared.Config.Balance)
local Formula = require(RS.Shared.Formula)
local Glassies = require(RS.Shared.Config.Glassies)
local Remotes = require(RS.Shared.Remotes)
local Assets = require(script.Parent.Parent.Util.AssetCatalog)
local Schema = require(script.Parent.Parent.Data.ProfileSchema)
local Guard = require(script.Parent.Parent.Util.RemoteGuard)
local Service = {}
local Crates = require(RS.Shared.CrateRules)
local Cosmetics = require(RS.Shared.Config.RoundCosmetics)
local CosmeticRules = require(RS.Shared.RoundCosmeticRules)

function Service:Init(services)
	self.Services, self.Quotes, self.Guard = services, {}, Guard.new()
end

function Service:Pool()
	local available, ids = {}, {}
	for _, def in Glassies.List do
		if Glassies.isRelease(def.Id) and def.Rarity ~= "Starter" and Assets.has(def.Asset) then
			available[def.Id] = true
			table.insert(ids, def.Id)
		end
	end
	for _, category in { "Rideables", "Finishers" } do
		local folder = RS.Assets:FindFirstChild(if category == "Finishers" then "RoundFinishers" else "Rideables")
		for _, def in Cosmetics[category] do
			if folder and folder:FindFirstChild(def.Id) then
				table.insert(ids, category .. ":" .. def.Id)
			end
		end
	end
	table.sort(ids)
	return available, table.concat(ids, ",")
end

function Service:Open(player, message, tab)
	local data = self.Services.DataService:Get(player)
	if not data or self.Services.MatchService.ByPlayer[player] then
		return
	end
	local available, signature = self:Pool()
	local odds = Formula.kilnOdds(available)
	local quote = {
		Id = HttpService:GenerateGUID(false),
		Signature = signature,
		Available = available,
		Expires = os.clock() + Balance.Data.KilnQuoteSeconds,
	}
	self.Quotes[player] = quote
	local paidAllowed = self.Services.MatchService.PaidRandomAllowed[player] == true
	local crates = {}
	for _, category in { "Glassies", "Finishers", "Rideables" } do
		local installed = available
		if category ~= "Glassies" then
			installed = {}
			local folder = RS.Assets:FindFirstChild(if category == "Finishers" then "RoundFinishers" else "Rideables")
			for _, def in Cosmetics[category] do
				installed[def.Id] = folder and folder:FindFirstChild(def.Id) ~= nil
			end
		end
		crates[category] = {}
		for _, currency in { "Coins", "Marbles" } do
			if currency == "Coins" or paidAllowed then
				crates[category][currency] = {
					Odds = Crates.odds(category, currency, installed, odds),
					Cost = Crates.cost(category, currency, 1),
					TenCost = Crates.cost(category, currency, 10),
				}
			end
		end
	end
	quote.Crates = crates
	Remotes.KilnOdds:FireClient(player, {
		Error = message,
		Tab = tab,
		Crates = crates,
		PaidRandomAllowed = paidAllowed,
		Quote = quote.Id,
		Odds = odds,
		Coins = data.Coins,
		Marbles = data.Marbles or 0,
		Welcome = Schema.welcomePulls(data),
		Free = {
			Glassies = Schema.welcomePulls(data) + (data.FreePulls.Glassies or 0),
			Finishers = data.FreePulls.Finishers or 0,
			Rideables = data.FreePulls.Rideables or 0,
		},
		Cost = Balance.Economy.KilnCoinCost,
		TenCost = Balance.Economy.KilnTenPullCost,
	})
end

function Service:Fail(player, message)
	Remotes.KilnResult:FireClient(player, { Error = message })
	self:Open(player, message)
end

function Service:Pull(player, count, token, category, currency)
	if not self.Guard:Allow(player, "Pull", Balance.Data.KilnRateSeconds) then
		return
	end
	local data = self.Services.DataService:Get(player)
	if not data or self.Services.MatchService.ByPlayer[player] then
		self:Fail(player, "Finish your match first")
		return
	end
	if (count ~= 1 and count ~= 10) or type(token) ~= "string" or #token > 64 then
		self:Fail(player, "Open the odds before pulling")
		return
	end
	local quote = self.Quotes[player]
	local _, signature = self:Pool()
	if not quote or quote.Id ~= token or os.clock() > quote.Expires or signature ~= quote.Signature then
		self:Fail(player, "The Kiln changed. Check the new odds")
		return
	end
	category, currency = category or "Glassies", currency or "Coins"
	if
		type(category) ~= "string"
		or type(currency) ~= "string"
		or not Balance.Crates.Prices[category]
		or (currency ~= "Coins" and currency ~= "Marbles")
	then
		self:Fail(player, "Choose a valid crate")
		return
	end
	if currency == "Marbles" and self.Services.MatchService.PaidRandomAllowed[player] ~= true then
		self:Fail(player, "This opening is unavailable for your account")
		return
	end
	local offer = quote.Crates[category] and quote.Crates[category][currency]
	local odds = offer and offer.Odds or {}
	if #odds == 0 then
		self:Fail(player, "The Kiln is warming up")
		return
	end
	local welcome = category == "Glassies" and currency == "Coins" and count == 1 and Schema.welcomePulls(data) > 0
	-- Free pull tickets from Daily Rewards, Playtime gifts and codes (decision 99): one Coin pull, odds shown as usual.
	local ticket = not welcome and currency == "Coins" and count == 1 and (data.FreePulls[category] or 0) > 0
	local cost = if welcome or ticket then 0 elseif count == 10 then offer.TenCost else offer.Cost
	if data[currency] < cost then
		self:Fail(player, "Not enough " .. string.lower(currency))
		return
	end
	-- No yield from quote consumption through debit/grants. One quote can grant only once.
	self.Quotes[player] = nil
	local random = Random.new()
	local rng = function()
		return random:NextNumber()
	end
	local pulls = {}
	for _ = 1, count do
		table.insert(
			pulls,
			{ Id = Crates.roll(odds, rng), Rainbow = category == "Glassies" and Formula.rollRainbow(rng) }
		)
	end
	data[currency] -= cost
	if welcome then
		data.Flags.WelcomePullUsed = true
	elseif ticket then
		data.FreePulls[category] -= 1
	end
	local results = {}
	for _, pull in pulls do
		table.insert(
			results,
			if category == "Glassies"
				then Schema.grant(data, pull.Id, pull.Rainbow, os.time())
				else CosmeticRules.grant(data, category, pull.Id)
		)
	end
	if category == "Glassies" then
		data.Stats.KilnPulls += count
	end
	if category == "Glassies" and self.Services.RetentionService then
		self.Services.RetentionService:Pulled(player, count)
	end
	self.Services.DataService:Sync(player)
	self.Services.DataService.Profiles[player].Profile:Save()
	Remotes.KilnResult:FireClient(player, {
		Quote = token,
		Category = category,
		Currency = currency,
		Odds = odds,
		Results = results,
		Coins = data.Coins,
		Marbles = data.Marbles,
		Cost = cost,
	})
end

function Service:Start()
	Remotes.RequestKiln.OnServerEvent:Connect(function(player)
		if self.Guard:Allow(player, "Open", Balance.Data.RequestRateSeconds) then
			self:Open(player)
		end
	end)
	Remotes.PullKiln.OnServerEvent:Connect(function(player, count, token, category, currency)
		self:Pull(player, count, token, category, currency)
	end)
	Players.PlayerRemoving:Connect(function(player)
		self.Quotes[player] = nil
		self.Guard:Remove(player)
	end)
	-- Every world kiln (Workspace.Kilns.*, or the older Lobby.GlassClashProps.Kiln) has an "OpenKiln"
	-- prompt; each opens the shop on the Glassies page.
	local roots = { workspace:FindFirstChild("Kilns") }
	local props = workspace:FindFirstChild("Lobby") and workspace.Lobby:FindFirstChild("GlassClashProps")
	table.insert(roots, props and props:FindFirstChild("Kiln"))
	for _, root in roots do
		for _, prompt in root:GetDescendants() do
			if prompt:IsA("ProximityPrompt") and prompt.Name == "OpenKiln" then
				self:ConnectPrompt(prompt)
			end
		end
	end
end

function Service:ConnectPrompt(prompt)
	local model = prompt:FindFirstAncestorWhichIsA("Model")
	if model and model.Name:find("Marble") then
		prompt.ObjectText = "Glassies • Marble pulls"
	end
	prompt.Triggered:Connect(function(player)
		if not self.Guard:Allow(player, "Open", Balance.Data.RequestRateSeconds) then
			return
		end
		local anchor = prompt.Parent
		local position = if anchor:IsA("Attachment") then anchor.WorldPosition else anchor.Position
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root and (root.Position - position).Magnitude <= prompt.MaxActivationDistance + 2 then
			self:Open(player, nil, "Glassies")
		end
	end)
end

return Service
