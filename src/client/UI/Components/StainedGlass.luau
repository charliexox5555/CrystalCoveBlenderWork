-- Editable artwork helpers. Runtime state changes never replace authored geometry.
local RS = game:GetService("ReplicatedStorage")
local Assets = require(RS.Shared.Config.UIAssets)
local Specs = require(script.Parent.StainedAssetSpecs)
local Theme = require(script.Parent.Parent.Theme)
local S = {}
local sliceBound = setmetatable({}, { __mode = "k" })
-- FitSingleLine labels (templates mark names, tabs and plaques with it) use the shared fit policy, kept to
-- one line: shrink to Theme.TextFit.Min, then MinSmall, then end with "…". It used to be an async
-- measure-and-set fitter here; the engine's TextScaled is synchronous and follows UIScale pop-ins.
function S.bindText(label)
	if not label:IsA("TextLabel") or not label:GetAttribute("FitSingleLine") then
		return
	end
	if not label:FindFirstChildOfClass("UITextSizeConstraint") then
		local limit = Instance.new("UITextSizeConstraint")
		limit.MaxTextSize, limit.Parent = 40, label
	end
	label:SetAttribute("FitLines", 1)
	local TextFit = require(script.Parent.TextFit)
	TextFit.prefer(label, { TextScaled = true, TextWrapped = false, TextTruncate = Enum.TextTruncate.None })
	TextFit.bind(label)
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
-- Gem art is drawn with ScaleType.Fit, so a button wider (or taller) than the gem's 600:172 shape shows a
-- narrower gem in its middle. Keep the Label's authored insets relative to the gem actually drawn, not the
-- button box, so its text never runs past the pointed ends.
local gemBound = setmetatable({}, { __mode = "k" })
function S.bindGemLabel(button)
	local art, label = button:FindFirstChild("Artwork"), button:FindFirstChild("Label")
	if gemBound[button] or not button:IsA("GuiButton") or not art or not label or button:FindFirstChild("Cost") then
		return
	end
	if art.ScaleType ~= Enum.ScaleType.Fit or art.Size ~= UDim2.fromScale(1, 1) then
		return
	end
	local p, z = label.Position, label.Size
	if
		p.X.Offset ~= 0
		or p.Y.Offset ~= 0
		or z.X.Offset ~= 0
		or z.Y.Offset ~= 0
		or label.AnchorPoint ~= Vector2.zero
	then
		return
	end
	gemBound[button] = true
	local x0, y0, w0, h0 = p.X.Scale, p.Y.Scale, z.X.Scale, z.Y.Scale
	local function fit()
		local spec = Specs[art:GetAttribute("AssetPath")]
		local size = button.AbsoluteSize
		if not spec or not string.match(art:GetAttribute("AssetPath"), "^button/gem") or size.X < 1 or size.Y < 1 then
			return
		end
		local ratio = spec.Width / spec.Height
		local fx = math.min(1, size.Y * ratio / size.X)
		local fy = math.min(1, size.X / ratio / size.Y)
		label.Position = UDim2.fromScale(0.5 + (x0 - 0.5) * fx, 0.5 + (y0 - 0.5) * fy)
		label.Size = UDim2.fromScale(w0 * fx, h0 * fy)
	end
	button:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	art:GetAttributeChangedSignal("AssetPath"):Connect(fit)
	fit()
end
function S.bindSlices(root)
	if root:IsA("GuiButton") then
		S.bindGemLabel(root)
	end
	for _, o in root:GetDescendants() do
		S.bindSlice(o)
		S.bindText(o)
		S.bindGemLabel(o)
		require(script.Parent.Motion).button(o)
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
