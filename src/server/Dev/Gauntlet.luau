-- Manual Studio-only entry point for the relaunch slice. Nothing in Main/Services requires this module.
-- Reuses the real swing, powers and rules through LoopLab.Session; progress lives in memory, no profiles.
local Gauntlet = {}

function Gauntlet.start()
	assert(game:GetService("RunService"):IsStudio(), "The Gauntlet slice is private to Studio")
	if Gauntlet.Stop then
		Gauntlet.Stop()
	end
	local RS = game:GetService("ReplicatedStorage")
	local G = require(RS.Shared.Config.Gauntlet)
	local B = require(RS.Shared.Config.Balance)
	local Rules = require(RS.Shared.GauntletRules)
	local FightRules = require(RS.Shared.FightRules)
	local Session = require(script.Parent.LoopLab.Session)
	local runtime = Instance.new("Folder")
	runtime.Name = "GauntletRuntime"
	local remote = Instance.new("RemoteEvent")
	remote.Name, remote.Parent = "Action", runtime
	runtime.Parent = RS

	local players, limits, reports, serial, connections = {}, {}, {}, 0, {}

	local function nextSeed()
		serial += 1
		return G.Seed + serial
	end

	local function newDuel(state, now)
		state.Duel = Session.new("B", state.Selected, nextSeed(), now, {
			Rival = state.Run.Rival,
			HookGap = G.HookGap,
			PlayerHp = G.PlayerHp,
			RivalHp = Rules.rivalHpScale(state.Collection, state.Run, state.Selected),
			Radius = G.Radius,
			AimSeconds = G.AimSeconds,
		})
		state.Outcome, state.HoldUntil = nil, nil
		state.Duels += 1
	end

	local function beginRun(state, now)
		local c = state.Collection
		state.Run = Rules.newRun(c, nextSeed())
		if not c.Owned[state.Selected] then
			state.Selected = G.Starter
		end
		state.StartedAt = now
		newDuel(state, now)
		-- Only a run's first duel asks for a launch; everything after it flows on its own.
		state.Aim, state.Yaw = nil, nil
	end

	local function packet(state)
		local data = state.Duel:packet()
		local c, run = state.Collection, state.Run
		data.Collection = {
			Owned = c.Owned,
			Shards = c.Shards,
			Needed = Rules.shardsNeeded(c),
			Best = c.Best,
			Coins = c.Coins,
			Runs = c.Runs,
		}
		data.Run = {
			Hearts = run.Hearts,
			Rung = run.Rung,
			Wins = run.Wins,
			Coins = run.Coins,
			Unlocked = run.Unlocked,
			Over = run.Over,
			Rival = run.Rival,
			Boss = Rules.isBoss(run.Rung),
		}
		data.Selected = state.Selected
		data.Outcome = state.Outcome
		data.RunOver = state.RunOver
		return data
	end

	local function report(state, now)
		table.insert(reports, {
			Runs = state.Collection.Runs,
			Wins = state.Run.Wins,
			Hearts = state.Run.Hearts,
			Duels = state.Duels,
			Seconds = now - state.StartedAt,
			FirstShatterSeconds = state.FirstShatterSeconds,
			Unlocked = #state.Run.Unlocked,
		})
	end

	table.insert(
		connections,
		remote.OnServerEvent:Connect(function(player, action, a, b)
			local now = workspace:GetServerTimeNow()
			local record = limits[player] or {}
			if now - (record[action] or -math.huge) < G.RateSeconds then
				return
			end
			if type(action) ~= "string" then
				return
			end
			record[action], limits[player] = now, record
			local state = players[player]
			if action == "Stop" then
				players[player] = nil
			elseif action == "Begin" then
				if not state then
					state = {
						Collection = Rules.newCollection(),
						Selected = G.Starter,
						Duels = 0,
						JoinedAt = now,
					}
					players[player] = state
					beginRun(state, now)
				elseif state.RunOver then
					state.RunOver = nil
					beginRun(state, now) -- a voluntary PLAY AGAIN: the only replay signal this slice reports
				end
				remote:FireClient(player, packet(state))
			elseif action == "Launch" and state and state.Duel.Phase == "Aim" then
				if type(a) ~= "number" or type(b) ~= "number" or a ~= a or b ~= b then
					return
				end
				a, b = FightRules.clampAim(a), FightRules.clampYaw(b)
				if state.Duel:launch(a, b, now) then
					state.Aim, state.Yaw = a, b
				end
			elseif action == "Switch" and state then
				if type(a) == "string" and state.Collection.Owned[a] then
					state.Selected = a -- takes effect next duel; the fight on screen is never interrupted
					if state.Duel.Phase == "Aim" and state.Duel.Id ~= a then
						newDuel(state, now) -- not launched yet, so the swap is immediate
					end
				end
			end
		end)
	)

	local accumulator, snapshotAt = 0, 0
	table.insert(
		connections,
		game:GetService("RunService").Heartbeat:Connect(function(dt)
			accumulator += math.min(dt, 0.1)
			local now = workspace:GetServerTimeNow()
			while accumulator >= G.Step do
				for _, state in players do
					if state.RunOver then
						continue
					end
					state.Duel:step(G.Step, now)
					if state.Duel.Phase == "Result" and not state.Outcome then
						state.FirstShatterSeconds = state.FirstShatterSeconds or (now - state.JoinedAt)
						state.Outcome = Rules.applyResult(state.Collection, state.Run, state.Duel.Winner == 1)
						state.HoldUntil = now + G.BeatSeconds + (if state.Outcome.Unlocked then G.UnlockSeconds else 0)
					elseif state.HoldUntil and now >= state.HoldUntil then
						state.HoldUntil = nil
						if state.Outcome.Over then
							state.RunOver = true
							report(state, now)
						else
							newDuel(state, now)
							state.Duel:launch(state.Aim or B.Motion.AimDefault, state.Yaw or 0, now)
						end
					end
				end
				accumulator -= G.Step
			end
			if now < snapshotAt then
				return
			end
			snapshotAt = now + G.SnapshotSeconds
			for player, state in players do
				remote:FireClient(player, packet(state))
			end
		end)
	)
	table.insert(
		connections,
		game.Players.PlayerRemoving:Connect(function(player)
			players[player], limits[player] = nil, nil
		end)
	)
	local dev = Instance.new("BindableFunction")
	dev.Name, dev.Parent = "GauntletReport", game.ServerStorage
	dev.OnInvoke = function()
		return reports
	end
	function Gauntlet.Stop()
		for _, c in connections do
			c:Disconnect()
		end
		runtime:Destroy()
		dev:Destroy()
		Gauntlet.Stop = nil
	end
	return "Gauntlet server ready (Studio only, nothing saved)"
end

return Gauntlet
