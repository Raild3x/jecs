# Core basics

Worlds, ids, entities and components, and how the fork differs from upstream. Behaviour is that of `ukendio/jecs` 0.11.0 and `raild3x/jecs` 0.11.0-fork.1 unless a line says **fork** or **upstream**. Every behaviour in the reference files is asserted in [`../verify/facts.luau`](../verify/facts.luau) or [`../verify/examples.luau`](../verify/examples.luau).

## Fork and upstream

| Behaviour | `raild3x/jecs` | `ukendio/jecs` |
|---|---|---|
| `world.deferred`, `jecs.deferred(world)` | present | absent: collect into a table and apply after the loop |
| `world:added/changed/removed(pair(R, target), fn)` | fires for that pair only | returns a disconnect function and never fires for `added` |
| `query:with(A):with(B)` | both apply | only the last call applies |
| `jecs.component()` or `jecs.tag()` after a world exists | that world's `world:component()` raises; a debug world also raises from `add`, `set`, `remove` | silent: the id returned is one the world already handed out |
| Hook or trait configured after the id's first use | debug world raises; normal world ignores it | ignored in both worlds |
| Raw hook set on an id that has signal listeners | debug world raises | silent |
| Structural change in `OnRemove` during `world:delete` | debug world raises | debug world raises only for cascaded deletes |
| `world:delete` of a dead handle in a debug world | raises | ignored |
| Entity generation | 24 bits | 16 bits |

## World and ids

```luau
--!strict
local jecs = require(path.to.jecs)
local pair = jecs.pair

-- before the world: ids shared by every world
local Health = jecs.component<<number>>()   -- data component
local Dead = jecs.tag()                     -- tag
jecs.meta(Health, jecs.Name, "Health")      -- set a value on the id
jecs.meta(Dead, jecs.Exclusive)             -- add a trait to the id

local world = jecs.world()                  -- jecs.world(true) is the debug world

-- after the world: ids of that world only
local Speed = world:component<<number>>()   -- data component, one of 256
local Marker = world:entity()               -- an entity; used as an id it is a tag
```

- `jecs.meta(id, key, value?)` records `world:set(id, key, value)`, or `world:add(id, key)` when there is no value, and every world created afterwards applies it. A world that already exists never sees it.
- `world:component()` is always a data component and raises after 256 component ids. For more, see [advanced-api.md](advanced-api.md).
- A tag is `jecs.tag()` or `world:entity()`. `jecs.is_tag(world, id)` tells the two kinds apart.
- A debug world, `jecs.world(true)`, raises where a normal world stays silent. Use it in development, for example `jecs.world(RunService:IsStudio())`: it makes `world:set` about 3.7 times slower.

## Entities and components

| Call | Does |
|---|---|
| `world:entity()` | New entity with no components. |
| `world:set(e, id, value)` | Stores the value. Adds the component when missing (structural), else overwrites (not structural). Raises when `id` is a tag. |
| `world:add(e, id)` | Adds a tag or a pair without a value. Does nothing when already present. On a data component it leaves the value nil. |
| `world:get(e, a, b?, c?, d?)` | Values of up to four ids. Nil for a missing component, a tag and a dead entity. A fifth id raises. |
| `world:has(e, a, b?, c?, d?)` | True when the entity has all of up to four ids. A fifth id raises: call it twice for more. |
| `world:remove(e, id)` | Removes one id. |
| `world:clear(e)` | Removes every component from `e`. `e` stays alive, and stays on the entities that have `e` as a tag or target. |
| `world:delete(e)` | Deletes `e`, removes it wherever it is used as a tag or target, and applies cleanup traits. A dead handle is ignored, except that the **fork**'s debug world raises on it. |
| `world:contains(e)` | True only for a live handle. |
| `world:exists(e)` | True when the slot is in use by any generation. Use `contains` to validate a handle. |

A singleton is a component set on its own id: `world:set(Time, Time, 12.5)`, `world:get(Time, Time)`.

## Handles

An entity handle packs a slot index and a generation: `jecs.ECS_ID(e)`, `jecs.ECS_GENERATION(e)`. Deleting an entity frees its slot, and the next `world:entity()` reuses the most recently freed slot with the generation raised by one. The old handle stays unequal to the new one until the generation wraps: after 16,777,216 reuses of one slot on the fork, 65,536 on upstream.

A normal world ignores `set`, `add`, `remove` and `delete` on a dead entity. A debug world raises on them. `get` and `has` on a dead entity return nil and false in both, so a read needs no check; check `world:contains` before a write and before building a pair.

Create entities with `world:entity()` and no argument. `world:entity(id)` can corrupt the entity index, and `world:range` raises on the second entity created inside its own range.
