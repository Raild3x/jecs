--!strict
-- Checks what SKILL.md says about typing. Not run by lune: it needs a type checker.
-- Copy the project's jecs.luau next to this file, then, with luau-lsp installed:
--   luau-lsp analyze --platform=standard --flag:LuauSolverV2=false types.luau   (old solver)
--   luau-lsp analyze --platform=standard --flag:LuauSolverV2=true types.luau    (new solver)
-- Every line marked EXPECT must be reported as a TypeError. Checked with luau-lsp 1.70.1:
-- the old solver reports the three marked "both", the new solver reports all five.
local jecs = require("./jecs")

local Health = jecs.component<<number>>()
local Name = jecs.component() :: jecs.Entity<string>
local world = jecs.world()
local e = world:entity()
world:set(e, Health, 5)

local _wrongGet: string = world:get(e, Health) -- EXPECT both: world:get returns number?
local _wrongGet2: number = world:get(e, Name) -- EXPECT both: world:get returns string?
for _, health, name in world:query(Health, Name) do
	local _wrongQuery: string = health -- EXPECT new solver only: query values are typed
	local _wrongQuery2: number = name -- EXPECT new solver only
end
world:set(e, Health, "not a number") -- EXPECT both: world:set checks the value
