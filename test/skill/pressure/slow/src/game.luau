--!strict
-- Skirmish prototype. Positions are one-dimensional numbers.
local jecs = require("../Packages/jecs")

local Position = jecs.component() :: jecs.Entity<number>
local Velocity = jecs.component() :: jecs.Entity<number>
local Health = jecs.component() :: jecs.Entity<number>
local State = jecs.component() :: jecs.Entity<string> -- "idle" or "burning"
local Hit = jecs.component() :: jecs.Entity<{ target: jecs.Entity, amount: number }>

local world = jecs.world(true)

local Game = {}
Game.world = world

function Game.spawnUnit(position: number, velocity: number): jecs.Entity
	local unit = world:entity()
	world:set(unit, Position, position)
	world:set(unit, Velocity, velocity)
	world:set(unit, Health, 100)
	world:set(unit, State, "idle")
	return unit
end

function Game.positionOf(unit: jecs.Entity): number?
	return world:get(unit, Position)
end

function Game.healthOf(unit: jecs.Entity): number?
	return world:get(unit, Health)
end

function Game.ignite(unit: jecs.Entity)
	world:set(unit, State, "burning")
end

function Game.douse(unit: jecs.Entity)
	world:set(unit, State, "idle")
end

function Game.isBurning(unit: jecs.Entity): boolean
	return world:get(unit, State) == "burning"
end

-- Called from anywhere, many times a frame. Nothing changes until applyHits.
function Game.damage(target: jecs.Entity, amount: number)
	local event = world:entity()
	world:set(event, Hit, { target = target, amount = amount })
end

function Game.move(dt: number)
	local movers = world:query(Position, Velocity):cached()
	for unit, position, velocity in movers do
		world:set(unit, Position, position + velocity * dt)
	end
end

-- Burning units lose 10 health a second.
function Game.burn(dt: number)
	for unit, state, health in world:query(State, Health) do
		if state == "burning" then
			world:set(unit, Health, health - 10 * dt)
		end
	end
end

function Game.applyHits()
	local events = {}
	for event, hit in world:query(Hit) do
		table.insert(events, { event = event, hit = hit })
	end
	for _, entry in events do
		local health = world:get(entry.hit.target, Health)
		if health then
			world:set(entry.hit.target, Health, health - entry.hit.amount)
		end
		world:delete(entry.event)
	end
end

function Game.step(dt: number)
	Game.move(dt)
	Game.burn(dt)
	Game.applyHits()
end

return Game
