-- Glass Clash buttons in the Roblox top bar (Config/Topbar, TopbarPlus in Shared.Vendor.Icon; decision 98).
-- A button with a Screen opens that ScreenGui and stays highlighted while it is open, like Roblox's own buttons.
-- A button with Items opens a dropdown; each row opens its own screen. Screens are authored in StarterGui
-- (tools/studio/build_topbar_screens.luau) and only toggled here: Enabled on/off, plus their "Close" button.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Config = require(RS.Shared.Config.Topbar)
local UIAssets = require(RS.Shared.Config.UIAssets)
local TouchGate = require(script.Parent.Parent.UI.TouchGate)
local StainedGlass = require(script.Parent.Parent.UI.Components.StainedGlass)
local Controller = {}

function Controller:Init(controllers)
	self.Controllers, self.Player = controllers, Players.LocalPlayer
	self.Icons, self.Wired, self.Warned = {}, {}, {}
end

-- Same rule as the lobby HUD: hidden in a match, the queue, results, while watching or with a fight HUD up.
local function matchUi(pg)
	local fight = pg:FindFirstChild("FightHud")
	return pg:GetAttribute("InMatch")
		or pg:GetAttribute("Queued")
		or pg:GetAttribute("ResultsOpen")
		or pg:GetAttribute("Watching")
		or (fight ~= nil and fight:IsA("ScreenGui") and fight.Enabled)
end

function Controller:Screen(name)
	local gui = self.Player.PlayerGui:FindFirstChild(name)
	if gui and gui:IsA("ScreenGui") then
		return gui
	end
	if not self.Warned[name] then
		self.Warned[name] = true
		warn(
			"[GlassClash] Top bar screen missing from StarterGui: "
				.. name
				.. " (run tools/studio/build_topbar_screens.luau)"
		)
	end
	return nil
end

function Controller:Wire(gui)
	if self.Wired[gui] then
		return
	end
	self.Wired[gui] = true
	StainedGlass.bindSlices(gui)
	local close = gui:FindFirstChild("Close", true)
	if close and close:IsA("GuiButton") then
		close.Activated:Connect(function()
			if self.Open == gui then
				self:CloseMenu()
			end
		end)
	end
	gui.Destroying:Connect(function()
		self.Wired[gui] = nil
	end)
end

function Controller:CloseMenu()
	local gui, icon = self.Open, self.OpenIcon
	if not gui then
		return
	end
	self.Open, self.OpenIcon = nil, nil
	gui.Enabled = false
	TouchGate.release(self)
	local lobby = self.Controllers.LobbyController
	if lobby and lobby.Gui then
		lobby:Close() -- gives the lobby HUD back unless a match hides it
	end
	if icon and icon.isSelected then
		icon:deselect()
	end
end

function Controller:OpenMenu(name, icon)
	local gui = self:Screen(name)
	if not gui then
		if icon and icon.isSelected then
			icon:deselect()
		end
		return
	end
	if self.Open == gui then
		return
	end
	self:CloseMenu()
	local lobby = self.Controllers.LobbyController
	if lobby and lobby.Gui then
		lobby:Close() -- one menu at a time: Shop, Inventory and Rewards windows close
		lobby:PanelOpened()
	end
	self:Wire(gui)
	self.Open, self.OpenIcon = gui, icon
	TouchGate.acquire(self)
	gui.Enabled = true
end

function Controller:Build(Icon)
	for order, spec in Config.Buttons do
		local icon = Icon.new():setName(spec.Id):setImage(UIAssets[spec.Image]):setCaption(spec.Caption):setOrder(order)
		if spec.Items then
			local rows = {}
			for _, item in spec.Items do
				local row = Icon.new():setName(item.Id):setImage(UIAssets[item.Image]):setLabel(item.Label):oneClick()
				row.selected:Connect(function()
					self:OpenMenu(item.Screen, nil)
					icon:deselect()
				end)
				table.insert(rows, row)
			end
			icon:modifyTheme({ "Dropdown", "MaxIcons", #rows })
				:modifyChildTheme({ "Widget", "MinimumWidth", Config.DropdownWidth })
				:setDropdown(rows)
		elseif spec.Screen then
			local screen = spec.Screen
			icon.selected:Connect(function()
				self:OpenMenu(screen, icon)
			end)
			icon.deselected:Connect(function()
				local gui = self.Open
				if gui and gui.Name == screen and self.OpenIcon == icon then
					self:CloseMenu()
				end
			end)
		end
		self.Icons[spec.Id] = { Icon = icon, Spec = spec }
	end
end

function Controller:ApplyMatch()
	local hidden = matchUi(self.Player.PlayerGui)
	for _, entry in self.Icons do
		if entry.Spec.HideInMatch then
			entry.Icon:setEnabled(not hidden)
		end
	end
	-- A match starting closes reward menus (their button just hid); Settings may stay open.
	local open = self.Open
	if hidden and open then
		for _, entry in self.Icons do
			if entry.Spec.HideInMatch then
				for _, item in entry.Spec.Items or {} do
					if item.Screen == open.Name then
						self:CloseMenu()
						return
					end
				end
				if entry.Spec.Screen == open.Name then
					self:CloseMenu()
					return
				end
			end
		end
	end
end

function Controller:Start()
	-- Required here, not at the top: a problem in the library must never stop the other controllers.
	local ok, Icon = pcall(require, RS.Shared.Vendor.Icon)
	if not ok then
		warn("[GlassClash] TopbarPlus unavailable: " .. tostring(Icon))
		return
	end
	self:Build(Icon)
	local pg = self.Player:WaitForChild("PlayerGui")
	local function changed()
		self:ApplyMatch()
	end
	for _, name in { "InMatch", "Queued", "ResultsOpen", "Watching" } do
		pg:GetAttributeChangedSignal(name):Connect(changed)
	end
	local function track(child)
		if child.Name == "FightHud" and child:IsA("ScreenGui") then
			child:GetPropertyChangedSignal("Enabled"):Connect(changed)
			changed()
		end
	end
	for _, child in pg:GetChildren() do
		track(child)
	end
	pg.ChildAdded:Connect(track)
	pg.ChildRemoved:Connect(function(child)
		if child.Name == "FightHud" then
			changed()
		end
	end)
	changed()
end

return Controller
