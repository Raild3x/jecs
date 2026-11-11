-- Hidden grader for the inherit tickets. Copy to the project root: lune run check.luau
-- Run it under a time limit: a thorns loop that never ends would hang it.
local Game = require("./src/game")
local world = Game.world
local Position, Velocity, Health, Thorns = Game.Position, Game.Velocity, Game.Health, Game.Thorns

local passed, total = 0, 0
local function try(label, fn)
	total += 1
	local ok, result = pcall(fn)
	if ok and result then
		passed += 1
	end
	print((ok and result) and "PASS " or "FAIL ", label, ok and "" or ("(error: " .. tostring(result):sub(-100) .. ")"))
end
local function has(list, x)
	return table.find(list, x) ~= nil
end
local function observers()
	local n = 0
	for _, byId in world.observable do
		for _, list in byId do
			n += #list
		end
	end
	return n
end

-- First, while the lobby pair is the only use of CarriedBy.
try("4 carried: the lobby lantern is deleted with the keeper", function()
	local keeper, lantern = Game.keeper, Game.lantern
	world:delete(keeper)
	return not world:contains(lantern)
end)
try("4 carried: a new item is deleted with its carrier, others stay", function()
	local a, b = Game.spawnNpc(0, 10), Game.spawnNpc(0, 10)
	local ia, ib = Game.spawnItem(a), Game.spawnItem(b)
	world:delete(a)
	return not world:contains(ia) and world:contains(ib) and world:contains(b)
end)

try("0 existing: an NPC without a target keeps the velocity others gave it", function()
	local n = Game.spawnNpc(5, 10)
	world:set(n, Velocity, 2)
	Game.step(1)
	return world:get(n, Position) == 7 and world:get(n, Velocity) == 2
end)

try("1 targets: steer toward the target, before moving", function()
	local a, b, t = Game.spawnNpc(0, 10), Game.spawnNpc(20, 10), Game.spawnNpc(10, 10)
	Game.setTarget(a, t)
	Game.setTarget(b, t)
	Game.step(1)
	local okMove = world:get(a, Position) == 1 and world:get(b, Position) == 19
	world:set(a, Position, 10)
	Game.step(1)
	return okMove and Game.targetOf(a) == t and world:get(a, Velocity) == 0 and world:get(a, Position) == 10
end)
try("1 targets: a deleted target is no target, also after its slot is reused", function()
	local a, t = Game.spawnNpc(0, 10), Game.spawnNpc(10, 10)
	Game.setTarget(a, t)
	Game.step(1)
	world:delete(t)
	local stranger = Game.spawnNpc(-50, 10)
	local gone = Game.targetOf(a) == nil
	Game.step(1)
	return gone and Game.targetOf(a) == nil and world:get(a, Velocity) == 0 and world:contains(stranger)
end)
try("1 targets: setTarget with a dead handle gives no target", function()
	local a, t = Game.spawnNpc(0, 10), Game.spawnNpc(10, 10)
	world:delete(t)
	local stranger = Game.spawnNpc(-50, 10)
	Game.setTarget(a, t)
	Game.step(1)
	return Game.targetOf(a) == nil and world:get(a, Velocity) == 0 and world:contains(stranger)
end)
try("1 targets: retargeting keeps the newest target", function()
	local a, t1, t2 = Game.spawnNpc(0, 10), Game.spawnNpc(10, 10), Game.spawnNpc(-10, 10)
	Game.setTarget(a, t1)
	Game.setTarget(a, t2)
	Game.step(1)
	return Game.targetOf(a) == t2 and world:get(a, Velocity) == -1
end)
try("1 targets: 1,000 NPCs with distinct targets create fewer than 50 archetypes", function()
	local before = #world.archetypes
	local npcs = {}
	for i = 1, 1000 do
		npcs[i] = Game.spawnNpc(i, 10)
	end
	for i = 1, 1000 do
		Game.setTarget(npcs[i], npcs[i % 1000 + 1])
	end
	Game.step(0)
	local grown = #world.archetypes - before
	local right = Game.targetOf(npcs[1]) == npcs[2]
	for _, npc in npcs do
		world:delete(npc)
	end
	return right and grown < 50
end)

try("2 zones: enter, zoneOf, npcsIn, one zone per NPC", function()
	local z1, z2 = Game.createZone(), Game.createZone()
	local a, b = Game.spawnNpc(0, 10), Game.spawnNpc(0, 10)
	Game.enterZone(a, z1)
	Game.enterZone(b, z1)
	local first = Game.npcsIn(z1)
	local okFirst = #first == 2 and has(first, a) and has(first, b) and Game.zoneOf(a) == z1
	Game.enterZone(a, z2)
	return okFirst and Game.zoneOf(a) == z2 and #Game.npcsIn(z1) == 1 and #Game.npcsIn(z2) == 1 and Game.zoneOf(Game.spawnNpc(0, 1)) == nil
end)
try("2 zones: deleting a zone leaves its NPCs alive and in no zone", function()
	local z = Game.createZone(3)
	local a = Game.spawnNpc(0, 10)
	Game.enterZone(a, z)
	world:delete(z)
	Game.step(1)
	return world:contains(a) and Game.zoneOf(a) == nil and world:get(a, Health) == 10
end)
try("2 zones: a zone that no longer exists is ignored, also after its slot is reused", function()
	local z = Game.createZone()
	world:delete(z)
	local a = Game.spawnNpc(0, 10)
	Game.enterZone(a, z)
	local free = Game.zoneOf(a) == nil
	local z2 = Game.createZone()
	Game.enterZone(a, z)
	return free and Game.zoneOf(a) == nil and #Game.npcsIn(z2) == 0 and #Game.npcsIn(z) == 0
end)
try("2 zones: only zones with regen heal, by regen * dt", function()
	local healing, plain = Game.createZone(4), Game.createZone()
	local a, b, c = Game.spawnNpc(0, 10), Game.spawnNpc(0, 10), Game.spawnNpc(0, 10)
	Game.enterZone(a, healing)
	Game.enterZone(b, plain)
	Game.step(0.5)
	local once = world:get(a, Health) == 12 and world:get(b, Health) == 10 and world:get(c, Health) == 10
	Game.enterZone(a, plain)
	Game.enterZone(b, healing)
	Game.step(0.5)
	return once and world:get(a, Health) == 12 and world:get(b, Health) == 12
end)

try("3 count: right, 0 for a deleted zone, and 100 calls register no observers", function()
	local z = Game.createZone()
	Game.enterZone(Game.spawnNpc(0, 1), z)
	Game.enterZone(Game.spawnNpc(0, 1), z)
	local dead = Game.createZone()
	world:delete(dead)
	Game.countIn(z)
	local before = observers()
	for _ = 1, 100 do
		Game.countIn(z)
	end
	return Game.countIn(z) == 2 and Game.countIn(dead) == 0 and observers() == before
end)
try("3 step: 100 steps register no observers", function()
	Game.step(0)
	local before = observers()
	for _ = 1, 100 do
		Game.step(0)
	end
	return observers() == before
end)

try("5 damage: nothing changes until step; several hits on one target all land", function()
	local a = Game.spawnNpc(0, 100)
	Game.damage(a, 10)
	Game.damage(a, 5)
	local untouched = world:get(a, Health) == 100
	Game.step(0)
	return untouched and world:get(a, Health) == 85
end)
try("5 damage: thorns hits the attacker in the following step", function()
	local thorny, attacker = Game.spawnNpc(0, 100), Game.spawnNpc(0, 100)
	world:set(thorny, Thorns, 3)
	Game.damage(thorny, 10, attacker)
	Game.step(0)
	local first = world:get(thorny, Health) == 90 and world:get(attacker, Health) == 100
	Game.step(0)
	return first and world:get(attacker, Health) == 97 and world:get(thorny, Health) == 90
end)
try("5 damage: a hit without an attacker triggers no thorns", function()
	local thorny = Game.spawnNpc(0, 100)
	world:set(thorny, Thorns, 3)
	Game.damage(thorny, 10)
	Game.step(0)
	Game.step(0)
	return world:get(thorny, Health) == 90
end)
try("5 damage: two thorned NPCs trade one hit per step and the frame returns", function()
	local a, b = Game.spawnNpc(0, 100), Game.spawnNpc(0, 100)
	world:set(a, Thorns, 2)
	world:set(b, Thorns, 2)
	Game.damage(a, 10, b)
	Game.step(0) -- a 90
	Game.step(0) -- b 98
	Game.step(0) -- a 88
	return world:get(a, Health) == 88 and world:get(b, Health) == 98
end)
try("5 damage: called from a query loop and from a changed listener", function()
	local npcs = {}
	for i = 1, 20 do
		npcs[i] = Game.spawnNpc(0, 50)
	end
	local watched = npcs[1]
	local echoed = false
	local disconnect = world:changed(Health, function(entity)
		if entity == watched and not echoed then
			echoed = true
			Game.damage(watched, 1)
		end
	end)
	for npc in world:query(Game.Npc) do
		if table.find(npcs, npc) then
			Game.damage(npc, 2)
		end
	end
	Game.step(0)
	local first = world:get(npcs[20], Health) == 48 and world:get(watched, Health) == 48
	Game.step(0)
	disconnect()
	return first and echoed and world:get(watched, Health) == 47
end)
try("5 damage: a hit on an entity deleted before the step is harmless, also after slot reuse", function()
	local a = Game.spawnNpc(0, 100)
	Game.damage(a, 10)
	world:delete(a)
	local stranger = Game.spawnNpc(0, 100)
	Game.step(0)
	return world:get(stranger, Health) == 100
end)
try("5 dead: every NPC at or below 0 Health is deleted at the end of the step, with its items", function()
	local zone = Game.createZone()
	local npcs, items = {}, {}
	for i = 1, 60 do
		npcs[i] = Game.spawnNpc(i, if i % 3 == 0 then 50 else 5)
		items[i] = Game.spawnItem(npcs[i])
		Game.enterZone(npcs[i], zone)
		Game.damage(npcs[i], 5, npcs[i % 60 + 1])
	end
	for i = 1, 60 do
		Game.setTarget(npcs[i], npcs[i % 60 + 1])
	end
	Game.step(0)
	for i = 1, 60 do
		local shouldLive = i % 3 == 0
		if world:contains(npcs[i]) ~= shouldLive or world:contains(items[i]) ~= shouldLive then
			return false
		end
	end
	Game.step(1)
	return #Game.npcsIn(zone) == 20
end)

try("6 speed: follows a Velocity written directly by another module", function()
	local a = Game.spawnNpc(0, 10)
	world:set(a, Velocity, -3)
	local direct = Game.speedOf(a) == 3
	Game.setTarget(a, Game.spawnNpc(10, 10))
	Game.step(1)
	return direct and Game.speedOf(a) == 1
end)

try("ids: none was registered after the world was created", function()
	return (pcall(world.component, world))
end)
print(`{passed}/{total} checks passed`)
