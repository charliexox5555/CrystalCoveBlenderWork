-- Keeps every piece of UI text inside its button, label or panel (UI/Components/TextFit): templates cloned
-- from StarterGui, screens built in code and pop-ups alike. Billboards and SurfaceGuis in the world are
-- included when they live in PlayerGui.
local Players = game:GetService("Players")
local Controller = {}

function Controller:Start()
	-- Required here, not at the top: Main requires every controller unguarded, so a problem in the fit
	-- module must never stop the other controllers from starting.
	local ok, TextFit = pcall(require, script.Parent.Parent.UI.Components.TextFit)
	if not ok then
		warn("[GlassClash] TextFit unavailable: " .. tostring(TextFit))
		return
	end
	self.Connection = TextFit.guard(Players.LocalPlayer:WaitForChild("PlayerGui"))
end

return Controller
