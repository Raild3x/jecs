# Garrison tickets

Playtest is in 30 minutes. The modules `ai.luau`, `render.luau`, `orders.luau` and `alarm.luau` in `src/` are already written against functions that `src/game.luau` does not have yet. Add them to `src/game.luau`; do not change the other modules. Read them to see how each function is used. The garrison holds a few thousand NPCs. Other code calls `Game.world` directly.

1. **Focus.** `Game.setFocus(npc, target)` and `Game.focusOf(npc)`. An NPC whose focus is gone has none: `focusOf` returns nil.
2. **Mood.** `Game.setMood(npc, mood)` and `Game.moodOf(npc)`. Moods are "calm", "wary" and "panicked"; an NPC that was never given one is "calm".
3. **Squads.** `Game.createSquad()`, `Game.assign(npc, squad)`, `Game.squadOf(npc)`, `Game.members(squad)` (an array). One squad per NPC; assigning to another leaves the first. Deleting a squad, by any code, leaves its NPCs alive and in no squad. Assigning to a squad that no longer exists does nothing.
4. **Alarm.** `Game.setAlarmed(npc, on: boolean)` and `Game.alarmed()` (an array of the alarmed NPCs).
