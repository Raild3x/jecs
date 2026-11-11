# Advanced API

## bulk_insert and bulk_remove

```luau
-- data components first, with their values in the same order; tags last
jecs.bulk_insert(world, world:entity(), { Speed, Armor, Stunned }, { 16, 5 })
jecs.bulk_remove(world, entity, { Speed, Armor })
```

`jecs.bulk_insert(world, entity, ids, values)` adds several ids in one archetype move, with `values[i]` going to `ids[i]`. `jecs.bulk_remove(world, entity, ids)` removes several.

- **Use it only to spawn a fresh entity with about eight or more plain components and tags, where a measurement shows the gain.** It is slower than `set` per component at three components, equal at six and 1.57 times faster at twelve.
- It runs hooks, but skips the `Exclusive` trait: an entity given a second `ChildOf` pair this way ends up with two parents. Use `world:add` for pairs of an exclusive relation.
- It skips every debug-world check.
- It accepts fewer values than data components without an error, and leaves the rest nil.

## More than 256 data components

`world:component()` and `jecs.component()` share 256 ids and raise past them. An entity given the `jecs.Component` trait holds data like a component:

```luau
local Dynamic = world:entity()
world:add(Dynamic, jecs.Component)
world:set(entity, Dynamic, 42)
```

## Reading ids

| Call | Returns |
|---|---|
| `jecs.is_tag(world, id)` | Whether the id, or pair, holds no data. |
| `jecs.ECS_ID(e)` | The slot index of a handle. |
| `jecs.ECS_GENERATION(e)` | The generation of a handle. |
| `jecs.IS_PAIR(id)` | Whether the id is a pair. |
| `jecs.pair_first(world, id)`, `jecs.pair_second(world, id)` | The live relation and target of a pair id. |

## Debug world

`jecs.world(true)` raises where a normal world stays silent. In both libraries it raises on:

- `set`, `add` and `remove` on a dead entity;
- adding a dead entity as an id;
- removing a wildcard pair;
- a structural change inside `OnRemove` during a cascaded delete.

On the **fork** it also raises on a hook or trait configured after the id's first use, a raw hook set over signal listeners, a structural change inside `OnRemove` during a direct `world:delete`, and any `add`, `set` or `remove` after a late `jecs.component()` or `jecs.tag()`.

It does not check `bulk_insert`, and it does not catch a pair built from a stale handle.

## world:cleanup

`world:cleanup()` removes empty archetypes. Cached queries stay correct across it.
