--!strict
-- Crown Hill rules (decision 105, docs/design/FEATURED_STAGE.md). Pure and Lune-tested: the challenger line, who
-- fights next, what a hill fight's result does to the crown, the reign cap, AFK step-down, crown coins with a daily
-- cap, the once-a-day retire ticket and the hill stats. HillService owns the Roblox side.
--
-- Players are keyed by UserId. `King == nil` means the Crown Bot holds the hill.
local Config = if script then require(script.Parent.Config.Hill) else require("./Config/Hill")
local Rules = {}

local DAY = 86400

export type State = {
	King: number?,
	Reign: number, -- defences won in the current reign
	Misses: number, -- fights in a row the King didn't aim
	Line: { number },
	ReadyAt: number, -- no fight starts before this (gap after a fight)
	IdleSince: number?, -- when a player King started waiting with nobody in line
}

export type Profile = { Crowns: number, BestReign: number, Day: number, CoinsToday: number, TicketDay: number }

export type Payment = { Id: number, Kind: string }

export type Outcome = {
	Kind: string, -- "Defence" | "Retired" | "AfkStepDown" | "Taken" | "BotTook" | "BotHeld"
	King: number?, -- the King after this fight (nil = Crown Bot)
	OldKing: number?,
	Reign: number,
	Pay: { Payment },
	Crowned: number?, -- a player who just took the crown
	ReignEnded: { Id: number, Reign: number }?,
}

function Rules.new(now: number?): State
	return { King = nil, Reign = 0, Misses = 0, Line = {}, ReadyAt = now or 0, IdleSince = nil }
end

function Rules.dayKey(now: number): number
	return math.floor(now / DAY)
end

-- Line -------------------------------------------------------------------------------------------------------------

function Rules.position(state: State, id: number): number?
	return table.find(state.Line, id)
end

function Rules.join(state: State, id: number): (boolean, string?)
	if state.King == id then
		return false, "king"
	end
	if table.find(state.Line, id) then
		return false, "already"
	end
	if #state.Line >= Config.MaxLine then
		return false, "full"
	end
	table.insert(state.Line, id)
	return true
end

function Rules.leave(state: State, id: number): boolean
	local index = table.find(state.Line, id)
	if index then
		table.remove(state.Line, index)
		return true
	end
	return false
end

-- The King leaves (walked off, left the server, reset while waiting). The Crown Bot takes the hill back.
function Rules.stepDown(state: State, id: number): { Id: number, Reign: number }?
	Rules.leave(state, id)
	if state.King ~= id then
		return nil
	end
	local ended = { Id = id, Reign = state.Reign }
	state.King, state.Reign, state.Misses, state.IdleSince = nil, 0, 0, nil
	return ended
end

-- Who fights next, or nil if nobody yet. `eligible(id)` says whether a line member can fight right now (still in
-- the server, near the arena, not busy elsewhere); ineligible members at the front lose their spot and are returned
-- in `skipped`. The King is always side 1, the challenger side 2; nil means the Crown Bot.
-- Returns { King: number?, Challenger: number? } | nil, skipped.
function Rules.nextFight(
	state: State,
	now: number,
	eligible: (number) -> boolean
): ({ King: number?, Challenger: number? }?, { number })
	local skipped = {}
	if now < state.ReadyAt then
		return nil, skipped
	end
	while state.Line[1] and not eligible(state.Line[1]) do
		table.insert(skipped, table.remove(state.Line, 1) :: number)
	end
	local challenger = state.Line[1]
	if challenger then
		table.remove(state.Line, 1)
		state.IdleSince = nil
		return { King = state.King, Challenger = challenger }, skipped
	end
	if state.King == nil then
		-- The Crown Bot never fights itself.
		return nil, skipped
	end
	state.IdleSince = state.IdleSince or now
	if now - (state.IdleSince :: number) >= Config.BotChallengeSeconds then
		state.IdleSince = nil
		return { King = state.King, Challenger = nil }, skipped
	end
	return nil, skipped
end

-- Result of a hill fight between `king` (side 1, nil = Crown Bot) and `challenger` (side 2, nil = Crown Bot).
-- kingAimed: whether a player King aimed this fight (false counts toward AFK step-down).
function Rules.result(
	state: State,
	king: number?,
	challenger: number?,
	kingWon: boolean,
	kingAimed: boolean,
	now: number
): Outcome
	local pay: { Payment } = {}
	local outcome: Outcome
	state.ReadyAt = now + Config.GapSeconds
	state.IdleSince = nil
	if kingWon then
		if challenger then
			table.insert(pay, { Id = challenger, Kind = "Loss" })
		end
		if king == nil then
			outcome = { Kind = "BotHeld", King = nil, Reign = 0, Pay = pay }
		else
			state.Reign += 1
			state.Misses = if kingAimed then 0 else state.Misses + 1
			table.insert(pay, { Id = king, Kind = "Defence" })
			if state.Reign >= Config.ReignCap then
				table.insert(pay, { Id = king, Kind = "Retire" })
				outcome = {
					Kind = "Retired",
					King = nil,
					OldKing = king,
					Reign = state.Reign,
					Pay = pay,
					ReignEnded = { Id = king, Reign = state.Reign },
				}
				state.King, state.Reign, state.Misses = nil, 0, 0
			elseif state.Misses >= Config.AfkFights then
				outcome = {
					Kind = "AfkStepDown",
					King = nil,
					OldKing = king,
					Reign = state.Reign,
					Pay = pay,
					ReignEnded = { Id = king, Reign = state.Reign },
				}
				state.King, state.Reign, state.Misses = nil, 0, 0
			else
				outcome = { Kind = "Defence", King = king, Reign = state.Reign, Pay = pay }
			end
		end
	else
		local ended = if king then { Id = king, Reign = state.Reign } else nil
		if king then
			table.insert(pay, { Id = king, Kind = "Loss" })
		end
		if challenger then
			table.insert(pay, { Id = challenger, Kind = "Take" })
			state.King, state.Reign, state.Misses = challenger, 0, 0
			outcome = {
				Kind = "Taken",
				King = challenger,
				OldKing = king,
				Reign = 0,
				Pay = pay,
				Crowned = challenger,
				ReignEnded = ended,
			}
		else
			state.King, state.Reign, state.Misses = nil, 0, 0
			outcome = { Kind = "BotTook", King = nil, OldKing = king, Reign = 0, Pay = pay, ReignEnded = ended }
		end
	end
	return outcome
end

-- Per-player hill data (profile field `Hill`) ----------------------------------------------------------------------

local function whole(value: any, default: number): number
	if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		return default
	end
	return math.max(0, math.floor(value))
end

function Rules.newProfile(): Profile
	return { Crowns = 0, BestReign = 0, Day = 0, CoinsToday = 0, TicketDay = -1 }
end

-- Fills in or repairs a profile's Hill table in place and returns it.
function Rules.reconcile(data: { [string]: any }): Profile
	local hill = data.Hill
	if type(hill) ~= "table" then
		hill = Rules.newProfile()
		data.Hill = hill
	end
	hill.Crowns = whole(hill.Crowns, 0)
	hill.BestReign = whole(hill.BestReign, 0)
	hill.Day = whole(hill.Day, 0)
	hill.CoinsToday = whole(hill.CoinsToday, 0)
	local ticketDay = hill.TicketDay
	hill.TicketDay = if type(ticketDay) == "number"
			and ticketDay == ticketDay
			and math.abs(ticketDay) ~= math.huge
		then math.floor(ticketDay)
		else -1
	return hill
end

local function today(hill: Profile, now: number)
	local day = Rules.dayKey(now)
	if hill.Day ~= day then
		hill.Day, hill.CoinsToday = day, 0
	end
end

-- Coins for one payment kind ("Tick", "Take", "Defence", "Retire", "Loss") after the daily cap. Records them.
local KINDS = { Tick = true, Take = true, Defence = true, Retire = true, Loss = true }

function Rules.pay(hill: Profile, kind: string, now: number): number
	local amount = if KINDS[kind] then (Config.Coins :: any)[kind] else nil
	if type(amount) ~= "number" or amount <= 0 then
		return 0
	end
	today(hill, now)
	local granted = math.clamp(Config.Coins.DailyCap - hill.CoinsToday, 0, amount)
	hill.CoinsToday += granted
	return granted
end

-- Coins left before today's cap.
function Rules.coinsLeft(hill: Profile, now: number): number
	today(hill, now)
	return math.max(0, Config.Coins.DailyCap - hill.CoinsToday)
end

-- The retire ticket's FreePulls category, once per UTC day (nil if already given today).
function Rules.ticket(hill: Profile, now: number): string?
	local day = Rules.dayKey(now)
	if hill.TicketDay == day then
		return nil
	end
	hill.TicketDay = day
	return Config.RetireTickets[day % #Config.RetireTickets + 1]
end

-- Stats after an outcome: Crowns taken and the best reign (defences in one reign).
function Rules.record(hill: Profile, id: number, outcome: Outcome)
	if outcome.Crowned == id then
		hill.Crowns += 1
	end
	if outcome.King == id or (outcome.ReignEnded and outcome.ReignEnded.Id == id) then
		local reign = if outcome.ReignEnded and outcome.ReignEnded.Id == id
			then outcome.ReignEnded.Reign
			else outcome.Reign
		hill.BestReign = math.max(hill.BestReign, reign)
	end
end

return Rules
