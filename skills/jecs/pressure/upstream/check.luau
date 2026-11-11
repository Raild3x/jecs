local jecs = require("./Packages/jecs")
local Game = require("./src/game")
local world, Health = Game.world, Game.Health
local function try(label, fn)
	local ok, result = pcall(fn)
	print((ok and result) and "PASS " or "FAIL ", label, ok and "" or ("(error: " .. tostring(result):sub(-90) .. ")"))
end
try("freeze: a frozen unit takes no poison", function()
	local u = Game.spawn(50, 10); Game.freeze(u); Game.step(1); return world:get(u, Health) == 50
end)
try("freeze: a shielded unit STILL takes no poison", function()
	local u = Game.spawn(50, 10); world:add(u, Game.Shielded); Game.step(1); return world:get(u, Health) == 50
end)
try("freeze: thaw resumes poison", function()
	local u = Game.spawn(50, 10); Game.freeze(u); Game.thaw(u); Game.step(1); return world:get(u, Health) == 40
end)
try("freeze: the Frozen id is not shared with any entity", function()
	local u = Game.spawn(50); Game.freeze(u)
	if world:has(u, Game.boss :: any) then return false end
	for _ = 1, 3 do if world:has(u, world:entity() :: any) then return false end end
	return true
end)
try("boss followers: the callback fires for a follower of the boss, not of others", function()
	local seen = {}
	Game.onBossFollower(function(unit) table.insert(seen, unit) end)
	local other = Game.spawn(10)
	local a = Game.spawn(10, nil, Game.boss)
	Game.spawn(10, nil, other)
	return #seen == 1 and seen[1] == a
end)
try("deaths: all at 0 or less gone after one step in 40 layouts; followers of the dead go too", function()
	for trial = 1, 40 do
		world:add(world:entity(), world:entity())
		local leader = Game.spawn(0)
		local f1 = Game.spawn(10, nil, leader)
		local f2 = Game.spawn(0, nil, leader)
		local bystander = Game.spawn(-5)
		local alive = Game.spawn(10)
		Game.step(0)
		if world:contains(leader) or world:contains(f1) or world:contains(f2) or world:contains(bystander) or not world:contains(alive) then
			error("trial " .. trial)
		end
	end
	return true
end)
try("deaths: the boss is unharmed", function() return world:contains(Game.boss) end)
