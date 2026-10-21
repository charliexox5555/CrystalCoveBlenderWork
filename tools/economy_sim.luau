-- Prints the economy report outside Studio:  lune run tools/economy_sim
local economySim = require("../src/tests/EconomySim")

print(economySim.report())
print()
print(require("../src/tests/HillEconomySim").report())
