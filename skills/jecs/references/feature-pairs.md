# Pairs and relationships

`pair(relation, target)` is an id built from two ids. Every distinct pair is its own id, so entities holding `pair(R, a)` and `pair(R, b)` are stored apart. That is what makes "everything pointing at `a`" a direct lookup, and also what a pair costs.

## When to use

| Use a pair when | Example | Because |
|---|---|---|
| The holder belongs to, is part of, or is grouped by the target | `pair(jecs.ChildOf, parent)`, `pair(OwnedBy, owner)`, `pair(InSquad, squad)` | A cleanup trait removes or deletes holders with the target; no stale link |
| Something asks "what points at X" | `world:query(pair(OwnedBy, player))` | One lookup instead of a scan (9x faster at 10 targets, about 200x at 1,000) |
| Systems select entities by a one-of-several state that rarely changes | exclusive `pair(Team, Red)` | The query never visits the other states |

| Use an entity in a component when | Example | Because |
|---|---|---|
| The holder merely points at the target and nothing asks the reverse | `Target`, `LastAttacker` | A pair buys nothing here and still fragments storage |
| A loop reads the target for every row | Steering reads each NPC's target | `world:target` per row costs 6-15x reading a component column |
| The link is retargeted often | Target re-picked twice a second | Retargeting a pair is a structural change: 4-11x a `set` depending on how many components the entity has, and tens of times more the first time an entity shape moves to a given target |
| Targets times holder shapes would pass the hundreds | Thousands of distinct attackers | One archetype per target per holder shape: build cost is 3x at 1,000 targets, 10-24x at 10,000 |

An entity in a component is not cleaned up when its target dies: the reader checks `world:contains` ([best-practices-entities](best-practices-entities.md)). If both columns apply, weigh reverse lookups per frame against retargets per frame, and measure.

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
- Hooks and signals on a relation run for its pairs and receive the pair id; `jecs.pair_second(world, id)` gives the target.

## Patterns

Ownership with cascade and both lookups. The pair goes on the item (the many side):

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

Work grouped by target (a cell, a squad): loop over the targets and query each group, so `world:target` per row is not needed. Example and when it pays: [best-practices-queries](best-practices-queries.md).

Several values of one type on an entity: a tag relation with the component as target. Hooks and signals of the component do not run for these pairs; put them on the relation if the values need the same invariant.

```luau
local Begin, End = jecs.tag(), jecs.tag()              -- before jecs.world()
world:set(beam, pair(Begin, Position), origin)
world:set(beam, pair(End, Position), tip)
for e, from, to in world:query(pair(Begin, Position), pair(End, Position)) do end
```

Inherited value: walk up the hierarchy. JECS queries do not traverse.

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

Composite: `ChildOf` owns the lifetime, a component holds direct handles. Use when the whole reads named parts every frame, since a query per part per frame would be wasted work.

```luau
world:add(hull, pair(jecs.ChildOf, car))
world:add(motor, pair(jecs.ChildOf, car))
world:set(car, Parts, { hull = hull, motor = motor })
```

## Mistakes

| Mistake | Result | Instead |
|---|---|---|
| `pair(R, staleHandle)` | A pair drops generations. Adding it raises while the slot is free; once reused, links to the new occupant with no error, even in a debug world | `world:contains` first |
| Pairs on the one side pointing at many (`pair(Owns, item)` on the owner) | Each owner gets its own archetype holding all its pair ids, and passes through one more per item added: 100 owners with 30 items made about 3,000 archetypes against about 110 | Pair on each of the many |
| A pair for a link nothing looks up in reverse | Fragmentation and structural retargets with no benefit | Entity in a component |
| `Exclusive` or a cleanup trait added after first use | Applied to some pairs and not others: see [feature-cleanup-traits](feature-cleanup-traits.md) | `jecs.meta` |
| Expecting several rows from a wildcard query | One row per entity | `world:targets(e, R)` |
| `world:set` on `pair(tagRelation, entity)` | Raises after the pair is already added, with no `OnAdd` | Make the relation a component |
