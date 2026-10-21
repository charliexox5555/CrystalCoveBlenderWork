local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Glassies = require(RS.Shared.Config.Glassies)
local S = require(script.Parent.Parent.Components.StainedGlass)
local Kit = require(script.Parent.Parent.Components.MatchKit)
local Theme = require(script.Parent.Parent.Theme)
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Feel = require(RS.Shared.Config.Balance).Feel
local Billboards = {}
function Billboards.new(data)
	local list = {}
	for side, setup in { data.A, data.B } do
		local d = Glassies.get(setup.Id)
		local gui = RS.Assets.UI.FightBillboard:Clone()
		gui.Name = "FightPlayer" .. side
		gui.AlwaysOnTop = false
		gui.LightInfluence = 0
		gui.Body.OwnerName.Text = data.Names and data.Names[side] or (if side == 1 then "YOU" else "BOT")
		S.tag(gui.Body.GlassyTag, d.Name, S.Types[d.Type])
		-- The name wears its arena side's colour (matches the queue pad glow); the HP line gets the same ink outline.
		gui.Body.OwnerName.TextColor3 = Theme.Sides[side]
		local amount = gui.Body:FindFirstChild("HpAmount")
		if amount then
			amount.FontFace, amount.TextColor3 = Theme.Fonts.Body, Theme.Palette.milkLight
			Kit.outline(amount, 1.5)
		end
		local player = data.PlayerIds and Players:GetPlayerByUserId(data.PlayerIds[side])
		local head = player and player.Character and player.Character:FindFirstChild("Head")
		local position = if data.AvatarPositions
			then data.AvatarPositions[side] + Vector3.yAxis * 2
			elseif head then head.Position
			else (
				data.HeartPositions and data.HeartPositions[side]
				or data.HookPositions and data.HookPositions[side]
				or Vector3.zero
			) + Vector3.yAxis * 3
		local offset = Vector3.zero
		local anchor = Instance.new("Part")
		anchor.Name = "FightBillboardAnchor" .. side
		anchor.Anchored, anchor.CanCollide, anchor.CanTouch, anchor.CanQuery, anchor.Transparency =
			true, false, false, false, 1
		anchor.Position, anchor.Parent = position + offset, workspace
		gui.Adornee, gui.Enabled, gui.Parent = anchor, true, Players.LocalPlayer.PlayerGui
		S.bindSlices(gui)
		list[side] = { Gui = gui, Anchor = anchor, Head = head, Offset = offset, Max = data.MaxHearts }
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
