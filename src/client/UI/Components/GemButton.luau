-- Reuse the game's editable cut-glass button artwork and interaction treatment.
local S = require(script.Parent.StainedGlass)
local Motion = require(script.Parent.Motion)
local Gem = {}
function Gem.new(parent, name, text, variant, size, position)
	local button = parent:FindFirstChild(name)
	if button and not button:FindFirstChild("Artwork") then
		-- A flat button from an older template: replace it with the cut-glass one.
		button:Destroy()
		button = nil
	end
	if not button then
		button = game.StarterGui.KilnScreen.Panel.Content.GlassiesPage.CoinKiln.Pull1:Clone()
		button.Name = name
		button.Size = size
		button.AnchorPoint = Vector2.zero
		button.Position = position
		button.Parent = parent
	end
	local tint = ({ Yellow = "amber", Blue = "sapphire", Green = "emerald", Purple = "amethyst", Red = "ruby" })[variant]
		or "aqua"
	S.setAsset(button.Artwork, "button/gem_" .. tint)
	button.Active, button.Selectable, button.Visible = true, true, true
	button.Label.Text, button.Label.TextTransparency = text, 0
	button.Label:SetAttribute("FitSingleLine", false)
	button.Label.TextScaled, button.Label.TextWrapped = true, true
	button.Label.UITextSizeConstraint.MaxTextSize = 28
	for _, object in { button, button.Artwork } do
		local aspect = object:FindFirstChildOfClass("UIAspectRatioConstraint")
		if aspect then
			aspect:Destroy()
		end
	end
	Motion.button(button)
	S.bindSlices(button)
	return button
end
return Gem
