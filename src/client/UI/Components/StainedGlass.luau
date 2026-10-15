-- Editable artwork helpers. Runtime state changes never replace authored geometry.
local RS = game:GetService("ReplicatedStorage")
local Assets = require(RS.Shared.Config.UIAssets)
local Specs = require(script.Parent.StainedAssetSpecs)
local Theme = require(script.Parent.Parent.Theme)
local S = {}
local sliceBound = setmetatable({}, { __mode = "k" })
local textBound = setmetatable({}, { __mode = "k" })
function S.bindText(label)
	if not label:IsA("TextLabel") or not label:GetAttribute("FitSingleLine") or textBound[label] then
		return
	end
	textBound[label] = true
	label.TextScaled, label.TextWrapped = false, false
	local version = 0
	local function fit()
		version += 1
		local serial = version
		task.spawn(function()
			local constraint = label:FindFirstChildOfClass("UITextSizeConstraint")
			local maximum = if constraint then constraint.MaxTextSize else 40
			local params = Instance.new("GetTextBoundsParams")
			params.Text, params.Font, params.Size, params.Width = label.Text, label.FontFace, maximum, 100000
			local ok, bounds =
				pcall(game:GetService("TextService").GetTextBoundsAsync, game:GetService("TextService"), params)
			params:Destroy()
			if not ok or serial ~= version or not label.Parent then
				return
			end
			local stroke = label:FindFirstChildOfClass("UIStroke")
			local inset = if stroke then stroke.Thickness * 2 + 2 else 2
			local size = label.AbsoluteSize - Vector2.one * inset
			local ratio = math.min(1, size.X / math.max(1, bounds.X), size.Y / math.max(1, bounds.Y))
			label.TextSize = math.max(if constraint then constraint.MinTextSize else 1, math.floor(maximum * ratio))
		end)
	end
	for _, property in { "AbsoluteSize", "Text", "FontFace" } do
		label:GetPropertyChangedSignal(property):Connect(fit)
	end
	local constraint = label:FindFirstChildOfClass("UITextSizeConstraint")
	if constraint then
		constraint:GetPropertyChangedSignal("MaxTextSize"):Connect(fit)
		constraint:GetPropertyChangedSignal("MinTextSize"):Connect(fit)
	end
	fit()
end
function S.bindSlice(object)
	if sliceBound[object] or not object:IsA("ImageLabel") or object.ScaleType ~= Enum.ScaleType.Slice then
		return
	end
	local function resize()
		local spec = Specs[object:GetAttribute("AssetPath")]
		if not spec then
			return
		end
		object.SliceScale = math.max(
			0.001,
			math.min(
				object.AbsoluteSize.X / (spec.TextureWidth or spec.Width),
				object.AbsoluteSize.Y / (spec.TextureHeight or spec.Height)
			)
		)
	end
	sliceBound[object] = true
	object:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
	resize()
end
function S.bindSlices(root)
	for _, o in root:GetDescendants() do
		S.bindSlice(o)
		S.bindText(o)
	end
end
S.Rarity = {
	Starter = "milk",
	Common = "milk",
	Uncommon = "emerald",
	Rare = "sapphire",
	Epic = "amethyst",
	Legendary = "amber",
	Mythic = "ruby",
}
S.Types = { Fizzy = "aqua", Heavy = "amber", Sharp = "amethyst" }
function S.rarity(rarity)
	return if rarity == "Starter" then "common" else string.lower(rarity)
end
function S.aspect(object, ratio)
	local c = object:FindFirstChildOfClass("UIAspectRatioConstraint") or Instance.new("UIAspectRatioConstraint")
	c.AspectRatio, c.Parent = ratio, object
	return c
end
function S.setAsset(object, path)
	if object:GetAttribute("AssetPath") == path then
		S.bindSlice(object)
		return
	end
	object:SetAttribute("AssetPath", path)
	local spec = assert(Specs[path], path)
	if object:IsA("ImageLabel") or object:IsA("ImageButton") then
		object.Image = Assets[path] or ""
		-- Pointed controls already have a locked PNG aspect. Render the complete silhouette:
		-- Studio's nine-slice renderer cuts the tips on these assets even at matching ratios.
		local stretch = path:match("^bar/") or path == "panel/pane_dark" or path == "panel/pane_viewport"
		object.ScaleType = if spec.Slice and stretch then Enum.ScaleType.Slice else Enum.ScaleType.Fit
		if spec.Slice then
			-- Roblox downsamples oversized uploads. SliceCenter is in decoded texture pixels.
			local sx = (spec.TextureWidth or spec.Width) / spec.Width
			local sy = (spec.TextureHeight or spec.Height) / spec.Height
			object.SliceCenter =
				Rect.new(spec.Slice.Min.X * sx, spec.Slice.Min.Y * sy, spec.Slice.Max.X * sx, spec.Slice.Max.Y * sy)
			object:SetAttribute("SourceSliceCenter", tostring(spec.Slice))
		end
	end
	S.bindSlice(object)
end
function S.image(parent, name, path, size, position)
	local id = Assets[path]
	local object = Instance.new(if id and id ~= "" then "ImageLabel" else "Frame")
	object.Name, object.Size, object.Position = name, size, position or UDim2.new()
	object.BackgroundTransparency, object.BorderSizePixel = 1, 0
	if object:IsA("Frame") then
		local colour = path:match("_(%a+)$") or "milk"
		object.BackgroundTransparency = 0
		object.BackgroundColor3 = Theme.Palette[colour] or Theme.Colors.Inset
		object:SetAttribute("MissingAsset", path)
	end
	S.setAsset(object, path)
	S.aspect(object, Specs[path].Width / Specs[path].Height)
	object.Parent = parent
	return object
end
function S.hearts(parent, count)
	for i = 1, 3 do
		S.setAsset(parent["Heart" .. i], if i <= (count or 3) then "icon/heart_full" else "icon/heart_broken")
	end
end
function S.tag(object, text, colour)
	S.setAsset(object, "tag/tag_" .. colour)
	object.Label.Text = text
	object.Label.TextColor3 = if colour == "milk" then Theme.Palette.lead else Theme.Palette.milkLight
end
function S.buttonText(button, text)
	local label = button:FindFirstChild("Label")
	if label then
		label.Text = text
	else
		button.Text = text
	end
end
function S.tint(tint)
	local nearest, distance = "aqua", math.huge
	for _, name in { "ruby", "amber", "emerald", "aqua", "sapphire", "amethyst" } do
		local c = Theme.Palette[name]
		local d = (c.R - tint.R) ^ 2 + (c.G - tint.G) ^ 2 + (c.B - tint.B) ^ 2
		if d < distance then
			nearest, distance = name, d
		end
	end
	return nearest
end
return S
