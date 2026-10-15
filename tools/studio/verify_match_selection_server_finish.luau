-- Continue verify_match_selection_server after inspecting the retained round-two UI.
local p = game.Players:GetPlayers()[1]
local data, dev = game.ServerStorage.DataDev, game.ServerStorage.MatchDev
assert(data:Invoke("Inspect", p).Mock)
local report = _G.MatchSelectionQAPart
local checks, expected = report.Checks, report.Expected
local function check(v, m)
	assert(v, m)
	checks += 1
end
local function state()
	return dev:Invoke("SelectionState", p)
end
local function attempt(kind, id, cost)
	local s = state()
	return dev:Invoke(
		"SelectionAttempt",
		p,
		kind,
		id,
		{ MatchId = s.MatchId, Round = s.Round, SelectionRevision = s.SelectionRevision, Cost = cost }
	)
end
for i, cost in { 6, 9, 12, 12 } do
	if i > 1 then
		dev:Invoke("SelectionTest", "NextRound", p)
	end
	dev:Invoke("SelectionTest", "Hold", p, 120)
	if i == 4 then
		local old = state().Marbles
		data:Invoke("Marbles", p, 11 - old)
		local ok, why = attempt("PickAny", "pop", 12)
		check(
			not ok and why == "insufficient_marbles" and state().Marbles == 11 and state().PickAnyUsed == 4,
			"No debit/use when insufficient"
		)
		data:Invoke("Marbles", p, old - 11)
		dev:Invoke("SelectionTest", "Hold", p, 0.1)
		ok, why = attempt("Reroll", nil, 9)
		check(not ok and why == "too_late" and state().Marbles == old, "No charge for late reroll")
		dev:Invoke("SelectionTest", "Hold", p, 120)
	end
	check(attempt("PickAny", "pop", cost), "Paid Pick Any tier")
	expected -= cost
	check(state().Marbles == expected and state().PickAnyUsed == i + 1, "Exact Pick Any debit")
	check(table.concat(state().Offers, ",") == report.Hand, "Hand still unchanged")
	check(not attempt("PickAny", "jam", cost), "Locked round cannot charge twice")
	check(state().Marbles == expected, "No repeat debit")
end
local saved = data:Invoke("Save", p)
for retry = 1, 3 do
	if saved.Saved and saved.Data.Marbles == expected then
		break
	end
	task.wait(0.1)
	saved = data:Invoke("Save", p)
end
check(saved.Saved and saved.Data.Marbles == expected, "Persist Marble balance")
dev:Invoke("SelectionTest", "Forfeit", p)
task.wait(0.1)
assert(dev:Invoke("Start", 1, p, nil))
dev:Invoke("SelectionTest", "Hold", p, 120)
local s = state()
check(s.RerollsUsed == 0 and s.PickAnyUsed == 0 and s.HandRevision == 0, "New match resets counters")
check(s.Marbles == expected, "Wallet survives match reset")
dev:Invoke("SelectionTest", "Forfeit", p)
return {
	Passed = true,
	Checks = checks,
	Marbles = expected,
	RerollCosts = { 3, 3, 6, 6, 9, 9, 9 },
	PickAnyCosts = {
		0,
		6,
		9,
		12,
		12,
	},
}
