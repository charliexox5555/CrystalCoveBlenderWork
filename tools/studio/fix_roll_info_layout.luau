-- One-time safe migration of the original placeholder roll-card info/footer controls.
-- Does not move controls whose authored placement differs from the original builder.
local roll = game.StarterGui:FindFirstChild("RollScreen")
local changed = 0
for _, item in roll and roll:GetDescendants() or {} do
	if
		item:IsA("TextButton")
		and item.Name == "Info"
		and item.Position == UDim2.fromScale(0.79, 0.01)
		and item.AnchorPoint == Vector2.zero
	then
		item.AnchorPoint = Vector2.new(1, 0)
		item.Position = UDim2.fromScale(0.98, 0.02)
		local constraint = item:FindFirstChildOfClass("UISizeConstraint")
		if constraint then
			constraint.MinSize, constraint.MaxSize = Vector2.new(44, 44), Vector2.new(56, 56)
		end
		changed += 1
	end
end
local panel = roll and roll:FindFirstChild("Roll")
if panel then
	local cards, message, reroll =
		panel:FindFirstChild("Cards"), panel:FindFirstChild("Message"), panel:FindFirstChild("Reroll")
	if cards and cards.Size == UDim2.fromScale(0.94, 0.53) then
		cards.Size = UDim2.fromScale(0.94, 0.47)
		changed += 1
	end
	if message and message.Position == UDim2.fromScale(0.25, 0.78) then
		message.Position, message.Size = UDim2.fromScale(0.25, 0.73), UDim2.fromScale(0.5, 0.07)
		changed += 1
	end
	if reroll and reroll.Position == UDim2.fromScale(0.325, 0.87) and reroll.AnchorPoint == Vector2.zero then
		reroll.Position, reroll.AnchorPoint = UDim2.fromScale(0.325, 0.98), Vector2.new(0, 1)
		changed += 1
	end
end
return { Changed = changed }
