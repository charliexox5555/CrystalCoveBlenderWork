-- Crown Hill on the client (decision 105): a crown + number chip while you wait in the challenger line, a "+1" coin
-- pop over your crown for every crown coin, and a gold burst when you take the crown or retire undefeated.
-- Driven by the player attributes HillService sets (HillLine, HillKing, HillTick, HillCrowned, HillRetired).
-- No reading needed: pictures, numbers and motion only.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local RS = game:GetService("ReplicatedStorage")
local UIAssets = require(RS.Shared.Config.UIAssets)
local Audio = require(RS.Shared.Config.Audio)
local Theme = require(script.Parent.Parent.UI.Theme)
local U = require(script.Parent.Parent.UI.Components.Util)
local Motion = require(script.Parent.Parent.UI.Components.Motion)
local Controller = {}

local CROWN = UIAssets["screens/profile/icon_crown"] or ""
local COIN = UIAssets["icon/coin"] or ""
local GOLD = Color3.fromHex("#FFC94A")

function Controller:Init(controllers)
	self.Controllers = controllers
	self.Player = Players.LocalPlayer
end

function Controller:Sound(name, volume)
	local shatter = self.Controllers.ShatterController
	local id = Audio[name]
	if shatter and id then
		shatter:Sound(id, workspace.CurrentCamera, 1, volume)
	end
end

-- Line chip -------------------------------------------------------------------------------------------------------

function Controller:BuildChip()
	local gui = U.screen("HillLine", 14)
	local chip = U.make("Frame", gui, {
		Name = "Chip",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -96),
		Size = UDim2.fromOffset(150, 64),
		BackgroundTransparency = 1,
		Visible = false,
	})
	U.make("ImageLabel", chip, {
		Name = "Plate",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Image = UIAssets["hud/label_plaque"] or "",
		ScaleType = Enum.ScaleType.Stretch,
	})
	U.make("ImageLabel", chip, {
		Name = "Crown",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.3, 0.45),
		Size = UDim2.fromOffset(52, 52),
		BackgroundTransparency = 1,
		Image = CROWN,
		Rotation = -10,
	})
	local number =
		U.text(chip, "Number", "#1", UDim2.fromScale(0.5, 0.7), UDim2.fromScale(0.45, 0.15), Theme.Fonts.Heading)
	number.TextColor3 = Theme.Colors.TextDark
	self.Chip, self.ChipNumber = chip, number
end

function Controller:UpdateChip()
	local position = self.Player:GetAttribute("HillLine")
	local pg = self.Player:FindFirstChild("PlayerGui")
	local busy = pg and (pg:GetAttribute("InMatch") or pg:GetAttribute("Queued"))
	local show = type(position) == "number" and position > 0 and not busy
	if show then
		self.ChipNumber.Text = "#" .. position
		if not self.Chip.Visible then
			self.Chip.Visible = true
			Motion.bump(self.Chip, 0.12)
		elseif self.LastPosition ~= position then
			Motion.bump(self.Chip, 0.08)
		end
	else
		self.Chip.Visible = false
	end
	self.LastPosition = position
end

-- Crown pops and bursts ------------------------------------------------------------------------------------------

function Controller:Crown()
	local character = self.Player.Character
	local crown = character and character:FindFirstChild("HillCrown")
	return crown and crown.PrimaryPart
end

-- A "+N" coin rising over the crown.
function Controller:CoinPop(amount)
	local core = self:Crown()
	if not core then
		return
	end
	local board = Instance.new("BillboardGui")
	board.Name = "HillCoinPop"
	board.Size = UDim2.fromScale(2.4, 1.1)
	board.StudsOffsetWorldSpace = Vector3.new(0, 0.9, 0)
	board.LightInfluence, board.AlwaysOnTop, board.Adornee = 0, true, core
	local coin = Instance.new("ImageLabel")
	coin.BackgroundTransparency, coin.Image = 1, COIN
	coin.Size, coin.Position = UDim2.fromScale(0.42, 0.9), UDim2.fromScale(0, 0.05)
	coin.Parent = board
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency, label.Text, label.TextScaled = 1, "+" .. amount, true
	label.FontFace, label.TextColor3 = Theme.Fonts.Heading, GOLD
	label.Size, label.Position = UDim2.fromScale(0.58, 1), UDim2.fromScale(0.42, 0)
	local stroke = Instance.new("UIStroke")
	stroke.Color, stroke.Thickness, stroke.Parent = Theme.Colors.Shadow, 2, label
	label.Parent = board
	board.Parent = self.Player:WaitForChild("PlayerGui")
	local info = TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(board, info, { StudsOffsetWorldSpace = Vector3.new(0, 2.6, 0) }):Play()
	TweenService:Create(label, info, { TextTransparency = 1 }):Play()
	TweenService:Create(stroke, info, { Transparency = 1 }):Play()
	TweenService:Create(coin, info, { ImageTransparency = 1 }):Play()
	Debris:AddItem(board, 1.2)
	self:Sound("UiTab", 0.12)
end

-- Gold burst at the crown and a big crown stamp on screen. `big` = retiring undefeated.
function Controller:Burst(big)
	local core = self:Crown()
	local character = self.Player.Character
	local at = core or (character and character:FindFirstChild("Head"))
	if at and not Motion.reduced() then
		local emitter = Instance.new("ParticleEmitter")
		emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		emitter.Color = ColorSequence.new(GOLD, Color3.new(1, 1, 1))
		emitter.LightEmission = 0.9
		emitter.Lifetime = NumberRange.new(0.8, 1.4)
		emitter.Speed = NumberRange.new(8, 16)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Acceleration = Vector3.new(0, -12, 0)
		emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
		emitter.Rate = 0
		emitter.Parent = at
		emitter:Emit(if big then 90 else 50)
		Debris:AddItem(emitter, 2)
	end
	local gui = U.screen("HillBurst", 40)
	local stamp = Instance.new("ImageLabel")
	stamp.Name = "Crown"
	stamp.BackgroundTransparency, stamp.Image = 1, CROWN
	stamp.AnchorPoint, stamp.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.32)
	stamp.Size = UDim2.fromOffset(40, 40)
	stamp.Rotation = -18
	stamp.Parent = gui
	local size = if big then 220 else 170
	local grow = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	TweenService:Create(stamp, grow, { Size = UDim2.fromOffset(size, size), Rotation = 0 }):Play()
	task.delay(if big then 1.6 else 1.1, function()
		local fade = TweenInfo.new(0.4)
		TweenService:Create(stamp, fade, { ImageTransparency = 1, Position = UDim2.fromScale(0.5, 0.22) }):Play()
		Debris:AddItem(stamp, 0.5)
	end)
	-- The chime itself plays from the King's pad on the server, so the whole island hears it.
end

function Controller:Start()
	self:BuildChip()
	local player = self.Player
	local function chip()
		self:UpdateChip()
	end
	player:GetAttributeChangedSignal("HillLine"):Connect(chip)
	local pg = player:WaitForChild("PlayerGui")
	pg:GetAttributeChangedSignal("InMatch"):Connect(chip)
	pg:GetAttributeChangedSignal("Queued"):Connect(chip)
	chip()
	local lastTick = player:GetAttribute("HillTick") or 0
	player:GetAttributeChangedSignal("HillTick"):Connect(function()
		local now = player:GetAttribute("HillTick") or 0
		if now > lastTick then
			self:CoinPop(now - lastTick)
		end
		lastTick = now
	end)
	for _, name in { "HillCrowned", "HillRetired" } do
		local last = player:GetAttribute(name) or 0
		player:GetAttributeChangedSignal(name):Connect(function()
			local now = player:GetAttribute(name) or 0
			if now > last then
				-- Let the crown arrive on the head first.
				task.delay(0.4, function()
					self:Burst(name == "HillRetired")
				end)
			end
			last = now
		end)
	end
end

return Controller
