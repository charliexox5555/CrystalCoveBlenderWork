-- Workstream J: give the editable StarterGui templates the same text-fit policy the runtime uses
-- (UI/Components/TextFit + Theme.TextFit). Run in Studio EDIT mode through the MCP (execute_luau, Edit),
-- then save/publish the place. Reversible: every changed object keeps its original values in the
-- attribute "TextFitBackup" (JSON); run with MODE = "restore" to put them back exactly.
--   MODE = "apply"   -- fit every template text object (idempotent; backs up only once)
--   MODE = "restore" -- undo everything this script changed
--   MODE = "dry"     -- report what "apply" would change
-- Policy per text object (not AutomaticSize, not FitSingleLine, not TextFit=false):
--   * fixed-size text becomes TextScaled with UITextSizeConstraint MaxTextSize = its old TextSize;
--   * MinTextSize below 10 px is raised to 10 (never above what the box holds); the runtime guard
--     (UI/Components/TextFit) applies the full 12 px -> two lines -> 10 px -> "…" policy per screen size;
--   * a label inside cut-glass gem art is pulled inside the gem's inner face (Theme.TextFit.GemInset).
local MODE = ...
MODE = MODE or "dry"
local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")
local MIN, MIN_SMALL, SMALL_BOX = 12, 10, 26 -- px; boxes shorter than SMALL_BOX in the edit viewport are "small"
local GEM = Vector2.new(0.1, 0.17)

local function isText(o)
	return o:IsA("TextLabel") or o:IsA("TextButton") or o:IsA("TextBox")
end

local function snapshot(o)
	local c = o:FindFirstChildOfClass("UITextSizeConstraint")
	return {
		TextScaled = o.TextScaled,
		TextWrapped = o.TextWrapped,
		TextTruncate = o.TextTruncate.Name,
		HadConstraint = c ~= nil,
		MinTextSize = c and c.MinTextSize,
		MaxTextSize = c and c.MaxTextSize,
		Position = { o.Position.X.Scale, o.Position.X.Offset, o.Position.Y.Scale, o.Position.Y.Offset },
		Size = { o.Size.X.Scale, o.Size.X.Offset, o.Size.Y.Scale, o.Size.Y.Offset },
	}
end

local function restore(o)
	local raw = o:GetAttribute("TextFitBackup")
	if not raw then
		return false
	end
	local b = HttpService:JSONDecode(raw)
	o.TextScaled, o.TextWrapped = b.TextScaled, b.TextWrapped
	o.TextTruncate = Enum.TextTruncate[b.TextTruncate]
	o.Position = UDim2.new(b.Position[1], b.Position[2], b.Position[3], b.Position[4])
	o.Size = UDim2.new(b.Size[1], b.Size[2], b.Size[3], b.Size[4])
	local c = o:FindFirstChildOfClass("UITextSizeConstraint")
	if b.HadConstraint and c then
		c.MinTextSize, c.MaxTextSize = b.MinTextSize, b.MaxTextSize
	elseif c and not b.HadConstraint then
		c:Destroy()
	end
	o:SetAttribute("TextFitBackup", nil)
	return true
end

-- The gem art this label sits on, if any (the label is a child of the button that holds Artwork).
local function gemOf(o)
	local parent = o.Parent
	local art = parent and parent:FindFirstChild("Artwork")
	local asset = art and art:GetAttribute("AssetPath")
	return art ~= nil
		and asset ~= nil
		and string.match(asset, "^button/gem") ~= nil
		and art.Size == UDim2.fromScale(1, 1)
end

local changes = {}
local function note(o, what)
	table.insert(changes, o:GetFullName():gsub("^StarterGui%.", "") .. ": " .. what)
end

local function apply(o, dry)
	if
		o.AutomaticSize ~= Enum.AutomaticSize.None
		or o:GetAttribute("FitSingleLine")
		or o:GetAttribute("TextFit") == false
		or o.Text == "" -- invisible hit areas (tile "Open", card "Select" buttons)
	then
		return
	end
	local before = snapshot(o)
	local what = {}
	local h = o.AbsoluteSize.Y
	local floor = if h > 0 and h < SMALL_BOX then MIN_SMALL else MIN
	if h > 0 then
		floor = math.min(floor, math.floor(h)) -- never more than the box holds
	end
	local c = o:FindFirstChildOfClass("UITextSizeConstraint")
	if not o.TextScaled then
		table.insert(what, "TextScaled (max " .. o.TextSize .. ")")
		if not dry then
			if not c then
				c = Instance.new("UITextSizeConstraint")
				c.MaxTextSize = math.max(floor, o.TextSize)
				c.MinTextSize = floor
				c.Parent = o
			end
			o.TextScaled = true
		end
	end
	-- Only lift unreadable floors (1-8 px). The runtime guard (UI/Components/TextFit) handles the rest per
	-- screen size, so the editable templates stay as close to the designer's values as possible.
	floor = math.min(floor, MIN_SMALL)
	if c and c.MinTextSize < floor then
		table.insert(what, "MinTextSize " .. c.MinTextSize .. "->" .. floor)
		if not dry then
			c.MinTextSize = floor
		end
	end
	if gemOf(o) then
		local p, s = o.Position, o.Size
		local x0, y0 = math.max(p.X.Scale, GEM.X), math.max(p.Y.Scale, GEM.Y)
		local x1 = math.min(p.X.Scale + s.X.Scale, 1 - GEM.X)
		local y1 = math.min(p.Y.Scale + s.Y.Scale, 1 - GEM.Y)
		local anchored = o.AnchorPoint == Vector2.zero and p.X.Offset == 0 and p.Y.Offset == 0 and s.X.Offset == 0
		local function off(a, b)
			return math.abs(a - b) > 0.005
		end
		if
			anchored
			and (off(x0, p.X.Scale) or off(y0, p.Y.Scale) or off(x1 - x0, s.X.Scale) or off(y1 - y0, s.Y.Scale))
		then
			table.insert(what, string.format("inside gem (%.2f,%.2f %.2fx%.2f)", x0, y0, x1 - x0, y1 - y0))
			if not dry then
				o.Position, o.Size = UDim2.fromScale(x0, y0), UDim2.fromScale(x1 - x0, y1 - y0)
			end
		end
	end
	if #what > 0 then
		note(o, table.concat(what, ", "))
		if not dry and not o:GetAttribute("TextFitBackup") then
			o:SetAttribute("TextFitBackup", HttpService:JSONEncode(before))
		end
	end
end

local count = 0
for _, gui in StarterGui:GetChildren() do
	if not gui:IsA("LayerCollector") then
		continue
	end
	for _, o in gui:GetDescendants() do
		if isText(o) then
			count += 1
			if MODE == "restore" then
				if restore(o) then
					note(o, "restored")
				end
			else
				apply(o, MODE == "dry")
			end
		end
	end
end
return string.format("%s: %d text objects, %d changed\n%s", MODE, count, #changes, table.concat(changes, "\n"))
