-- Player profile window (decision 104): fills the StarterGui.ProfileScreen template built by
-- tools/studio/build_profile_screen.luau (element map: docs/ui/screens/ProfileScreen.md). Read-only for everyone:
-- your own profile and other players' look the same. Equipping stays in the Inventory.
--
--   local screen = ProfileScreen.new(playerGui.ProfileScreen)
--   screen:Show({ UserId, Name, Self, Level = { Level, Xp, XpNext }, Stats, Glassies, Cosmetics })
local RS = game:GetService("ReplicatedStorage")
local Glassies = require(RS.Shared.Config.Glassies)
local Cosmetics = require(RS.Shared.Config.RoundCosmetics)
local UIAssets = require(RS.Shared.Config.UIAssets)
local Balance = require(RS.Shared.Config.Balance)
local S = require(script.Parent.Parent.Components.StainedGlass)
local Motion = require(script.Parent.Parent.Components.Motion)
local GlassyPortrait = require(script.Parent.Parent.Components.GlassyPortrait)
local CosmeticPortrait = require(script.Parent.Parent.Components.CosmeticPortrait)
local Screen = {}
Screen.__index = Screen

local TABS = { "Profile", "Glassies", "Finishers", "Flyers" }
local CATEGORY = { Finishers = "Finishers", Flyers = "Rideables" }
local IDLE_ICON = Color3.fromRGB(205, 200, 220)
local RARITY_ORDER = { Mythic = 1, Legendary = 2, Epic = 3, Rare = 4, Uncommon = 5, Common = 6, Starter = 7 }
-- Grid rows as fractions of the grid's height (two rows fill it; more rows scroll).
local CELL_W, CELL_H, PAD_W, PAD_H = 0.18, 0.44, 0.025, 0.07

local function headshot(userId)
	return ("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150"):format(math.max(1, userId))
end

local function sorted(entries)
	table.sort(entries, function(a, b)
		local ra, rb = RARITY_ORDER[a.Rarity] or 9, RARITY_ORDER[b.Rarity] or 9
		if ra ~= rb then
			return ra < rb
		end
		return a.Name < b.Name
	end)
	return entries
end

function Screen.new(gui)
	local self = setmetatable({ Gui = gui, Connections = {}, Dirty = {}, Tab = "Profile" }, Screen)
	self.Panel = gui:WaitForChild("Panel")
	self.Tabs = self.Panel:WaitForChild("Tabs")
	self.Content = self.Panel:WaitForChild("Content")
	for _, name in TABS do
		local tab = self.Tabs:WaitForChild(name .. "Tab")
		Motion.button(tab)
		table.insert(
			self.Connections,
			tab.Activated:Connect(function()
				self:SelectTab(name)
			end)
		)
	end
	for _, name in { "Glassies", "Finishers", "Flyers" } do
		local page = self.Content:FindFirstChild(name .. "Page")
		local grid = page and page:FindFirstChild("Grid")
		if grid then
			table.insert(
				self.Connections,
				grid:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
					self:LayoutGrid(name)
				end)
			)
		end
	end
	return self
end

-- Win rate as a whole percent; no matches yet reads 0%.
function Screen.winRate(stats)
	local wins, losses = stats.MatchWins or 0, stats.MatchLosses or 0
	return if wins + losses > 0 then math.floor(wins / (wins + losses) * 100 + 0.5) else 0
end

-- Owned glassies that count toward the collection (the release list), and the list's size.
function Screen.collection(owned)
	local count = 0
	for _, def in Glassies.ReleaseList do
		local entry = owned and owned[def.Id]
		if entry and (entry.Count == nil or entry.Count > 0) then
			count += 1
		end
	end
	return count, #Glassies.ReleaseList
end

-- One string per collection that changes what its grid shows (profile refreshes leave unchanged grids alone).
local function signature(data, name)
	local parts = { tostring(data.UserId) }
	if name == "Glassies" then
		for id, entry in data.Glassies or {} do
			table.insert(parts, id .. ":" .. tostring(type(entry) == "table" and entry.Count))
		end
	else
		for _, id in (data.Cosmetics or {})[CATEGORY[name]] or {} do
			table.insert(parts, id)
		end
	end
	table.sort(parts)
	return table.concat(parts, "|")
end

function Screen:Show(data)
	local sameUser = self.Data ~= nil and self.Data.UserId == data.UserId
	self.Data = data
	self.Signatures = self.Signatures or {}
	for _, name in { "Glassies", "Finishers", "Flyers" } do
		local current = signature(data, name)
		if self.Signatures[name] ~= current then
			self.Signatures[name], self.Dirty[name] = current, true
		end
	end
	local page = self.Content.ProfilePage
	local level = data.Level or { Level = 1, Xp = 0, XpNext = Balance.Levels.BaseXp }
	local stats = data.Stats or {}
	self.Tabs.ProfileTab.Icon.Image = headshot(data.UserId)
	page.NamePlate:FindFirstChild("Name").Text = data.Name or "Player"
	page.Portrait.Avatar.Image = ("rbxthumb://type=Avatar&id=%d&w=420&h=420"):format(math.max(1, data.UserId))
	page.Portrait.Level.Text.Text = "Lv." .. level.Level
	local progress = if level.XpNext > 0 then math.clamp(level.Xp / level.XpNext, 0, 1) else 0
	local fill = page.Xp.Fill
	fill.Size = UDim2.fromScale(0.98 * progress, fill.Size.Y.Scale)
	-- The art inside keeps the track's full length, so a short fill shows only its left part.
	fill.Art.Size = UDim2.fromScale(if progress > 0 then 1 / progress else 0, 1)
	fill.Visible = progress > 0
	page.Xp:SetAttribute("Xp", level.Xp)
	page.Xp:SetAttribute("XpNext", level.XpNext)
	page.XpText.Text = ("%d / %d XP"):format(level.Xp, level.XpNext)
	local owned, total = Screen.collection(data.Glassies)
	page.Wins.Value.Text = tostring(stats.MatchWins or 0)
	page.WinRate.Value.Text = Screen.winRate(stats) .. "%"
	page.BestStreak.Value.Text = tostring(stats.BestStreak or 0)
	page.Collection.Value.Text = owned .. "/" .. total
	-- A profile refresh keeps the open tab; a different player starts on Profile.
	if sameUser and self.Tab ~= "Profile" then
		self:SelectTab(self.Tab, true)
	else
		self:SelectTab("Profile", true)
	end
end

function Screen:SelectTab(name, quiet)
	self.Tab = name
	for _, tabName in TABS do
		local tab = self.Tabs[tabName .. "Tab"]
		local active = tabName == name
		tab.Image = UIAssets[if active then "screens/profile/tab_active" else "screens/profile/tab_idle"]
		tab:SetAttribute("Active", active)
		local icon = tab:FindFirstChild("Icon")
		if icon then
			icon.ImageColor3 = if active then Color3.new(1, 1, 1) else IDLE_ICON
		end
		local page = self.Content:FindFirstChild(tabName .. "Page")
		if page then
			page.Visible = active
		end
	end
	if name ~= "Profile" and self.Dirty[name] then
		self.Dirty[name] = false
		self:BuildGrid(name)
	end
	if not quiet then
		Motion.bump(self.Tabs[name .. "Tab"])
	end
end

-- Entries shown on a collection tab: only what this player owns, rarest first.
function Screen:Entries(name)
	local data, out = self.Data or {}, {}
	if name == "Glassies" then
		for id, entry in data.Glassies or {} do
			local def = Glassies.ById[id]
			if def and type(entry) == "table" and (entry.Count == nil or entry.Count > 0) then
				table.insert(out, { Id = id, Name = def.Name, Rarity = def.Rarity, Count = entry.Count or 1 })
			end
		end
		return sorted(out), Screen.collection(data.Glassies)
	end
	local category = CATEGORY[name]
	local catalog = Cosmetics.catalog(category)
	for _, id in (data.Cosmetics or {})[category] or {} do
		local def = Cosmetics.ByCategory[category][id]
		if def then
			table.insert(out, { Id = id, Name = def.Name, Rarity = def.Rarity })
		end
	end
	return sorted(out), #out, #catalog
end

function Screen:BuildGrid(name)
	local page = self.Content:FindFirstChild(name .. "Page")
	local grid = page and page:FindFirstChild("Grid")
	local tiles = grid and grid:FindFirstChild("Tiles")
	local source = self.Gui.Parent and self.Gui.Parent:FindFirstChild("CollectionScreen")
	local template = source and source:FindFirstChild("GlassyTile", true)
	if not tiles or not template then
		return
	end
	for _, child in tiles:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local entries, owned, total = self:Entries(name)
	page.Count.Text.Text = owned .. " / " .. total
	local made = {}
	for order, entry in entries do
		local tile = template:Clone()
		tile.Name, tile.LayoutOrder, tile.Visible = entry.Id, order, true
		for _, part in { "Open", "SelectedOutline", "Unknown", "Count", "Equipped" } do
			local child = tile:FindFirstChild(part)
			if child then
				child:Destroy()
			end
		end
		S.setAsset(tile.Artwork, "tile/tile_" .. S.rarity(entry.Rarity))
		tile:FindFirstChild("Name").Text = entry.Name
		local old = tile.Portrait
		local size, position = old.Size, old.Position
		local aspect = old:FindFirstChildOfClass("UIAspectRatioConstraint")
		aspect = aspect and aspect:Clone()
		old:Destroy()
		tile.Parent = tiles
		local viewport = if name == "Glassies"
			then GlassyPortrait.new(tile, entry.Id, size, position)
			else CosmeticPortrait.new(tile, CATEGORY[name], entry.Id, size, position, "Portrait")
		viewport.AnchorPoint, viewport.Position = Vector2.new(0.5, 0.5), position
		if aspect then
			aspect.Parent = viewport
		end
		if entry.Count and entry.Count > 1 then
			local count = Instance.new("TextLabel")
			count.Name, count.BackgroundTransparency, count.Text = "Count", 1, "×" .. entry.Count
			count.AnchorPoint, count.Position, count.Size =
				Vector2.new(1, 0), UDim2.fromScale(0.9, 0.07), UDim2.fromScale(0.5, 0.1)
			count.TextXAlignment, count.TextScaled, count.ZIndex = Enum.TextXAlignment.Right, true, 3
			count.FontFace = tile:FindFirstChild("Name").FontFace
			count.TextColor3 = Color3.new(1, 1, 1)
			local stroke = Instance.new("UIStroke")
			stroke.Color, stroke.Thickness, stroke.Parent = Color3.fromHex("#1F1830"), 1.5, count
			count.Parent = tile
		end
		S.bindSlices(tile)
		table.insert(made, tile)
	end
	self:LayoutGrid(name)
	grid.CanvasPosition = Vector2.zero
	Motion.stagger(made)
end

-- Rows keep the template's size (two rows fill the grid); the canvas grows for more rows.
function Screen:LayoutGrid(name)
	local page = self.Content:FindFirstChild(name .. "Page")
	local grid = page and page:FindFirstChild("Grid")
	local tiles = grid and grid:FindFirstChild("Tiles")
	local layout = tiles and tiles:FindFirstChildOfClass("UIGridLayout")
	if not layout then
		return
	end
	local height = grid.AbsoluteSize.Y
	local count = 0
	for _, child in tiles:GetChildren() do
		if child:IsA("GuiObject") then
			count += 1
		end
	end
	local perRow = math.max(1, math.floor((1 + PAD_W) / (CELL_W + PAD_W)))
	local rows = math.max(2, math.ceil(count / perRow))
	layout.CellSize = UDim2.new(CELL_W, 0, 0, math.floor(height * CELL_H))
	layout.CellPadding = UDim2.new(PAD_W, 0, 0, math.floor(height * PAD_H))
	local canvas = rows * math.floor(height * CELL_H) + (rows - 1) * math.floor(height * PAD_H)
	grid.CanvasSize = UDim2.new(0, 0, 0, if rows > 2 then canvas else 0)
	tiles.Size = UDim2.new(1, 0, 0, math.max(canvas, height))
end

function Screen:Destroy()
	for _, connection in self.Connections do
		connection:Disconnect()
	end
	self.Connections = {}
end

return Screen
