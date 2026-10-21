local RS = game:GetService("ReplicatedStorage")
local Glassies = require(RS.Shared.Config.Glassies)
local Powers = require(RS.Shared.CombatText)
local Balance = require(RS.Shared.Config.Balance)
local Formula = require(RS.Shared.Formula)
local Theme = require(script.Parent.Parent.Theme)
local U = require(script.Parent.Parent.Components.Util)
local Window = require(script.Parent.Parent.Components.Window)
local Button = require(script.Parent.Parent.Components.Button)
local Panel = require(script.Parent.Parent.Components.Panel)
local Portrait = require(script.Parent.Parent.Components.GlassyPortrait)
local Screen = {}
Screen.__index = Screen
local types = { "All types", "Heavy", "Sharp", "Fizzy" }
local rarities = { "All rarities", "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" }
local sorts = { "Rarity", "Name", "Stars" }
local function installed(id)
	return RS.Assets.Glassies:FindFirstChild(id) ~= nil
end

function Screen.new(index, profile, close)
	if not index then
		return require(script.Parent.InventoryScreen).new(profile, close)
	end
	local self = setmetatable({ Index = index, Profile = profile, Type = 1, Rarity = 1, Sort = 1, Tiles = {} }, Screen)
	self.Window = Window.new(
		if index then "IndexScreen" else "CollectionScreen",
		if index then "GLASSY INDEX" else "MY GLASSIES",
		close
	)
	local parent = self.Window.Content
	for i, key in { "Type", "Rarity", "Sort" } do
		local button =
			Button.new(parent, key, "", "Blue", UDim2.fromScale(0.315, 0.14), UDim2.fromScale((i - 1) * 0.342, 0))
		self[key .. "Button"] = button
		self.Window:Connect(button, function()
			self[key] = self[key] % #(if key == "Type" then types elseif key == "Rarity" then rarities else sorts) + 1
			self:Refresh(self.Profile)
		end)
	end
	self.Count = U.text(parent, "Count", "", UDim2.fromScale(1, 0.08), UDim2.fromScale(0, 0.16), Theme.Fonts.Caption)
	self.Grid = U.make("ScrollingFrame", parent, {
		Name = "Grid",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 0.72),
		Position = UDim2.fromScale(0, 0.27),
		CanvasSize = UDim2.new(),
		ScrollBarThickness = 5,
	})
	self.Resize = self.Grid:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		self:Layout()
	end)
	self:Refresh(profile)
	return self
end

function Screen:Layout()
	if not self.TileRoot then
		return
	end
	local s = self.Grid.AbsoluteSize
	local columns = if s.X > 900 then 5 elseif s.X > 600 then 4 elseif s.X > 400 then 3 else 2
	local rows = math.max(1, math.ceil(#self.Tiles / columns))
	local canvas = math.max(1, rows * (s.X / columns) * 1.15 / math.max(1, s.Y))
	self.Grid.CanvasSize = UDim2.fromScale(0, canvas)
	for i, tile in self.Tiles do
		tile.Size = UDim2.fromScale(1 / columns - 0.018, 1 / rows - 0.012)
		tile.Position = UDim2.fromScale(((i - 1) % columns) / columns, math.floor((i - 1) / columns) / rows)
	end
end

function Screen:Refresh(profile)
	self.Profile = profile
	if not profile then
		self.Count.Text = "Loading your glassies..."
		return
	end
	self.TypeButton.Text, self.RarityButton.Text, self.SortButton.Text =
		types[self.Type], rarities[self.Rarity], "Sort: " .. sorts[self.Sort]
	local ownedCount, entries = 0, {}
	for _, def in Glassies.visible(profile.Glassies) do
		local owned = profile.Glassies[def.Id]
		if owned and Glassies.isRelease(def.Id) then
			ownedCount += 1
		end
		if
			(self.Index or owned)
			and (self.Type == 1 or def.Type == types[self.Type])
			and (self.Rarity == 1 or def.Rarity == rarities[self.Rarity])
		then
			table.insert(entries, def)
		end
	end
	table.sort(entries, function(a, b)
		if self.Sort == 3 then
			local x, y = (profile.Glassies[a.Id] or {}).Stars or 0, (profile.Glassies[b.Id] or {}).Stars or 0
			if x ~= y then
				return x > y
			end
		elseif self.Sort == 1 then
			local x, y = Balance.Rarities[a.Rarity].Order, Balance.Rarities[b.Rarity].Order
			if x ~= y then
				return x > y
			end
		end
		return a.Name < b.Name
	end)
	self.Count.Text = ownedCount .. " / " .. #Glassies.ReleaseList .. " discovered • Tap for powers & stats"
	if self.TileRoot then
		self.TileRoot:Destroy()
	else
		local old = self.Grid:FindFirstChild("Tiles")
		if old then
			old:Destroy()
		end
	end
	self.TileRoot =
		U.make("Frame", self.Grid, { Name = "Tiles", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) })
	self.Tiles = {}
	for i, def in entries do
		local owned = profile.Glassies[def.Id]
		local prototype = U.prototype(self.Grid, "GlassyTile", def.Id)
		if prototype then
			prototype.Parent = self.TileRoot
		end
		local tile = Panel.new(self.TileRoot, def.Id, UDim2.fromScale(0.3, 0.9), UDim2.new(), true)
		table.insert(self.Tiles, tile)
		tile.UIStroke.UIGradient.Color =
			ColorSequence.new(Theme.Rarity[def.Rarity].Top, Theme.Rarity[def.Rarity].Bottom)
		local p
		if installed(def.Id) then
			p = Portrait.new(tile, def.Id, UDim2.fromScale(1, 0.6), UDim2.new())
			p.Visible = true
			if not owned then
				p.Ambient, p.LightColor = Color3.new(), Color3.new()
				for _, part in p:GetDescendants() do
					if part:IsA("BasePart") then
						part.Color, part.Material = Theme.Colors.Shadow, Enum.Material.SmoothPlastic
					end
				end
			end
		else
			local existing = tile:FindFirstChild("Portrait")
			if existing then
				existing.Visible = false
			end
		end
		local unknown = U.text(tile, "Undiscovered", "?", UDim2.fromScale(1, 0.6), UDim2.new(), Theme.Fonts.Heading)
		unknown.Visible = not p
		unknown.UITextSizeConstraint.MaxTextSize = 48
		U.text(tile, "Name", def.Name, UDim2.fromScale(0.94, 0.17), UDim2.fromScale(0.03, 0.6))
		U.text(
			tile,
			"Rarity",
			def.Rarity .. (if owned then " • ★" .. owned.Stars else " • Unowned"),
			UDim2.fromScale(0.96, 0.14),
			UDim2.fromScale(0.02, 0.78),
			Theme.Fonts.Caption
		)
		local rainbow = U.text(tile, "Rainbow", "RAINBOW", UDim2.fromScale(1, 0.1), UDim2.fromScale(0, 0.9))
		rainbow.Visible = owned ~= nil and owned.Rainbow
		rainbow.TextColor3 = Theme.Colors.Highlight
		local tap = U.make("TextButton", tile, {
			Name = "Open",
			Text = "",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Selectable = true,
			ZIndex = 5,
		})
		tap.Activated:Connect(function()
			self:Detail(def.Id)
		end)
	end
	self:Layout()
end

function Screen:Detail(id)
	if self.DetailWindow then
		self.DetailWindow:Destroy()
	end
	self.Window.Gui.Enabled = false
	local function back()
		self.DetailWindow:Destroy()
		self.DetailWindow = nil
		self.DetailPortrait = nil
		self.Window.Gui.Enabled = true
	end
	self.DetailWindow = Window.new("GlassyDetailScreen", "GLASSY DETAILS", back)
	local def, owned = Glassies.get(id), self.Profile.Glassies[id]
	local parent = self.DetailWindow.Content
	local art = U.make("Frame", parent, {
		Name = "Art",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(0.34, 0.9),
		Position = UDim2.fromScale(0, 0.04),
	})
	if installed(id) and owned then
		self.DetailPortrait = Portrait.new(art, id, UDim2.fromScale(1, 1), UDim2.new())
	else
		U.text(art, "Unowned", "?", UDim2.fromScale(1, 1), UDim2.new(), Theme.Fonts.Heading).UITextSizeConstraint.MaxTextSize =
			80
	end
	local info = U.make("ScrollingFrame", parent, {
		Name = "Info",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0.63, 0.96),
		Position = UDim2.fromScale(0.37, 0.02),
		CanvasSize = UDim2.fromScale(0, 1.8),
		ScrollBarThickness = 4,
	})
	local body = U.make("Frame", info, { Name = "Lines", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) })
	local stats, passive, special = Formula.stats(def, owned), Powers.passive(def), Powers.special(def)
	local lines = {
		def.Name .. (if owned then " ★" .. owned.Stars else " • UNOWNED"),
		def.Type .. " • " .. def.Rarity,
		def.Description,
		"POWER " .. stats.Power .. "   HP " .. stats.HP .. "   SWING " .. stats.Swing,
		passive.Name .. ": " .. passive.Description,
		special.Name .. ": " .. special.Description,
		"Powers charge by themselves. Tap CAST to time them, or let them go off automatically.",
		"Used in " .. (self.Profile.Stats.GlassyUses[id] or 0) .. " matches",
	}
	local y = 0
	for i, line in lines do
		local h = if i == 5 or i == 6 then 0.18 else 0.1
		local label = U.text(
			body,
			"Line" .. i,
			line,
			UDim2.fromScale(0.96, h - 0.012),
			UDim2.fromScale(0, y),
			if i == 1 then Theme.Fonts.Heading else Theme.Fonts.Body
		)
		label.TextWrapped, label.TextXAlignment = true, Enum.TextXAlignment.Left
		label.UITextSizeConstraint.MinTextSize, label.UITextSizeConstraint.MaxTextSize = 14, if i == 1 then 24 else 18
		y += h
	end
end

function Screen:Step(dt)
	-- Portraits stay upright and centered; interactive controls retain their animation.
end
function Screen:Destroy()
	if self.Resize then
		self.Resize:Disconnect()
	end
	if self.DetailWindow then
		self.DetailWindow:Destroy()
	end
	self.Window:Destroy()
end
return Screen
