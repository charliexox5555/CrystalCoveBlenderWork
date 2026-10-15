local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Glassies = require(RS.Shared.Config.Glassies)
local S = require(script.Parent.Parent.Components.StainedGlass)
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
		local player = data.PlayerIds and Players:GetPlayerByUserId(data.PlayerIds[side])
		local head = player and player.Character and player.Character:FindFirstChild("Head")
		local position = if head
			then head.Position
			else (
				data.HeartPositions and data.HeartPositions[side]
				or data.HookPositions and data.HookPositions[side]
				or Vector3.zero
			) + Vector3.yAxis * 3
		local center = if data.HookPositions then (data.HookPositions[1] + data.HookPositions[2]) / 2 else position
		local toward = Vector3.new(center.X - position.X, 0, center.Z - position.Z)
		local offset = if toward.Magnitude > 0.01 then toward.Unit * 1.75 else Vector3.zero
		local anchor = Instance.new("Part")
		anchor.Name = "FightBillboardAnchor" .. side
		anchor.Anchored, anchor.CanCollide, anchor.CanTouch, anchor.CanQuery, anchor.Transparency =
			true, false, false, false, 1
		anchor.Position, anchor.Parent = position + offset, workspace
		gui.Adornee, gui.Enabled, gui.Parent = anchor, true, Players.LocalPlayer.PlayerGui
		S.bindSlices(gui)
		list[side] = { Gui = gui, Anchor = anchor, Head = head, Offset = offset }
	end
	return list
end
function Billboards.update(list, hearts)
	for side, item in list do
		S.hearts(item.Gui.Body.Hearts, hearts[side])
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
