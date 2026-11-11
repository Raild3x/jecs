# Core basics

Applies to `ukendio/jecs` 0.11.0 and `raild3x/jecs` 0.11.0-fork.1 unless marked. Every statement in these files is asserted in [`../verify/`](../verify/).

## Fork vs upstream

| Behaviour | `raild3x/jecs` | `ukendio/jecs` |
|---|---|---|
| `world.deferred`, `jecs.deferred(world)` | present | absent |
| Signal on `pair(R, target)` | fires for that pair | `added` never fires; `changed`/`removed` only if the pair existed when connected |
| Listener disconnecting during dispatch | others still run | another listener can miss the event |
| Chained `:with(A):with(B)`, `:without(A):without(B)` | both apply | last call only |
| `jecs.component()` / `jecs.tag()` after a world exists | `world:component()` raises; debug world raises on `add`/`set`/`remove` | silent id collision |
| Hook or trait set after first use | debug world raises | ignored |
| Raw hook over signal listeners | debug world raises | silent |
| Structural change in `OnRemove` during `delete` | debug world raises | raises only on cascades |
| `delete` of a dead handle, debug world | raises | ignored |
| Generation | 24 bits | 16 bits |

## Setup

```luau
--!strict
local jecs = require(path.to.jecs)
local pair = jecs.pair

local Health = jecs.component<<number>>()   -- data
local Dead = jecs.tag()                     -- tag
jecs.meta(Health, jecs.Name, "Health")      -- value on the id
jecs.meta(Dead, jecs.Exclusive)             -- trait on the id

local world = jecs.world(RunService:IsStudio()) -- true = debug world
```

- Ids, then `jecs.meta`, then the world. `meta` only reaches worlds created after it.
- After the world exists, make ids with `world:component<<T>>()` (data) and `world:entity()` (tag).
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

Singleton: `world:set(Time, Time, 12.5)`, `world:get(Time, Time)`.

## Handles

- A handle is slot + generation: `jecs.ECS_ID(e)`, `jecs.ECS_GENERATION(e)`.
- The newest freed slot is reused first, generation + 1. The old handle stays unequal until the generation wraps (16,777,216 reuses, **fork**; 65,536 upstream).
- Reads through a dead handle are safe: `get` nil, `has` false.
- Check `world:contains` before a write or `pair()`. A pair from a dead handle raises while the slot is free, and silently links to the new occupant once it is reused.

## Mistakes

| Mistake | Result | Instead |
|---|---|---|
| `world:component()` as a marker | A column and one of 256 ids ("Too many components" past them) | `jecs.tag()` |
| `world:set` with a value on a tag | Raises | `world:add` |
| `world:add` of a data component | `has` true, `get` nil | `world:set` |
| Fifth id to `get` / `has` | On a live entity `get` raises "args exceeded"; `has` raises only if the first four are present, else false | Two calls |
| `world:exists` to validate | True for a dead handle | `world:contains` |
| Write to a dead handle | Ignored (normal world), raises (debug) | `world:contains` first |
| `world:entity(id)` | Can kill a live entity and give its components to the new id | `world:entity()` |
| `world:range(a, b)` | Hands out ids above `a` (and above the current highest id) up to `b - 1`, then raises | Avoid |
