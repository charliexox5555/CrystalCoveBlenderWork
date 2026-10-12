-- Tiny test harness shared by Studio and Lune runs.

export type T = {
	test: (name: string, fn: () -> ()) -> (),
	ok: (cond: any, msg: string?) -> (),
	eq: (actual: any, expected: any, msg: string?) -> (),
	near: (actual: number, expected: number, eps: number, msg: string?) -> (),
	between: (actual: number, lo: number, hi: number, msg: string?) -> (),
	passed: number,
	failed: number,
	failures: { string },
}

local Harness = {}

function Harness.new(suite: string): T
	local t = { passed = 0, failed = 0, failures = {} } :: any

	function t.test(name: string, fn: () -> ())
		local ok, err = pcall(fn)
		if ok then
			t.passed += 1
		else
			t.failed += 1
			table.insert(t.failures, string.format("[%s] %s: %s", suite, name, tostring(err)))
		end
	end

	function t.ok(cond: any, msg: string?)
		if not cond then
			error(msg or "expected condition to be true", 2)
		end
	end

	function t.eq(actual: any, expected: any, msg: string?)
		if actual ~= expected then
			error(string.format("%s: expected %s, got %s", msg or "eq", tostring(expected), tostring(actual)), 2)
		end
	end

	function t.near(actual: number, expected: number, eps: number, msg: string?)
		if math.abs(actual - expected) > eps then
			error(string.format("%s: expected %s +/- %s, got %s", msg or "near", expected, eps, actual), 2)
		end
	end

	function t.between(actual: number, lo: number, hi: number, msg: string?)
		if actual < lo or actual > hi then
			error(string.format("%s: expected between %s and %s, got %s", msg or "between", lo, hi, actual), 2)
		end
	end

	return t
end

return Harness
