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
local Motion = require(script.Parent.Parent.UI.Components.Motion)
local UiAudio = require(script.Parent.Parent.UI.Components.UiAudio)
local GamepadNav = require(script.Parent.Parent.UI.Components.GamepadNav)
local Controller = {}

-- Screens that keep the HUD wallet visible (Config/Topbar Wallet = true).
local wallet = {}
for _, spec in Config.Buttons do
	for _, item in spec.Items or {} do
		if item.Wallet then
			wallet[item.Screen] = true
		end
	end
end

local function UiAudioClose()
	UiAudio.play("Close")
end

function Controller:Init(controllers)
	self.Controllers, self.Player = controllers, Players.LocalPlayer
	self.Icons, self.Rows, self.Wired, self.Warned = {}, {}, {}, {}
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
	local gui, icon, anim = self.Open, self.OpenIcon, self.OpenAnim
	if not gui then
		return
	end
	self.Open, self.OpenIcon, self.OpenAnim = nil, nil, nil
	if self.Nav then
		self.Nav.Pop()
		self.Nav = nil
	end
	local panel = gui:FindFirstChild("Panel")
	if anim and panel then
		-- Same close as the other windows (shrink + fade); the template's look comes back once it is hidden.
		local restore = Motion.fadeSnapshot(panel)
		anim.Close(function()
			if self.Open ~= gui then
				gui.Enabled = false
			end
			restore()
		end)
		UiAudioClose()
	else
		gui.Enabled = false
	end
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
	if lobby and lobby.ShowWallet and wallet[name] then
		lobby:ShowWallet()
	end
	gui.Enabled = true
	local panel = gui:FindFirstChild("Panel")
	-- Controller: land inside the menu; B / Escape closes it.
	self.Nav = GamepadNav.push(panel or gui, {
		Close = function()
			if self.Open == gui then
				self:CloseMenu()
			end
		end,
	})
	if panel then
		self.OpenAnim = Motion.windowIn(gui, panel)
		for _, container in Config.Stagger do
			local holder = panel:FindFirstChild(container, true)
			if holder then
				local items = {}
				for _, child in holder:GetChildren() do
					if child:IsA("GuiObject") then
						Motion.center(child) -- pop in from the middle, not a corner
						table.insert(items, child)
					end
				end
				table.sort(items, function(a, b)
					return a.AbsolutePosition.X + a.AbsolutePosition.Y * 4
						< b.AbsolutePosition.X + b.AbsolutePosition.Y * 4
				end)
				Motion.stagger(items)
			end
		end
	end
end

function Controller:Build(Icon)
	for order, spec in Config.Buttons do
		local image = UIAssets[spec.Image]
		if spec.Headshot and self.Player.UserId > 0 then
			image = ("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150"):format(self.Player.UserId)
		end
		local icon = Icon.new():setName(spec.Id):setImage(image):setCaption(spec.Caption):setOrder(order)
		if spec.Items then
			local rows = {}
			for _, item in spec.Items do
				local row = Icon.new():setName(item.Id):setImage(UIAssets[item.Image]):setLabel(item.Label):oneClick()
				row.selected:Connect(function()
					self:OpenMenu(item.Screen, nil)
					icon:deselect()
				end)
				table.insert(rows, row)
				self.Rows[item.Id] = { Icon = row, Count = 0 }
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

-- Red count on a dropdown row (and, summed by TopbarPlus, on its button): claimable rewards (decision 99).
function Controller:SetNotice(id, count)
	local entry = self.Rows[id]
	if not entry or entry.Count == count then
		return
	end
	entry.Count = count
	entry.Clear = entry.Clear or Instance.new("BindableEvent")
	entry.Clear:Fire() -- drops this row's notices and the copies it added to its parent button
	for _ = 1, count do
		entry.Icon:notify(entry.Clear.Event)
	end
end

-- Opens a top bar screen from elsewhere (the lobby rewards board, a "claim" toast).
function Controller:OpenScreen(name)
	self:OpenMenu(name, nil)
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
	Icon.setDisplayOrder(Config.DisplayOrder)
	self:Build(Icon)
	-- Controller: D-pad up reaches the top bar from the lobby, but inside an open menu it moves the selection.
	GamepadNav.onMenuChanged(function(open)
		Icon.highlightKey = if open then false else Enum.KeyCode.DPadUp
	end)
	-- Fetch the screens' art in the background so a first open never shows empty frames on a slow connection.
	task.spawn(function()
		require(script.Parent.Parent.LoadGate).afterLoading() -- Essential tier first (Daily is already in it)
		local pg = self.Player:WaitForChild("PlayerGui")
		local images = {}
		for _, spec in Config.Buttons do
			local names = { spec.Screen }
			for _, item in spec.Items or {} do
				table.insert(names, item.Screen)
			end
			for _, name in names do
				local gui = name and pg:WaitForChild(name, 30)
				for _, object in gui and gui:GetDescendants() or {} do
					if object:IsA("ImageLabel") or object:IsA("ImageButton") then
						table.insert(images, object)
					end
				end
			end
		end
		pcall(function()
			game:GetService("ContentProvider"):PreloadAsync(images)
		end)
	end)
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
