-- Hidden grader for the slow ticket. Copy to the project root: lune run check.luau
-- MODEL lines detect the data model by looking at archetypes and entity counts; see KEY.md.
local fs = require("@lune/fs")
local Game = require("./src/game")
local world = Game.world
local function try(kind, label, fn)
	local ok, result = pcall(fn)
	print((ok and result) and "PASS " or "FAIL ", kind, label, ok and "" or ("(error: " .. tostring(result):sub(-100) .. ")"))
end
local function count()
	local archetypes, entities = 0, 0
	for _, archetype in world.archetypes do
		archetypes += 1
		entities += #archetype.entities
	end
	return archetypes, entities
end
local function shareArchetype(a, b)
	for _, archetype in world.archetypes do
		local hasA, hasB = false, false
		for _, e in archetype.entities do
			hasA = hasA or e == a
			hasB = hasB or e == b
		end
		if hasA or hasB then
			return hasA and hasB
		end
	end
	return false
end
try("BEHAVE", "move advances every unit by velocity * dt", function()
	local a, b = Game.spawnUnit(0, 2), Game.spawnUnit(10, -4)
	Game.move(0.5)
	Game.move(0.5)
	return Game.positionOf(a) == 2 and Game.positionOf(b) == 6
end)
try("BEHAVE", "burn hurts burning units only; douse stops it; isBurning", function()
	local a, b = Game.spawnUnit(0, 0), Game.spawnUnit(0, 0)
	Game.ignite(a)
	Game.ignite(a)
	local lit = Game.isBurning(a) and not Game.isBurning(b)
	Game.burn(1)
	local first = Game.healthOf(a) == 90 and Game.healthOf(b) == 100
	Game.douse(a)
	Game.douse(a)
	Game.burn(1)
	return lit and first and Game.healthOf(a) == 90 and not Game.isBurning(a)
end)
try("BEHAVE", "hits wait for applyHits, several per target all land, a dead target is skipped", function()
	local a, b = Game.spawnUnit(0, 0), Game.spawnUnit(0, 0)
	Game.damage(a, 5)
	Game.damage(a, 7)
	Game.damage(b, 1)
	local waiting = Game.healthOf(a) == 100
	world:delete(b)
	Game.applyHits()
	local once = Game.healthOf(a) == 88
	Game.applyHits()
	return waiting and once and Game.healthOf(a) == 88
end)
try("BEHAVE", "step runs move, burn and hits", function()
	local a = Game.spawnUnit(0, 1)
	Game.ignite(a)
	Game.damage(a, 3)
	Game.step(1)
	return Game.positionOf(a) == 1 and Game.healthOf(a) == 87
end)
try("MODEL", "burning is selected by presence: a burning unit leaves the idle units' archetype", function()
	local a, b = Game.spawnUnit(0, 0), Game.spawnUnit(0, 0)
	local together = shareArchetype(a, b)
	Game.ignite(a)
	return together and not shareArchetype(a, b)
end)
try("MODEL", "1,000 damage calls create no entity and no archetype (events in an array)", function()
	local a = Game.spawnUnit(0, 0)
	local archetypes, entities = count()
	for _ = 1, 1000 do
		Game.damage(a, 0)
	end
	local archetypes2, entities2 = count()
	Game.applyHits()
	return archetypes2 == archetypes and entities2 == entities
end)
try("STATIC", "no :cached() inside a function body", function()
	for _, line in fs.readFile("src/game.luau"):split("\n") do
		if line:find(":cached()", 1, true) and line:match("^%s") and not line:match("^%s*%-%-") then
			return false
		end
	end
	return true
end)
try("BEHAVE", "ids: none was registered after the world was created", function()
	return (pcall(world.component, world))
end)
