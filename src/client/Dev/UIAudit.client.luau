-- Studio-only UI audit hook for device checks (Studio device simulator + screen_capture).
-- PlayerScripts.UIAuditDev:Invoke(command, arg):
--   "Open", name   opens a screen: Kiln, Glassies, Profile, Settings, Daily, Playtime, Codes, Roll, Queue, Results
--   "Close"        closes lobby panels and top bar screens
--   "Scan"         lists visible GuiObjects that leave the screen, interactive ones under 36 px, and buttons that
--                  overlap other visible buttons in another window
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

local function scan()
	local camera = workspace.CurrentCamera
	local viewport = camera.ViewportSize
	local out = { string.format("viewport %dx%d", viewport.X, viewport.Y) }
	local buttons = {}
	for _, gui in player.PlayerGui:GetChildren() do
		if not gui:IsA("ScreenGui") or not gui.Enabled then
			continue
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
			local transparent = object.BackgroundTransparency >= 1
				and (not object:IsA("ImageLabel") and not object:IsA("ImageButton") or object.ImageTransparency >= 1)
				and (not object:IsA("TextLabel") and not object:IsA("TextButton") or object.TextTransparency >= 1)
			local path = object:GetFullName():gsub("^.-PlayerGui%.", "")
			if
				not transparent and (p.X < -2 or p.Y < -2 or p.X + s.X > viewport.X + 2 or p.Y + s.Y > viewport.Y + 2)
			then
				-- Clipped by a scrolling frame is fine.
				if not object:FindFirstAncestorWhichIsA("ScrollingFrame") then
					table.insert(out, string.format("OFF %s [%d,%d %dx%d]", path, p.X, p.Y, s.X, s.Y))
				end
			end
			if object:IsA("GuiButton") and object.Active then
				if (s.X < 36 or s.Y < 36) and not transparent then
					table.insert(out, string.format("SMALL %s %dx%d", path, s.X, s.Y))
				end
				table.insert(buttons, { Path = path, Gui = gui, P = p, S = s })
			end
			if
				(object:IsA("TextLabel") or object:IsA("TextButton"))
				and object.Text ~= ""
				and object.TextTransparency < 1
				and not object.TextFits
			then
				table.insert(out, "TEXT " .. path .. " '" .. object.Text:sub(1, 24) .. "'")
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
