-- Client-mode layout fixture; does not pull, pick, claim or grant anything.
local player = game:GetService("Players").LocalPlayer
assert(not player.PlayerGui:GetAttribute("InMatch"), "Finish the active match first")
local simulator = game:GetService("StudioDeviceSimulatorService")
local dev = player.PlayerScripts:WaitForChild("LobbyClientDev")
local report = {}
local function inspect(label)
	local record = { Screen = label, Buttons = 0, Problems = {} }
	for _, gui in player.PlayerGui:GetChildren() do
		if gui:IsA("ScreenGui") and gui.Enabled and gui:GetAttribute("TemplateBacked") then
			for _, item in gui:GetDescendants() do
				if item:IsA("GuiButton") then
					local visible, scrolled, parent = item.Visible, false, item.Parent
					while parent and parent ~= gui do
						if parent:IsA("GuiObject") then
							visible = visible and parent.Visible
						end
						scrolled = scrolled or parent:IsA("ScrollingFrame")
						parent = parent.Parent
					end
					if visible then
						record.Buttons += 1
						local p, size = item.AbsolutePosition - gui.AbsolutePosition, item.AbsoluteSize
						if (item.Name == "Info" and item.Parent.Name:match("^Card%d")) or item.Name == "Reroll" then
							local localPosition = item.AbsolutePosition - item.Parent.AbsolutePosition
							local cardSize = item.Parent.AbsoluteSize
							if
								localPosition.X < -1
								or localPosition.Y < -1
								or localPosition.X + size.X > cardSize.X + 1
								or localPosition.Y + size.Y > cardSize.Y + 1
							then
								table.insert(record.Problems, "Outside card: " .. item:GetFullName())
							end
						end
						if size.X < 43.9 or size.Y < 43.9 then
							table.insert(record.Problems, "Small: " .. item:GetFullName() .. " " .. tostring(size))
						end
						if
							not scrolled
							and (
								p.X < -1
								or p.Y < -1
								or p.X + size.X > gui.AbsoluteSize.X + 1
								or p.Y + size.Y > gui.AbsoluteSize.Y + 1
							)
						then
							table.insert(record.Problems, "Outside safe screen: " .. item:GetFullName())
						end
					end
				end
			end
		end
	end
	return record
end
local ok, err = xpcall(function()
	for _, id in { "samsung_galaxy_a06", "iphone_17_pro", "ipad_pro_M5_13in" } do
		dev:Invoke("Close")
		simulator:SetDeviceAsync(id)
		task.wait(0.2)
		simulator:SetOrientationAsync(Enum.ScreenOrientation.LandscapeLeft)
		task.wait(0.3)
		local record = { Device = id, Viewport = tostring(workspace.CurrentCamera.ViewportSize), Screens = {} }
		table.insert(record.Screens, inspect("Lobby"))
		for _, kind in { "Glassies", "Index", "Kiln", "Rewards" } do
			dev:Invoke("Open", kind)
			task.wait(0.4)
			table.insert(record.Screens, inspect(kind))
			if kind == "Glassies" then
				dev:Invoke("Detail", "pop")
				task.wait(0.3)
				table.insert(record.Screens, inspect("Detail"))
			elseif kind == "Rewards" then
				for _, tab in { "Gifts", "Streak", "Codes" } do
					dev:Invoke("RewardsTab", tab)
					task.wait(0.2)
					table.insert(record.Screens, inspect(tab))
				end
			end
		end
		for _, kind in { "Queue", "Roll", "Results" } do
			dev:Invoke("PreviewMatch", kind)
			task.wait(0.2)
			table.insert(record.Screens, inspect(kind))
		end
		dev:Invoke("PreviewKiln")
		task.wait(0.7)
		table.insert(record.Screens, inspect("Reveal"))
		table.insert(report, record)
	end
end, debug.traceback)
dev:Invoke("Close")
simulator:StopSimulationAsync()
assert(ok, err)
for _, device in report do
	for _, screen in device.Screens do
		assert(
			#screen.Problems == 0,
			device.Device .. " / " .. screen.Screen .. ": " .. table.concat(screen.Problems, "; ")
		)
	end
end
return report
