-- Runs all tests outside Studio:  lune run tools/run_tests
local process = require("@lune/process")
local runAll = require("../src/tests/RunAll")

local ok = runAll()
process.exit(if ok then 0 else 1)
