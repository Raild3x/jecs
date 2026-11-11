--!strict
local jecs = require("../Packages/jecs")
local pair = jecs.pair

local Health = jecs.component() :: jecs.Entity<number>
local Inventory = jecs.component() :: jecs.Entity<{ string }>
local Target = jecs.component() :: jecs.Entity<jecs.Entity>

local world = jecs.world()

local Burning = world:component()
local Armored, Blessed, Cursed, Wet, Marked = world:entity(), world:entity(), world:entity(), world:entity(), world:entity()
local Likes = jecs.tag()
local Shield = world:component() :: jecs.Entity<number>
local Exposed = world:entity()

local Game = {}
Game.world = world

function Game.spawn(health: number): jecs.Entity
	local unit = world:entity()
	world:set(unit, Health, health)
	world:set(unit, Inventory, {})
	return unit
end

Game.boss = Game.spawn(1000)

world:set(Health, jecs.OnChange, function(unit, _, value)
	if value > 1000 then
		world:set(unit, Health, 1000)
	end
end)

local inventoryDirty = {}
world:changed(Inventory, function(unit)
	inventoryDirty[unit] = true
end)

function Game.giveItem(unit: jecs.Entity, item: string)
	table.insert(world:get(unit, Inventory) :: { string }, item)
end

world:removed(Shield, function(unit)
	world:add(unit, Exposed)
end)

function Game.ignite(unit: jecs.Entity)
	world:add(unit, Burning)
end

function Game.like(unit: jecs.Entity, liked: jecs.Entity)
	world:add(unit, pair(Likes, liked))
end

function Game.isDoomed(unit: jecs.Entity): boolean
	return world:has(unit, Armored, Blessed, Cursed, Wet, Marked)
end

local everyone = world:query(Health)

function Game.countUnits(): number
	local n = 0
	for _ in everyone do
		n += 1
	end
	return n
end

function Game.step(dt: number)
	for unit, health in world:query(Health):with(Burning):cached() do
		world:set(unit, Health, health - 10 * dt)
	end
	for unit, health in world:query(Health) do
		if health <= 0 then
			world:delete(unit)
		end
	end
	for unit, target in world:query(Target) do
		if not world:exists(target) then
			world:remove(unit, Target)
		end
	end
end

return Game
