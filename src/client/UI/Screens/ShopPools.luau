local RS = game:GetService("ReplicatedStorage")
local Glassies = require(RS.Shared.Config.Glassies)
local Portrait = require(script.Parent.Parent.Components.GlassyPortrait)
local S = require(script.Parent.Parent.Components.StainedGlass)
local Pools = {}
local SAMPLES = { { Id = "pop" }, { Id = "jam" }, { Id = "prism" } }
local function entries(self, kind)
	return if kind == "Coins" then self.Data.Odds else SAMPLES
end
local function clear(self, root)
	for _, connection in self.PoolConnections[root] or {} do
		connection:Disconnect()
	end
	self.PoolConnections[root] = {}
	for _, child in root:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end
local function tile(self, root, entry, index, kind)
	local result = root.Templates.GlassyTile:Clone()
	local def = Glassies.get(entry.Id)
	result.Name, result.Visible, result.LayoutOrder, result.Parent = def.Id, true, index, root
	S.setAsset(result.Artwork, "tile/tile_" .. S.rarity(def.Rarity))
	local name = result:FindFirstChild("Name")
	name.Text = def.Name
	name.UITextSizeConstraint.MinTextSize = 1
	result.SelectedOutline.Visible = false
	Portrait.new(result, def.Id, result.Portrait.Size, result.Portrait.Position)
	result:SetAttribute("ExactChance", entry.Chance)
	result:SetAttribute("PreviewOnly", kind == "Marbles")
	table.insert(
		self.PoolConnections[root],
		result.Open.Activated:Connect(function()
			self.Message.Text = if entry.Chance
				then def.Name .. " · " .. string.format("%.4g%%", entry.Chance * 100) .. " per Coin Kiln pull"
				else def.Name .. " · sample preview · Marble Kiln coming soon"
		end)
	)
	S.bindSlices(result)
	return result
end
function Pools.strip(self, root, kind)
	clear(self, root)
	local list = entries(self, kind)
	local canvas = math.max(1, #list * 0.32)
	root.CanvasSize = UDim2.fromScale(canvas, 0)
	root.UIListLayout.Padding = UDim.new(0.025 / canvas, 0)
	for i, entry in list do
		local t = tile(self, root, entry, i, kind)
		t.Size = UDim2.fromScale(0.295 / canvas, 1)
	end
end
function Pools.grid(self, root, kind)
	clear(self, root)
	local list = entries(self, kind)
	local rows = math.max(1, math.ceil(#list / 5))
	local canvas = math.max(1, rows * 0.49)
	root.CanvasSize = UDim2.fromScale(0, canvas)
	root.UIGridLayout.CellSize, root.UIGridLayout.CellPadding =
		UDim2.fromScale(0.18, 0.46 / canvas), UDim2.fromScale(0.025, 0.03 / canvas)
	for i, entry in list do
		tile(self, root, entry, i, kind)
	end
end
function Pools.destroy(self)
	for _, list in self.PoolConnections or {} do
		for _, connection in list do
			connection:Disconnect()
		end
	end
	self.PoolConnections = {}
end
return Pools
