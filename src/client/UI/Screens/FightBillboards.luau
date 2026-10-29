local RS = game:GetService("ReplicatedStorage")
local Glassies = require(RS.Shared.Config.Glassies)
local S = require(script.Parent.Parent.Components.StainedGlass)
local Kit = require(script.Parent.Parent.Components.MatchKit)
local Theme = require(script.Parent.Parent.Theme)
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Feel = require(RS.Shared.Config.Balance).Feel
local Billboards = {}
-- Stable screen panels keep HP/hearts readable while the glassies swing in 3D.
function Billboards.new(data, parent)
	local list = {}
	for side, setup in { data.A, data.B } do
		local d = Glassies.get(setup.Id)
		local gui = Instance.new("Frame")
		gui.Name, gui.BackgroundTransparency = "FightPlayer" .. side, 1
		gui.Size = UDim2.fromScale(Feel.FightPanelWidth, Feel.FightPanelHeight)
		gui.AnchorPoint = Vector2.new(if side == 1 then 0 else 1, 0)
		gui.Position =
			UDim2.fromScale(if side == 1 then Feel.FightPanelInset else 1 - Feel.FightPanelInset, Feel.FightPanelTop)
		gui.Parent = parent
		local body = RS.Assets.UI.FightBillboard.Body:Clone()
		body.Parent = gui
		body.OwnerName.Text = data.Names and data.Names[side] or (if side == 1 then "YOU" else "BOT")
		body.OwnerName.TextColor3 = Theme.Sides[side]
		-- The world tag's aspect constraint shrank long names to "Crystal..." on phone screens.
		local tag = body.GlassyTag
		local aspect = tag:FindFirstChildOfClass("UIAspectRatioConstraint")
		if aspect then
			aspect:Destroy()
		end
		S.tag(body.GlassyTag, d.Name, S.Types[d.Type])
		local amount = body:FindFirstChild("HpAmount")
		if amount then
			amount.FontFace, amount.TextColor3 = Theme.Fonts.Body, Theme.Palette.milkLight
			Kit.outline(amount, 1.5)
		end
		local track = Instance.new("Frame")
		track.Name, track.BorderSizePixel, track.BackgroundTransparency = "HpTrack", 0, 0.25
		track.BackgroundColor3 = Theme.Colors.Shadow
		track.Size = UDim2.fromScale(body.GlassyTag.Size.X.Scale, Feel.FightHpBarHeight)
		track.Position = UDim2.fromScale(body.GlassyTag.Position.X.Scale, Feel.FightHpBarY)
		track.Parent = body
		local fill = Instance.new("Frame")
		fill.Name, fill.BorderSizePixel, fill.Size = "Fill", 0, UDim2.fromScale(1, 1)
		fill.BackgroundColor3, fill.Parent = Theme.Sides[side], track
		S.bindSlices(gui)
		list[side] = { Gui = gui, Fill = fill, Max = data.MaxHearts }
	end
	return list
end
function Billboards.update(list, hearts, hp, maxima)
	for side, item in list do
		local count = hearts[side]
		if item.Hearts and count < item.Hearts then
			for i = count + 1, item.Hearts do
				local original = item.Gui.Body.Hearts["Heart" .. i]
				local pop = original:Clone()
				local body = item.Gui.Body
				pop.Name, pop.AnchorPoint = "LostHeart", Vector2.new(0.5, 0.5)
				pop.Position = UDim2.fromScale(
					(original.AbsolutePosition.X - body.AbsolutePosition.X + original.AbsoluteSize.X / 2)
						/ math.max(1, body.AbsoluteSize.X),
					(original.AbsolutePosition.Y - body.AbsolutePosition.Y + original.AbsoluteSize.Y / 2)
						/ math.max(1, body.AbsoluteSize.Y)
				)
				pop.Size = UDim2.fromScale(
					original.AbsoluteSize.X / math.max(1, body.AbsoluteSize.X),
					original.AbsoluteSize.Y / math.max(1, body.AbsoluteSize.Y)
				)
				pop.ZIndex, pop.Parent = 10, body
				TweenService:Create(pop, TweenInfo.new(Feel.HeartTweenSeconds, Enum.EasingStyle.Back), {
					Size = UDim2.fromScale(pop.Size.X.Scale * 1.7, pop.Size.Y.Scale * 1.7),
					Position = pop.Position - UDim2.fromScale(0, 0.25),
					ImageTransparency = 1,
					Rotation = 25,
				}):Play()
				Debris:AddItem(pop, Feel.HeartTweenSeconds)
			end
		end
		S.hearts(item.Gui.Body.Hearts, hearts[side], item.Max)
		item.Hearts = count
		local amount = item.Gui.Body:FindFirstChild("HpAmount")
		if amount and hp then
			amount.Text = string.format("%d / %d HP", math.ceil(math.max(0, hp[side])), math.ceil(maxima[side]))
			item.Fill.Size = UDim2.fromScale(math.clamp(hp[side] / math.max(1, maxima[side]), 0, 1), 1)
		end
		if item.Head and item.Head.Parent then
			item.Anchor.Position = item.Head.Position + item.Offset
		end
	end
end
function Billboards.destroy(list)
	for _, item in list do
		item.Gui:Destroy()
		if item.Anchor then
			item.Anchor:Destroy()
		end
	end
end
return Billboards
