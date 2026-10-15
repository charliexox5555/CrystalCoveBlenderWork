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
screen:Render(started + 0.7)
check(screen.Animation.Rows[2].Clip.Visible and not screen.Animation.Rows[3].Clip.Visible, "Second card next")
screen:Render(started + 1.3)
check(screen.Animation.Rows[3].Clip.Visible, "Third card last")
for i, id in quote.Offers do
	check(screen.Animation.Rows[i].Stream[screen.Animation.Rows[i].Target] == id, "Server pinned target")
end
screen:Render(started + 2)
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
check(count == 12, "Complete installed owned collection")
screen:ChooseAny("mason_jar")
check(sends.Any == 1 and sends.Id == "mason_jar" and sends.Quote.PickAnyCost == 0, "One free round-only pick")
update({ Picked = "mason_jar" })
check(table.concat(quote.Offers, ",") == "pop,jam,milk_bottle", "Pick Any doesn't alter displayed hand")
update({ Picked = false, Round = 2, PickAnyCost = 6, SelectionRevision = 1 })
screen:OpenPicker()
screen:ChooseAny("mason_jar")
check(screen.Panel.Confirm.Visible and sends.Any == 1, "Paid pick requires confirmation")
check(screen.Panel.Confirm.Body.Text:find("6 Marbles", 1, true) ~= nil, "Exact price shown")
screen:Confirm()
screen:Confirm()
check(sends.Any == 2 and sends.Quote.PickAnyCost == 6, "Paid pick sends once")
update({ Marbles = 0 })
screen:OpenPicker()
screen:ChooseAny("pop")
check(sends.Any == 2 and screen.Message.Text:find("6", 1, true) ~= nil, "Insufficient balance doesn't send")
update({ Marbles = 100 })
screen:ConfirmReroll()
check(screen.Panel.Confirm.Visible, "Paid reroll confirmation")
local n = 0
for _, row in screen.Panel.Confirm.Odds:GetChildren() do
	if row:IsA("TextLabel") then
		n += 1
		check(row.Text:find("25.00%", 1, true) ~= nil, "Uniform inclusion odds")
	end
end
check(n == 12, "Every outcome disclosed")
screen:Confirm()
screen:Confirm()
check(sends.Reroll == 1 and sends.Quote.RerollCost == 3, "One quoted reroll request")
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
		check(o.TextFits, "Text fit " .. o:GetFullName())
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
