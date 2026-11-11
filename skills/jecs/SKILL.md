---
name: jecs
description: Use when writing, reviewing or debugging Luau that uses JECS (worlds, components, tags, queries, pairs, hooks, signals, deferred changes), when designing ECS components, entities or systems for a Roblox game, when a JECS hook never fires, a query yields nothing or a loop skips entities, or when carrying a Flecs pattern over to JECS.
---

# JECS

## Overview

JECS is an archetype entity-component-system for Luau. Most mistakes with it fail silently: a late hook is ignored, a stored query yields nothing, a loop skips entities.

**Core principle: configure every id before the world exists, and change structure only after a loop ends.**

Written for the fork `raild3x/jecs`. Behaviour only the fork has is marked **fork**.

Not covered: roblox-ts, replication between client and server, and the choice of scheduler.

## Before writing code

1. **Read `wally.toml` for `raild3x/jecs` or `ukendio/jecs`.** On `ukendio/jecs` the fork features are absent: use the alternatives in [core-basics](references/core-basics.md).
2. **Confirm the place holds one copy of JECS.** *Why:* ids come from state inside the module, so two copies hand out the same ids for different things.
3. **Write `--!strict` Luau with explicit type instantiation:** `jecs.component<<number>>()`. *Why:* the id carries its value type, so `world:get` and query loops come back typed.
4. **Develop on `jecs.world(true)`, ship on `jecs.world()`**, for example `jecs.world(RunService:IsStudio())`. *Why:* the debug world raises where a normal world stays silent, and makes `world:set` about 3.7 times slower.

## Quick reference

| Need | Use | Why |
|---|---|---|
| Data on an entity | `jecs.component<<T>>()`, `world:set` | Queries read it as a typed column. |
| A yes/no fact | `jecs.tag()`, `world:add` | `world:component()` always takes storage and one of 256 ids. |
| One of several states | One value component | Switching an exclusive pair costs 4 to 38 times a `set`. |
| A per-frame system picks a small share of thousands | Exclusive pair | The query visits only the matches. |
| Holder belongs to target, targets few | Pair on the many side, with a cleanup trait | Reverse lookup and cascade delete. |
| Holder points at a target | The entity in a component; a dead target reads as none | No archetype per target. |
| "Who points at me", many targets | A table built once per frame | Pairs fragment; scans repeat. |
| An event handled this frame | A record in a plain array, cleared by the last system | A "pending" component keeps only the last event. |
| A component's own invariant | A hook through `jecs.meta` | Hooks are read once, at first use. |
| An outside observer, or a runtime toggle | `world:added`, `world:changed`, `world:removed` | Signals connect and disconnect at any time. |
| A structural change from a loop, hook or listener | `world.deferred`, then `apply()` (**fork**); else collect, then apply | Changing structure mid-loop skips or repeats entities. |
| Other systems must skip a doomed entity | A marker tag and `:without(Dead)` | A queued delete is invisible until applied. |

A **structural change** is `add`, `remove`, `delete`, `clear`, or `set` of a component the entity lacks. `set` of a component it already has is not.

## Common mistakes

| Mistake | What happens | Instead |
|---|---|---|
| Structural change inside a loop over a query, `world:each` or `world:children` | Live entities are skipped (about 30% of trials when the deleted entity is a pair target) or visited twice. | Make it after the loop. |
| Structural change, or code that can raise, in a remove hook or listener | Undefined behaviour. A raise aborts half way: the value is stored, or the entity stays alive. | Queue it on `world.deferred`. Keep callbacks trivial. |
| `jecs.component()`, `jecs.tag()` or `jecs.meta` after `jecs.world()` | The id collides with one the world handed out (**fork** raises), and `meta` never reaches that world. | Define and configure every id in one module, then create the world. |
| `world:set(id, jecs.OnAdd, fn)` or a trait added at runtime | Ignored once the id is in use. Over signal listeners it silences them or is ignored. | `jecs.meta` at definition, or a signal. |
| `:with(A):with(B)`, `:without(A):without(B)` | On upstream only the last call applies. | `:with(A, B)`, `:without(A, B)` |
| `:cached()` inside a function that runs repeatedly | Each call registers two observers that stay until `:fini()`. | Once, at module scope. |
| An uncached query kept in a variable | It yields nothing the second time. | Iterate it where it is built, or cache it. |
| A query iterated inside its own loop | The outer loop ends early. | A separate query for the inner loop. |
| `world:component()` as a marker, `set` on a tag, `add` of a data component | A wasted column and one of 256 ids ("Too many components" past them); a raise; a nil value. | `jecs.tag()`; `add` for tags, `set` for data. |
| `world:has` or `world:get` with five ids | `get` raises "args exceeded". `has` raises only when the first four are present, else returns false. | Two calls. |
| `pair(R, handle)` from a stored handle | Links to the slot's new occupant, even in a debug world. | `world:contains(handle)` first. |
| Writing through an unchecked handle, or checking with `world:exists` | A normal world ignores the write; `exists` stays true for a dead entity. | `world:contains`. Reads need no check. |
| Treating `OnChange` as "the value differs" | It fires on an equal value, never for an in-place table mutation, and not for the first `set`. | [change tracking](references/best-practices-change-tracking.md) |
| `world:entity(id)` | Can kill a live entity and hand its components to the new id. | `world:entity()` |
| Relying on iteration order | It differs between runs. | Sort the results. |
| `jecs.bulk_insert` for small entities or exclusive pairs | Slower below six components; bypasses `Exclusive` and debug checks. | `set` and `add`; bulk only when measured. |
| Many pair listeners on one relation (**fork**) | Every event on it runs each one. | One listener on the relation and a table lookup. |

## References

| Read | When |
|---|---|
| **Core** | |
| [core-basics](references/core-basics.md) | Creating a world, ids, entities, components; what a call does on a tag or a dead entity; the fork and upstream differences. |
| [core-queries](references/core-queries.md) | Writing a query, filter, cached query or pair term. |
| **Features** | |
| [feature-pairs](references/feature-pairs.md) | Relationships, targets, wildcards, `ChildOf`. |
| [feature-cleanup-traits](references/feature-cleanup-traits.md) | What happens to holders when an id or target is deleted. |
| [feature-hooks](references/feature-hooks.md) | `OnAdd`, `OnChange`, `OnRemove`: when each runs and with what. |
| [feature-signals](references/feature-signals.md) | Listeners, hook or signal, signals on one pair. |
| [feature-deferred](references/feature-deferred.md) | `world.deferred`: semantics, who calls `apply`. |
| **Best practices** | |
| [best-practices-components](references/best-practices-components.md) | Splitting data, tag or value or pair, the components module. |
| [best-practices-entities](references/best-practices-entities.md) | What deserves an entity, handles, links between entities. |
| [best-practices-systems](references/best-practices-systems.md) | Writing a system, changing structure from a loop, marker tags, events. |
| [best-practices-change-tracking](references/best-practices-change-tracking.md) | Finding what changed since last frame. |
| [best-practices-archetypes](references/best-practices-archetypes.md) | Why a choice is fast or slow: the archetype model and the measured cost table. |
| **Advanced** | |
| [advanced-api](references/advanced-api.md) | `bulk_insert`, more than 256 components, what the debug world checks. |
| [flecs](references/flecs.md) | The user names Flecs: what carries over and what JECS lacks. |
| [verify/](verify/) | A rule seems wrong, or JECS was updated: copy the project's `jecs.luau` into `verify/` and run `lune run facts.luau` and `lune run examples.luau`. Inside the JECS repository, `lune run run.luau` does both. |

Rewritten from the `jecs` and `ecs-design` skills by christopher-buss.
