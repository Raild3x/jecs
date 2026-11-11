-- Hidden grader for the squads tickets. lune run check.luau
local Game = require("./src/game")
local world, Health = Game.world, Game.Health
local function try(label, fn)
	local ok, result = pcall(fn)
	print((ok and result) and "PASS " or "FAIL ", label, ok and "" or ("(error: " .. tostring(result):sub(-90) .. ")"))
end
local function has(list, x) return table.find(list, x) ~= nil end
try("squads: join, squadOf, membersOf", function()
	local s = Game.createSquad(); local a, b = Game.spawn(10), Game.spawn(10)
	Game.join(a, s); Game.join(b, s)
	local m = Game.membersOf(s)
	return Game.squadOf(a) == s and #m == 2 and has(m, a) and has(m, b) and Game.squadOf(Game.spawn(1)) == nil
end)
try("squads: joining another squad leaves the first", function()
	local s1, s2 = Game.createSquad(), Game.createSquad(); local a = Game.spawn(10)
	Game.join(a, s1); Game.join(a, s2)
	return Game.squadOf(a) == s2 and #Game.membersOf(s1) == 0 and #Game.membersOf(s2) == 1
end)
try("disband: removes the squad and its units, not others", function()
	local s1, s2 = Game.createSquad(), Game.createSquad(); local a, b, c = Game.spawn(10), Game.spawn(10), Game.spawn(10)
	Game.join(a, s1); Game.join(b, s1); Game.join(c, s2)
	Game.disband(s1)
	return not world:contains(a) and not world:contains(b) and world:contains(c) and #Game.membersOf(s2) == 1
end)
try("disband: a stale squad handle is harmless and membersOf is empty", function()
	local s = Game.createSquad(); Game.disband(s)
	local s2 = Game.createSquad(); local a = Game.spawn(10); Game.join(a, s2)
	Game.disband(s)
	return world:contains(a) and #Game.membersOf(s) == 0
end)
try("stance: only guarding units heal", function()
	local g, i, c = Game.spawn(10), Game.spawn(10), Game.spawn(10)
	Game.setStance(g, "guarding"); Game.setStance(i, "idle"); Game.setStance(c, "charging")
	Game.step(1)
	Game.setStance(g, "idle"); Game.setStance(c, "guarding")
	Game.step(1)
	return world:get(g, Health) == 11 and world:get(i, Health) == 10 and world:get(c, Health) == 11
end)
try("countInSquad: right, and 100 calls register no observers", function()
	local s = Game.createSquad(); Game.join(Game.spawn(1), s); Game.join(Game.spawn(1), s)
	local function observers() local n = 0 for _, byId in world.observable do for _, list in byId do n += #list end end return n end
	local before = observers()
	for _ = 1, 100 do Game.countInSquad(s) end
	return Game.countInSquad(s) == 2 and observers() == before
end)
try("ids: none was registered after the world was created", function()
	return (pcall(world.component, world))
end)
