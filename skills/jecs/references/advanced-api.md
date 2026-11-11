# Advanced API

## bulk_insert / bulk_remove

```luau
-- data first, values in the same order; tags last
jecs.bulk_insert(world, world:entity(), { Speed, Armor, Stunned }, { 16, 5 })
jecs.bulk_remove(world, entity, { Speed, Armor }) -- a wildcard pair raises
```

One archetype move instead of one per component, and no archetype for each partial combination on the way: 5,000 entities with 2 components and 3 of 12 tags made 220 archetypes, against 300 added one id at a time. Use only to spawn a fresh entity with about 8+ plain components and tags, when measured: it is slower than `set` at 3 components, equal at 6, 1.3-1.6x faster at 12 ([performance](performance.md)), and it skips the checks below.

| Mistake | Result | Instead |
|---|---|---|
| Pair of an exclusive relation | `Exclusive` skipped: two parents | `world:add` |
| Relying on debug checks | All skipped | `set` / `add` while developing |
| Fewer values than data components | Silent; the rest are nil | Match the arrays |

## More than 256 data components

`jecs.component()` and `world:component()` raise "Too many components" past 256. Beyond that, make an entity a component:

```luau
local Dynamic = world:entity() :: jecs.Entity<number>
world:add(Dynamic, jecs.Component)
world:set(entity, Dynamic, 42)
```

Add `jecs.Component` before the entity is used for anything else: added later it is ignored, and the debug world does not catch it.

## world:range

`world:range(a, b)` makes the world hand out ids above `a` (and above its current highest id) up to `b - 1`, then raise. Its use is replication: a client that mirrors server entities at the same ids with `world:entity(serverId)` calls `world:range(N)`, with N above any id the server will reach, so its own entities never land in the server's id space. A client that maps server ids to its own through a table needs no range. Leave it alone otherwise.
