--!strict
local jecs = require("../Packages/jecs")

local Health = jecs.component() :: jecs.Entity<number>
local Inventory = jecs.component() :: jecs.Entity<{ string }>

local world = jecs.world()

local Game = {}
Game.world = world
Game.Health = Health
Game.Inventory = Inventory

function Game.spawn(health: number): jecs.Entity
	local unit = world:entity()
	world:set(unit, Health, health)
	world:set(unit, Inventory, {})
	return unit
end

function Game.step(dt: number) end

-- the lobby dummies exist from the moment the game loads
Game.dummies = { Game.spawn(50), Game.spawn(50) }

return Game
