--!strict
-- Runs every frame: each squad that has an order moves its members.
local Game = require("./game")
local world = Game.world

local orders: { [any]: number } = {} -- squad -> destination, set by the commander UI

local Orders = {}

function Orders.give(squad: any, destination: number)
	orders[squad] = destination
end

function Orders.step(dt: number)
	for squad, destination in orders do
		for _, npc in Game.members(squad) do
			local position = world:get(npc, Game.Position) or 0
			world:set(npc, Game.Position, position + math.sign(destination - position) * dt)
		end
	end
end

-- Called from the commander UI when the player drags an NPC onto a squad banner.
function Orders.reassign(npc: any, squad: any)
	Game.assign(npc, squad)
end

return Orders
