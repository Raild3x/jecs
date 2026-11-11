--!strict
-- Arena prototype. Positions and velocities are one-dimensional numbers.
local jecs = require("../Packages/jecs")
local pair = jecs.pair

local Position = jecs.component() :: jecs.Entity<number>
local Velocity = jecs.component() :: jecs.Entity<number>
local Health = jecs.component() :: jecs.Entity<number>
local Thorns = jecs.component() :: jecs.Entity<number>
local Npc = jecs.tag()
local CarriedBy = jecs.tag()

local world = jecs.world()

local Game = {}
Game.world = world
Game.Position = Position
Game.Velocity = Velocity
Game.Health = Health
Game.Thorns = Thorns
Game.Npc = Npc
Game.CarriedBy = CarriedBy

function Game.spawnNpc(position: number, health: number): jecs.Entity
	local npc = world:entity()
	world:add(npc, Npc)
	world:set(npc, Position, position)
	world:set(npc, Velocity, 0)
	world:set(npc, Health, health)
	return npc
end

function Game.spawnItem(carrier: jecs.Entity): jecs.Entity
	local item = world:entity()
	world:add(item, pair(CarriedBy, carrier))
	return item
end

-- Called once per frame by the main loop.
function Game.step(dt: number)
	for npc, position, velocity in world:query(Position, Velocity) do
		world:set(npc, Position, position + velocity * dt)
	end
end

-- The lobby keeper and its lantern exist from the moment the game loads.
Game.keeper = Game.spawnNpc(0, 100)
Game.lantern = Game.spawnItem(Game.keeper)

return Game
