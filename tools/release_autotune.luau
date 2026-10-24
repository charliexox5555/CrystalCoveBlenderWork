-- One damped retune step for the release kits from a release_matrix run (decision 122 retune).
--   lune run tools/release_autotune <matrix dir> [band low=0.46] [band high=0.54] [dry]
-- For every glassy outside the band, scales its kit's main strength knob by (0.5 / win rate) ^ Gain,
-- clamped to one step of MaxStep, and writes the new value into src/shared/Config/Balance.luau.
-- Run a fresh matrix after each step; the field moves as everyone is retuned together.
local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")
local Balance = require("../src/shared/Config/Balance")

local dir = process.args[1] or "."
local low, high = tonumber(process.args[2]) or 0.46, tonumber(process.args[3]) or 0.54
local dry = process.args[4] == "dry"
local Gain, MaxStep = 1.6, 0.3
local PATH = "src/shared/Config/Balance.luau"

-- The one knob that best scales each shape's strength; `Cap` keeps fractions sane.
local KNOBS = {
	ray = { Key = "Damage" },
	cone = { Key = "Damage" },
	volley = { Key = "Damage" },
	projectile = { Key = "Damage" },
	breath = { Key = "Damage" },
	zone = { Key = "Damage" },
	sweep = { Key = "Damage" },
	pulse = { Key = "Damage" },
	orbit = { Key = "Damage" },
	contact = { Key = "ContactBonus" },
	armed_contact = { Key = "ContactBonus" },
	slow_contact = { Key = "ContactBonus" },
	drain_contact = { Key = "ContactBonus" },
	boost = { Key = "ContactBonus" },
	mark_contact = { Key = "MarkDamage" },
	heal = { Key = "Heal", Cap = 0.25 },
	guard = { Key = "Duration", Cap = 5 },
}

local per = {}
for _, name in fs.readDir(dir) do
	if string.match(name, "^shard_%d+%.json$") then
		for _, r in serde.decode("json", fs.readFile(dir .. "/" .. name)).Pairs do
			for side, id in { r.A, r.B } do
				local p = per[id] or { Wins = 0, N = 0 }
				per[id] = p
				p.Wins += if side == 1 then r.WinsA else r.N - r.WinsA
				p.N += r.N
			end
		end
	end
end

local text = fs.readFile(PATH)
-- Kits are written either as a block (one key per line) or on one line: `jam = { ..., Duration = 2, ... },`.
local function setValue(id, key, value)
	local start = string.find(text, "\n\t\t" .. id .. " = {\n", 1, true)
	local stop, pattern
	if start then
		stop = string.find(text, "\n\t\t},", start, true)
		pattern = "(\n\t\t\t" .. key .. " = )([%d%.]+)(,)"
	else
		start = string.find(text, "\n\t\t" .. id .. " = { ", 1, true)
		assert(start, "kit not found: " .. id)
		stop = string.find(text, "\n", start + 1, true)
		pattern = "([ {]" .. key .. " = )([%d%.]+)([, ])"
	end
	local block = string.sub(text, start, stop)
	assert(string.match(block, pattern), id .. " has no " .. key)
	local replaced = string.gsub(block, pattern, "%1" .. value .. "%3", 1)
	text = string.sub(text, 1, start - 1) .. replaced .. string.sub(text, stop + 1)
end

local ids = {}
for id in per do
	table.insert(ids, id)
end
table.sort(ids)
for _, id in ids do
	local p = per[id]
	local rate = p.Wins / p.N
	local kit = Balance.CombatRelease.Kits[id]
	if rate >= low and rate <= high or not kit then
		continue
	end
	local knob = KNOBS[kit.Shape]
	local old = knob and kit[knob.Key]
	if type(old) ~= "number" then
		print(string.format("%-18s %5.1f%%  no knob for shape %s", id, rate * 100, tostring(kit.Shape)))
		continue
	end
	local factor = math.clamp((0.5 / math.max(rate, 0.05)) ^ Gain, 1 - MaxStep, 1 + MaxStep)
	local new = old * factor
	if knob.Cap then
		new = math.min(new, knob.Cap)
	end
	new = math.floor(new * 1000 + 0.5) / 1000
	print(string.format("%-18s %5.1f%%  %s %.3f -> %.3f", id, rate * 100, knob.Key, old, new))
	if not dry then
		setValue(id, knob.Key, tostring(new))
	end
end
if not dry then
	fs.writeFile(PATH, text)
end
