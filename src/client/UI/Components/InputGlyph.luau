-- A small key or button picture on an action button, matching what the player is holding: a key-cap on
-- keyboard, the platform's own button art on a controller (Xbox / PlayStation shapes come from Roblox), and
-- nothing on touch. Pictures over words (kids don't read): the key-cap shows only the key's short name.
local UIS = game:GetService("UserInputService")
local Theme = require(script.Parent.Parent.Theme)
local InputKind = require(script.Parent.Parent.InputKind)
local Glyph = {}
Glyph.__index = Glyph

local SHORT = { Space = "SPACE", Return = "ENTER" }

-- keys = { Keyboard = Enum.KeyCode?, Gamepad = Enum.KeyCode? }; size/position place the glyph in parent.
function Glyph.new(parent, keys, size, position)
	local self = setmetatable({ Keys = keys }, Glyph)
	local root = Instance.new("Frame")
	root.Name, root.BackgroundTransparency = "InputGlyph", 1
	root.Size, root.Position, root.AnchorPoint = size, position, Vector2.new(0.5, 0.5)
	root.ZIndex = 20
	self.Root = root
	-- Key-cap: dark rounded key with a light rim and the key's name.
	local cap = Instance.new("TextLabel")
	cap.Name, cap.Size, cap.Position, cap.AnchorPoint =
		"KeyCap", UDim2.fromScale(1, 1), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5)
	cap.BackgroundColor3, cap.BackgroundTransparency = Theme.Colors.Shadow, 0.05
	cap.TextColor3, cap.FontFace, cap.TextScaled = Color3.new(1, 1, 1), Theme.Fonts.Heading, true
	cap.ZIndex = 20
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.25, 0)
	corner.Parent = cap
	local rim = Instance.new("UIStroke")
	rim.Color, rim.Thickness, rim.ApplyStrokeMode = Color3.fromRGB(235, 225, 200), 2, Enum.ApplyStrokeMode.Border
	rim.Parent = cap
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0.12, 0), UDim.new(0.12, 0)
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0.14, 0), UDim.new(0.14, 0)
	pad.Parent = cap
	cap.Parent = root
	self.Cap = cap
	-- Controller button art from Roblox, square.
	local pad2 = Instance.new("ImageLabel")
	pad2.Name, pad2.BackgroundTransparency = "PadButton", 1
	pad2.Size, pad2.Position, pad2.AnchorPoint = UDim2.fromScale(1, 1), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5)
	pad2.ScaleType, pad2.ZIndex = Enum.ScaleType.Fit, 20
	pad2.Parent = root
	self.Pad = pad2
	root.Parent = parent
	self.Connections = InputKind.changed(function()
		self:Refresh()
	end)
	self:Refresh()
	return self
end

function Glyph:Refresh()
	local input = InputKind.current()
	local label = nil
	local image = ""
	if input == Enum.PreferredInput.KeyboardAndMouse and self.Keys.Keyboard then
		local name = self.Keys.Keyboard.Name
		label = SHORT[name] or name
	elseif input == Enum.PreferredInput.Gamepad and self.Keys.Gamepad then
		local ok, result = pcall(UIS.GetImageForKeyCode, UIS, self.Keys.Gamepad)
		image = if ok and type(result) == "string" then result else ""
		if image == "" then
			-- No platform art (rare): fall back to a key-cap with the button's letter, e.g. "A".
			label = self.Keys.Gamepad.Name:gsub("^Button", "")
		end
	end
	self.Pad.Image, self.Pad.Visible = image, image ~= ""
	self.Cap.Visible = label ~= nil
	if label then
		self.Cap.Text = label
		-- A wide key for long names (SPACE), a square one for letters.
		self.Cap.Size = if #label > 2 then UDim2.fromScale(1, 0.62) else UDim2.fromScale(0.62, 1)
	end
	self.Root.Visible = self.Cap.Visible or self.Pad.Visible
end

function Glyph:Destroy()
	for _, connection in self.Connections do
		connection:Disconnect()
	end
	self.Root:Destroy()
end

return Glyph
