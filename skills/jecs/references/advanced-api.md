# Advanced API

## bulk_insert / bulk_remove

```luau
-- data first, values in the same order; tags last
jecs.bulk_insert(world, world:entity(), { Speed, Armor, Stunned }, { 16, 5 })
jecs.bulk_remove(world, entity, { Speed, Armor })
```

Use only to spawn a fresh entity with about 8+ plain components and tags, when measured. Slower than `set` at 3 components, equal at 6, 1.57x faster at 12.

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
- a structural change in `OnRemove` during a cascaded delete

**fork** adds: hook or trait set after first use; raw hook over signal listeners; structural change in `OnRemove` during a direct `delete`; `delete` of a dead handle; any `add`/`set`/`remove` after a late `jecs.component()` / `jecs.tag()`.

Not checked: `bulk_insert`; a pair built from a stale handle whose slot was reused.

## world:cleanup

Removes empty archetypes. Cached queries stay correct.
