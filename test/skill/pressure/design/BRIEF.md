# Combat prototype: data design

Design review is at 3pm and the prototype has to be playable tomorrow, so keep this short. The project uses JECS (see `wally.toml`).

Deliver two files:

- `src/components.luau`: every id, its configuration, and the world. It must run under `lune run src/components.luau`.
- `DESIGN.md`: one numbered entry per requirement below. Say what it is modelled as and give the reason in one or two lines. For 7, include the code.

Requirements:

1. About 3,000 NPCs. Each NPC chases one attack target, another entity. The steering system reads every NPC's target each frame. An NPC picks a new target about twice a second. Nothing ever asks "who is targeting X".
2. Every NPC is in one of four factions. Faction changes only through a rare "convert" spell. Several systems work on one faction at a time, for example an aura that heals only that faction's NPCs.
3. Every NPC has a locomotion state: idle, walking, running or falling. For most NPCs it changes several times a second. The animation system visits every NPC each frame and plays the matching animation.
4. Loot items belong to the player who picked them up. Up to 40 players, a few hundred items. The UI lists a player's items. When a player leaves, their items must go too.
5. Every NPC has a Velocity. The animation system and the footstep system both need the NPC's speed (the magnitude of its velocity).
6. Each NPC remembers who damaged it last, to award kill credit when it dies. There are thousands of possible attackers.
7. Weapons call `damage(target, amount)` many times per frame, also from inside query loops. Applying a hit can trigger thorns, which calls `damage` on the attacker. No hit may be lost, and one frame must not loop forever.
8. The prototype needs `spawnNpc(position, faction)` and "move everything that has a Position and a Velocity". Say which of these is a system.
9. The map has 20,000 decorative grass blades that never change, and 300 bushes. A bush only needs harvest progress while a player is harvesting it.
10. Poison lasts about five seconds on an NPC and starts or stops a few times a minute per NPC. The poison tick should only visit poisoned NPCs.
