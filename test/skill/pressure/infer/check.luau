-- Hidden grader for the infer tickets. Copy to the project root: lune run check.luau
-- BEHAVE lines check what the tickets ask. MODEL lines detect the data model chosen,
-- by counting the archetypes each choice creates; see KEY.md for what is expected.
local Game = require("./src/game")
local jecs = require("./Packages/jecs")
local world = Game.world

local score = { BEHAVE = { 0, 0 }, MODEL = { 0, 0 } }
local function try(kind, label, fn)
	score[kind][2] += 1
	local ok, result = pcall(fn)
	if ok and result then
		score[kind][1] += 1
	end
	print((ok and result) and "PASS " or "FAIL ", kind, label, ok and "" or ("(error: " .. tostring(result):sub(-100) .. ")"))
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
local function archetypes()
	local n = 0
	for _ in world.archetypes do
		n += 1
	end
	return n
end

try("BEHAVE", "1 focus: set, read, retarget", function()
	local a, t1, t2 = Game.spawnNpc(0, 100), Game.spawnNpc(1, 100), Game.spawnNpc(2, 100)
	local none = Game.focusOf(a) == nil
	Game.setFocus(a, t1)
	local first = Game.focusOf(a) == t1
	Game.setFocus(a, t2)
	return none and first and Game.focusOf(a) == t2
end)
try("BEHAVE", "1 focus: a deleted focus is none, also after its slot is reused", function()
	local a, t = Game.spawnNpc(0, 100), Game.spawnNpc(1, 100)
	Game.setFocus(a, t)
	world:delete(t)
	local gone = Game.focusOf(a) == nil
	local stranger = Game.spawnNpc(9, 100)
	return gone and Game.focusOf(a) == nil and world:contains(stranger)
end)
try("BEHAVE", "1 focus: setFocus with a dead handle leaves no focus, also after slot reuse", function()
	local a, t, old = Game.spawnNpc(0, 100), Game.spawnNpc(1, 100), Game.spawnNpc(2, 100)
	Game.setFocus(a, old)
	world:delete(t)
	local stranger = Game.spawnNpc(9, 100)
	Game.setFocus(a, t)
	return Game.focusOf(a) == nil and world:contains(stranger)
end)
try("MODEL", "1 focus: 1,000 NPCs with distinct focuses create fewer than 50 archetypes (entity in a component)", function()
	local npcs = {}
	for i = 1, 1000 do
		npcs[i] = Game.spawnNpc(i, 100)
	end
	local before = archetypes()
	for i = 1, 1000 do
		Game.setFocus(npcs[i], npcs[i % 1000 + 1])
	end
	local grown = archetypes() - before
	local right = Game.focusOf(npcs[1]) == npcs[2]
	for _, npc in npcs do
		world:delete(npc)
	end
	return right and grown < 50
end)

try("BEHAVE", "2 mood: default calm, set and read all three", function()
	local a = Game.spawnNpc(0, 100)
	local default = Game.moodOf(a) == "calm"
	Game.setMood(a, "wary")
	local wary = Game.moodOf(a) == "wary"
	Game.setMood(a, "panicked")
	local panicked = Game.moodOf(a) == "panicked"
	Game.setMood(a, "calm")
	return default and wary and panicked and Game.moodOf(a) == "calm"
end)
try("MODEL", "2 mood: switching mood leaves the NPC in the same archetype (value component)", function()
	local a = Game.spawnNpc(0, 100)
	Game.setMood(a, "calm")
	local home = jecs.record(world, a).archetype
	for _, mood in { "wary", "panicked", "calm", "wary" } do
		Game.setMood(a, mood)
		if jecs.record(world, a).archetype ~= home then
			return false
		end
	end
	return Game.moodOf(a) == "wary"
end)

try("BEHAVE", "3 squads: assign, squadOf, members, one squad per NPC", function()
	local s1, s2 = Game.createSquad(), Game.createSquad()
	local a, b = Game.spawnNpc(0, 100), Game.spawnNpc(0, 100)
	Game.assign(a, s1)
	Game.assign(b, s1)
	local m = Game.members(s1)
	local first = #m == 2 and has(m, a) and has(m, b) and Game.squadOf(a) == s1
	Game.assign(a, s2)
	return first and Game.squadOf(a) == s2 and #Game.members(s1) == 1 and #Game.members(s2) == 1 and Game.squadOf(Game.spawnNpc(0, 1)) == nil
end)
try("BEHAVE", "3 squads: deleting a squad leaves its NPCs alive and in no squad", function()
	local s = Game.createSquad()
	local a = Game.spawnNpc(0, 100)
	Game.assign(a, s)
	world:delete(s)
	return world:contains(a) and Game.squadOf(a) == nil
end)
try("BEHAVE", "3 squads: a squad that no longer exists is ignored, also after its slot is reused", function()
	local s = Game.createSquad()
	world:delete(s)
	local a = Game.spawnNpc(0, 100)
	Game.assign(a, s)
	local free = Game.squadOf(a) == nil
	local s2 = Game.createSquad()
	Game.assign(a, s)
	return free and Game.squadOf(a) == nil and #Game.members(s2) == 0 and #Game.members(s) == 0
end)
try("MODEL", "3 squads: 20 squads create at least 20 archetypes (a pair per squad)", function()
	local squads, npcs = {}, {}
	for i = 1, 20 do
		squads[i] = Game.createSquad()
	end
	for i = 1, 200 do
		npcs[i] = Game.spawnNpc(i, 100)
	end
	Game.assign(npcs[1], squads[1])
	for i = 1, 200 do
		Game.assign(npcs[i], squads[1])
	end
	local before = archetypes()
	for i = 1, 200 do
		Game.assign(npcs[i], squads[i % 20 + 1])
	end
	return #Game.members(squads[2]) == 10 and archetypes() - before >= 19
end)

try("BEHAVE", "4 alarm: on, off, list", function()
	local a, b, c = Game.spawnNpc(0, 100), Game.spawnNpc(0, 100), Game.spawnNpc(0, 100)
	local start = #Game.alarmed()
	Game.setAlarmed(a, true)
	Game.setAlarmed(b, true)
	Game.setAlarmed(b, true)
	local list = Game.alarmed()
	local two = #list == start + 2 and has(list, a) and has(list, b) and not has(list, c)
	Game.setAlarmed(a, false)
	Game.setAlarmed(c, false)
	list = Game.alarmed()
	local one = #list == start + 1 and has(list, b) and not has(list, a)
	Game.setAlarmed(b, false)
	return two and one and #Game.alarmed() == start
end)
try("BEHAVE", "4 alarm: a deleted NPC leaves the list", function()
	local a = Game.spawnNpc(0, 100)
	local start = #Game.alarmed()
	Game.setAlarmed(a, true)
	world:delete(a)
	return #Game.alarmed() == start and not has(Game.alarmed(), a)
end)
try("MODEL", "4 alarm: alarming an NPC changes its archetype, calming it changes it back (a tag the query selects on)", function()
	local a, b = Game.spawnNpc(0, 100), Game.spawnNpc(0, 100)
	Game.setAlarmed(a, false)
	Game.setAlarmed(b, false)
	Game.setAlarmed(a, true)
	Game.setAlarmed(a, false)
	local calm = jecs.record(world, a).archetype
	Game.setAlarmed(a, true)
	local alarmed = jecs.record(world, a).archetype
	Game.setAlarmed(a, false)
	return alarmed ~= calm and jecs.record(world, a).archetype == calm and jecs.record(world, b).archetype == calm
end)

try("BEHAVE", "all: 100 calls of each read register no observers", function()
	local s = Game.createSquad()
	local a = Game.spawnNpc(0, 100)
	Game.assign(a, s)
	Game.setAlarmed(a, true)
	Game.setFocus(a, s)
	Game.members(s)
	Game.alarmed()
	local before = observers()
	for _ = 1, 100 do
		Game.members(s)
		Game.alarmed()
		Game.focusOf(a)
		Game.moodOf(a)
		Game.squadOf(a)
	end
	Game.setAlarmed(a, false)
	return observers() == before
end)
try("BEHAVE", "ids: none was registered after the world was created", function()
	return (pcall(world.component, world))
end)

print(`behaviour {score.BEHAVE[1]}/{score.BEHAVE[2]}, model {score.MODEL[1]}/{score.MODEL[2]}`)
