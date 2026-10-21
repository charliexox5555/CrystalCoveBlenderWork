-- What the player is holding: UserInputService.PreferredInput (keyboard and mouse, gamepad or touch).
-- In Studio only, a PlayerGui attribute "DevInput" ("Gamepad", "Touch" or "KeyboardAndMouse") overrides it, so
-- controller and touch layouts can be checked without the hardware (the device simulator doesn't emulate a pad).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local InputKind = {}

local STUDIO = RunService:IsStudio()

local function override()
	if not STUDIO then
		return nil
	end
	local player = Players.LocalPlayer
	local gui = player and player:FindFirstChildOfClass("PlayerGui")
	local value = gui and gui:GetAttribute("DevInput")
	if type(value) ~= "string" then
		return nil
	end
	local ok, item = pcall(function()
		return (Enum.PreferredInput :: any)[value]
	end)
	return if ok then item else nil
end

function InputKind.current(): Enum.PreferredInput
	return override() or UIS.PreferredInput
end

function InputKind.gamepad(): boolean
	return InputKind.current() == Enum.PreferredInput.Gamepad
end

function InputKind.touch(): boolean
	return InputKind.current() == Enum.PreferredInput.Touch
end

-- Calls back whenever the input kind may have changed; returns the connections (disconnect both to stop).
function InputKind.changed(callback)
	local connections = { UIS:GetPropertyChangedSignal("PreferredInput"):Connect(callback) }
	if STUDIO then
		task.spawn(function()
			local gui = Players.LocalPlayer:WaitForChild("PlayerGui")
			table.insert(connections, gui:GetAttributeChangedSignal("DevInput"):Connect(callback))
		end)
	end
	return connections
end

return InputKind
