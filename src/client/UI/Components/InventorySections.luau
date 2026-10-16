local Sections = {}
function Sections.layout(grid, ownedCount, unownedCount)
	local height, gap = grid:GetAttribute("SectionTileHeight"), grid:GetAttribute("SectionTileGap")
	local header = grid:GetAttribute("SectionHeaderHeight")
	local sectionGap = grid:GetAttribute("SectionGap")
	local function area(count, root)
		local layout = root.UIGridLayout
		local columns = math.max(
			1,
			math.floor(
				(1 + layout.CellPadding.X.Scale) / (layout.CellSize.X.Scale + layout.CellPadding.X.Scale) + 0.001
			)
		)
		local rows = math.ceil(count / columns)
		return if count == 0
			then grid:GetAttribute("SectionEmptyHeight")
			else rows * height + math.max(0, rows - 1) * gap
	end
	local ownedHeight = area(ownedCount, grid.Tiles)
	local unownedHeight = area(unownedCount, grid.UnownedTiles)
	local divider = header + ownedHeight + sectionGap
	local total = math.max(1, divider + header + unownedHeight + grid:GetAttribute("SectionBottomPadding"))
	grid.CanvasSize = UDim2.fromScale(0, total)
	for _, entry in
		{
			{ "Owned", grid.Tiles, ownedCount, 0, ownedHeight },
			{ "Unowned", grid.UnownedTiles, unownedCount, divider, unownedHeight },
		}
	do
		local name, root, count, y, sectionHeight = table.unpack(entry)
		local title = grid[name .. "Header"]
		title.Position, title.Size = UDim2.fromScale(0, y / total), UDim2.fromScale(1, header / total)
		title.Label.Text = name:upper() .. "  ·  " .. count
		root.Position, root.Size = UDim2.fromScale(0, (y + header) / total), UDim2.fromScale(1, sectionHeight / total)
		local layout = root.UIGridLayout
		layout.CellSize = UDim2.fromScale(layout.CellSize.X.Scale, height / sectionHeight)
		layout.CellPadding = UDim2.fromScale(layout.CellPadding.X.Scale, gap / sectionHeight)
		root.Visible = count > 0
		local empty = grid[name .. "Empty"]
		empty.Visible = count == 0
		empty.Position, empty.Size = root.Position, root.Size
	end
	grid:SetAttribute("OwnedCount", ownedCount)
	grid:SetAttribute("UnownedCount", unownedCount)
end
return Sections
