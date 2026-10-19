-- UI text-fit scanner (workstream J). Run in Studio Play on the Client DataModel through the MCP.
-- Read-only: it measures every visible TextLabel/TextButton/TextBox in PlayerGui and reports text that
-- overflows its own box, sticks out of its button/container, or renders below the readable minimum.
-- Phone/tablet sizes are estimated by scaling each label's on-screen box by min(Wp/W, Hp/H) of the
-- current viewport (layouts here are scale + aspect-constrained) and re-fitting the text with
-- TextService:GetTextBoundsAsync, so it is an estimate, not a Device Emulator run.
-- Usage (paste as the body of execute_luau, then call): local scan = <this file>; return scan({ Root = nil })
local TextService = game:GetService("TextService")
local Players = game:GetService("Players")

local MIN_READABLE = 10 -- px; below Theme.TextFit.MinSmall a kid on a phone can't read it
local VIEWPORTS = {
	{ Name = "phone 667x375", X = 667, Y = 375 },
	{ Name = "phone 844x390", X = 844, Y = 390 },
	{ Name = "tablet 1024x768", X = 1024, Y = 768 },
}

-- Cut-glass art is not rectangular: text must stay inside the inner face, away from the pointed tips.
-- Fractions of the art's box (from the SVGs in assets/ui/stained_glass/svg).
local SAFE = {
	{ "^button/gem", 0.1, 0.13 },
	{ "^tag/", 0.08, 0.1 },
	{ "^tile/name_plaque", 0.1, 0.1 },
	{ "^panel/title_", 0.12, 0.15 },
}
local function safeInset(holder)
	local art = holder:FindFirstChild("Artwork") or holder
	local asset = art:GetAttribute("AssetPath") or ""
	for _, rule in SAFE do
		if string.match(asset, rule[1]) then
			return rule[2], rule[3]
		end
	end
	return 0, 0
end

local cache = {}
local function bounds(text, font, size, width)
	local key = table.concat({ text, font.Family, font.Weight.Name, size, width }, "|")
	local hit = cache[key]
	if hit then
		return hit
	end
	local params = Instance.new("GetTextBoundsParams")
	params.Text, params.Font, params.Size, params.Width = text, font, size, width
	local ok, result = pcall(TextService.GetTextBoundsAsync, TextService, params)
	params:Destroy()
	hit = if ok then result else Vector2.zero
	cache[key] = hit
	return hit
end

local function visible(object)
	local node = object
	while node and not node:IsA("LayerCollector") do
		if node:IsA("GuiObject") and not node.Visible then
			return false
		end
		node = node.Parent
	end
	return node ~= nil and node.Enabled
end

local function plain(label)
	if not label.RichText then
		return label.Text
	end
	return (label.Text:gsub("<[^>]->", ""))
end

local function inner(label)
	local size = label.AbsoluteSize
	local pad = label:FindFirstChildOfClass("UIPadding")
	if pad then
		size -= Vector2.new(
			pad.PaddingLeft.Offset + pad.PaddingRight.Offset + (pad.PaddingLeft.Scale + pad.PaddingRight.Scale) * size.X,
			pad.PaddingTop.Offset + pad.PaddingBottom.Offset + (pad.PaddingTop.Scale + pad.PaddingBottom.Scale) * size.Y
		)
	end
	return size
end

local function limits(label)
	local c = label:FindFirstChildOfClass("UITextSizeConstraint")
	local maxSize = if label.TextScaled then 100 else label.TextSize
	if c and label.TextScaled then
		maxSize = c.MaxTextSize
	end
	return (if c then c.MinTextSize else 1), maxSize
end

-- Largest size in [1, maxSize] whose bounds fit `box`, like the engine's TextScaled.
local function fitted(label, text, box, maxSize)
	local lo, hi = 1, math.max(1, math.floor(maxSize))
	local width = if label.TextWrapped then math.max(1, box.X) else 100000
	local best = 0
	while lo <= hi do
		local mid = (lo + hi) // 2
		local b = bounds(text, label.FontFace, mid, width)
		if b.X <= box.X + 0.5 and b.Y <= box.Y + 0.5 then
			best, lo = mid, mid + 1
		else
			hi = mid - 1
		end
	end
	return best
end

-- Size a label renders at in a box: TextScaled clamps the fit to [min, max]; fixed text uses TextSize.
local function rendered(label, text, box)
	local minSize, maxSize = limits(label)
	if not label.TextScaled then
		local b = bounds(text, label.FontFace, label.TextSize, if label.TextWrapped then box.X else 100000)
		return label.TextSize, b.X <= box.X + 1 and b.Y <= box.Y + 1
	end
	local fit = fitted(label, text, box, maxSize)
	local size = math.max(fit, minSize)
	return size, fit >= minSize and fit > 0
end

-- What the TextFit policy (UI/Components/TextFit) does with this text in a box of this size:
-- the size it renders at, "CUT" (min size with …), or "OVERFLOW" for labels the policy doesn't cover.
local FIT_MIN, FIT_LINES = 12, 2
local function policy(label, text, box)
	if label:GetAttribute("TextFit") == false or label.AutomaticSize ~= Enum.AutomaticSize.None then
		local size, ok = rendered(label, text, box)
		return if ok then size else "OVERFLOW"
	end
	local c = label:FindFirstChildOfClass("UITextSizeConstraint")
	local maxSize = if label.TextScaled and c then c.MaxTextSize elseif label.TextScaled then 100 else label.TextSize
	local minimum = math.max(1, math.min(label:GetAttribute("FitMin") or FIT_MIN, math.floor(box.Y)))
	local fit = fitted(label, text, box, maxSize)
	if fit >= minimum then
		return fit
	end
	if (label:GetAttribute("FitLines") or FIT_LINES) > 1 and box.Y >= minimum * 2.2 and not label.TextWrapped then
		local wrapped = bounds(text, label.FontFace, minimum, math.max(1, box.X))
		if wrapped.Y <= box.Y + 0.5 and wrapped.X <= box.X + 0.5 then
			return minimum
		end
	end
	if label.TextWrapped and bounds(text, label.FontFace, minimum, math.max(1, box.X)).Y <= box.Y + 0.5 then
		return minimum
	end
	return "CUT"
end

local function container(label)
	-- Nearest ancestor that draws the shape the text must stay inside: a button, or an image/frame of art.
	local node = label.Parent
	while node and node:IsA("GuiObject") do
		if node:IsA("GuiButton") or node:IsA("ImageLabel") then
			return node
		end
		if node:IsA("Frame") and node.BackgroundTransparency < 1 then
			return node
		end
		if node:IsA("ScrollingFrame") then
			return nil -- scrolled content legitimately extends past the frame
		end
		node = node.Parent
	end
	return nil
end

local function path(object)
	local parts = {}
	local node = object
	while node and not node:IsA("PlayerGui") do
		table.insert(parts, 1, node.Name)
		node = node.Parent
	end
	return table.concat(parts, ".")
end

return function(options)
	options = options or {}
	local pg = Players.LocalPlayer.PlayerGui
	local root = options.Root or pg
	-- A hidden Studio window reports a 1x1 camera; the ScreenGui still has the real layout size.
	local camera = workspace.CurrentCamera.ViewportSize
	if camera.X < 10 then
		local gui = if root:IsA("ScreenGui") then root else pg:FindFirstChildWhichIsA("ScreenGui")
		camera = gui.AbsoluteSize
	end
	local rows, counts =
		{},
		{ Checked = 0, Cut = 0, Overflow = 0, Outside = 0, Tiny = 0, PhoneOverflow = 0, PhoneTiny = 0, PhoneCut = 0 }
	for _, label in root:GetDescendants() do
		if
			not (label:IsA("TextLabel") or label:IsA("TextButton") or label:IsA("TextBox"))
			or label.Text == ""
			or label.TextTransparency >= 0.99
			or label.AbsoluteSize.X < 2
			or not visible(label)
		then
			continue
		end
		if label:FindFirstAncestorWhichIsA("BillboardGui") or label:FindFirstAncestorWhichIsA("SurfaceGui") then
			if not options.World then
				continue
			end
		end
		counts.Checked += 1
		local text = plain(label)
		local box = inner(label)
		local issues = {}
		local size, fits = rendered(label, text, box)
		if label.TextTruncate ~= Enum.TextTruncate.None and not fits then
			table.insert(issues, "CUT")
			counts.Cut += 1
		elseif not label.TextFits or not fits then
			table.insert(issues, "OVERFLOW")
			counts.Overflow += 1
		end
		if size < MIN_READABLE then
			table.insert(issues, "TINY")
			counts.Tiny += 1
		end
		local holder = container(label)
		if holder and holder.AbsoluteSize.X > 4 then
			-- Where the text actually draws (TextBounds, centred per alignment), against the holder's box.
			local tb = label.TextBounds
			local x = label.AbsolutePosition.X
			if label.TextXAlignment == Enum.TextXAlignment.Center then
				x += (label.AbsoluteSize.X - tb.X) / 2
			elseif label.TextXAlignment == Enum.TextXAlignment.Right then
				x += label.AbsoluteSize.X - tb.X
			end
			local y = label.AbsolutePosition.Y
			if label.TextYAlignment == Enum.TextYAlignment.Center then
				y += (label.AbsoluteSize.Y - tb.Y) / 2
			elseif label.TextYAlignment == Enum.TextYAlignment.Bottom then
				y += label.AbsoluteSize.Y - tb.Y
			end
			local ix, iy = safeInset(holder)
			-- Gem art is drawn with ScaleType.Fit: in a box wider than 600:172 the gem is narrower than the box.
			local art = holder:FindFirstChild("Artwork") or holder
			local box, origin = holder.AbsoluteSize, holder.AbsolutePosition
			if
				art:IsA("ImageLabel")
				and art.ScaleType == Enum.ScaleType.Fit
				and string.match(art:GetAttribute("AssetPath") or "", "^button/gem")
			then
				local ratio = 600 / 172
				local drawn = Vector2.new(math.min(box.X, box.Y * ratio), math.min(box.Y, box.X / ratio))
				origin += (box - drawn) / 2
				box = drawn
			end
			local hs = box * Vector2.new(1 - 2 * ix, 1 - 2 * iy)
			local hp = origin + box * Vector2.new(ix, iy)
			local slack = 2
			if
				x < hp.X - slack
				or y < hp.Y - slack
				or x + tb.X > hp.X + hs.X + slack
				or y + tb.Y > hp.Y + hs.Y + slack
			then
				table.insert(issues, "OUTSIDE:" .. holder.Name)
				counts.Outside += 1
			end
		end
		local phone = {}
		for _, view in VIEWPORTS do
			local k = math.min(view.X / camera.X, view.Y / camera.Y)
			local small = box * k
			local verdict = policy(label, text, small)
			if verdict == "OVERFLOW" then
				counts.PhoneOverflow += 1
				table.insert(phone, view.Name .. " OVERFLOW")
			elseif verdict == "CUT" then
				counts.PhoneCut += 1
				table.insert(phone, view.Name .. " cut…")
			elseif type(verdict) == "number" and verdict < MIN_READABLE then
				counts.PhoneTiny += 1
				table.insert(phone, view.Name .. " " .. verdict .. "px")
			end
		end
		if #issues > 0 or (#phone > 0 and options.Phone ~= false) then
			table.insert(
				rows,
				string.format(
					"%s | %q | %dx%d @%dpx %s%s | %s | %s",
					path(label),
					string.sub(text, 1, 40),
					label.AbsoluteSize.X,
					label.AbsoluteSize.Y,
					size,
					if label.TextScaled then "scaled" else "fixed",
					if label.TextWrapped then "+wrap" else "",
					table.concat(issues, ","),
					table.concat(phone, "; ")
				)
			)
		end
	end
	table.sort(rows)
	local head = string.format(
		"viewport %dx%d checked %d | overflow %d, cut %d, outside %d, tiny %d | phone/tablet: overflow %d, tiny %d, cut %d",
		camera.X,
		camera.Y,
		counts.Checked,
		counts.Overflow,
		counts.Cut,
		counts.Outside,
		counts.Tiny,
		counts.PhoneOverflow,
		counts.PhoneTiny,
		counts.PhoneCut
	)
	return head .. "\n" .. table.concat(rows, "\n"), counts
end
