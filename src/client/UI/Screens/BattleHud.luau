local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local RS = game:GetService("ReplicatedStorage")
local Formula = require(RS.Shared.Formula)
local Balance = require(RS.Shared.Config.Balance)
local Theme = require(script.Parent.Parent.Theme)
local C = script.Parent.Parent.Components
local U, Panel = require(C.Util), require(C.Panel)
local ProgressBar, Pill = require(C.ProgressBar), require(C.Pill)
local Hud = {}
Hud.__index = Hud

local function crackStage(hp, maxHP)
	local stage = 0
	for _, threshold in Balance.Feel.CrackThresholds do
		if hp / maxHP <= threshold then
			stage += 1
		end
	end
	return stage
end
local function card(parent, fighter, position)
	local root = Panel.new(parent, fighter.Id, UDim2.fromScale(0.43, 1), position)
	local name = U.text(
		root,
		"Name",
		fighter.Name,
		UDim2.fromScale(0.63, 0.32),
		UDim2.fromScale(0.04, 0.04),
		Theme.Fonts.Heading
	)
	name.TextXAlignment = Enum.TextXAlignment.Left
	U.text(root, "Level", "Lv " .. fighter.Level, UDim2.fromScale(0.25, 0.26), UDim2.fromScale(0.7, 0.08))
	Pill.new(root, fighter.Type, UDim2.fromScale(0.44, 0.27), UDim2.fromScale(0.04, 0.4))
	local cracks = U.text(root, "Cracks", "", UDim2.fromScale(0.43, 0.24), UDim2.fromScale(0.52, 0.42))
	cracks.TextColor3 = Theme.Colors.Highlight
	local bar = ProgressBar.new(root, UDim2.fromScale(0.92, 0.22), UDim2.fromScale(0.04, 0.72))
	ProgressBar.set(bar, fighter.HP, fighter.MaxHP)
	return { Root = root, Bar = bar, Cracks = cracks, Maximum = fighter.MaxHP }
end

function Hud.new(a, b)
	local self = setmetatable({}, Hud)
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	self.Gui = U.make("ScreenGui", playerGui, {
		Name = "BattleHud",
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
		ResetOnSpawn = false,
		DisplayOrder = 20,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})
	self.Effects = U.make("ScreenGui", playerGui, {
		Name = "BattleEffects",
		ScreenInsets = Enum.ScreenInsets.None,
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		DisplayOrder = 21,
	})
	local top = U.make("Frame", self.Gui, {
		Name = "Top",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.02),
		Size = UDim2.fromScale(0.95, 0.19),
	})
	U.make("UISizeConstraint", top, { MaxSize = Vector2.new(1100, 90) })
	self.Cards = { A = card(top, a, UDim2.fromScale(0, 0)), B = card(top, b, UDim2.fromScale(0.57, 0)) }
	U.text(top, "VS", "VS", UDim2.fromScale(0.1, 0.6), UDim2.fromScale(0.45, 0.15), Theme.Fonts.Heading)
	self.Counter =
		U.text(self.Gui, "ClashCounter", "PRACTICE CLASH", UDim2.fromScale(0.5, 0.06), UDim2.fromScale(0.25, 0.23))
	local controls = U.make("Frame", self.Gui, {
		Name = "Controls",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.96),
		Size = UDim2.fromScale(0.9, 0.18),
	})
	U.make("UISizeConstraint", controls, { MinSize = Vector2.new(0, 70), MaxSize = Vector2.new(900, 90) })
	local meter = Panel.new(controls, "PowerMeter", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0))
	self.Instruction = U.text(
		meter,
		"Instruction",
		"HOLD SCREEN • RELEASE ON GOLD",
		UDim2.fromScale(0.94, 0.24),
		UDim2.fromScale(0.03, 0.07)
	)
	self.Track = U.make("Frame", meter, {
		Name = "Track",
		Size = UDim2.fromScale(0.92, 0.29),
		Position = UDim2.fromScale(0.04, 0.41),
		BackgroundColor3 = Theme.Meter.Weak.Bottom,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	})
	U.corner(self.Track, Theme.Radius.Bar)
	local bounds = Formula.meterBounds(a.Swing)
	-- Layers form the symmetric Weak | Good | Great | Perfect | ... bar.
	for _, zone in { "Good", "Great", "Perfect" } do
		local half = bounds[zone]
		local band = U.make("Frame", self.Track, {
			Name = zone,
			Position = UDim2.fromScale(0.5 - half, 0),
			Size = UDim2.fromScale(half * 2, 1),
			BorderSizePixel = 0,
			BackgroundColor3 = Color3.new(1, 1, 1),
		})
		U.gradient(band, Theme.Meter[zone].Top, Theme.Meter[zone].Bottom)
	end
	self.Needle = U.make("Frame", self.Track, {
		Name = "Needle",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.new(0, 4, 1.7, 0),
		BackgroundColor3 = Theme.Colors.Text,
		BorderSizePixel = 0,
		ZIndex = 3,
	})
	U.corner(self.Needle, UDim.new(0, 2))
	U.make("UIStroke", self.Needle, { Color = Theme.Colors.PanelBottom, Thickness = 1 })
	self.Zone = U.text(
		meter,
		"Zone",
		"WEAK  /  GOOD  /  GREAT  /  PERFECT",
		UDim2.fromScale(0.94, 0.18),
		UDim2.fromScale(0.03, 0.77)
	)
	self.Banner =
		U.text(self.Gui, "Banner", "", UDim2.fromScale(0.85, 0.16), UDim2.fromScale(0.075, 0.38), Theme.Fonts.PopUp)
	self.Banner.UITextSizeConstraint.MaxTextSize = 64
	self.Subtitle = U.text(self.Gui, "Subtitle", "", UDim2.fromScale(0.8, 0.08), UDim2.fromScale(0.1, 0.55))
	self.Flash = U.make("Frame", self.Effects, {
		Name = "Flash",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 10,
	})
	self.Alive = true
	return self
end

function Hud:SetClash(index)
	self.Counter.Text = "CLASH " .. index
	self.Instruction.Text = "HOLD SCREEN • RELEASE ON GOLD"
	self.Banner.Text, self.Subtitle.Text = "", ""
end
function Hud:SetMeter(elapsed, holding, enabled, swing)
	self.Needle.Position = UDim2.fromScale(Formula.needlePosition(elapsed), 0.5)
	self.Instruction.Text = enabled and (holding and "HOLDING • RELEASE ON GOLD" or "HOLD SCREEN • RELEASE ON GOLD")
		or "GET READY"
	if enabled then
		self.Zone.Text = string.upper(Formula.zoneFromRelease(elapsed, swing))
	end
end
function Hud:Release()
	self.Instruction.Text = "BOOST LOCKED • KEEP SWINGING"
end
function Hud:UpdateHP(hpA, hpB)
	for side, hp in { A = hpA, B = hpB } do
		local c = self.Cards[side]
		ProgressBar.set(c.Bar, hp, c.Maximum)
		local stage = crackStage(hp, c.Maximum)
		c.Cracks.Text = stage > 0 and ("CRACK " .. string.rep("I", stage)) or ""
	end
end
function Hud:Popup(text, worldPosition, color)
	if not self.Alive then
		return
	end
	local point = workspace.CurrentCamera:WorldToViewportPoint(worldPosition)
	local label = U.text(
		self.Effects,
		"Popup",
		text,
		UDim2.fromOffset(230, 65),
		UDim2.fromOffset(point.X - 115, point.Y - 45),
		Theme.Fonts.PopUp
	)
	label.TextColor3 = color or Theme.Colors.Text
	label.UITextSizeConstraint.MaxTextSize = 38
	label.ZIndex = 5
	U.make("UIStroke", label, { Thickness = Theme.Stroke.PopUp, Color = Theme.Colors.PanelBottom, Transparency = 0.2 })
	TweenService:Create(
		label,
		TweenInfo.new(0.85, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Position = label.Position - UDim2.fromOffset(0, 55), TextTransparency = 1 }
	):Play()
	Debris:AddItem(label, 1)
end
function Hud:Shattered(won)
	self.Flash.BackgroundTransparency = 0.12
	TweenService:Create(self.Flash, TweenInfo.new(0.13), { BackgroundTransparency = 1 }):Play()
	self.Banner.Text = "SHATTERED!"
	self.Banner.TextColor3 = Theme.Colors.Highlight
	self.Subtitle.Text = won and "YOU WIN • NICE CLASH" or "JAM WINS • YOUR GLASSY IS SAFE"
	self.Instruction.Text = "PRACTICE COMPLETE"
end
function Hud:Destroy()
	self.Alive = false
	self.Gui:Destroy()
	self.Effects:Destroy()
end
return Hud
