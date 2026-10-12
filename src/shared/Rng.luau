--!strict
-- Small deterministic random number generator (Park-Miller), used by tests and the balance
-- simulator so results are repeatable. In live gameplay pass a function wrapping Random.new().
--
--   local rng = Rng.new(42)
--   rng() --> number in [0, 1)

export type RngFn = () -> number

local Rng = {}

local MODULUS = 2147483647
local MULTIPLIER = 16807

function Rng.new(seed: number): RngFn
	local state = math.floor(seed) % MODULUS
	if state <= 0 then
		state = state + MODULUS - 1
	end
	return function(): number
		state = (state * MULTIPLIER) % MODULUS
		return (state - 1) / (MODULUS - 1)
	end
end

return Rng
