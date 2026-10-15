local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local RS = game:GetService("ReplicatedStorage")
local Balance = require(RS.Shared.Config.Balance)
local Theme = require(script.Parent.Parent.Theme)
local U = require(script.Parent.Parent.Components.Util)
local Panel = require(script.Parent.Parent.Components.Panel)
local Button = require(script.Parent.Parent.Components.Button)
local Hud = {}
Hud.__index = Hud

-- `stop` is given only when spectating: the HUD then hides aim controls and offers STOP WATCHING.
function Hud.new(data, maxima, lock, stop)
	local self = setmetatable({ Maxima = maxima }, Hud)
	self.Spectator = stop ~= nil
	self.Hearts = data.Hearts or { Balance.Match.Hearts, Balance.Match.Hearts }
	self.Gui = U.screen("FightHud", 20)
	self.Gui:SetAttribute("FightId", data.Id)
	self.Billboards = require(script.Parent.FightBillboards).new(data)
	self.Headline = U.text(
		self.Gui,
		"Headline",
		"PULL BACK",
		UDim2.fromScale(0.7, 0.1),
		UDim2.fromScale(0.15, 0.24),
		Theme.Fonts.Heading
	)
	self.Headline.UITextSizeConstraint.MaxTextSize = Theme.TextSize.Title
	self.Instruction = U.text(
		self.Gui,
		"Instruction",
		"Drag to pull • aim for gold",
		UDim2.fromScale(0.7, 0.07),
		UDim2.fromScale(0.15, 0.83),
		Theme.Fonts.Caption
	)
	self.AimPanel = Panel.new(self.Gui, "AimMeter", UDim2.fromScale(0.5, 0.1), UDim2.fromScale(0.07, 0.7), true)
	local rail = U.make("Frame", self.AimPanel, {
		Name = "Rail",
		Size = UDim2.fromScale(0.9, 0.18),
		Position = UDim2.fromScale(0.05, 0.5),
		BackgroundColor3 = Theme.Colors.Inset,
		BorderSizePixel = 0,
	})
	U.corner(rail, Theme.Radius.Bar)
	local m = Balance.Motion
	local lo = (data.SweetSpot - m.SweetSpotWidth - m.AimMin) / (m.AimMax - m.AimMin)
	local band = U.make("Frame", rail, {
		Name = "PerfectBand",
		Size = UDim2.fromScale(2 * m.SweetSpotWidth / (m.AimMax - m.AimMin), 2),
		Position = UDim2.fromScale(lo, -0.5),
		BackgroundColor3 = Theme.Colors.Highlight,
		BorderSizePixel = 0,
	})
	-- The band is game state (this round's sweet spot), so it must move even when the template authored a
	-- placement. Keep any authored vertical styling; only the horizontal span follows the round.
	band.Position = UDim2.new(lo, 0, band.Position.Y.Scale, band.Position.Y.Offset)
	band.Size = UDim2.new(2 * m.SweetSpotWidth / (m.AimMax - m.AimMin), 0, band.Size.Y.Scale, band.Size.Y.Offset)
	self.Marker = U.make("Frame", rail, {
		Name = "Marker",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromScale(0.012, 3),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundColor3 = Theme.Colors.Text,
		BorderSizePixel = 0,
		ZIndex = 3,
	})
	self.AimText = U.text(self.AimPanel, "Aim", "PULL", UDim2.fromScale(0.9, 0.36), UDim2.fromScale(0.05, 0.02))
	self.Lock = Button.new(self.Gui, "Lock", "LOCK", "Green", UDim2.fromScale(0.23, 0.13), UDim2.fromScale(0.69, 0.69))
	U.make("UISizeConstraint", self.Lock, { MinSize = Vector2.new(80, 44) })
	self.LockConnection = self.Lock.Activated:Connect(lock)
	if stop then
		self.Stop = Button.new(
			self.Gui,
			"StopWatching",
			"STOP WATCHING",
			"Red",
			UDim2.fromScale(0.26, 0.1),
			UDim2.fromScale(0.5, 0.98),
			Vector2.new(0.5, 1) -- bottom-anchored so the 44 px minimum grows upward on short phones
		)
		self.Stop.Visible = true
		U.make("UISizeConstraint", self.Stop, { MinSize = Vector2.new(120, 44) })
		self.StopConnection = self.Stop.Activated:Connect(stop)
	elseif self.Gui:FindFirstChild("StopWatching") then
		self.Gui.StopWatching.Visible = false
	end
	self.PowerBanner = self.Gui.PowerBanner
	self.PowerBanner.Visible = false
	self.BannerSerial = 0
	self:Update({ Hp = maxima })
	return self
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
	self.Headline.Text = if phase == "Fighting" then "" else text or ""
	if self.Stop then
		self.Stop.Visible = phase ~= "Fighting"
	end
	self.Instruction.Text = if aiming
		then "Drag to pull • aim for gold"
		elseif self.Spectator and phase == "Aiming" then "WATCHING • players are aiming"
		else ""
end

function Hud:Update(r)
	require(script.Parent.FightBillboards).update(self.Billboards, self.Hearts, r.Hp, self.Maxima)
end

function Hud:Banner(side, text, tint, quiet)
	-- Powers communicate through their effects; the creator removed announcement banners.
end

function Hud:Edge(tint)
	-- The approved fight UI only uses billboards, power banners and damage popups.
end

function Hud:Popup(text, position, tint, lane, key)
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
	label.UITextSizeConstraint.MaxTextSize = Theme.TextSize.Heading
	U.make("UIStroke", label, { Thickness = 1.5, Color = Theme.Colors.Shadow, Transparency = 0.15 })
	TweenService:Create(
		label,
		TweenInfo.new(Balance.Feel.PopupSeconds),
		{ Position = label.Position - UDim2.fromScale(0, 0.1), TextTransparency = 1 }
	):Play()
	Debris:AddItem(label, Balance.Feel.PopupSeconds)
end

function Hud:Destroy()
	self.BannerSerial += 1
	require(script.Parent.FightBillboards).destroy(self.Billboards)
	self.LockConnection:Disconnect()
	if self.StopConnection then
		self.StopConnection:Disconnect()
	end
	self.Gui:Destroy()
end

return Hud
