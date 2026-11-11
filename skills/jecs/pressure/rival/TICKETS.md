# Rival ticket

Playtest is in 20 minutes. `spawner.luau` and `taunts.luau` in `src/` are already written against two functions that `src/game.luau` does not have yet. Add them to `src/game.luau`; do not change the other modules. Read them to see how the functions are used. The garrison holds a few thousand NPCs, and every NPC has a rival of its own. Other code calls `Game.world` directly.

**Rivals.** `Game.setRival(npc, rival)` and `Game.rivalOf(npc)`. An NPC whose rival is gone has none: `rivalOf` returns nil.
