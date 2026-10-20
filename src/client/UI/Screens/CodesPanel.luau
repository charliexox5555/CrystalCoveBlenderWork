-- Drives StarterGui.CodesScreen (design: docs/ui/screens/CodesScreen.md; rules: decision 99).
-- REDEEM (or Enter in the field) sends the code; Result(ok, message) shows the server's answer in Status.
local Screen = {}
Screen.__index = Screen

local OK_TEXT, ERROR_TEXT = Color3.fromHex("#86EDB8"), Color3.fromHex("#FF8EA0")
local BUSY_TINT = Color3.fromRGB(150, 150, 150)
local MIN_GAP = 1.1 -- seconds between sends (the server allows one per Balance.Retention.CodeRateSeconds)
local TIMEOUT = 4

function Screen.bind(gui, onRedeem)
	local content = gui:FindFirstChild("Content", true)
	local field = content and content:FindFirstChild("InputField")
	local self = setmetatable({
		Gui = gui,
		Input = field and field:FindFirstChild("CodeInput"),
		Focus = field and field:FindFirstChild("FocusOutline"),
		Button = content and content:FindFirstChild("RedeemButton"),
		Status = content and content:FindFirstChild("Status"),
		OnRedeem = onRedeem,
		SentAt = 0,
	}, Screen)
	if self.Input then
		self.Input.Focused:Connect(function()
			if self.Focus then
				self.Focus.Visible = true
			end
		end)
		self.Input.FocusLost:Connect(function(enterPressed)
			if self.Focus then
				self.Focus.Visible = false
			end
			if enterPressed then
				self:Submit()
			end
		end)
	end
	if self.Button and self.Button:IsA("GuiButton") then
		self.Button.Activated:Connect(function()
			self:Submit()
		end)
	end
	gui:GetPropertyChangedSignal("Enabled"):Connect(function()
		if not gui.Enabled then
			self:Show(nil)
		end
	end)
	return self
end

function Screen:Show(message, ok)
	local status = self.Status
	if not status then
		return
	end
	status.Text = message or ""
	status.Visible = message ~= nil
	status.TextColor3 = if ok then OK_TEXT else ERROR_TEXT
end

function Screen:SetBusy(busy)
	self.Busy = busy
	local button = self.Button
	if not button then
		return
	end
	local art, label = button:FindFirstChild("Artwork"), button:FindFirstChild("Label")
	if art then
		art.ImageColor3 = if busy then BUSY_TINT else Color3.new(1, 1, 1)
	end
	if label then
		label.Text = if busy then "…" else "REDEEM"
	end
end

function Screen:Submit()
	local code = self.Input and self.Input.Text:match("^%s*(.-)%s*$") or ""
	if self.Busy then
		return
	end
	if code == "" then
		self:Show("Type a code first!", false)
		return
	end
	if os.clock() - self.SentAt < MIN_GAP then
		self:Show("Slow down!", false)
		return
	end
	self.SentAt = os.clock()
	self:SetBusy(true)
	self:Show(nil)
	self.OnRedeem(code)
	local sent = self.SentAt
	task.delay(TIMEOUT, function()
		if self.Busy and self.SentAt == sent then
			self:SetBusy(false)
			self:Show("No answer. Try again in a moment", false)
		end
	end)
end

function Screen:Result(ok, message)
	self:SetBusy(false)
	self:Show(message, ok)
	if ok and self.Input then
		self.Input.Text = ""
	end
end

return Screen
