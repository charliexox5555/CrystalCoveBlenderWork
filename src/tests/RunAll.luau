-- Runs every test suite. In Studio (through the MCP's run_code):
--   require(game.ServerStorage.Tests.RunAll)()
-- Outside Studio: lune run tools/run_tests

local Deps = if script then require(script.Parent.Deps) else require("./Deps")
local Harness = if script then require(script.Parent.Harness) else require("./Harness")

local suites = {
	ConfigTests = if script then require(script.Parent.ConfigTests) else require("./ConfigTests"),
	FormulaTests = if script then require(script.Parent.FormulaTests) else require("./FormulaTests"),
	BalanceTests = if script then require(script.Parent.BalanceTests) else require("./BalanceTests"),
}
local order = { "ConfigTests", "FormulaTests", "BalanceTests" }

return function(): (boolean, string)
	local passed, failed, lines = 0, 0, {}
	for _, name in order do
		local t = Harness.new(name)
		suites[name](t, Deps)
		passed += t.passed
		failed += t.failed
		for _, f in t.failures do
			table.insert(lines, "FAIL " .. f)
		end
	end
	table.insert(lines, string.format("%d passed, %d failed", passed, failed))
	local report = table.concat(lines, "\n")
	print(report)
	return failed == 0, report
end
