-- Private lab adapter: reuse the game's damage/status presentation without its aim/menu controls.
local FightHud = require(script.Parent.Parent.UI.Screens.FightHud)
local Feedback = {}
Feedback.__index = Feedback

function Feedback.new(gui)
	return setmetatable({ Gui = gui, Popups = {} }, Feedback)
end

function Feedback:Popup(text, position, tint, lane, key, scale)
	-- Near passes already have motion/audio; reserve words for damage and meaningful power outcomes.
	if text == "WHOOSH" then
		return
	end
	FightHud.Popup(self, text, position, tint, lane, key, scale)
	self.Gui:SetAttribute("FeedbackCount", (self.Gui:GetAttribute("FeedbackCount") or 0) + 1)
	self.Gui:SetAttribute("LastFeedback", text)
end

-- Keep the existing no-announcement-banner presentation policy.
Feedback.Banner, Feedback.Edge = FightHud.Banner, FightHud.Edge

function Feedback:Phase(phase)
	self.Gui:SetAttribute("FeedbackPhase", phase)
end

function Feedback:Reset()
	for _, popup in self.Popups do
		popup:Destroy()
	end
	self.Popups = {}
end

return Feedback
