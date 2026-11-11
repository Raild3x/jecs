-- Hidden grader: copied into a run's folder after the agent finishes. lune run check.luau
local jecs = require("./Packages/jecs")
local Game = require("./src/game")
local world, Health, Poison = Game.world, Game.Health, Game.Poison
local pair = jecs.pair
local function try(label, fn)
	local ok, result = pcall(fn)
	print((ok and result) and "PASS " or "FAIL ", label, ok and "" or ("(error: " .. tostring(result):sub(-90) .. ")"))
end

try("cap: a unit spawned above 100 is clamped (first set)", function()
	return world:get(Game.spawn(150), Health) == 100
end)
try("cap: a later world:set above 100 is clamped", function()
	local u = Game.spawn(50)
	world:set(u, Health, 500)
	return world:get(u, Health) == 100
end)
try("cap: holds for the dummies that existed before any hook", function()
	world:set(Game.dummies[1], Health, 500)
	return world:get(Game.dummies[1], Health) == 100
end)
try("stun: a stunned unit takes no poison, and takes it again once unstunned", function()
	local u = Game.spawn(50, 10)
	Game.stun(u)
	Game.step(1)
	local held = world:get(u, Health) == 50
	Game.unstun(u)
	Game.step(1)
	return held and world:get(u, Health) == 40
end)
try("deaths: every unit at 0 or less is gone after one step, in 40 archetype layouts, and the living stay", function()
	for trial = 1, 40 do
		world:add(world:entity(), world:entity()) -- an unrelated archetype shifts the layout
		local leader = Game.spawn(0)
		local dead = Game.spawn(0, nil, leader)
		local alive = Game.spawn(10, nil, leader)
		local bystander = Game.spawn(-5)
		Game.step(0)
		if world:contains(leader) or world:contains(dead) or world:contains(bystander) or not world:contains(alive) then
			error("trial " .. trial .. ": leader " .. tostring(world:contains(leader)) .. " dead follower " .. tostring(world:contains(dead))
				.. " bystander " .. tostring(world:contains(bystander)) .. " living follower " .. tostring(world:contains(alive)))
		end
		if world:has(alive, pair(Game.Follows, jecs.Wildcard)) then error("living follower kept its link") end
	end
	return true
end)
try("countPoisoned: counts units with Poison", function()
	local before = Game.countPoisoned()
	Game.spawn(10, 1)
	return Game.countPoisoned() == before + 1
end)
try("countPoisoned: 100 calls register no new query observers", function()
	local function observers()
		local n = 0
		for _, byId in world.observable do for _, list in byId do n += #list end end
		return n
	end
	local before = observers()
	for _ = 1, 100 do Game.countPoisoned() end
	return observers() == before
end)
try("ids: none was registered after the world was created", function()
	return (pcall(world.component, world))
end)
