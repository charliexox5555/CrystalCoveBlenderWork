assert(game:GetService("RunService"):IsClient())
local p = game.Players.LocalPlayer
p.PlayerScripts.LobbyClientDev:Invoke("Close")
local hud = p.PlayerGui.LobbyHUD
local oldHUD = hud.Enabled
hud.Enabled = false
local modules = p.PlayerScripts.Client.UI:Clone()
modules.Name, modules.Parent = "HandSelectionQA", p.PlayerScripts
local Selection = require(modules.Screens.MatchSelection)
local Glassies = require(game.ReplicatedStorage.Shared.Config.Glassies)
local K = require(modules.Theme).Selection
local checks = 0
local function check(v, m)
	assert(v, m)
	checks += 1
end
local collection = {}
for _, g in game.ReplicatedStorage.Assets.Glassies:GetChildren() do
	collection[g.Name] = {}
end
local sends = { Pick = 0, Any = 0, Reroll = 0 }
local screen = Selection.new({
	Names = { "YOU", "BOT" },
	Hearts = { 3, 3 },
	Deadline = workspace:GetServerTimeNow() + 600,
	Round = 1,
	MatchId = "qa",
}, function()
	sends.Pick += 1
end, function(q)
	sends.Reroll += 1
	sends.Quote = q
end, function(id, q)
	sends.Any += 1
	sends.Id = id
	sends.Quote = q
end)
local quote = {
	MatchId = "qa",
	Round = 1,
	HandRevision = 0,
	SelectionRevision = 0,
	Offers = { "pop", "jam", "milk_bottle" },
	Collection = collection,
	CanReroll = true,
	PaidRandomAllowed = true,
	PickAnyCost = 0,
	RerollCost = 3,
	Marbles = 100,
	Animate = true,
}
screen:Offers(quote)
task.wait(0.2)
local started = screen.AnimationStarted
screen:Render(started + 0.1)
check(screen.Animation.Rows[1].Clip.Visible and not screen.Animation.Rows[2].Clip.Visible, "First card only")
screen:Render(started + K.CardSeconds + K.CardGap + 0.1)
check(screen.Animation.Rows[2].Clip.Visible and not screen.Animation.Rows[3].Clip.Visible, "Second card next")
screen:Render(started + 2 * (K.CardSeconds + K.CardGap) + 0.1)
check(screen.Animation.Rows[3].Clip.Visible, "Third card last")
for i, id in quote.Offers do
	check(screen.Animation.Rows[i].Stream[screen.Animation.Rows[i].Target] == id, "Server pinned target")
end
screen:Render(started + 3 * K.CardSeconds + 2 * K.CardGap + K.LandHold + 0.01)
check(not screen.Animation and not game.SoundService:FindFirstChild("HandRollAudio"), "Roll/audio finish cleanly")
local function update(changes)
	local next = table.clone(quote)
	next.Animate = false
	for k, v in changes or {} do
		next[k] = v
	end
	quote = next
	screen:Offers(next)
end
update()
check(screen.Gui:GetAttribute("RollAnimationCount") == 1, "Status update doesn't repeat roll")
screen:OpenPicker()
check(screen.Panel.PickAnyChooser.Visible, "Owned picker opens")
local count = 0
for _, o in screen.Panel.PickAnyChooser.Grid.Tiles:GetChildren() do
	if o:IsA("GuiObject") then
		count += 1
		check(collection[o.Name] ~= nil, "Only owned picker items")
	end
end
check(count == #Glassies.ReleaseList, "Complete installed owned collection")
screen:ChooseAny("mason_jar")
check(sends.Any == 1 and sends.Id == "mason_jar" and sends.Quote.PickAnyCost == 0, "One free round-only pick")
update({ Picked = "mason_jar" })
check(table.concat(quote.Offers, ",") == "pop,jam,milk_bottle", "Pick Any doesn't alter displayed hand")
update({ Picked = false, Round = 2, PickAnyCost = 6, SelectionRevision = 1 })
screen:OpenPicker()
screen:ChooseAny("mason_jar")
check(not screen.Panel.Confirm.Visible and sends.Any == 2, "Paid pick sends without confirmation")
check(sends.Quote.PickAnyCost == 6, "Exact paid-pick quote")
screen:ChooseAny("mason_jar")
check(sends.Any == 2, "Busy guard prevents repeat send")
local requests = 0
local requestConnection = screen.MarblesRequested.Event:Connect(function()
	requests += 1
end)
update({ Marbles = 0 })
check(screen.Panel.PickAny.Visible and screen.Panel.Reroll.Visible, "Low-balance buttons remain visible")
screen:OpenPicker()
screen:ChooseAny("pop")
task.wait()
check(
	sends.Any == 2 and requests == 1 and screen.Gui:GetAttribute("RequestedMarbles") == 6,
	"Insufficient Pick Any requests future store hook without spending"
)
update({ Marbles = 0 })
screen:RerollNow()
task.wait()
check(sends.Reroll == 0 and requests == 2, "Insufficient reroll requests store hook without spending")
update({ Marbles = 100 })
check(
	screen.Panel.RerollOdds.Visible and screen.Panel.RerollOdds.Text:find("12.50%%"),
	"Uniform odds shown inline before spending"
)
screen:OpenPicker(true)
local n = 0
for _, row in screen.Panel.PickAnyChooser.Grid.Tiles:GetChildren() do
	if row:IsA("Frame") then
		n += 1
		check(row.InclusionOdds.Text == "12.50%", "Every outcome disclosed")
	end
end
check(n == 24, "All owned outcomes listed")
screen.Panel.PickAnyChooser.Visible, screen.Modal = false, false
screen:RerollNow()
screen:RerollNow()
check(
	not screen.Panel.Confirm.Visible and sends.Reroll == 1 and sends.Quote.RerollCost == 3,
	"Single-tap quoted reroll with busy guard"
)
requestConnection:Disconnect()
update({ PaidRandomAllowed = false, CanReroll = false })
check(not screen.Panel.Reroll.Visible, "Restricted reroll hidden")
update({ PaidRandomAllowed = true, CanReroll = true })
screen:OpenPicker()
task.wait(0.2)
for _, o in screen.Gui:GetDescendants() do
	if o:IsA("GuiButton") then
		check(o.AnchorPoint == Vector2.new(0.5, 0.5), "Centered anchors")
	end
	if o:IsA("TextLabel") and o.Visible and not o:FindFirstAncestor("Templates") then
		local visible = true
		local ancestor = o.Parent
		while ancestor and ancestor ~= screen.Gui do
			if ancestor:IsA("GuiObject") and not ancestor.Visible then
				visible = false
			end
			ancestor = ancestor.Parent
		end
		if visible then
			check(o.TextFits, "Text fit " .. o:GetFullName())
		end
	end
end
screen:Destroy()
check(not p.PlayerGui:FindFirstChild("RollScreen"), "Close cleans picker/modal")
local interrupted = Selection.new(
	{ Names = { "YOU", "BOT" }, Deadline = workspace:GetServerTimeNow() + 60 },
	function() end,
	function() end,
	function() end
)
quote.Animate = true
quote.Picked = nil
interrupted:Offers(quote)
task.wait(0.1)
interrupted:Render(interrupted.AnimationStarted + 0.1)
interrupted:Destroy()
check(not game.SoundService:FindFirstChild("HandRollAudio"), "Interrupted reel audio cleanup")
modules:Destroy()
hud.Enabled = oldHUD
return { Passed = true, Checks = checks, Requests = sends.Any + sends.Reroll, SendsWereFixtures = true }
