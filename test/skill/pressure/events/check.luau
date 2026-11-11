local Game = require("./src/game")
local world, Health = Game.world, Game.Health
local function try(label, fn)
	local ok, result = pcall(fn)
	print((ok and result) and "PASS " or "FAIL ", label, ok and "" or ("(error: " .. tostring(result):sub(-90) .. ")"))
end
local function has(list, x) return table.find(list, x) ~= nil end
local hits = {}
pcall(function() Game.onHit(function(target, amount) table.insert(hits, { target, amount }) end) end)
try("damage: several hits on one unit in a frame all count, applied in step", function()
	local u = Game.spawn(100)
	Game.damage(u, 10); Game.damage(u, 20); Game.damage(u, 5)
	local before = world:get(u, Health)
	Game.step(1)
	return before == 100 and world:get(u, Health) == 65
end)
try("damage: the hit callback ran once per hit, and nothing repeats next frame", function()
	local n = #hits
	Game.step(1)
	return n == 3 and #hits == 3
end)
try("damage: a hit on a unit deleted before step is harmless", function()
	local u = Game.spawn(10); Game.damage(u, 5); world:delete(u); Game.step(1); return true
end)
try("changed health: each changed unit listed once, then the list is empty", function()
	Game.takeChangedHealth()
	local a, b, c = Game.spawn(10), Game.spawn(10), Game.spawn(10)
	Game.takeChangedHealth()
	world:set(a, Health, 9); world:set(a, Health, 8); world:set(b, Health, 7)
	local list = Game.takeChangedHealth()
	return #list == 2 and has(list, a) and has(list, b) and not has(list, c) and #Game.takeChangedHealth() == 0
end)
try("changed health: a newly spawned unit is listed", function()
	Game.takeChangedHealth()
	local n = Game.spawn(10)
	return has(Game.takeChangedHealth(), n)
end)
try("changed health: a deleted unit is not listed", function()
	local u = Game.spawn(10); world:set(u, Health, 5); world:delete(u)
	return not has(Game.takeChangedHealth(), u)
end)
try("inventory: addItem is seen by a world:changed(Inventory) listener", function()
	local seen = 0
	world:changed(Game.Inventory, function() seen += 1 end)
	local u = Game.spawn(10)
	Game.addItem(u, "sword")
	return seen == 1 and world:get(u, Game.Inventory)[1] == "sword"
end)
try("ids: none was registered after the world was created", function()
	return (pcall(world.component, world))
end)
