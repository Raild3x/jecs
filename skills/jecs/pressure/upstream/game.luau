--!strict
local jecs = require("../Packages/jecs")
local pair = jecs.pair

local Health = jecs.component() :: jecs.Entity<number>
local Poison = jecs.component() :: jecs.Entity<number> -- damage per second
local Shielded = jecs.tag()
local Follows = jecs.tag()

local world = jecs.world()

local Game = {}
Game.world = world
Game.Health = Health
Game.Poison = Poison
Game.Shielded = Shielded
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

function Game.step(dt: number)
	for unit, health, poison in world:query(Health, Poison):without(Shielded) do
		world:set(unit, Health, health - poison * dt)
	end
end

-- the boss exists from the moment the game loads
Game.boss = Game.spawn(1000)

return Game
