# Entity design

## What is an entity

The test: does it have its own state that changes, and does a system process that state? An entity nothing queries is bookkeeping with a cost and no reader.

| Thing | Entity? | Because |
|---|---|---|
| Has its own changing state that systems process (character, projectile, lasting effect) | Yes | |
| Abstract thing other entities relate to (squad, team, quest, cell) | Yes | It can be a pair target and carry its own data |
| Needs per-instance state only some of the time (a bush while it is being harvested) | Lazily: create the entity when the state starts, delete it when it ends | 300 idle entities are 300 rows no system should have to skip |
| Static scenery, pooled visual effects, UI elements | No: plain instances or tables | Roblox already stores and renders them; nothing in the world reads them |
| Lasts one frame | No: an event record ([best-practices-systems](best-practices-systems.md)) | Creating and deleting an entity per event costs 6-9x the direct change |
| Shared, unchanging definition (item stats) | No: one table, referenced from a component | Copying it per entity wastes memory and invites drift |

Many instances of one kind: one shared table for the type, one entity per instance holding only what differs (`CropKind`, `GrowthStage`). Instances then share one archetype.

## Links between entities

| Link | Model | Because |
|---|---|---|
| Belongs to / is part of / is in | Pair with a cleanup trait | Reverse lookup and cascade without extra code |
| Parent and child | `pair(jecs.ChildOf, parent)` | |
| Whole needs fast access to named parts | `ChildOf` for lifetime + a component holding the part handles | The handles save a query per part per frame |
| Merely points at (AI target, last attacker), read every row, or retargeted often | Entity in a component | No fragmentation, no structural change to retarget; reads straight from the column |

Full decision table and patterns: [feature-pairs](feature-pairs.md).

## Handles

- Storing a handle is fine. A dead handle never equals its slot's next occupant.
- `get` and `has` on a dead handle are safe (nil, false). A pair or query built from it answers for the slot's next occupant.
- When the check fails, decide what the dead handle means. `if not world:contains(target) then return end` in a setter leaves the old link in place; if "no target" is what a dead target means, remove the link there.
- `world:contains` before a write or `pair()`.

Entity in a component: nothing clears it when the target dies. Check where it is read, and drop it when stale.

```luau
local targeting = world:query(Target):cached()

local function dropDeadTargets()
	local deferred = world.deferred
	for entity, target in targeting do
		if not world:contains(target) then
			deferred:remove(entity, Target)
		end
	end
	deferred:apply()
end
```

## Mistakes

| Mistake | Result | Instead |
|---|---|---|
| An entity for everything | Bookkeeping with no system that reads it | Entities only for processed state |
| A permanent entity for state that is rarely active | Rows every query must match or exclude | Create on first need, delete after |
| A hand-kept table of "who points at X" | Duplicates what a pair query gives; goes stale | `world:query(pair(R, X))` |
| A stored handle used without a check in a write | Silently ignored on a normal world | `world:contains` |
