-- "A clean stage": while anything holds it, the lobby HUD shows only the wallet (Currency). Wallet-only reward screens,
-- the onboarding claim cards, Kiln openings and offer popups all ask for it here, like TouchGate.
-- They used to each save and restore the HUD children's Visible themselves. Those saves don't nest: a popup open under
-- a reward screen saved "hidden", and closing in the other order put the PLAY / Shop / Inventory column away for good
-- (creator, mobile, 2026-10-22). So nothing is saved: the last release puts each child back to what it shows when
-- nothing is open (natural).
local Players = game:GetService("Players")
local Stage = { Owners = {} }

local function hud(): ScreenGui?
	local pg = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	local gui = pg and pg:FindFirstChild("LobbyHUD")
	return if gui and gui:IsA("ScreenGui") then gui else nil
end

-- What a HUD child shows with nothing open: offer tiles the server put away carry DealHidden (DealsController), and the
-- "step on a pad" hint hides while queued.
function Stage.natural(child: GuiObject): boolean
	if child:GetAttribute("DealHidden") then
		return false
	end
	if child.Name == "Hint" then
		local pg = child:FindFirstAncestorOfClass("PlayerGui")
		return not (pg and pg:GetAttribute("Queued"))
	end
	return true
end

function Stage.held(): boolean
	return next(Stage.Owners) ~= nil
end

-- Hides everything but the wallet, or puts each child back to natural. Navigation goes last when showing: its Visible
-- change makes DealsController place the offer tiles again.
function Stage.apply()
	local gui = hud()
	if not gui then
		return
	end
	local held = Stage.held()
	local nav = gui:FindFirstChild("Navigation")
	for _, child in gui:GetChildren() do
		if child:IsA("GuiObject") and child.Name ~= "Currency" and child ~= nav then
			child.Visible = not held and Stage.natural(child)
		end
	end
	if nav and nav:IsA("GuiObject") then
		nav.Visible = not held
	end
end

function Stage.hide(owner)
	if Stage.Owners[owner] then
		return
	end
	Stage.Owners[owner] = true
	Stage.apply()
end

function Stage.show(owner)
	if not Stage.Owners[owner] then
		return
	end
	Stage.Owners[owner] = nil
	if not Stage.held() then
		Stage.apply()
	end
end

-- LobbyController's watchdog: owners left behind once the lobby is free (a screen destroyed without its close).
function Stage.reset(): { string }
	local names = {}
	for owner in Stage.Owners do
		table.insert(names, if type(owner) == "table" and owner.StageName then owner.StageName else tostring(owner))
	end
	table.clear(Stage.Owners)
	Stage.apply()
	return names
end

return Stage
