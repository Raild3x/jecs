# Core basics

## Setup

```luau
--!strict
local jecs = require(path.to.jecs)
local pair = jecs.pair
local RunService = game:GetService("RunService")

local Health = jecs.component<<number>>()   -- data
local Dead = jecs.tag()                     -- tag
local Team = jecs.tag()                     -- relation
jecs.meta(Health, jecs.Name, "Health")      -- value on the id
jecs.meta(Team, jecs.Exclusive)             -- trait on the relation

local world = jecs.world(RunService:IsStudio()) -- true = debug world
```

- Ids, then `jecs.meta`, then the world. A world copies ids and their config when it is created, so `meta` only reaches worlds created after it, and an id made later collides with one the world already handed out.
- If an id must be made after the world exists: `world:component<<T>>()` (data) or `world:entity()` (tag).
- `jecs.is_tag(world, id)` tells data from tag.

## API

| Call | Does |
|---|---|
| `world:entity()` | New empty entity |
| `world:set(e, id, value)` | Stores the value. Structural if the component is missing |
| `world:add(e, id)` | Adds a tag or pair. No-op if present |
| `world:get(e, a, b?, c?, d?)` | Up to 4 values. Nil if missing, a tag, or `e` is dead |
| `world:has(e, a, b?, c?, d?)` | Up to 4 ids, all required. Accepts wildcard pairs |
| `world:remove(e, id)` | Removes one id |
| `world:clear(e)` | Removes all of `e`'s components. `e` lives on, still usable as a tag or target |
| `world:delete(e)` | Deletes `e`, removes it as tag/target elsewhere, runs cleanup traits |
| `world:contains(e)` | True only for a live handle |

Singleton: `world:set(Time, Time, 12.5)`, `world:get(Time, Time)`. World-wide state (frame time, settings) lives in the world this way.

## Handles

- A handle is slot + generation: `jecs.ECS_ID(e)`, `jecs.ECS_GENERATION(e)`.
- The newest freed slot is reused first, generation + 1. The old handle stays unequal until the generation wraps (16,777,216 reuses), so a stored handle can be compared and checked safely.
- `get` and `has` on a dead handle are safe: nil and false. A pair or query built from it is not: once the slot is reused, `world:has(x, pair(R, dead))`, `world:query(pair(R, dead))` and `world:children(dead)` answer for the new occupant.
- Check `world:contains` before a write or `pair()`. A pair id keeps only the slot, not the generation: `pair()` itself never fails. Adding a pair built from a dead handle raises while the slot is free, and silently links to the new occupant once the slot is reused.

## Debug world

`jecs.world(true)` raises on:

- `set`, `add`, `remove` on a dead entity
- adding a dead entity as an id
- a wildcard pair passed to `add`, `set` or `remove`
- any `add`/`set`/`remove` on an entity from its own `OnRemove` while it is being deleted, direct or cascaded. The delete stops half way: the entity stays alive with its components, but the remove hooks of the ids before the failing one have already run, so a hook that releases a resource will run again on the next delete
- `delete` of a dead handle
- a hook or trait set after the id's first use
- a raw hook (`world:set(id, jecs.OnAdd, fn)` instead of `jecs.meta`) on an id that has signal listeners
- any `add`/`set`/`remove` after a late `jecs.component()` / `jecs.tag()`

Run it in Studio and in tests: on a normal world all but the wildcard removal are silent. It costs about 3.7x on a component `set` ([performance](performance.md)), so not in production.

Not checked: `bulk_insert`; `world:clear` on a dead handle; a pair built from a stale handle whose slot was reused.

## Mistakes

| Mistake | Result | Instead |
|---|---|---|
| `world:component()` as a marker | A column and one of 256 ids ("Too many components" past them) | `jecs.tag()` |
| `world:set` on a tag (any value, nil too) | Raises after the tag is already added, with no `OnAdd` and no `added` signal | `world:add` |
| `world:add` of a data component, or `world:set(e, id, nil)` | `has` true, `get` nil | `world:set` with a value; `world:remove` to clear |
| Fifth id to `get` / `has` | On a live entity `get` raises "args exceeded"; `has` raises only if the first four are present, else false | Two calls |
| `world:exists` to validate | True for a dead handle | `world:contains` |
| `world:entity(id)` | Can kill a live entity and give its components to the new id | `world:entity()` |
| `world:range(a, b)` | Changes which ids the world hands out, then raises at `b` | Only for replication: [advanced-api](advanced-api.md) |
