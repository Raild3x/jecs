# Entity design and links

## What is an entity

- **An entity is anything with its own changing state** that systems process: a character, a projectile, a status effect that lasts.
- **Something that lasts one frame is an event**, kept in an array: see [best-practices-systems.md](best-practices-systems.md).
- **Shared, unchanging data is one table**, referenced from a component, with no entity per copy.

## Handles

Store an entity handle freely. A deleted entity's handle stays unequal to its slot's next occupant.

- **Reading through a stored handle needs no check:** `world:get` and `world:has` return nil and false for a dead entity.
- **Check `world:contains` before writing to it or building a pair from it.** A normal world ignores a write to a dead entity without an error, and a pair keeps no generation, so a stale handle links to the slot's new occupant.

## Links between entities

| The link | Model | Why |
|---|---|---|
| The holder belongs to the target: an item to its owner, a part to its vehicle | A pair on the many side pointing at the few, with a cleanup trait: `pair(OwnedBy, owner)` | The pair gives the reverse lookup `world:query(pair(OwnedBy, owner))` and deletes the holders with the target. |
| The holder merely points at the target: an aim target, a last attacker | The entity stored in a component: `world:set(npc, Target, enemy)` | Retargeting is a plain `set`, and no archetype is created per target. |
| One entity pointing at many | A pair or component on each of the many, pointing back | Pairs on the one side put every target's id in that one entity's archetype. |

"Few" means the number of targets times the number of different holder shapes stays in the hundreds. Past that, store the owner in a component and keep the reverse table and the delete cascade by hand.

## A target that may die

A component does not clear itself when its target dies, so the reader treats a dead target as none:

```luau
local targeting = world:query(Target):cached()

local function dropDeadTargets()
	local stale: { jecs.Entity } = {}
	for entity, target in targeting do
		if not world:contains(target) or world:has(target, Dead) then
			table.insert(stale, entity)
		end
	end
	for _, entity in stale do
		world:remove(entity, Target)
	end
end
```

## Who points at me

Over many changing targets, build a table from the forward component, on first use in a frame, inside the system that needs it, and drop it at frame end:

```luau
local hunters: { [jecs.Entity]: { jecs.Entity } } = {}
for entity, target in targeting do
	local list = hunters[target]
	if not list then
		list = {}
		hunters[target] = list
	end
	table.insert(list, entity)
end
```

*Why:* pairs would create an archetype per target, and a scan per lookup reads every holder each time.
