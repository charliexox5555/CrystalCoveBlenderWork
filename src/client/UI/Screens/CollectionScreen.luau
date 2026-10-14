local RS = game:GetService("ReplicatedStorage")
local Glassies = require(RS.Shared.Config.Glassies)
local Powers = require(RS.Shared.Config.Powers)
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
local rarities = { "All rarities", "Starter", "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" }
local sorts = { "Rarity", "Name", "Stars" }

local function installed(id)
	return RS.Assets.Glassies:FindFirstChild(id) ~= nil
end

function Screen.new(index, profile, close)
	local self = setmetatable({ Index = index, Profile = profile, Type = 1, Rarity = 1, Sort = 1 }, Screen)
	self.Window = Window.new(
		if index then "IndexScreen" else "CollectionScreen",
		if index then "GLASSY INDEX" else "MY GLASSIES",
		close
	)
	local parent = self.Window.Content
	for i, key in { "Type", "Rarity", "Sort" } do
		local button = Button.new(parent, key, "", "Blue", UDim2.new(1 / 3, -8, 0, 44), UDim2.new((i - 1) / 3, 4, 0, 0))
		self[key .. "Button"] = button
		self.Window:Connect(button, function()
			self[key] = self[key] % #(if key == "Type" then types elseif key == "Rarity" then rarities else sorts) + 1
			self:Refresh(self.Profile)
		end)
	end
	self.Count = U.text(parent, "Count", "", UDim2.new(1, 0, 0, 28), UDim2.fromOffset(0, 48), Theme.Fonts.Caption)
	self.Grid = U.make("ScrollingFrame", parent, {
		Name = "Grid",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 1, -80),
		Position = UDim2.fromOffset(0, 80),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollBarThickness = 5,
	})
	self:Refresh(profile)
	return self
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
	for _, def in Glassies.List do
		local owned = profile.Glassies[def.Id]
		if owned then
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
	self.Count.Text = ownedCount
		.. " / "
		.. #Glassies.List
		.. " discovered"
		.. (if self.Index then " • Tap to explore" else " • Tap for powers & stats")
	-- Destroying old tiles also disconnects their button events; avoid retaining stale callbacks.
	if self.TileRoot then
		self.TileRoot:Destroy()
	end
	self.TileRoot = U.make("Frame", self.Grid, {
		Name = "Tiles",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	})
	local layout = U.make(
		"UIGridLayout",
		self.TileRoot,
		{ CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder }
	)
	local function resize()
		local width = math.max(1, self.Grid.AbsoluteSize.X - 12)
		local columns = math.max(2, math.floor(width / 144))
		layout.CellSize = UDim2.fromOffset(math.floor((width - (columns - 1) * 10) / columns), 166)
	end
	if self.Resize then
		self.Resize:Disconnect()
	end
	self.Resize = self.Grid:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
	resize()
	for i, def in entries do
		local owned = profile.Glassies[def.Id]
		local tile = Panel.new(self.TileRoot, def.Id, UDim2.new(), UDim2.new(), true)
		tile.LayoutOrder = i
		tile.UIStroke.UIGradient.Color =
			ColorSequence.new(Theme.Rarity[def.Rarity].Top, Theme.Rarity[def.Rarity].Bottom)
		if owned and installed(def.Id) then
			Portrait.new(tile, def.Id, UDim2.new(1, 0, 0, 96), UDim2.new())
		elseif installed(def.Id) then
			local silhouette = Portrait.new(tile, def.Id, UDim2.new(1, 0, 0, 96), UDim2.new())
			silhouette.Ambient, silhouette.LightColor = Color3.new(), Color3.new()
			for _, part in silhouette:GetDescendants() do
				if part:IsA("BasePart") then
					part.Color, part.Material = Theme.Colors.Shadow, Enum.Material.SmoothPlastic
				end
			end
		else
			U.text(tile, "Undiscovered", "?", UDim2.new(1, 0, 0, 96), UDim2.new(), Theme.Fonts.Heading).UITextSizeConstraint.MaxTextSize =
				48
		end
		U.text(tile, "Name", def.Name, UDim2.new(1, -10, 0, 28), UDim2.fromOffset(5, 96))
		U.text(
			tile,
			"Rarity",
			def.Rarity .. (if owned then " • ★" .. owned.Stars else " • Unowned"),
			UDim2.new(1, -8, 0, 24),
			UDim2.fromOffset(4, 124),
			Theme.Fonts.Caption
		)
		if owned and owned.Rainbow then
			U.text(tile, "Rainbow", "RAINBOW", UDim2.new(1, 0, 0, 18), UDim2.fromOffset(0, 146)).TextColor3 =
				Theme.Colors.Highlight
		end
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
end

function Screen:Detail(id)
	if self.DetailFrame then
		self.DetailFrame:Destroy()
	end
	local def, owned = Glassies.get(id), self.Profile.Glassies[id]
	local frame = Panel.new(self.Window.Panel, "Details", UDim2.new(1, -24, 1, -64), UDim2.fromOffset(12, 56))
	frame.ZIndex, frame.Active = 10, true
	self.DetailFrame = frame
	self.Window.Content.Visible = false
	frame.BackgroundTransparency = 0
	local back = Button.new(frame, "Back", "BACK", "Blue", UDim2.fromOffset(92, 44), UDim2.fromOffset(6, 6))
	back.Activated:Connect(function()
		frame:Destroy()
		self.DetailFrame = nil
		self.DetailPortrait = nil
		self.Window.Content.Visible = true
	end)
	local art = U.make("Frame", frame, { BackgroundTransparency = 1 })
	if installed(id) and owned then
		self.DetailPortrait = Portrait.new(art, id, UDim2.fromScale(1, 1), UDim2.new())
	else
		U.text(art, "Unowned", "?", UDim2.fromScale(1, 1), UDim2.new(), Theme.Fonts.Heading).UITextSizeConstraint.MaxTextSize =
			80
	end
	local info = U.make("ScrollingFrame", frame, {
		Name = "Info",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollBarThickness = 4,
	})
	U.make("UIListLayout", info, { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder })
	local stats, passive, special = Formula.stats(def, owned), Powers.passive(def.Passive), Powers.special(def.Special)
	local lines = {
		def.Name .. (if owned then " ★" .. owned.Stars else " • UNOWNED"),
		def.Type .. " • " .. def.Rarity,
		def.Description,
		"POWER " .. stats.Power .. "   HP " .. stats.HP .. "   SWING " .. stats.Swing,
		(def.PassiveName or passive.Name) .. ": " .. passive.Description,
		(def.SpecialName or special.Name) .. ": " .. special.Description,
		"Powers fire automatically during fights.",
		"Used in " .. (self.Profile.Stats.GlassyUses[id] or 0) .. " matches",
	}
	for i, line in lines do
		local label = U.text(
			info,
			"Line" .. i,
			line,
			UDim2.new(1, -10, 0, if i == 5 or i == 6 then 64 else 36),
			UDim2.new(),
			if i == 1 then Theme.Fonts.Heading else Theme.Fonts.Body
		)
		label.LayoutOrder, label.TextWrapped, label.TextXAlignment = i, true, Enum.TextXAlignment.Left
		label.UITextSizeConstraint.MinTextSize, label.UITextSizeConstraint.MaxTextSize = 14, if i == 1 then 24 else 18
	end
	local function resize()
		if frame.AbsoluteSize.X > frame.AbsoluteSize.Y then
			art.Size, art.Position = UDim2.new(0.35, 0, 1, -56), UDim2.fromOffset(0, 50)
			info.Size, info.Position = UDim2.new(0.62, -8, 1, -12), UDim2.new(0.38, 0, 0, 6)
		else
			art.Size, art.Position = UDim2.new(1, 0, 0.32, -16), UDim2.fromOffset(0, 48)
			info.Size, info.Position = UDim2.new(1, -16, 0.68, -42), UDim2.new(0, 8, 0.32, 40)
		end
	end
	frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
	resize()
end

function Screen:Step(dt)
	local p = self.DetailPortrait
	if p and p.Parent then
		for _, part in p.WorldModel:GetChildren() do
			if part:IsA("BasePart") then
				part:PivotTo(part:GetPivot() * CFrame.Angles(0, dt * 0.35, 0))
			end
		end
	end
end

function Screen:Destroy()
	if self.Resize then
		self.Resize:Disconnect()
	end
	self.Window:Destroy()
end
return Screen
