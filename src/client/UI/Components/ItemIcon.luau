-- Flat item portraits: an ImageLabel showing the pre-rendered icon (Config/ItemIcons) where a ViewportFrame used to
-- be. Grids, cards, reels and reward cells use these; live 3D stays only where motion is the point (decision 113).
-- Returns nil when an item has no icon yet, so callers fall back to their viewport.
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Icons = require(RS.Shared.Config.ItemIcons)
local ItemIcon = {}

-- Studio A/B switches (docs/testing/viewports): workspace attribute ItemIconsOff = true shows every viewport again;
-- ItemIconsTest = "rbxassetid://..." shows that image for every item.
local function lookup(category, id)
	if RunService:IsStudio() then
		if workspace:GetAttribute("ItemIconsOff") then
			return nil
		end
		local test = workspace:GetAttribute("ItemIconsTest")
		if type(test) == "string" then
			return { Small = test }
		end
	end
	return Icons.get(category, id)
end
local resizeBindings = setmetatable({}, { __mode = "k" })

local LAYOUT = { "Size", "Position", "AnchorPoint", "ZIndex", "Visible", "LayoutOrder", "Rotation", "SizeConstraint" }

-- Swaps the slot `name` under `parent` to `class` (ImageLabel <-> ViewportFrame), keeping its layout, attributes and
-- UI children (aspect constraints, the Featured "Owned" mark...). Returns the slot and whether it already existed.
function ItemIcon.slot(parent, name, class)
	local old = parent:FindFirstChild(name)
	if old and old:IsA(class) then
		return old, true
	end
	local new = Instance.new(class)
	new.Name, new.BackgroundTransparency = name, 1
	if old and old:IsA("GuiObject") then
		for _, key in LAYOUT do
			new[key] = old[key]
		end
		for key, value in old:GetAttributes() do
			new:SetAttribute(key, value)
		end
		for _, child in old:GetChildren() do
			if
				not (
					child:IsA("WorldModel")
					or child:IsA("Camera")
					or child.Name == "Icon"
					or child.Name == "Placeholder"
				)
			then
				child.Parent = new
			end
		end
		old:Destroy()
	end
	new.Parent = parent
	return new, old ~= nil
end

-- Before building a live viewport in `name`: turn an icon slot left there back into a ViewportFrame.
function ItemIcon.viewportSlot(parent, name)
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("ImageLabel") and existing:GetAttribute("ItemIcon") then
		ItemIcon.slot(parent, name, "ViewportFrame")
	end
end

local function pick(image, entry)
	local size = image.AbsoluteSize
	local large = entry.Large and math.max(size.X, size.Y) > Icons.LargeAbovePixels
	image.Image = if large then entry.Large :: string else entry.Small
end

function ItemIcon.has(category, id)
	return lookup(category, id) ~= nil
end

-- Mounts the icon in the slot `name` (reusing an authored slot's layout like Util.make does). nil = no icon.
function ItemIcon.mount(parent, name, category, id, size, position)
	local entry = lookup(category, id)
	if not entry then
		return nil
	end
	local image, existed = ItemIcon.slot(parent, name, "ImageLabel")
	if not existed then
		image.Size = size or image.Size
		image.Position = position or image.Position
	end
	require(script.Parent.Motion).center(image)
	local shape = image:FindFirstChildOfClass("UIAspectRatioConstraint")
	if shape then
		shape.AspectType = Enum.AspectType.FitWithinMaxSize
	end
	image.BackgroundTransparency, image.ScaleType = 1, Enum.ScaleType.Fit
	image.ImageColor3 = Color3.new(1, 1, 1)
	image:SetAttribute("ItemIcon", category .. ":" .. id)
	if category == "Glassies" then
		image:SetAttribute("GlassyId", id)
	end
	pick(image, entry)
	if resizeBindings[image] then
		resizeBindings[image]:Disconnect()
	end
	resizeBindings[image] = if entry.Large
		then image:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			pick(image, entry)
		end)
		else nil
	return image
end

-- Undiscovered look (Collection): a flat shadow shape, for an icon or a live viewport.
function ItemIcon.silhouette(portrait, colour)
	if portrait:IsA("ImageLabel") then
		portrait.ImageColor3 = colour
		return
	end
	portrait.Ambient, portrait.LightColor = Color3.new(), Color3.new()
	for _, part in portrait:GetDescendants() do
		if part:IsA("BasePart") then
			part.Color, part.Material = colour, Enum.Material.SmoothPlastic
		end
	end
end

return ItemIcon
