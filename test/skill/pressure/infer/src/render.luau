--!strict
-- Runs every frame, for every NPC: turns the head toward the focus and picks the face for the mood.
local Game = require("./game")

return function(npcs: { any }, lookAt: (any, any) -> (), setFace: (any, string) -> ())
	for _, npc in npcs do
		local focus = Game.focusOf(npc)
		if focus then
			lookAt(npc, focus)
		end
		setFace(npc, Game.moodOf(npc))
	end
end
