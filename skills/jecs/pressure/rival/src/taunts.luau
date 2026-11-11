--!strict
-- Runs every frame, for every NPC: each one turns to glare at its rival.
local Game = require("./game")

return function(npcs: { any }, glareAt: (any, any) -> ())
	for _, npc in npcs do
		local rival = Game.rivalOf(npc)
		if rival then
			glareAt(npc, rival)
		end
	end
end
