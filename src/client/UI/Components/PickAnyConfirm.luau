-- "Use this glassy?" dialog for the Pick Any list: portrait, name, Marble cost and Yes / No.
-- Nothing is sent until the player presses Yes.
local RS = game:GetService("ReplicatedStorage")
local Glassies = require(RS.Shared.Config.Glassies)
local Theme = require(script.Parent.Parent.Theme)
local S = require(script.Parent.StainedGlass)
local Kit = require(script.Parent.MatchKit)
local Portrait = require(script.Parent.GlassyPortrait)
local Confirm = {}
Confirm.__index = Confirm

-- options: Id, Cost (0 = free), Marbles (wallet), OnYes(), OnNo()
function Confirm.new(options)
	local self = setmetatable({ Closed = false }, Confirm)
	local def = Glassies.get(options.Id)
	self.Gui = Kit.gui("PickAnyConfirm", 30)
	-- Invisible blocker: taps outside the dialog do nothing, and there is no dark backdrop.
	local block = Instance.new("TextButton")
	block.Name, block.Size, block.BackgroundTransparency, block.Text = "Block", UDim2.fromScale(1, 1), 1, ""
	block.AutoButtonColor, block.Active, block.Parent = false, true, self.Gui
	local panel = Instance.new("ImageLabel")
	panel.Name, panel.AnchorPoint, panel.Position = "Panel", Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
	panel.Size, panel.BackgroundTransparency, panel.Parent = UDim2.fromScale(0.44, 0.78), 1, self.Gui
	S.setAsset(panel, "panel/pane_dark")
	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.AspectRatio, ratio.Parent = 1.2, panel
	self.Panel = panel
	Kit.label(
		panel,
		"Title",
		"USE THIS GLASSY?",
		UDim2.fromScale(0.84, 0.11),
		UDim2.fromScale(0.08, 0.06),
		{ Color = Theme.Palette.amberLight, MaxSize = Theme.TextSize.Heading }
	)
	local portrait = Portrait.new(panel, options.Id, UDim2.fromScale(0.3, 0.3), UDim2.fromScale(0.35, 0.18))
	S.aspect(portrait, 1)
	Portrait.fitOnResize(portrait)
	Kit.label(
		panel,
		"GlassyName",
		def.Name,
		UDim2.fromScale(0.84, 0.1),
		UDim2.fromScale(0.08, 0.5),
		{ MaxSize = Theme.TextSize.Heading + 6 }
	)
	local cost = options.Cost or 0
	local line = Kit.marbleLine(panel, "Cost", UDim2.fromScale(0.84, 0.1), UDim2.fromScale(0.08, 0.6))
	line:Set(
		if cost > 0 then "Costs {M}" .. cost .. " Marbles" else "FREE this match!",
		if cost > 0 then Theme.Palette.milkLight else Theme.Palette.emeraldLight
	)
	if cost > 0 then
		local wallet = Kit.marbleLine(panel, "Wallet", UDim2.fromScale(0.84, 0.07), UDim2.fromScale(0.08, 0.705))
		wallet:Set("You have {M}" .. (options.Marbles or 0), Theme.Palette.milkDark)
	end
	local yes = Kit.gem(panel, "Yes", "YES", "emerald", UDim2.fromScale(0.4, 0.17), UDim2.fromScale(0.28, 0.87))
	local no = Kit.gem(panel, "No", "NO", "ruby", UDim2.fromScale(0.4, 0.17), UDim2.fromScale(0.72, 0.87))
	self.Connections = {
		yes.Activated:Connect(function()
			self:Finish(options.OnYes)
		end),
		no.Activated:Connect(function()
			self:Finish(options.OnNo)
		end),
	}
	Kit.popIn(panel)
	return self
end

function Confirm:Finish(callback)
	if self.Closed then
		return
	end
	self:Close()
	if callback then
		callback()
	end
end

function Confirm:Close()
	if self.Closed then
		return
	end
	self.Closed = true
	for _, connection in self.Connections do
		connection:Disconnect()
	end
	local gui = self.Gui
	gui.Name = "PickAnyConfirm_Closing"
	gui.Block.Active = false
	Kit.popOut(self.Panel, function()
		gui:Destroy()
	end)
end

return Confirm
