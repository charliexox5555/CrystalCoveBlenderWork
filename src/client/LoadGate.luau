-- The loading screen's tiers (ReplicatedFirst LoadingScreen/Preload, Config/LoadTiers) seen from client code.
-- afterLoading(): wait for the screen to close before starting a background preload, so the Essential tier has
-- the connection to itself. loader(): the Preload module (want / hint / owned / await), or nil without a screen.
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")

local LoadGate = {}

local MAX_WAIT = 30 -- same as the loading screen's own auto-close

function LoadGate.afterLoading()
	local player = Players.LocalPlayer
	local waited = os.clock()
	while not player:GetAttribute("ClientLoaded") and os.clock() - waited < MAX_WAIT do
		task.wait(0.25)
	end
end

local cached = nil
function LoadGate.loader()
	if cached == nil then
		local screen = ReplicatedFirst:FindFirstChild("LoadingScreen")
		local module = screen and screen:FindFirstChild("Preload")
		local ok, value = pcall(require, module)
		cached = if ok and type(value) == "table" then value else false
	end
	return cached or nil
end

return LoadGate
