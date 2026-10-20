-- Cosmetic reels only. The server result is pinned at the target; filler cannot award anything.
local Theme = require(script.Parent.Parent.Theme)
local S = require(script.Parent.StainedGlass)
local Reels = {}
local Item = require(script.Parent.ItemPresentation)
local TweenService = game:GetService("TweenService")
local Assets = require(game.ReplicatedStorage.Shared.Config.UIAssets)
local RevealFx = require(script.Parent.RevealFx)
Reels.__index = Reels
-- A soft glow in each tile's rarity colour, so rare items flash by as you watch the reel slow down.
local GLOW_TRANSPARENCY = { [0] = 0.8, [1] = 0.6, [2] = 0.45, [3] = 0.3, [4] = 0.2 }
local function rarityGlow(cell, rarity)
	local glow = cell:FindFirstChild("RarityGlow")
	if not glow then
		glow = Instance.new("ImageLabel")
		glow.Name, glow.BackgroundTransparency = "RarityGlow", 1
		glow.Image = Assets["screens/playtime_rewards/glow"] or ""
		glow.AnchorPoint, glow.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.42)
		glow.Size = UDim2.fromScale(0.95, 0.75)
		local portrait = cell:FindFirstChild("Portrait")
		glow.ZIndex = if portrait then portrait.ZIndex - 1 else 1
		glow.Parent = cell
	end
	glow.ImageColor3 = RevealFx.color(rarity)
	glow.ImageTransparency = GLOW_TRANSPARENCY[RevealFx.tier(rarity)] or 0.8
end

function Reels.new(content, results, odds, category)
	local self =
		setmetatable({ Rows = {}, Content = content, Random = Random.new(), Category = category or "Glassies" }, Reels)
	local multi = #results > 1
	local pool, total = {}, 0
	for _, entry in odds or {} do
		if entry.Chance > 0 then
			total += entry.Chance
			table.insert(pool, { Id = entry.Id, Ceiling = total })
		end
	end
	local function filler()
		local draw = self.Random:NextNumber() * total
		for _, entry in pool do
			if draw < entry.Ceiling then
				return entry.Id
			end
		end
		return results[1].Id
	end
	for i, result in results do
		local frame = content.Templates.Reel:Clone()
		frame.Name, frame.Visible = "Reel" .. i, true
		if multi then
			frame.Size = UDim2.fromScale(0.485, 0.181)
			frame.Position = UDim2.fromScale((i - 1) % 2 * 0.515, math.floor((i - 1) / 2) * 0.204)
		else
			frame.Size, frame.Position = UDim2.fromScale(0.96, 0.64), UDim2.fromScale(0.02, 0.18)
		end
		frame.Parent = content.Reels
		local target = Theme.Kiln.ReelSteps + i
		local row = { Frame = frame, Target = target, Cells = {}, Stream = {}, LastTick = 0, Result = result }
		for n = 1, target + 5 do
			row.Stream[n] = filler()
		end
		row.Stream[target] = result.Id
		row.Stride = if multi then 0.32 else 0.22
		row.Radius = if multi then 2 else 3
		for n = 1, row.Radius * 2 + 1 do
			local cell = content.Templates.ReelCell:Clone()
			cell.Name, cell.Visible = "Cell" .. n, true
			cell.Size, cell.Parent = UDim2.fromScale(row.Stride * 0.93, 0.96), frame.Track
			if multi then
				cell.NameLabel.Visible = false
				cell.Portrait.Size, cell.Portrait.Position = UDim2.fromScale(0.9, 0.86), UDim2.fromScale(0.5, 0.46)
			end
			table.insert(row.Cells, cell)
		end
		table.insert(self.Rows, row)
	end
	S.bindSlices(content.Reels)
	self:Step(0)
	return self
end

function Reels:Step(time)
	local ticked, finished = false, true
	for i, row in self.Rows do
		local duration = Theme.Kiln.SpinSeconds + (i - 1) * Theme.Kiln.ReelStagger
		local t = math.clamp(time / duration, 0, 1)
		local offset = 5 + (row.Target - 5) * (1 - (1 - t) ^ 4)
		local nearest = math.floor(offset + 0.5)
		if nearest ~= row.LastTick then
			ticked, row.LastTick = true, nearest
		end
		for n, cell in row.Cells do
			-- Ring-buffer slots retain their portraits while passing through the viewport.
			-- Only the card entering from the right needs a new model, even with ten reels.
			local first = math.floor(offset) - row.Radius
			local index = first + (n - 1 - (first - 1) % #row.Cells) % #row.Cells
			local id = row.Stream[index]
			cell.Visible = id ~= nil
			cell.Position = UDim2.fromScale(0.5 + (index - offset) * row.Stride, 0.5)
			if id and cell:GetAttribute("GlassyId") ~= id then
				cell:SetAttribute("GlassyId", id)
				local def = Item.definition(self.Category, id)
				Item.portrait(cell, self.Category, id)
				cell.NameLabel.Text = def.Name
				cell.RarityBand.BackgroundColor3 = Theme.Rarity[def.Rarity].Bottom
				rarityGlow(cell, def.Rarity)
			end
		end
		if t == 1 then
			if not row.Landed then
				-- The winning tile pops and glows; the others step back.
				row.Landed = true
				for _, cell in row.Cells do
					local selected = cell:GetAttribute("GlassyId") == row.Result.Id
						and math.abs(cell.Position.X.Scale - 0.5) < row.Stride / 2
					if selected then
						local scale = cell:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
						scale.Parent, scale.Scale = cell, 1.18
						TweenService
							:Create(scale, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
								Scale = 1.08,
							})
							:Play()
						local glow = cell:FindFirstChild("RarityGlow")
						if glow then
							glow.ImageTransparency = 0.05
						end
					else
						cell.ZIndex = math.max(0, cell.ZIndex - 1)
						for _, d in cell:GetDescendants() do
							if d:IsA("ImageLabel") then
								d.ImageTransparency = math.max(d.ImageTransparency, 0.55)
							elseif d:IsA("TextLabel") then
								d.TextTransparency = math.max(d.TextTransparency, 0.55)
							elseif d:IsA("ViewportFrame") then
								d.ImageTransparency = 0.55
							end
						end
					end
				end
			end
			row.Frame:SetAttribute("SelectedId", row.Stream[row.Target])
			local def = Item.definition(self.Category, row.Result.Id)
			row.Frame.Marker.BackgroundColor3 = Theme.Rarity[def.Rarity].Top
			local pulse = math.clamp((time - duration) / 0.32, 0, 1)
			row.Frame.Marker.Size = UDim2.fromScale(0.008 + math.sin(pulse * math.pi) * 0.006, 1)
		else
			finished = false
		end
	end
	return finished, ticked
end

function Reels:Destroy()
	for _, row in self.Rows do
		row.Frame:Destroy()
	end
	table.clear(self.Rows)
end
return Reels
