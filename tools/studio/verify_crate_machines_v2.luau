-- Client Play fixture (no purchases): Crate Machines v2 in the Finisher/Flyer opening, shop preview and lobby.
-- Checks template use, title, anticipation (core grows), lid opening inside the frame, launch origin and reset.
local player = game.Players.LocalPlayer
local dev = player.PlayerScripts:FindFirstChild("LobbyClientDev")
if dev then
	dev:Invoke("Close")
end
local Client = player.PlayerScripts.Client
local Screen = require(Client.UI.Screens.KilnScreen)
local K = require(Client.UI.Theme).Kiln
local O = require(game.ReplicatedStorage.Shared.Config.CrateMachines).Opening
local Machine = require(Client.Presentation.CrateMachine)
local Item = require(Client.UI.Components.ItemPresentation)
local checks, fails = 0, {}
local function check(ok, message)
	checks += 1
	if not ok then
		table.insert(fails, message)
	end
end
local data = {
	Odds = { { Id = "pop", Rarity = "Starter", Chance = 1 } },
	Cost = 300,
	TenCost = 2700,
	Coins = 0,
	Marbles = 0,
	Quote = "fixture",
}
for category, id in { Finishers = "starfall", Rideables = "prism_ray" } do
	for _, currency in { "Coins", "Marbles" } do
		local s = Screen.new(data, function() end, function()
			error("No fixture purchases")
		end, function() end)
		s:Pending(category, currency)
		s:Result({
			Category = category,
			Currency = currency,
			Results = { { Id = id, Count = 1 } },
			Odds = { { Id = id, Chance = 1 } },
		})
		task.wait(0.1)
		s:Step(7)
		s:Step(K.LandHold)
		local o = s.Opening
		local tag = category .. "/" .. currency
		local fx = o.FireFX
		check(fx and fx.Machine ~= nil, tag .. ": not a v2 machine")
		local model = fx.Machine.Model
		check(
			model:GetAttribute("Category") == category and model:GetAttribute("Currency") == currency,
			tag .. ": wrong machine"
		)
		check(
			s.Window.Title.Text:find(if category == "Finishers" then "BURST DOME" else "CLOUD GLOBE") ~= nil,
			tag .. ": title"
		)
		local core, lid = model.RevealCore, model.RevealLid
		local coreSize, lidY = core.Size, lid.Position.Y
		s:Step(O.ChargeSeconds * 0.9)
		task.wait(0.1)
		check(core.Size.Magnitude > coreSize.Magnitude * 1.15, tag .. ": core did not grow")
		check(math.abs(lid.Position.Y - lidY) < 0.05, tag .. ": lid moved early")
		s:Step(O.ChargeSeconds * 0.1 + O.ReleaseSeconds)
		task.wait(0.1)
		check(lid.Position.Y > lidY + O.LidLiftStuds * 0.8, tag .. ": lid did not open")
		local cam = fx.View.CurrentCamera
		local p = cam.CFrame:PointToObjectSpace(lid.Position + Vector3.yAxis * lid.Size.Y / 2)
		check(p.Y < -p.Z * math.tan(math.rad(cam.FieldOfView) / 2), tag .. ": lid leaves the frame")
		s:Step(O.FireSeconds)
		task.wait(0.05)
		check(o.Phase == "Launch", tag .. ": phase " .. tostring(o.Phase))
		-- Measure in the same frame: the core keeps idling (bob/spin) between frames.
		o:LaunchStep(0)
		local first, mouth = o.Cards[1].Object, fx:Pixel()
		task.wait(0.05)
		check((first.AbsolutePosition + first.AbsoluteSize / 2 - mouth).Magnitude < 3, tag .. ": launch origin")
		o:Skip()
		s:Destroy()
		task.wait()
		check(math.abs(lid.Position.Y - lidY) < 0.01, tag .. ": lid not reset")
		check(not game.SoundService:FindFirstChild("KilnOpeningAudio"), tag .. ": leaked sound")
	end
end
-- Shop-style preview: Item.crate uses the machine and idle-animates it.
local gui = Instance.new("ScreenGui")
gui.Name, gui.Parent = "CM2Fixture", player.PlayerGui
local holder = Instance.new("Frame")
holder.Size, holder.Parent = UDim2.fromOffset(300, 300), gui
local vp, world = Item.crate(holder, "Rideables", "Coins", UDim2.fromScale(1, 1), UDim2.new())
check(Machine.forViewport(vp) ~= nil, "preview not animated")
local prop = world:FindFirstChild("SpinProp1", true)
local before = prop.CFrame
task.wait(0.3)
check(not prop.CFrame:FuzzyEq(before, 1e-4), "propeller idle not moving")
gui:Destroy()
-- Lobby: tagged machines near the player animate with pooled effects.
local placed, lit = 0, 0
for _, m in game:GetService("CollectionService"):GetTagged("CrateMachine") do
	if m:IsDescendantOf(workspace) then
		placed += 1
	end
end
for _, l in workspace:GetDescendants() do
	if l.Name == "CrateMachineLight" then
		lit += 1
	end
end
return { Checks = checks, Failed = fails, PlacedMachines = placed, ActiveEffects = lit }
