# Entity design

## What is an entity

| Thing | Entity? |
|---|---|
| Has its own state that changes and systems process (character, projectile, lasting effect) | Yes |
| Created only when something first needs per-instance state | Yes, lazily: no entity until then |
| Static scenery, pooled visual effects, UI elements | No: plain instances or tables |
| Lasts one frame | No: an event record ([best-practices-systems](best-practices-systems.md)) |
| Shared, unchanging definition (item stats) | No: one table, referenced from a component |

Many instances of one kind: one shared table for the type, one entity per instance holding only what differs.

## Links between entities

| Link | Model |
|---|---|
| Belongs to / is part of / is in | Pair with a cleanup trait. Gives reverse lookup and cascade |
| Parent and child | `pair(jecs.ChildOf, parent)` |
| Whole needs fast access to named parts | `ChildOf` for lifetime + a component holding the part handles |
| Target rewritten on most entities every frame, or about 10,000 distinct targets | Entity in a component. Retargeting a pair costs 4-22x a `set`; building and deleting climb steeply at that scale |

Patterns for each: [feature-pairs](feature-pairs.md).

## Handles

- Storing a handle is fine. A dead handle never equals its slot's next occupant.
- Reads are safe on a dead handle (`get` nil, `has` false).
- `world:contains` before a write or `pair()`.

Entity in a component: nothing clears it when the target dies. The reader drops it.

```luau
local targeting = world:query(Target):cached()

local function dropDeadTargets()
	local stale: { jecs.Entity } = {}
	for entity, target in targeting do
		if not world:contains(target) then
			table.insert(stale, entity)
		end
	end
	for _, entity in stale do
		world:remove(entity, Target)
	end
end
```

## Mistakes

| Mistake | Result | Instead |
|---|---|---|
| An entity for everything | Bookkeeping with no system that reads it | Entities only for processed state |
| A hand-kept table of "who points at X" | Duplicates what a pair query gives; goes stale | `world:query(pair(R, X))` |
| A stored handle used without a check in a write | Silently ignored on a normal world | `world:contains` |
