--!strict
-- Runs every frame, for every NPC.
local Game = require("./game")
local world = Game.world

local function nearestThreat(npc: any): any
	-- stand-in for the spatial lookup
	return npc
end

return function(npcs: { any })
	for _, npc in npcs do
		Game.setFocus(npc, nearestThreat(npc))

		local health = world:get(npc, Game.Health) or 0
		Game.setMood(npc, if health < 30 then "panicked" elseif health < 70 then "wary" else "calm")
	end
end
