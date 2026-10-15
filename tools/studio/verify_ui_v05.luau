-- Structural audit; run in Edit or Client after opening the screen under test.
local RunService = game:GetService("RunService")
local root = if RunService:IsRunning() and RunService:IsClient()
	then game.Players.LocalPlayer.PlayerGui
	else game.StarterGui
local names = { "LobbyHUD", "CollectionScreen", "KilnScreen", "RollScreen", "FightHud" }
local result = { Screens = 0, Objects = 0, Images = 0, Missing = {}, Failures = {} }
for _, name in names do
	local gui = assert(root:FindFirstChild(name), "Missing template " .. name)
	result.Screens += 1
	assert(gui.ScreenInsets == Enum.ScreenInsets.CoreUISafeInsets, name .. " safe inset")
	for _, o in gui:GetDescendants() do
		if o:IsA("UICorner") then
			table.insert(result.Failures, o:GetFullName() .. " rounded corner")
		end
		if o:IsA("GuiObject") then
			result.Objects += 1
			if o.Size.X.Offset ~= 0 or o.Size.Y.Offset ~= 0 or o.Position.X.Offset ~= 0 or o.Position.Y.Offset ~= 0 then
				table.insert(result.Failures, o:GetFullName() .. " layout offset")
			end
		end
		if o:IsA("ImageLabel") and o:GetAttribute("AssetPath") then
			result.Images += 1
			if
				o.Image == ""
				or (not o:FindFirstChildOfClass("UIAspectRatioConstraint") and not o:GetAttribute("StretchArtwork"))
			then
				table.insert(result.Failures, o:GetFullName() .. " image/ratio")
			end
		end
		if o:GetAttribute("MissingAsset") then
			table.insert(result.Missing, o:GetAttribute("MissingAsset"))
		end
		if o:IsA("GuiButton") and o.Selectable then
			local minimum = o:FindFirstChildOfClass("UISizeConstraint")
			if not minimum or minimum.MinSize.X < 44 or minimum.MinSize.Y < 44 then
				table.insert(result.Failures, o:GetFullName() .. " tap minimum")
			end
		end
		if
			gui.Enabled
			and o:IsA("TextLabel")
			and not o:FindFirstAncestor("Templates")
			and o.Text ~= ""
			and not o.TextFits
		then
			table.insert(result.Failures, o:GetFullName() .. " text does not fit")
		end
	end
end
assert(#result.Failures == 0, table.concat(result.Failures, "\n"))
assert(#result.Missing == 0, table.concat(result.Missing, "\n"))
return result
