local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local Balance = require(RS.Shared.Config.Balance)
local Theme = require(script.Parent.Parent.Theme)
local U = require(script.Parent.Parent.Components.Util)
local S = require(script.Parent.Parent.Components.StainedGlass)
local Kit = require(script.Parent.Parent.Components.MatchKit)
local InputGlyph = require(script.Parent.Parent.Components.InputGlyph)
local InputKind = require(script.Parent.Parent.InputKind)
local Hud = {}
Hud.__index = Hud

-- `stop` is given only when spectating: the HUD then hides aim controls and offers STOP WATCHING.
-- Everything is built here in the Stained Glass style and floats over the fight: no panels hide the arena.
function Hud.new(data, maxima, lock, stop)
	local self = setmetatable({ Maxima = maxima }, Hud)
	self.Spectator = stop ~= nil
	self.Hearts = data.Hearts or { Balance.Match.Hearts, Balance.Match.Hearts }
	self.Gui = Kit.gui("FightHud", 20)
	self.Gui:SetAttribute("FightId", data.Id)
	self.Billboards = require(script.Parent.FightBillboards).new(data)
	-- Countdown / "PULL BACK" / "LET GO!"
	self.Headline = Kit.label(
		self.Gui,
		"Headline",
		"PULL BACK",
		UDim2.fromScale(0.7, 0.2),
		UDim2.fromScale(0.15, 0.16),
		{ MaxSize = 150, Outline = 4 }
	)
	self.Instruction = Kit.label(
		self.Gui,
		"Instruction",
		"Drag to pull • aim for gold",
		UDim2.fromScale(0.7, 0.06),
		UDim2.fromScale(0.15, 0.84),
		{ Font = Theme.Fonts.Body, MaxSize = Theme.TextSize.Label, Outline = 2 }
	)
	-- Aim meter: a glass rail with the gold sweet spot and a white marker.
	self.AimPanel = Kit.frame(self.Gui, "AimMeter", UDim2.fromScale(0.5, 0.13), UDim2.fromScale(0.05, 0.7))
	self.AimText = Kit.label(
		self.AimPanel,
		"Aim",
		"PULL",
		UDim2.fromScale(0.94, 0.42),
		UDim2.fromScale(0.03, 0),
		{ Font = Theme.Fonts.Body, MaxSize = Theme.TextSize.Label, Outline = 2 }
	)
	local rail = Instance.new("ImageLabel")
	rail.Name, rail.BackgroundTransparency = "Rail", 1
	rail.Size, rail.Position, rail.Parent = UDim2.fromScale(0.94, 0.3), UDim2.fromScale(0.03, 0.56), self.AimPanel
	S.setAsset(rail, "bar/stat_track")
	local m = Balance.Motion
	local lo = (data.SweetSpot - m.SweetSpotWidth - m.AimMin) / (m.AimMax - m.AimMin)
	local band = Instance.new("ImageLabel")
	band.Name, band.BackgroundTransparency, band.ZIndex = "PerfectBand", 1, 2
	band.Size = UDim2.fromScale(2 * m.SweetSpotWidth / (m.AimMax - m.AimMin), 1)
	band.Position, band.Parent = UDim2.fromScale(lo, 0), rail
	S.setAsset(band, "bar/stat_fill_amber")
	self.Marker = Instance.new("Frame")
	self.Marker.Name, self.Marker.AnchorPoint, self.Marker.BorderSizePixel = "Marker", Vector2.new(0.5, 0.5), 0
	self.Marker.Size, self.Marker.Position = UDim2.new(0, 5, 1.9, 0), UDim2.fromScale(0.5, 0.5)
	self.Marker.BackgroundColor3, self.Marker.ZIndex, self.Marker.Parent = Theme.Colors.Text, 3, rail
	Kit.outline(self.Marker, 1.5)
	self.Lock = Kit.gem(self.Gui, "Lock", "LOCK", "emerald", UDim2.fromScale(0.26, 0.15), UDim2.fromScale(0.79, 0.77))
	self.LockConnection = self.Lock.Activated:Connect(function()
		lock()
		self:LockPressed()
	end)
	-- Keyboard / controller players see the key that locks (FightController binds it while aiming).
	self.LockGlyph = InputGlyph.new(
		self.Lock,
		{ Keyboard = Enum.KeyCode.Space, Gamepad = Enum.KeyCode.ButtonA },
		UDim2.fromScale(0.3, 0.5),
		UDim2.fromScale(0.86, 0.14)
	)
	local square = Instance.new("UIAspectRatioConstraint")
	square.AspectRatio, square.Parent = 1, self.LockGlyph.Root
	if stop then
		self.Stop = Kit.gem(
			self.Gui,
			"StopWatching",
			"STOP WATCHING",
			"ruby",
			UDim2.fromScale(0.28, 0.11),
			UDim2.fromScale(0.5, 0.92)
		)
		self.StopConnection = self.Stop.Activated:Connect(stop)
	end
	self.BannerSerial = 0
	self.InputConnections = InputKind.changed(function()
		self:Instruct()
	end)
	self:Update({ Hp = maxima })
	return self
end

-- One press per round: grey LOCK out until the next aiming phase (button, key or controller).
function Hud:LockPressed()
	Kit.enable(self.Lock, false)
end

function Hud:Aim(aim, yaw, perfect)
	self.Marker.Position =
		UDim2.fromScale((aim - Balance.Motion.AimMin) / (Balance.Motion.AimMax - Balance.Motion.AimMin), 0.5)
	self.AimText.Text = if perfect
		then "PERFECT!"
		else string.format(
			"PULL %d%%  •  %d°",
			(aim - Balance.Motion.AimMin) / (Balance.Motion.AimMax - Balance.Motion.AimMin) * 100,
			math.deg(yaw)
		)
	self.AimText.TextColor3 = if perfect then Theme.Colors.Highlight else Theme.Colors.Text
end

function Hud:Phase(phase, text)
	self.Gui:SetAttribute("Phase", phase)
	local aiming = phase == "Aiming" and not self.Spectator
	self.AimPanel.Visible, self.Lock.Visible = aiming, aiming
	if aiming and phase ~= self.LastPhase then
		Kit.enable(self.Lock, true)
		S.buttonText(self.Lock, "LOCK")
	end
	self.LastPhase = phase
	self.Headline.Text = if phase == "Fighting" then "" else text or ""
	if self.Stop then
		self.Stop.Visible = phase ~= "Fighting"
	end
	self:Instruct()
end

-- The one-line hint under the fight, worded for what the player is holding (refreshed when that changes).
function Hud:Instruct()
	local phase = self.LastPhase
	local aiming = phase == "Aiming" and not self.Spectator
	local input = InputKind.current()
	self.Instruction.Text = if aiming
		then (if input == Enum.PreferredInput.Gamepad
			then "Left stick to pull • aim for gold"
			elseif input == Enum.PreferredInput.KeyboardAndMouse then "Drag or arrows to pull • aim for gold"
			else "Drag to pull • aim for gold")
		elseif phase == "Fighting" then (if input == Enum.PreferredInput.Touch
			then "Swipe to rotate the camera"
			elseif input == Enum.PreferredInput.Gamepad then "Right stick to rotate the camera"
			else "Drag or Q / E to rotate the camera")
		elseif self.Spectator and phase == "Aiming" then "WATCHING • players are aiming"
		else ""
end

function Hud:Update(r)
	require(script.Parent.FightBillboards).update(self.Billboards, self.Hearts, r.Hp, self.Maxima)
end

function Hud:Beat()
	if self.BeatTween then
		self.BeatTween:Cancel()
	end
	local scale = self.Headline:FindFirstChild("BeatScale") or Instance.new("UIScale")
	scale.Name, scale.Parent = "BeatScale", self.Headline
	scale.Scale = Balance.Feel.CountdownPulseScale
	self.BeatTween = TweenService:Create(
		scale,
		TweenInfo.new(Balance.Feel.CountdownPulseSeconds, Enum.EasingStyle.Back),
		{ Scale = 1 }
	)
	self.BeatTween:Play()
end

function Hud:Banner(side, text, tint, quiet)
	-- Powers communicate through their effects; the creator removed announcement banners.
end

function Hud:Edge(tint)
	-- The approved fight UI only uses billboards, power banners and damage popups.
end

function Hud:Popup(text, position, tint, lane, key, scale)
	self.Popups = self.Popups or {}
	key = key or text
	if self.Popups[key] then
		self.Popups[key]:Destroy()
	end
	local p, visible = workspace.CurrentCamera:WorldToViewportPoint(position)
	if not visible then
		return
	end
	local label = U.prototype(self.Gui, "Popup", "Popup")
		or U.text(self.Gui, "Popup", text, UDim2.fromScale(0.2, 0.12), UDim2.new(), Theme.Fonts.PopUp, true)
	label.Text = text
	-- Viewport coordinates include the safe inset; ScreenGui coordinates do not.
	local inset = self.Gui.AbsolutePosition
	local size = self.Gui.AbsoluteSize
	label.Position = UDim2.fromScale(
		(p.X - inset.X) / math.max(1, size.X) + (lane or 0) * 0.06,
		(p.Y - inset.Y) / math.max(1, size.Y)
	)
	self.Popups[key] = label
	label.AnchorPoint, label.TextColor3, label.ZIndex = Vector2.new(0.5, 0.5), tint, 8
	label.UITextSizeConstraint.MaxTextSize = math.floor(Theme.TextSize.Heading * (scale or 1))
	if scale then
		label.Size = UDim2.new(
			label.Size.X.Scale * scale,
			label.Size.X.Offset * scale,
			label.Size.Y.Scale * scale,
			label.Size.Y.Offset * scale
		)
	end
	U.make("UIStroke", label, { Thickness = 1.5, Color = Theme.Colors.Shadow, Transparency = 0.15 })
	TweenService:Create(
		label,
		TweenInfo.new(Balance.Feel.PopupSeconds),
		{ Position = label.Position - UDim2.fromScale(0, 0.1), TextTransparency = 1, TextStrokeTransparency = 1 }
	):Play()
	-- Authored popups may use UIStroke as well as the legacy text stroke.
	for _, stroke in label:GetDescendants() do
		if stroke:IsA("UIStroke") then
			TweenService:Create(stroke, TweenInfo.new(Balance.Feel.PopupSeconds), { Transparency = 1 }):Play()
		end
	end
	Debris:AddItem(label, Balance.Feel.PopupSeconds)
end

function Hud:Destroy()
	self.BannerSerial += 1
	require(script.Parent.FightBillboards).destroy(self.Billboards)
	self.LockConnection:Disconnect()
	self.LockGlyph:Destroy()
	for _, connection in self.InputConnections do
		connection:Disconnect()
	end
	if self.StopConnection then
		self.StopConnection:Disconnect()
	end
	self.Gui:Destroy()
end

return Hud
