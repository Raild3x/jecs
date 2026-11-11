# Pairs and relationships

`pair(relation, target)` is an id built from two ids.

## When to use

Default for any relationship between entities:

- Hierarchy: `pair(jecs.ChildOf, parent)`.
- Ownership, membership, grouping: `pair(OwnedBy, owner)`, `pair(InSquad, squad)`.
- One-of-several state that queries select on: exclusive `pair(Team, Red)`.
- Reverse lookup ("everything that points at X"): query the pair.

Use a component holding the entity instead only when the target is rewritten on most entities every frame, or distinct targets approach 10,000. Costs: [best-practices-archetypes](best-practices-archetypes.md).

## API

| Pair | Holds |
|---|---|
| `pair(dataRelation, entity)` | A value, typed by the relation |
| `pair(tagRelation, dataComponent)` | A value, typed by the target |
| `pair(tagRelation, entity)` | Nothing (a tag) |

| Call | Does |
|---|---|
| `world:add(e, pair(R, t))` / `world:set(e, pair(R, t), v)` | Add a tag pair / a data pair |
| `world:target(e, R, index?)` | `index`-th target, from 0. Nil if none |
| `world:targets(e, R)` | Iterator over all targets |
| `world:parent(e)` | `world:target(e, jecs.ChildOf)` |
| `world:children(parent)` | Entities with `pair(jecs.ChildOf, parent)` |
| `world:has(e, pair(R, jecs.Wildcard))` | Has any target of `R` |
| `world:query(pair(R, t))` | Entities holding that pair |
| `jecs.pair_first(world, id)`, `jecs.pair_second(world, id)` | Relation and target of a pair id |
| `jecs.IS_PAIR(id)` | Is it a pair |

- `jecs.ChildOf`: exclusive; deleting a parent deletes its descendants.
- `jecs.Exclusive` on a relation: one target per entity; adding another replaces it.
- Hooks and signals on a relation run for its pairs and receive the pair id.

## Patterns

Ownership with cascade and both lookups:

```luau
-- before jecs.world()
local OwnedBy = jecs.tag()
jecs.meta(OwnedBy, pair(jecs.OnDeleteTarget, jecs.Delete))

-- after
world:add(sword, pair(OwnedBy, player))
for item in world:query(pair(OwnedBy, player)) do end -- reverse
local owner = world:target(sword, OwnedBy)             -- forward
world:delete(player)                                   -- deletes the sword
```

Exclusive state:

```luau
-- before jecs.world()
local Team = jecs.tag()
local Red, Blue = jecs.tag(), jecs.tag()
jecs.meta(Team, jecs.Exclusive)

-- after
world:add(npc, pair(Team, Red))
world:add(npc, pair(Team, Blue))                       -- replaces Red
for e in world:query(Health):with(pair(Team, Blue)) do end
```

Inherited value: walk up the hierarchy.

```luau
local function inherited<T>(entity: jecs.Entity, id: jecs.Id<T>): T?
	local current: jecs.Entity? = entity
	while current do
		local value = world:get(current, id)
		if value ~= nil then
			return value
		end
		current = world:parent(current)
	end
	return nil
end
```

Composite: `ChildOf` owns the lifetime, a component holds direct handles.

```luau
world:add(hull, pair(jecs.ChildOf, car))
world:add(motor, pair(jecs.ChildOf, car))
world:set(car, Parts, { hull = hull, motor = motor })
```

## Mistakes

| Mistake | Result | Instead |
|---|---|---|
| `pair(R, staleHandle)` | A pair drops generations. Raises while the slot is free; once reused, links to the new occupant with no error, even in a debug world | `world:contains` first |
| Pairs on the one side pointing at many | Every target id lands in one archetype | Pair on each of the many |
| `Exclusive` or a cleanup trait added after first use | Ignored | `jecs.meta` |
| Expecting several rows from a wildcard query | One row per entity | `world:targets(e, R)` |
| `world:set` on `pair(tagRelation, entity)` | Raises | Make the relation a component |
