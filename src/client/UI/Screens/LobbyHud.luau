local Theme = require(script.Parent.Parent.Theme)
local U = require(script.Parent.Parent.Components.Util)
local Panel = require(script.Parent.Parent.Components.Panel)
local Button = require(script.Parent.Parent.Components.Button)
local Hud = {}
function Hud.new(open)
	local gui = U.screen("LobbyHUD", 5)
	local money = Panel.new(gui, "Currency", UDim2.fromScale(0.3, 0.08), UDim2.fromScale(0.68, 0.015), true)
	local currency = U.text(
		money,
		"Balances",
		"COINS 0 • TROPHIES 0",
		UDim2.fromScale(0.94, 1),
		UDim2.fromScale(0.03, 0),
		Theme.Fonts.Body
	)
	local nav = U.make(
		"Frame",
		gui,
		{
			Name = "Navigation",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(0.17, 0.48),
			Position = UDim2.fromScale(0.02, 0.16),
		}
	)
	local connections = {}
	for i, kind in { "Kiln", "Glassies", "Index" } do
		local button =
			Button.new(nav, kind, kind:upper(), "Blue", UDim2.fromScale(1, 0.29), UDim2.fromScale(0, (i - 1) * 0.35))
		U.make("UISizeConstraint", button, { MinSize = Vector2.new(44, 44) })
		table.insert(
			connections,
			button.Activated:Connect(function()
				open(kind)
			end)
		)
	end
	local hint = U.text(
		gui,
		"Hint",
		"Step on a glowing pad to clash!",
		UDim2.fromScale(0.4, 0.06),
		UDim2.fromScale(0.3, 0.11),
		Theme.Fonts.Caption
	)
	return { Gui = gui, Currency = currency, Hint = hint, Connections = connections }
end
return Hud
