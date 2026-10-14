local Calibration = require("../src/server/Simulation/Calibration")
local serde = require("@lune/serde")
local process = require("@lune/process")
if process.args[1] == "aim" then
	print(serde.encode("json", Calibration.round("prism", "lemonade_bottle", 101).AimLog, true))
else
	print(
		serde.encode("json", Calibration.run(tonumber(process.args[1]) or 40, tonumber(process.args[2]) or 100), true)
	)
end
