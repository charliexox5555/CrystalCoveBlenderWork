-- Client Play: bake editable controls from fresh UI modules; export before stopping Play.
assert(game:GetService("RunService"):IsClient(), "Run in the Play client")
local client = game.Players.LocalPlayer.PlayerScripts.Client
local build = client.UI:Clone()
build.Name, build.Parent = "CrateTemplateBuild", client
local RS, starter = game.ReplicatedStorage, game.StarterGui
local Rules = require(RS.Shared.CrateRules)
local G = require(RS.Shared.Config.Glassies)
local available = {}
for _, def in G.List do
	if G.isRelease(def.Id) and def.Rarity ~= "Starter" and RS.Assets.Glassies:FindFirstChild(def.Id) then
		available[def.Id] = true
	end
end
local glassyOdds = require(RS.Shared.Formula).kilnOdds(available)
local Panel = require(build.Components.CrateShopPanel)
local noop = function() end
local counts = { Panels = 0, PrizeSlots = 0 }
local function disconnect(view)
	for _, key in { "Connections", "TileConnections" } do
		for _, c in view[key] or {} do
			c:Disconnect()
		end
	end
	if view.PreviewResize then
		view.PreviewResize:Disconnect()
	end
end
for _, category in { "Glassies", "Finishers", "Rideables" } do
	local tab = if category == "Rideables" then "Flyers" else category
	local page = starter.KilnScreen.Panel.Content[tab .. "Page"]
	for _, child in page:GetChildren() do
		if child:IsA("GuiObject") then
			child.Visible = false
		end
	end
	local offers = {}
	for _, currency in { "Coins", "Marbles" } do
		offers[currency] = {
			Odds = Rules.odds(category, currency, if category == "Glassies" then available else nil, glassyOdds),
			Cost = Rules.cost(category, currency, 1),
			TenCost = Rules.cost(category, currency, 10),
		}
	end
	local view = Panel.new(page, category, offers, { Open = noop, ViewAll = noop, Inspect = noop })
	view:Wallet({ Coins = 0, Marbles = 0 }, 0)
	disconnect(view)
	for _, carousel in view.Carousels do
		disconnect(carousel)
		counts.PrizeSlots += #carousel.Slots
	end
	counts.Panels += 2
	page.Visible = false
end
starter.KilnScreen.Panel.Content.FeaturedPage.Visible = true
starter.KilnScreen.Panel.Content.PoolPage.Visible = false
local profile = { Cosmetics = {}, Stats = {} }
require(RS.Shared.RoundCosmeticRules).reconcile(profile)
local catalog = require(build.Screens.CosmeticCatalog).new(starter.CollectionScreen.Panel.Content, profile, "Finishers")
disconnect(catalog)
catalog.Root.Visible = false
local bundle = Instance.new("Folder")
bundle.Name = "CrateShopV1"
for _, name in { "KilnScreen", "CollectionScreen", "KilnRevealScreen" } do
	local gui = starter[name]
	gui.Enabled = false
	gui:SetAttribute("CrateShopVersion", 1)
	gui:Clone().Parent = bundle
end
RS.Assets.Crates:Clone().Parent = bundle
for _, object in bundle:GetDescendants() do
	assert(not object:IsA("LuaSourceContainer"), "No scripts in native art/UI snapshots")
end
local bytes = game:GetService("SerializationService"):SerializeInstancesAsync({ bundle })
_G.CrateTemplateExport = buffer.tostring(game:GetService("EncodingService"):Base64Encode(bytes))
bundle:Destroy()
build:Destroy()
counts.Bytes, counts.Base64Length = buffer.len(bytes), #_G.CrateTemplateExport
return counts
