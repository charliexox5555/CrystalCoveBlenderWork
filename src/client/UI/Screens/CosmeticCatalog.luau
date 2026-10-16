-- Shared editable grid + right-hand detail panel for Inventory and Shop.
local RS = game:GetService("ReplicatedStorage")
local C = require(RS.Shared.Config.RoundCosmetics)
local Rules = require(RS.Shared.RoundCosmeticRules)
local Theme = require(script.Parent.Parent.Theme)
local U = require(script.Parent.Parent.Components.Util)
local Button = require(script.Parent.Parent.Components.Button)
local Portrait = require(script.Parent.Parent.Components.CosmeticPortrait)
local FX = require(script.Parent.Parent.Parent.Presentation.FinisherFX)
local Tuning = require(RS.Shared.Config.Balance).CosmeticPresentation
local Catalog = {}
Catalog.__index = Catalog
function Catalog.new(parent, profile, category)
	local self = setmetatable({ Category = category, Connections = {}, TileConnections = {}, Tiles = {} }, Catalog)
	self.Root =
		U.make("Frame", parent, { Name = "CosmeticPage", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 })
	self.Root.Visible = true
	self.Grid = U.make("Frame", self.Root, {
		Name = "Cards",
		Size = UDim2.fromScale(0.61, 0.91),
		Position = UDim2.fromScale(0, 0.06),
		BackgroundTransparency = 1,
	})
	self.Info = U.make("Frame", self.Root, {
		Name = "Details",
		Size = UDim2.fromScale(0.35, 0.96),
		Position = UDim2.fromScale(0.65, 0.02),
		BackgroundTransparency = 1,
	})
	self.Count = U.text(self.Root, "Count", "", UDim2.fromScale(0.61, 0.06), UDim2.new(), Theme.Fonts.Caption)
	self.Name = U.text(self.Info, "ItemName", "", UDim2.fromScale(1, 0.1), UDim2.new(), Theme.Fonts.Heading)
	self.Description = U.text(self.Info, "Description", "", UDim2.fromScale(1, 0.18), UDim2.fromScale(0, 0.47))
	self.Description.TextWrapped = true
	self.Status =
		U.text(self.Info, "Ownership", "", UDim2.fromScale(1, 0.1), UDim2.fromScale(0, 0.66), Theme.Fonts.Caption)
	self.Equip = Button.new(self.Info, "Equip", "EQUIP", "Green", UDim2.fromScale(1, 0.1), UDim2.fromScale(0, 0.88))
	self.Preview =
		Button.new(self.Info, "Preview", "PREVIEW", "Blue", UDim2.fromScale(1, 0.1), UDim2.fromScale(0, 0.75))
	for _, button in { self.Equip, self.Preview } do
		U.make("UISizeConstraint", button, { MinSize = Vector2.new(44, 44) })
	end
	table.insert(
		self.Connections,
		self.Equip.Activated:Connect(function()
			if self.Owned and not self.Equipped then
				require(RS.Shared.Remotes).EquipRoundCosmetic:FireServer(self.Category, self.Selected)
			end
		end)
	)
	table.insert(
		self.Connections,
		self.Preview.Activated:Connect(function()
			self:PreviewSelected()
		end)
	)
	self:Refresh(profile)
	return self
end
function Catalog:FitPreview()
	if self.Previewing and self.Portrait then
		Portrait.fitEffect(self.Portrait, Tuning.FinisherRadius + Tuning.FinisherCoreSize / 2)
	end
end
function Catalog:PreviewSelected()
	if self.Category == "Finishers" and self.World then
		self.Previewing = true
		self:FitPreview()
		for _, child in self.World:GetChildren() do
			child:Destroy()
		end
		local effect =
			FX.emit(self.World, self.Selected, Vector3.zero, false, self.Portrait.CurrentCamera.CFrame.Rotation)
		self.Preview.Text = "PREVIEW AGAIN"
		return effect
	elseif self.Portrait then
		local model = self.World:FindFirstChildOfClass("Model")
		if model then
			model:PivotTo(model:GetPivot() * CFrame.Angles(0, math.pi / 2, 0))
		end
	end
end
function Catalog:Refresh(profile)
	self.Profile = profile or { Cosmetics = {}, Stats = {} }
	for _, connection in self.TileConnections do
		connection:Disconnect()
	end
	self.TileConnections = {}
	for _, child in self.Grid:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	self.Tiles = {}
	local owned = (self.Profile.Cosmetics or {})[self.Category] or {}
	self.Count.Text = string.upper(if self.Category == "Rideables" then "RIDES" else "FINISHERS")
		.. " · "
		.. #owned
		.. " / "
		.. #C[self.Category]
		.. "  ·  EARN BY PLAYING"
	for i, def in C[self.Category] do
		local tile = U.make("Frame", self.Grid, {
			Name = def.Id,
			Size = UDim2.fromScale(0.31, 0.45),
			Position = UDim2.fromScale(((i - 1) % 3) * 0.34, math.floor((i - 1) / 3) * 0.51),
			BackgroundColor3 = Color3.fromHex("#24374F"),
			BorderSizePixel = 0,
		})
		U.make("UIStroke", tile, { Color = Color3.fromHex(def.Color), Thickness = 1.5, Transparency = 0.35 })
		Portrait.new(tile, self.Category, def.Id, UDim2.fromScale(0.96, 0.64), UDim2.fromScale(0.02, 0.01))
		U.text(
			tile,
			"ItemName",
			def.Name,
			UDim2.fromScale(0.96, 0.17),
			UDim2.fromScale(0.02, 0.64),
			Theme.Fonts.Heading
		)
		U.text(
			tile,
			"Unlock",
			if table.find(owned, def.Id)
				then "OWNED"
				else def.Matches .. (if def.Matches == 1 then " MATCH" else " MATCHES"),
			UDim2.fromScale(0.96, 0.14),
			UDim2.fromScale(0.02, 0.83),
			Theme.Fonts.Caption
		)
		local tap = U.make(
			"TextButton",
			tile,
			{ Name = "Select", Text = "", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 5 }
		)
		table.insert(
			self.TileConnections,
			tap.Activated:Connect(function()
				self:Detail(def.Id)
			end)
		)
		self.Tiles[def.Id] = tile
	end
	self:Detail(self.Selected or C[self.Category][1].Id)
end
function Catalog:Detail(id)
	local def = C.ByCategory[self.Category][id]
	if not def then
		return
	end
	self.Selected = id
	self.Previewing = false
	if self.PreviewResize then
		self.PreviewResize:Disconnect()
		self.PreviewResize = nil
	end
	local cosmetics = self.Profile.Cosmetics or {}
	self.Owned = table.find(cosmetics[self.Category] or {}, id) ~= nil
	self.Equipped = cosmetics["Equipped" .. self.Category] == id
	self.Name.Text, self.Description.Text = def.Name, def.Description
	self.Status.Text = if self.Owned
		then (if self.Equipped then "EQUIPPED · COSMETIC ONLY" else "OWNED · COSMETIC ONLY")
		else math.min(Rules.matches(self.Profile), def.Matches) .. " / " .. def.Matches .. " COMPLETED MATCHES"
	self.Equip.Text = if self.Equipped then "EQUIPPED" elseif self.Owned then "EQUIP" else "KEEP CLASHING TO UNLOCK"
	self.Equip.Active, self.Equip.Selectable = self.Owned and not self.Equipped, self.Owned and not self.Equipped
	self.Equip.TextTransparency = if self.Owned then 0 else 0.35
	self.Preview.Text = if self.Category == "Finishers" then "PREVIEW EFFECT" else "TURN PREVIEW"
	self.Portrait, self.World =
		Portrait.new(self.Info, self.Category, id, UDim2.fromScale(1, 0.38), UDim2.fromScale(0, 0.12), "PreviewModel")
	self.PreviewResize = self.Portrait:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		self:FitPreview()
	end)
	for key, tile in self.Tiles do
		tile.UIStroke.Transparency = if key == id then 0 else 0.6
		tile.UIStroke.Thickness = if key == id then 2.5 else 1
	end
end
function Catalog:Destroy()
	if self.PreviewResize then
		self.PreviewResize:Disconnect()
		self.PreviewResize = nil
	end
	for _, list in { self.Connections, self.TileConnections } do
		for _, connection in list do
			connection:Disconnect()
		end
	end
	self.Root:Destroy()
end
return Catalog
