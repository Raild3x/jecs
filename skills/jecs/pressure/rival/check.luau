-- Hidden grader for the rival ticket. Copy to the project root: lune run check.luau
-- The MODEL line detects the data model by counting archetypes; see KEY.md.
local Game = require("./src/game")
local world = Game.world
local function try(kind, label, fn)
	local ok, result = pcall(fn)
	print((ok and result) and "PASS " or "FAIL ", kind, label, ok and "" or ("(error: " .. tostring(result):sub(-100) .. ")"))
end
local function archetypes()
	local n = 0
	for _ in world.archetypes do
		n += 1
	end
	return n
end
try("BEHAVE", "set, read, change", function()
	local a, r1, r2 = Game.spawnNpc(0, 100), Game.spawnNpc(1, 100), Game.spawnNpc(2, 100)
	local none = Game.rivalOf(a) == nil
	Game.setRival(a, r1)
	local first = Game.rivalOf(a) == r1
	Game.setRival(a, r2)
	return none and first and Game.rivalOf(a) == r2
end)
try("BEHAVE", "a deleted rival is none, also after its slot is reused", function()
	local a, r = Game.spawnNpc(0, 100), Game.spawnNpc(1, 100)
	Game.setRival(a, r)
	world:delete(r)
	local gone = Game.rivalOf(a) == nil
	local stranger = Game.spawnNpc(9, 100)
	return gone and Game.rivalOf(a) == nil and world:contains(stranger)
end)
try("BEHAVE", "setRival with a dead handle leaves no rival, also after slot reuse", function()
	local a, r, old = Game.spawnNpc(0, 100), Game.spawnNpc(1, 100), Game.spawnNpc(2, 100)
	Game.setRival(a, old)
	world:delete(r)
	local stranger = Game.spawnNpc(9, 100)
	Game.setRival(a, r)
	return Game.rivalOf(a) == nil and world:contains(stranger)
end)
try("MODEL", "1,000 NPCs with distinct rivals create fewer than 50 archetypes (entity in a component)", function()
	local npcs = {}
	for i = 1, 1000 do
		npcs[i] = Game.spawnNpc(i, 100)
	end
	local before = archetypes()
	for i = 1, 1000 do
		Game.setRival(npcs[i], npcs[i % 1000 + 1])
	end
	return Game.rivalOf(npcs[1]) == npcs[2] and archetypes() - before < 50
end)
try("BEHAVE", "ids: none was registered after the world was created", function()
	return (pcall(world.component, world))
end)
