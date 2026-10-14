local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local RS = game:GetService("ReplicatedStorage")
local Balance = require(RS.Shared.Config.Balance)
local Glassies = require(RS.Shared.Config.Glassies)
local Theme = require(script.Parent.Parent.Theme)
local U = require(script.Parent.Parent.Components.Util)
local Panel = require(script.Parent.Parent.Components.Panel)
local Button = require(script.Parent.Parent.Components.Button)
local Bar = require(script.Parent.Parent.Components.ProgressBar)
local Portrait = require(script.Parent.Parent.Components.GlassyPortrait)
local Hud = {}
Hud.__index = Hud

function Hud.new(data, maxima, lock)
	local self =
		setmetatable({ Bars = {}, Rings = {}, Status = {}, CrackLabels = {}, Maxima = maxima, LastHP = {} }, Hud)
	self.Hearts = data.Hearts or { Balance.Match.Hearts, Balance.Match.Hearts }
	self.Gui = U.screen("FightHud", 20)
	self.Gui:SetAttribute("FightId", data.Id)
	for side, setup in { data.A, data.B } do
		local def = Glassies.get(setup.Id)
		local tint = Color3.fromHex(def.Tint)
		local panel = Panel.new(
			self.Gui,
			"Side" .. side,
			UDim2.fromScale(0.41, 0.2),
			UDim2.fromScale(if side == 1 then 0.025 else 0.565, 0.02),
			true
		)
		local portrait = Portrait.new(panel, def.Id, UDim2.fromScale(0.22, 0.9), UDim2.fromScale(0.015, 0.04))
		U.make("UIAspectRatioConstraint", portrait, { AspectRatio = 1 })
		local ring =
			U.make("Frame", portrait, { Name = "PowerRing", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 })
		U.corner(ring, UDim.new(1, 0))
		local stroke = U.make("UIStroke", ring, { Thickness = 2, Color = tint, Transparency = 0.8 })
		self.Rings[side] = {}
		for i = 1, 16 do
			local angle = (i / 16 - 0.25) * math.pi * 2
			local pip = U.make("Frame", ring, {
				Name = "Charge" .. i,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5 + math.cos(angle) * 0.47, 0.5 + math.sin(angle) * 0.47),
				Size = UDim2.fromScale(0.06, 0.06),
				BackgroundColor3 = tint,
				BackgroundTransparency = 0.85,
				BorderSizePixel = 0,
			})
			U.corner(pip, UDim.new(1, 0))
			table.insert(self.Rings[side], pip)
		end
		local displayName = if data.PlayerIds
				and data.PlayerIds[side] == (Players.LocalPlayer and Players.LocalPlayer.UserId or 0)
			then "YOU • " .. string.upper(def.Name)
			else string.upper(def.Name)
		U.text(panel, "Name", displayName, UDim2.fromScale(0.7, 0.25), UDim2.fromScale(0.26, 0.08), Theme.Fonts.Heading)
		self.Bars[side] = Bar.new(panel, UDim2.fromScale(0.69, 0.28), UDim2.fromScale(0.26, 0.35), true)
		local hearts = U.text(panel, "Hearts", "♥ ♥ ♥", UDim2.fromScale(0.28, 0.19), UDim2.fromScale(0.26, 0.68))
		hearts.TextColor3 = tint
		self.Status[side] = U.text(
			panel,
			"Status",
			def.Type,
			UDim2.fromScale(0.42, 0.2),
			UDim2.fromScale(0.55, 0.67),
			Theme.Fonts.Caption
		)
		self.CrackLabels[side] = hearts
	end
	U.text(self.Gui, "VS", "VS", UDim2.fromScale(0.08, 0.09), UDim2.fromScale(0.46, 0.07), Theme.Fonts.Heading)
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
	U.make("Frame", rail, {
		Name = "PerfectBand",
		Size = UDim2.fromScale(2 * m.SweetSpotWidth / (m.AimMax - m.AimMin), 2),
		Position = UDim2.fromScale(lo, -0.5),
		BackgroundColor3 = Theme.Colors.Highlight,
		BorderSizePixel = 0,
	})
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
	self.Banners = {}
	for side = 1, 2 do
		local label = U.text(
			self.Gui,
			"PowerBanner" .. side,
			"",
			UDim2.fromScale(0.44, 0.1),
			UDim2.fromScale(if side == 1 then 0.03 else 0.53, 0.38),
			Theme.Fonts.Heading
		)
		label.UITextSizeConstraint.MaxTextSize = Theme.TextSize.Heading
		self.Banners[side] = label
	end
	self:Update({ Hp = maxima, Power = { 0, 0 }, Shield = {}, Frozen = {}, Rage = {} })
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
	self.AimPanel.Visible, self.Lock.Visible = phase == "Aiming", phase == "Aiming"
	self.Headline.Text = text or ""
	self.Instruction.Text = if phase == "Aiming" then "Drag to pull • aim for gold" else ""
end

function Hud:Update(r)
	for side = 1, 2 do
		local hp = r.Hp[side]
		if not self.LastHP[side] or math.abs(hp - self.LastHP[side]) >= 0.1 then
			Bar.set(self.Bars[side], hp, self.Maxima[side])
			self.LastHP[side] = hp
		end
		local cracks = 0
		for _, threshold in Balance.Feel.CrackThresholds do
			if hp / self.Maxima[side] <= threshold then
				cracks += 1
			end
		end
		self.CrackLabels[side].Text = string.rep("♥ ", self.Hearts[side])
			.. string.rep("◇ ", Balance.Match.Hearts - self.Hearts[side])
			.. string.rep("·", cracks)
		for i, pip in self.Rings[side] do
			pip.BackgroundTransparency = if i <= math.ceil((r.Power[side] or 0) * 16) then 0 else 0.85
		end
		self.Status[side].Text = if r.Frozen[side]
			then "FROZEN"
			elseif r.Shield[side] then "SHIELD"
			elseif r.Rage[side] then "RAGE"
			elseif r.Pump and r.Pump[side] then "BIG SWING"
			elseif r.Slam and r.Slam[side] then "SLAM"
			else ""
		if r.Effect and self.Status[side].Text ~= "" then
			local remaining = math.max(table.unpack(r.Effect[side]))
			self.Status[side].Text ..= string.format(" %.1fs", remaining)
		end
	end
end

function Hud:Banner(side, text, tint, quiet)
	local label = self.Banners[side]
	label.UITextSizeConstraint.MaxTextSize = if quiet then Theme.TextSize.Body else Theme.TextSize.Heading
	label.Text, label.TextColor3, label.TextTransparency = text, tint, 0
	if self["BannerTween" .. side] then
		self["BannerTween" .. side]:Cancel()
	end
	local tween = TweenService:Create(
		label,
		TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0.8),
		{ TextTransparency = 1 }
	)
	self["BannerTween" .. side] = tween
	tween:Play()
end

function Hud:Edge(tint)
	local frame = U.make(
		"Frame",
		self.Gui,
		{ Name = "PowerEdge", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 },
		true
	)
	local stroke = U.make("UIStroke", frame, { Thickness = 6, Color = tint, Transparency = 0.35 })
	TweenService:Create(stroke, TweenInfo.new(Balance.Feel.PowerEdgeSeconds), { Transparency = 1 }):Play()
	Debris:AddItem(frame, Balance.Feel.PowerEdgeSeconds)
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
	self.LockConnection:Disconnect()
	self.Gui:Destroy()
end

return Hud
