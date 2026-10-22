-- Studio-only UI audit hook for device checks (Studio device simulator + screen_capture).
-- PlayerScripts.UIAuditDev:Invoke(command, arg):
--   "Open", name   opens a screen: Kiln, Glassies, Profile, Settings, Daily, Playtime, Codes, Roll, Queue, Results
--   "Close"        closes lobby panels and top bar screens
--   "Scan"         lists visible GuiObjects that leave the screen (OFF), interactive ones under 36 px (SMALL), cut text
--                  (TEXT), text under 9.5 px (TINY), buttons over buttons of another window (OVERLAP), text drawn over
--                  other text (TEXT-OVERLAP) and more than one window open at once (TWO-OPEN)
local RunService = game:GetService("RunService")
if not RunService:IsStudio() then
	return
end
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local controllers = script.Parent.Parent:WaitForChild("Controllers")
local function controller(name)
	local module = controllers:FindFirstChild(name)
	return module and require(module)
end

local TOPBAR = {
	Profile = "ProfileScreen",
	Settings = "SettingsScreen",
	Daily = "DailyRewardsScreen",
	Playtime = "PlaytimeRewardsScreen",
	Codes = "CodesScreen",
}

local function visible(object)
	local current = object
	while current and current:IsA("GuiObject") do
		if not current.Visible then
			return false
		end
		current = current.Parent
	end
	local screen = object:FindFirstAncestorWhichIsA("LayerCollector")
	return screen ~= nil and (not screen:IsA("ScreenGui") or screen.Enabled)
end

-- Where a GuiObject is actually drawn: its box cut by every clipping ancestor (scroll frames, canvas groups).
local function drawnRect(object, p, s)
	local x1, y1, x2, y2 = p.X, p.Y, p.X + s.X, p.Y + s.Y
	local current = object.Parent
	while current and current:IsA("GuiObject") do
		if current.ClipsDescendants or current:IsA("ScrollingFrame") or current:IsA("CanvasGroup") then
			local cp, cs = current.AbsolutePosition, current.AbsoluteSize
			x1, y1 = math.max(x1, cp.X), math.max(y1, cp.Y)
			x2, y2 = math.min(x2, cp.X + cs.X), math.min(y2, cp.Y + cs.Y)
		end
		current = current.Parent
	end
	return x1, y1, x2, y2
end

-- The box the glyphs take inside a text object, from its alignment and TextBounds.
local function textRect(object, p, s)
	local b = object.TextBounds
	local x = if object.TextXAlignment == Enum.TextXAlignment.Left
		then p.X
		elseif object.TextXAlignment == Enum.TextXAlignment.Right then p.X + s.X - b.X
		else p.X + (s.X - b.X) / 2
	local y = if object.TextYAlignment == Enum.TextYAlignment.Top
		then p.Y
		elseif object.TextYAlignment == Enum.TextYAlignment.Bottom then p.Y + s.Y - b.Y
		else p.Y + (s.Y - b.Y) / 2
	return x, y, x + b.X, y + b.Y
end

local function scan()
	local camera = workspace.CurrentCamera
	local viewport = camera.ViewportSize
	local out = { string.format("viewport %dx%d", viewport.X, viewport.Y) }
	local buttons, texts, open = {}, {}, {}
	for _, gui in player.PlayerGui:GetChildren() do
		-- TopbarPlus keeps hidden clones above the screen and Roblox-sized (36 px) buttons on purpose.
		if not gui:IsA("ScreenGui") or not gui.Enabled or gui.Name:match("^Topbar") then
			continue
		end
		local panel = gui:FindFirstChild("Panel")
		if panel and panel:IsA("GuiObject") and panel.Visible then
			table.insert(open, gui.Name)
		end
		local inset = gui.AbsolutePosition
		for _, object in gui:GetDescendants() do
			if not object:IsA("GuiObject") or not visible(object) then
				continue
			end
			local p, s = object.AbsolutePosition + inset, object.AbsoluteSize
			if s.X < 1 or s.Y < 1 then
				continue
			end
			local isText = (object:IsA("TextLabel") or object:IsA("TextButton"))
				and object.Text ~= ""
				and object.TextTransparency < 0.95
			local drawn = object.BackgroundTransparency < 1
				or (object:IsA("ImageLabel") or object:IsA("ImageButton")) and object.ImageTransparency < 1
				or isText
			local x1, y1, x2, y2 = drawnRect(object, p, s)
			if x2 - x1 < 1 or y2 - y1 < 1 then
				continue -- clipped away entirely
			end
			local path = object:GetFullName():gsub("^.-PlayerGui%.", "")
			if drawn and (x1 < -2 or y1 < -2 - inset.Y or x2 > viewport.X + 2 or y2 > viewport.Y + 2) then
				table.insert(out, string.format("OFF %s [%d,%d..%d,%d]", path, x1, y1, x2, y2))
			end
			if object:IsA("GuiButton") and object.Active then
				if (s.X < 36 or s.Y < 36) and drawn then
					table.insert(out, string.format("SMALL %s %dx%d", path, s.X, s.Y))
				end
				table.insert(buttons, { Path = path, Gui = gui, P = p, S = s })
			end
			if isText then
				-- TextFit ends text it can't fit with "…" (TextFits is true again by then).
				if not object.TextFits or object:GetAttribute("TextFitCut") then
					table.insert(out, "TEXT " .. path .. " '" .. object.Text:sub(1, 24) .. "'")
				end
				local lines = select(2, object.ContentText:gsub("\n", "")) + 1
				local px = object.TextBounds.Y / lines
				if px > 0 and px < 9.5 then
					table.insert(out, string.format("TINY %s %.1fpx '%s'", path, px, object.ContentText:sub(1, 20)))
				end
				local tx1, ty1, tx2, ty2 = textRect(object, p, s)
				table.insert(texts, {
					Object = object,
					Path = path,
					Rect = { math.max(tx1, x1), math.max(ty1, y1), math.min(tx2, x2), math.min(ty2, y2) },
				})
			end
		end
	end
	for i, a in buttons do
		for j = i + 1, #buttons do
			local b = buttons[j]
			if a.Gui ~= b.Gui then
				local x = math.min(a.P.X + a.S.X, b.P.X + b.S.X) - math.max(a.P.X, b.P.X)
				local y = math.min(a.P.Y + a.S.Y, b.P.Y + b.S.Y) - math.max(a.P.Y, b.P.Y)
				if x > 4 and y > 4 then
					table.insert(out, "OVERLAP " .. a.Path .. " <> " .. b.Path)
				end
			end
		end
	end
	-- Text drawn over other text (a shadow copy with the same words in the same place is fine).
	for i, a in texts do
		for j = i + 1, #texts do
			local b = texts[j]
			if a.Object:IsAncestorOf(b.Object) or b.Object:IsAncestorOf(a.Object) then
				continue
			end
			local ra, rb = a.Rect, b.Rect
			local w = math.min(ra[3], rb[3]) - math.max(ra[1], rb[1])
			local h = math.min(ra[4], rb[4]) - math.max(ra[2], rb[2])
			local copy = a.Object.Text == b.Object.Text and math.abs(ra[1] - rb[1]) < 6 and math.abs(ra[2] - rb[2]) < 6
			if w > 3 and h > 3 and not copy then
				table.insert(out, string.format("TEXT-OVERLAP %s <> %s (%dx%d)", a.Path, b.Path, w, h))
			end
		end
	end
	if #open > 1 then
		table.insert(out, "TWO-OPEN " .. table.concat(open, ", "))
	end
	table.insert(out, "open: " .. table.concat(open, ", "))
	return table.concat(out, "\n")
end

local dev = Instance.new("BindableFunction")
dev.Name = "UIAuditDev"
dev.OnInvoke = function(command, arg)
	if command == "Scan" then
		return scan()
	end
	local lobby, topbar = controller("LobbyController"), controller("TopbarController")
	if command == "Close" then
		if lobby then
			lobby:Close()
		end
		if topbar then
			topbar:CloseMenu()
		end
		local match = player.PlayerScripts:FindFirstChild("MatchClientDev")
		if match then
			match:Invoke("DismissResults")
		end
		return true
	end
	if command == "Open" then
		if TOPBAR[arg] and topbar then
			if lobby then
				lobby:Close()
			end
			topbar:OpenScreen(TOPBAR[arg])
		elseif arg == "Roll" or arg == "Queue" or arg == "Results" then
			player.PlayerScripts.LobbyClientDev:Invoke("PreviewMatch", arg)
		elseif lobby then
			lobby:Open(arg)
		end
		return true
	end
	return false
end
dev.Parent = player:WaitForChild("PlayerScripts")
