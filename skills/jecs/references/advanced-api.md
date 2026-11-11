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

## world:cleanup

Removes empty archetypes; cached queries stay correct. When to call it: [core-archetypes](core-archetypes.md).
