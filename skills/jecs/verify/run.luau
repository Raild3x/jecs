-- In the jecs repository: runs both checks against src/jecs.luau.
-- From this folder: lune run run.luau
local fs = require("@lune/fs")
local process = require("@lune/process")

fs.writeFile("jecs.luau", fs.readFile("../../../src/jecs.luau"))

local failed = false
for _, script in { "facts.luau", "examples.luau" } do
	print("== " .. script)
	local result = process.exec("lune", { "run", script }, { stdio = "inherit" })
	failed = failed or not result.ok
end
process.exit(if failed then 1 else 0)
