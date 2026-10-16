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
	table.sort(ids)
	return available, table.concat(ids, ",")
end

function Service:Open(player)
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
	Remotes.KilnOdds:FireClient(player, {
		Quote = quote.Id,
		Odds = odds,
		Coins = data.Coins,
		Marbles = data.Marbles or 0,
		Welcome = Schema.welcomePulls(data),
		Cost = Balance.Economy.KilnCoinCost,
		TenCost = Balance.Economy.KilnTenPullCost,
	})
end

function Service:Fail(player, message)
	Remotes.KilnResult:FireClient(player, { Error = message })
	self:Open(player)
end

function Service:Pull(player, count, token)
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
	local odds = Formula.kilnOdds(quote.Available)
	if #odds == 0 then
		self:Fail(player, "The Kiln is warming up")
		return
	end
	local welcome = count == 1 and Schema.welcomePulls(data) > 0
	local cost = if welcome
		then 0
		elseif count == 10 then Balance.Economy.KilnTenPullCost
		else Balance.Economy.KilnCoinCost
	if data.Coins < cost then
		self:Fail(player, "Play a match for more coins")
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
		table.insert(pulls, { Id = Formula.rollKiln(rng, quote.Available), Rainbow = Formula.rollRainbow(rng) })
	end
	data.Coins -= cost
	if welcome then
		data.Flags.WelcomePullUsed = true
	end
	local results = {}
	for _, pull in pulls do
		table.insert(results, Schema.grant(data, pull.Id, pull.Rainbow, os.time()))
	end
	data.Stats.KilnPulls += count
	if self.Services.RetentionService then
		self.Services.RetentionService:Pulled(player, count)
	end
	self.Services.DataService:Sync(player)
	self.Services.DataService.Profiles[player].Profile:Save()
	Remotes.KilnResult:FireClient(player, { Quote = token, Results = results, Coins = data.Coins, Cost = cost })
end

function Service:Start()
	Remotes.RequestKiln.OnServerEvent:Connect(function(player)
		if self.Guard:Allow(player, "Open", Balance.Data.RequestRateSeconds) then
			self:Open(player)
		end
	end)
	Remotes.PullKiln.OnServerEvent:Connect(function(player, count, token)
		self:Pull(player, count, token)
	end)
	Players.PlayerRemoving:Connect(function(player)
		self.Quotes[player] = nil
		self.Guard:Remove(player)
	end)
	local props = workspace.Lobby:FindFirstChild("GlassClashProps")
	local kiln = props and props:FindFirstChild("Kiln")
	local prompt = kiln and kiln:FindFirstChild("OpenKiln", true)
	if prompt then
		prompt.Triggered:Connect(function(player)
			if not self.Guard:Allow(player, "Open", Balance.Data.RequestRateSeconds) then
				return
			end
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if root and (root.Position - prompt.Parent.Position).Magnitude <= prompt.MaxActivationDistance then
				self:Open(player)
			end
		end)
	end
end

return Service
