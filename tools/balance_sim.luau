-- Prints the balance report outside Studio:  lune run tools/balance_sim [battlesPerMatchup]
local process = require("@lune/process")
local balanceSim = require("../src/tests/BalanceSim")

print(balanceSim(tonumber(process.args[1])))
