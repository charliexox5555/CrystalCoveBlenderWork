-- Merges release_matrix shard files and prints win rates.
--   lune run tools/release_matrix_report <dir>
local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")
local Glassies = require("../src/shared/Config/Glassies")

local dir = process.args[1] or "."
local rows, mode = {}, "?"
for _, name in fs.readDir(dir) do
	if string.match(name, "^shard_%d+%.json$") then
		local data = serde.decode("json", fs.readFile(dir .. "/" .. name))
		mode = data.Mode
		for _, row in data.Pairs do
			table.insert(rows, row)
		end
	end
end

local per, total = {}, { N = 0, Seconds = 0, Hits = 0, Timeouts = 0 }
local function add(id, wins, n, opponent)
	local p = per[id] or { Wins = 0, N = 0, Opp = {} }
	per[id] = p
	p.Wins += wins
	p.N += n
	if opponent then
		table.insert(p.Opp, { Id = opponent, Rate = wins / n })
	end
end
for _, r in rows do
	total.N += r.N
	total.Seconds += r.Seconds
	total.Hits += r.Hits
	total.Timeouts += r.Timeouts
	if r.A == r.B then
		add(r.A, r.WinsA, r.N)
	else
		add(r.A, r.WinsA, r.N, r.B)
		add(r.B, r.N - r.WinsA, r.N, r.A)
	end
end

local list = {}
for id, p in per do
	table.insert(list, { Id = id, Rate = p.Wins / p.N, N = p.N, Opp = p.Opp })
end
table.sort(list, function(a, b)
	return a.Rate > b.Rate
end)

print(
	string.format(
		"mode=%s rounds=%d avg %.1f s, %.1f hits, %.1f%% timeouts",
		mode,
		total.N,
		total.Seconds / math.max(1, total.N),
		total.Hits / math.max(1, total.N),
		100 * total.Timeouts / math.max(1, total.N)
	)
)
local inBand, lo, hi = 0, 1, 0
for _, e in list do
	local def = Glassies.ById[e.Id]
	table.sort(e.Opp, function(a, b)
		return a.Rate < b.Rate
	end)
	local worst = e.Opp[1]
	local best = e.Opp[#e.Opp]
	local flag = if e.Rate < 0.45 then " LOW" elseif e.Rate > 0.55 then " HIGH" else ""
	if flag == "" then
		inBand += 1
	end
	lo, hi = math.min(lo, e.Rate), math.max(hi, e.Rate)
	print(
		string.format(
			"  %-16s %-9s %-5s %5.1f%%  (n=%d)%s%s",
			e.Id,
			def and def.Rarity or "?",
			def and def.Type or "?",
			100 * e.Rate,
			e.N,
			if worst
				then string.format(
					"  worst %s %.0f%%, best %s %.0f%%",
					worst.Id,
					100 * worst.Rate,
					best.Id,
					100 * best.Rate
				)
				else "",
			flag
		)
	)
end
print(string.format("in 45-55%% band: %d/%d, spread %.1f%%-%.1f%%", inBand, #list, 100 * lo, 100 * hi))
