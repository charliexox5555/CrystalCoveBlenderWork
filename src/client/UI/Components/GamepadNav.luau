-- Controller support for every menu, in one place.
-- A screen that opens calls GamepadNav.push(root, { Close = fn, First = button }) and keeps the handle; it calls
-- handle.Pop() when it closes (a destroyed root drops out by itself; a hidden one is skipped while hidden).
-- While a controller is in use the top menu gets a selected button (its First, else the top-left one),
-- selection stays inside it (SelectionGroup), and B runs its Close (Escape belongs to the Roblox menu on PC;
-- keyboard players use the X). The selection frame is a gold Stained Glass outline, not Roblox's grey box.
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local UIS = game:GetService("UserInputService")
local CAS = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local Theme = require(script.Parent.Parent.Theme)
local InputKind = require(script.Parent.Parent.InputKind)

local Nav = {}
local stack = {} -- { Root, Gui, Close, First, Popped }
local started = false
local BACK = "GlassClashNavBack"
local BACK_NAMES = { Close = true, Back = true, No = true, Cancel = true }
local menuOpen, menuListeners = false, {}
local home = nil -- { Gui, First }: the always-on lobby HUD a controller can step onto with the D-pad
local HOME = "GlassClashNavHome"
local editing = nil -- a grabbed control (a slider): B lets go of it instead of closing the menu
local glowStroke = nil
local EDIT_COLOR = Color3.fromRGB(120, 235, 255)

function Nav.usingGamepad(): boolean
	return InputKind.gamepad()
end

local function screenOf(object)
	return if object:IsA("LayerCollector") then object else object:FindFirstAncestorWhichIsA("LayerCollector")
end

-- Visible on screen right now: every GuiObject up to the ScreenGui is Visible and the ScreenGui is Enabled.
local function shown(object)
	local node = object
	while node and not node:IsA("LayerCollector") do
		if node:IsA("GuiObject") and not node.Visible then
			return false
		end
		node = node.Parent
	end
	return node ~= nil and node.Enabled and node:IsDescendantOf(Players.LocalPlayer)
end

local function selectable(object)
	return object
		and object.Parent
		and object:IsA("GuiObject")
		and object.Selectable
		and (not object:IsA("GuiButton") or object.Active)
		and object.AbsoluteSize.X > 2
		and object.AbsoluteSize.Y > 2
		and shown(object)
end

local function alive(entry)
	return not entry.Popped
		and entry.Root.Parent ~= nil
		and entry.Gui ~= nil
		and entry.Gui.Enabled
		and (not entry.Root:IsA("GuiObject") or shown(entry.Root))
end

local function top()
	for i = #stack, 1, -1 do
		local entry = stack[i]
		if alive(entry) then
			return entry
		end
		if entry.Popped or entry.Root.Parent == nil then
			table.remove(stack, i)
		end
	end
	return nil
end

-- The button a controller should land on: the screen's own choice, else the top-left button that isn't a close.
local function first(entry)
	local chosen = if type(entry.First) == "function" then entry.First() else entry.First
	if selectable(chosen) then
		return chosen
	end
	local best, bestKey = nil, math.huge
	for _, object in entry.Root:GetDescendants() do
		if object:IsA("GuiButton") and selectable(object) and not BACK_NAMES[object.Name] then
			local p = object.AbsolutePosition
			local key = math.floor(p.Y / 24) * 100000 + p.X
			if key < bestKey then
				best, bestKey = object, key
			end
		end
	end
	if best then
		return best
	end
	for _, object in entry.Root:GetDescendants() do
		if object:IsA("GuiButton") and selectable(object) then
			return object
		end
	end
	return nil
end

local function selectionFrame()
	local frame = Instance.new("Frame")
	frame.Name = "GlassClashSelection"
	frame.BackgroundTransparency = 1
	frame.Size, frame.Position = UDim2.new(1, 10, 1, 10), UDim2.fromOffset(-5, -5)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.18, 0)
	corner.Parent = frame
	local outer = Instance.new("UIStroke")
	outer.Name, outer.Color, outer.Thickness = "Glow", Theme.Colors.Highlight, 4
	outer.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	outer.Parent = frame
	-- A thin bright core line inside the gold reads as lit glass at TV distance.
	local inner = Instance.new("Frame")
	inner.Name, inner.BackgroundTransparency = "Core", 1
	inner.Size, inner.Position = UDim2.new(1, -6, 1, -6), UDim2.fromOffset(3, 3)
	local innerCorner = corner:Clone()
	innerCorner.Parent = inner
	local core = Instance.new("UIStroke")
	core.Color, core.Thickness, core.Transparency = Color3.new(1, 1, 1), 1.5, 0.25
	core.Parent = inner
	inner.Parent = frame
	return frame, outer
end

local function step()
	local entry = top()
	if (entry ~= nil) ~= menuOpen then
		menuOpen = entry ~= nil
		for _, listener in menuListeners do
			task.spawn(listener, menuOpen)
		end
	end
	local selected = GuiService.SelectedObject
	if selected and not selectable(selected) then
		-- Its screen hid or rebuilt under it: never leave the controller on an invisible button.
		GuiService.SelectedObject = nil
		selected = nil
	end
	if not Nav.usingGamepad() or not entry or not entry.AutoSelect then
		return
	end
	if selectable(selected) and selected:IsDescendantOf(entry.Root) then
		return
	end
	local target = first(entry)
	if target then
		GuiService.SelectedObject = target
	end
end

local function start()
	if started or not RunService:IsRunning() then
		return
	end
	started = true
	local player = Players.LocalPlayer
	local frame, glow = selectionFrame()
	glowStroke = glow
	task.spawn(function()
		local pg = player:WaitForChild("PlayerGui")
		pg.SelectionImageObject = frame
	end)
	CAS:BindActionAtPriority(BACK, function(_, state)
		if state == Enum.UserInputState.Begin and Nav.back() then
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.ContextActionPriority.High.Value + 20, Enum.KeyCode.ButtonB)
	-- With nothing open and nothing selected, D-pad left / right / down steps onto the lobby HUD (PLAY first).
	-- D-pad up stays the top bar's (TopbarPlus).
	CAS:BindActionAtPriority(
		HOME,
		function(_, state)
			if state == Enum.UserInputState.Begin and Nav.home() then
				return Enum.ContextActionResult.Sink
			end
			return Enum.ContextActionResult.Pass
		end,
		false,
		Enum.ContextActionPriority.Medium.Value,
		Enum.KeyCode.DPadLeft,
		Enum.KeyCode.DPadRight,
		Enum.KeyCode.DPadDown
	)
	if RunService:IsStudio() then
		-- Studio-only: Studio can't fake a controller, so tests call the same handlers through this.
		local dev = Instance.new("BindableFunction")
		dev.Name = "GamepadNavDev"
		dev.OnInvoke = function(command)
			if command == "Back" then
				return Nav.back()
			elseif command == "Home" then
				return Nav.home()
			end
			local entry = top()
			local selected = GuiService.SelectedObject
			return {
				Top = entry and entry.Root:GetFullName(),
				Selected = selected and selected:GetFullName(),
				Depth = #stack,
			}
		end
		task.spawn(function()
			dev.Parent = player:WaitForChild("PlayerScripts")
		end)
	end
	local clock = 0
	RunService.Heartbeat:Connect(function(dt)
		clock += dt
		glow.Transparency = 0.15 + 0.2 * (0.5 + 0.5 * math.sin(clock * 5))
		if clock % 0.15 < dt then
			step()
		end
	end)
	InputKind.changed(function()
		if Nav.usingGamepad() then
			step()
		end
	end)
end

-- Registers an open menu. `root` is its ScreenGui or panel; options: Close (B), First (a button or a
-- function returning one), Group (default true: keep the controller inside root when root is a GuiObject),
-- AutoSelect (default true; false = B only, nothing pre-selected, e.g. the queue where A must not leave).
function Nav.push(root, options)
	start()
	options = options or {}
	local entry = {
		Root = root,
		Gui = screenOf(root),
		Close = options.Close,
		First = options.First,
		AutoSelect = options.AutoSelect ~= false,
		Popped = false,
	}
	if root:IsA("GuiObject") and options.Group ~= false then
		root.SelectionGroup = true
		root.SelectionBehaviorUp, root.SelectionBehaviorDown = Enum.SelectionBehavior.Stop, Enum.SelectionBehavior.Stop
		root.SelectionBehaviorLeft, root.SelectionBehaviorRight =
			Enum.SelectionBehavior.Stop, Enum.SelectionBehavior.Stop
	end
	table.insert(stack, entry)
	-- Buttons may still be laying out; select on the next frames.
	task.defer(step)
	local handle = {}
	function handle.Pop()
		if entry.Popped then
			return
		end
		entry.Popped = true
		local selected = GuiService.SelectedObject
		if selected and selected:IsDescendantOf(root) then
			GuiService.SelectedObject = nil
		end
		task.defer(step)
	end
	-- Repoint the first button (a screen that rebuilds its buttons, e.g. a new tab).
	function handle.SetFirst(object)
		entry.First = object
		local selected = GuiService.SelectedObject
		if Nav.usingGamepad() and not (selectable(selected) and selected:IsDescendantOf(root)) then
			task.defer(step)
		end
	end
	-- Moves the controller onto a button now (e.g. after a confirm appears).
	function handle.Select(object)
		if Nav.usingGamepad() and selectable(object) then
			GuiService.SelectedObject = object
		end
	end
	return handle
end

-- The lobby HUD: reachable from the D-pad when no menu is open (see HOME above).
function Nav.setHome(gui, firstButton)
	start()
	home = { Gui = gui, First = firstButton }
end

-- B: closes the top menu, or steps off the lobby HUD. Returns true when it did something.
function Nav.back(): boolean
	if editing then
		editing()
		return true
	end
	local entry = top()
	if not entry then
		-- On the lobby HUD with nothing open: B steps back off it, so the stick moves the avatar again.
		local selected = GuiService.SelectedObject
		if home and selected and selected:IsDescendantOf(home.Gui) then
			GuiService.SelectedObject = nil
			return true
		end
		return false
	end
	if not entry.Close then
		return false
	end
	entry.Close()
	return true
end

-- D-pad from the lobby: lands on the HUD's first button when nothing is open or selected.
function Nav.home(): boolean
	if not home or top() or GuiService.SelectedObject then
		return false
	end
	local target = if type(home.First) == "function" then home.First() else home.First
	if not selectable(target) then
		return false
	end
	GuiService.SelectedObject = target
	return true
end

-- A control grabbed with A (a slider): the selection glows aqua and B lets go (calls `release`) instead of
-- closing the menu. Pass nil when it is let go.
function Nav.setEditing(release)
	editing = release
	if glowStroke then
		glowStroke.Color = if release then EDIT_COLOR else Theme.Colors.Highlight
		glowStroke.Thickness = if release then 5 else 4
	end
end

function Nav.hasMenu(): boolean
	return top() ~= nil
end

-- Called with true/false when a menu opens or the last one closes (e.g. the top bar turns its D-pad shortcut off,
-- since D-pad up should move inside the menu, not jump to the top bar).
function Nav.onMenuChanged(listener)
	table.insert(menuListeners, listener)
	start()
end

-- For screens with no close (a claim card, a roll): nothing extra, but the controller still lands inside.
function Nav.focus(root, firstButton)
	return Nav.push(root, { First = firstButton })
end

return Nav
