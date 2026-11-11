--!strict
-- Runs once per NPC, when the garrison is populated at the start of a round.
local Game = require("./game")

return function(count: number, pickRival: (any, { any }) -> any): { any }
	local npcs = {}
	for i = 1, count do
		npcs[i] = Game.spawnNpc(i, 100)
	end
	for _, npc in npcs do
		Game.setRival(npc, pickRival(npc, npcs)) -- fixed for the round
	end
	return npcs
end
