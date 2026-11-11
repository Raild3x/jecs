# Advanced API

## bulk_insert / bulk_remove

```luau
-- data first, values in the same order; tags last
jecs.bulk_insert(world, world:entity(), { Speed, Armor, Stunned }, { 16, 5 })
jecs.bulk_remove(world, entity, { Speed, Armor }) -- a wildcard pair raises
```

One archetype move instead of one per component. Use only to spawn a fresh entity with about 8+ plain components and tags, when measured: it is slower than `set` at 3 components, equal at 6, 1.3-1.6x faster at 12 ([performance](performance.md)), and it skips the checks below.

| Mistake | Result | Instead |
|---|---|---|
| Pair of an exclusive relation | `Exclusive` skipped: two parents | `world:add` |
| Relying on debug checks | All skipped | `set` / `add` while developing |
| Fewer values than data components | Silent; the rest are nil | Match the arrays |

## More than 256 data components

```luau
local Dynamic = world:entity() :: jecs.Entity<number>
world:add(Dynamic, jecs.Component)
world:set(entity, Dynamic, 42)
```

## Reading ids

| Call | Returns |
|---|---|
| `jecs.is_tag(world, id)` | Id or pair holds no data |
| `jecs.ECS_ID(e)` / `jecs.ECS_GENERATION(e)` | Slot / generation |
| `jecs.IS_PAIR(id)` | Is a pair |
| `jecs.pair_first(world, id)` / `jecs.pair_second(world, id)` | Live relation / target |

## Debug world

`jecs.world(true)` raises on:

- `set`, `add`, `remove` on a dead entity
- adding a dead entity as an id
- removing a wildcard pair
- any `add`/`set`/`remove` on an entity from its own `OnRemove` while it is being deleted, direct or cascaded. The delete stops half way: the entity stays alive with its components, but the remove hooks of the ids before the failing one have already run, so a hook that releases a resource will run again on the next delete
- `delete` of a dead handle
- a hook or trait set after the id's first use
- a raw hook on an id that has signal listeners
- any `add`/`set`/`remove` after a late `jecs.component()` / `jecs.tag()`

Run it in Studio and in tests: on a normal world all but the wildcard removal are silent.

Not checked: `bulk_insert`; `world:clear` on a dead handle; a pair built from a stale handle whose slot was reused; the `jecs.Component` trait added to an entity already in use (ignored).

## world:cleanup

Removes empty archetypes. Cached queries stay correct.

Call it after a mass delete or a wave of retargeting, when many archetypes were left empty. The gain is mostly memory: 1,000 empty archetypes slowed a cached query by 1.2x. Not needed after deleting pair targets, which destroys their archetypes already.
