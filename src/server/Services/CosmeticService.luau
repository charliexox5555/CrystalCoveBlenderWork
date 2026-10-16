local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Remotes = require(RS.Shared.Remotes)
local Rules = require(RS.Shared.RoundCosmeticRules)
local Balance = require(RS.Shared.Config.Balance)
local Guard = require(script.Parent.Parent.Util.RemoteGuard)
local Service = {}
function Service:Init(services)
	self.Services, self.Guard = services, Guard.new()
end
function Service:Equip(player, category, id)
	if not self.Guard:Allow(player, "Cosmetic", Balance.Data.RequestRateSeconds) then
		return false
	end
	local data = self.Services.DataService:Get(player)
	if not data then
		return false
	end
	local ok = Rules.equip(data, category, id)
	Remotes.CosmeticResult:FireClient(player, {
		Ok = ok,
		Message = if ok then "Equipped for your next match" else "Complete more matches to unlock this cosmetic",
	})
	if ok then
		self.Services.DataService:Sync(player)
	end
	return ok
end
function Service:Start()
	Remotes.EquipRoundCosmetic.OnServerEvent:Connect(function(player, category, id)
		self:Equip(player, category, id)
	end)
	Players.PlayerRemoving:Connect(function(player)
		self.Guard:Remove(player)
	end)
	if game:GetService("RunService"):IsStudio() then
		local dev = Instance.new("BindableFunction")
		dev.Name, dev.Parent = "CosmeticDev", game.ServerStorage
		dev.OnInvoke = function(command, player, category, id)
			if command == "Equip" then
				return self:Equip(player, category, id)
			end
			if command == "PreviewAll" and self.Services.DataService.Mock then
				local data = self.Services.DataService:Get(player)
				if not data then
					return false
				end
				local C = require(RS.Shared.Config.RoundCosmetics)
				for _, key in { "Rideables", "Finishers" } do
					for _, def in C[key] do
						if not table.find(data.Cosmetics[key], def.Id) then
							table.insert(data.Cosmetics[key], def.Id)
						end
					end
				end
				self.Services.DataService:Sync(player)
				return true
			end
		end
	end
end
return Service
