--!strict
local jecs = require("../Packages/jecs")
local pair = jecs.pair

local Health = jecs.component() :: jecs.Entity<number>
local Poison = jecs.component() :: jecs.Entity<number> -- damage per second
local Follows = jecs.tag()

local world = jecs.world()

local Game = {}
Game.world = world
Game.Health = Health
Game.Poison = Poison
Game.Follows = Follows

function Game.spawn(health: number, poison: number?, leader: jecs.Entity?): jecs.Entity
	local unit = world:entity()
	world:set(unit, Health, health)
	if poison then
		world:set(unit, Poison, poison)
	end
	if leader then
		world:add(unit, pair(Follows, leader))
	end
	return unit
end

local poisoned = world:query(Health, Poison):cached()

function Game.step(dt: number)
	for unit, health, poison in poisoned do
		world:set(unit, Health, health - poison * dt)
	end
end

-- the lobby dummies exist from the moment the game loads
Game.dummies = { Game.spawn(100), Game.spawn(100, 5) }

return Game
