--!strict
-- Garrison prototype. Positions are one-dimensional numbers.
local jecs = require("../Packages/jecs")

local Position = jecs.component() :: jecs.Entity<number>
local Health = jecs.component() :: jecs.Entity<number>
local Npc = jecs.tag()

local world = jecs.world()

local Game = {}
Game.world = world
Game.Position = Position
Game.Health = Health
Game.Npc = Npc

function Game.spawnNpc(position: number, health: number): jecs.Entity
	local npc = world:entity()
	world:add(npc, Npc)
	world:set(npc, Position, position)
	world:set(npc, Health, health)
	return npc
end

return Game
