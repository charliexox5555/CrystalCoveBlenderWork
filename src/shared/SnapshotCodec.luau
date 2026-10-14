--!strict
-- Compact binary form of a fight snapshot for the 20 Hz unreliable FightSnapshot remote.
-- A table snapshot (Pendulum.snapshot + FightRules.snapshot) costs ~500-750 bytes per send; this is 128.
-- Only the wire format changes: decode() returns the same table shape the client already uses.
-- Pure Luau (buffer library), so it runs in Lune tests and in Roblox.

local Codec = {}

local SIDES = 2
local BODY_VALUES = 10 -- P.xyz, V.xyz, Twist, Spin, Tilt.X, Tilt.Z
local EFFECTS = 5 -- Shield, Frozen, Rage, Pump, Slam seconds remaining
local FLAGS = { "Rage", "Shield", "Frozen", "Pump", "Slam" }
local EFFECT_SCALE = 100 -- hundredths of a second
local POWER_SCALE = 65535

Codec.Size = 2 + 8 + 4 + SIDES * BODY_VALUES * 4 + SIDES * (4 + 2) + 2 + SIDES * EFFECTS * 2

local function u16(value: number): number
	return math.clamp(math.floor(value + 0.5), 0, 65535)
end

function Codec.encode(key: number, snapshot: { [string]: any }, sentAt: number): buffer
	local b = buffer.create(Codec.Size)
	local o = 0
	buffer.writeu16(b, o, u16(key))
	o += 2
	buffer.writef64(b, o, sentAt)
	o += 8
	buffer.writef32(b, o, snapshot.T)
	o += 4
	for side = 1, SIDES do
		local body = snapshot.B[side]
		for i = 1, BODY_VALUES do
			buffer.writef32(b, o, body[i])
			o += 4
		end
	end
	local r = snapshot.R
	local flags = 0
	for side = 1, SIDES do
		buffer.writef32(b, o, r.Hp[side])
		o += 4
		buffer.writeu16(b, o, u16(math.clamp(r.Power[side] or 0, 0, 1) * POWER_SCALE))
		o += 2
		for bit, name in FLAGS do
			if r[name][side] then
				flags = bit32.bor(flags, bit32.lshift(1, (side - 1) * #FLAGS + bit - 1))
			end
		end
	end
	buffer.writeu16(b, o, flags)
	o += 2
	for side = 1, SIDES do
		for i = 1, EFFECTS do
			buffer.writeu16(b, o, u16(r.Effect[side][i] * EFFECT_SCALE))
			o += 2
		end
	end
	return b
end

function Codec.decode(b: buffer): (number?, { [string]: any }?)
	if buffer.len(b) ~= Codec.Size then
		return nil, nil
	end
	local o = 0
	local key = buffer.readu16(b, o)
	o += 2
	local sentAt = buffer.readf64(b, o)
	o += 8
	local t = buffer.readf32(b, o)
	o += 4
	local bodies = {}
	for side = 1, SIDES do
		local body = table.create(BODY_VALUES)
		for i = 1, BODY_VALUES do
			body[i] = buffer.readf32(b, o)
			o += 4
		end
		bodies[side] = body
	end
	local r = { T = t, Hp = {}, Power = {}, Effect = {} }
	for _, name in FLAGS do
		r[name] = {}
	end
	for side = 1, SIDES do
		r.Hp[side] = buffer.readf32(b, o)
		o += 4
		r.Power[side] = buffer.readu16(b, o) / POWER_SCALE
		o += 2
	end
	local flags = buffer.readu16(b, o)
	o += 2
	for side = 1, SIDES do
		for bit, name in FLAGS do
			r[name][side] = bit32.btest(flags, bit32.lshift(1, (side - 1) * #FLAGS + bit - 1))
		end
		local effects = table.create(EFFECTS)
		for i = 1, EFFECTS do
			effects[i] = buffer.readu16(b, o) / EFFECT_SCALE
			o += 2
		end
		r.Effect[side] = effects
	end
	return key, { T = t, B = bodies, R = r, SentAt = sentAt }
end

return Codec
