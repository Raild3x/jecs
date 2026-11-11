# Arena tickets

Playtest is in 30 minutes. All work goes in `src/game.luau`; keep its existing exports working and keep the diff small. Other modules call `Game.world` directly, so nothing may depend on them going through `Game`.

`Game.step(dt)` must do its work in this order: apply damage, steer, move, zone regeneration, remove the dead.

1. **Targets.** `Game.setTarget(npc, target)` and `Game.targetOf(npc)`. The AI module calls `setTarget` for every NPC about twice a second, and the arena holds a few thousand NPCs, each usually chasing a different target. In `Game.step`, before moving, set each targeting NPC's Velocity to 1 or -1 toward its target's Position, or 0 when it is already there. An NPC whose target is gone has no target: `targetOf` returns nil and its Velocity becomes 0.

2. **Zones.** `Game.createZone(regen: number?)`, `Game.enterZone(npc, zone)`, `Game.zoneOf(npc)`, `Game.npcsIn(zone)` (an array). An NPC is in at most one zone; entering another leaves the first. There are a few dozen zones and NPCs change zone a few times a minute. Deleting a zone, by any code, leaves its NPCs alive and in no zone. `enterZone` with a zone that no longer exists does nothing. In `Game.step`, every NPC in a zone that has `regen` gains `regen * dt` Health; only a handful of zones have it.

3. **Zone count.** `Game.countIn(zone)`, called every frame by the HUD.

4. **Carried items.** When an NPC is deleted, by any code, the items it carries (`Game.spawnItem`) are deleted with it. This includes the lobby keeper and its lantern.

5. **Damage.** `Game.damage(target, amount, attacker: jecs.Entity?)`. It is called many times per frame, from inside query loops and from `world:changed` listeners. It changes nothing by itself; the next `Game.step` applies every hit that was queued before that step began. When a hit with an attacker lands on an NPC that has `Thorns`, the attacker takes that NPC's `Thorns` value as damage through `Game.damage`, with the thorned NPC as attacker. Two NPCs with thorns that hit each other must not hang the frame. At the end of `Game.step`, every NPC with Health at or below 0 is deleted.

6. **Speed.** `Game.speedOf(npc)` returns the magnitude of the NPC's Velocity. The animation and footstep modules call it for every NPC every frame.
