---
name: jecs
description: Use when writing, reviewing or debugging Luau that uses JECS (worlds, components, tags, queries, pairs, hooks, signals, deferred changes), when designing ECS components, entities or systems for a Roblox game, when a JECS hook never fires, a query yields nothing or a loop skips entities, or when carrying a Flecs pattern over to JECS.
---

# JECS

Archetype ECS for Luau. Most mistakes fail silently, so the rules here come with the reason: use it to judge cases the rule does not name.

**Core principle: configure every id before the world exists; change structure only after a loop ends; choose each model by how the data is read and how often it changes.**

Written for the fork `raild3x/jecs`. Not covered: roblox-ts, replication, scheduler choice.

## Before writing code

1. Read `wally.toml`. If it names `ukendio/jecs`, read [upstream-differences](references/upstream-differences.md) first: several calls here are missing or fail silently there.
2. One copy of JECS per place. Ids come from module state, so two copies hand out colliding ids.
3. `--!strict`, explicit types: `jecs.component<<number>>()`. `world:get` comes back typed; query values only under the new type solver.
4. `jecs.world(RunService:IsStudio())`; outside Roblox (lune tests, scripts) pass `true`. The debug world raises where a normal one is silent. It costs about 3.7x on a component `set` and 9x on a pair `set`, so not in production.

## Quick reference

| Need | Use | Because |
|---|---|---|
| Data | `jecs.component<<T>>()` + `world:set` | |
| Yes/no fact | `jecs.tag()` + `world:add` | Queries select on presence |
| Query a system runs every frame | `world:query(...):cached()`, once, at module scope | An uncached query matches archetypes again on every call: no measurable cost with one archetype, 1.3x at 1,000, and 2.6-4x when few entities are spread over many |
| Query with a term only known at call time (`pair(InZone, zone)`) | Uncached, iterated where it is built | A cached one per call leaks observers |
| Holder belongs to, is part of, or is grouped by another entity | Pair + cleanup trait | Reverse lookup and cascade come free |
| Holder merely points at another entity (AI target, last attacker) | Entity in a component; the system that reads it removes it once `world:contains` fails | Read per row and retargeted without moving the entity. Nothing else clears it when the target dies |
| One-of-several state that systems select by, rarely changed | Exclusive pair | The query skips non-matching entities |
| One-of-several state read in a loop over everyone, or changed often | Value component | A pair switch costs 4-38x a `set` |
| Derived value (speed from velocity) | Compute it; store only if costly or widely read, refreshed by one system | A stored copy goes stale when any writer forgets it |
| Event handled this frame | Record in an array | No structural change per event |
| Component's own invariant | Hook via `jecs.meta` | Runs for every writer |
| Observer, runtime toggle | `world:added/changed/removed` | Many listeners, disconnectable |
| Structural change from a loop, hook or listener | `world.deferred` then `apply()` | The loop finishes on unchanged storage |

**Structural change:** `add`, `remove`, `delete`, `clear`, or `set` of a component the entity lacks. It moves the entity to another archetype.

Design choices only matter for speed at thousands of entities touched every frame. Below that, pick the model that is simplest to query and hardest to get wrong.

## Symptoms

| Symptom | Likely cause | See |
|---|---|---|
| Hook never fires | Installed after the id's first use; only `OnChange` installed (the first `set` is `OnAdd`); a second hook of the same kind replaced it; the hook is on a component used as a pair target (`pair(Begin, Position)` does not run `Position`'s hooks) | [feature-hooks](references/feature-hooks.md) |
| `changed` never fires | Table mutated in place; no `world:set` | [best-practices-change-tracking](references/best-practices-change-tracking.md) |
| Query yields nothing, or only the rest, the second time | An uncached query was stored and iterated again | [core-queries](references/core-queries.md) |
| `has` is true but `get` is nil | `world:add` used for a data component, or `world:set(e, id, nil)` | [core-basics](references/core-basics.md) |
| Loop skips or repeats entities | Structural change inside the loop | [best-practices-systems](references/best-practices-systems.md) |
| A tag vanishes from every entity when an unrelated entity is deleted | `jecs.tag()` / `jecs.component()` called after `jecs.world()` | [core-basics](references/core-basics.md) |
| Write does nothing | Dead handle on a normal world | [core-basics](references/core-basics.md) |
| Entity linked to the wrong target | `pair()` built from a stale handle | [feature-pairs](references/feature-pairs.md) |
| Queued change never happens | `apply()` not called; the entity or a pair's target died before `apply`; it went to a different queue than the one applied | [feature-deferred](references/feature-deferred.md) |
| Memory or frame time climbs | `:cached()` inside a system; pairs retargeted or built every frame across many targets | [core-archetypes](references/core-archetypes.md), [performance](references/performance.md) |

## Mistakes that cut across topics

| Mistake | Result | Instead |
|---|---|---|
| Structural change inside a query, `each` or `children` loop | Entities skipped or visited twice | Queue on `world.deferred`, apply after the loop |
| Structural change or a raise in a remove hook/listener | Undefined; operation aborts half done | Queue on `world.deferred`; keep callbacks trivial |
| `jecs.component/tag/meta` after `jecs.world()` | Id collides with a world id (`world:component()` raises, debug world raises on writes); `meta` ignored | Ids and config in one module, then the world |
| Hook or trait set at runtime | Applied unevenly: ignored for ids and pairs already in use, partly honoured for pairs to new targets | `jecs.meta`, or a signal |
| Write or `pair()` through a stored handle | Write ignored; adding the pair raises, or once the slot is reused links to its new occupant | `world:contains` first, and decide what a dead handle means: a setter that just returns keeps the old value, where clearing it is usually what was meant |
| Reading or writing a parent or pair target from a remove hook or listener | It may be the entity being deleted: `contains` is true, `get` gives nil, writes are thrown away with it | Record the id, act after the delete returns, or queue on `world.deferred` |
| A wildcard pair passed to `add`, `set`, `remove` or `bulk_remove` | `remove` and `bulk_remove` raise. On a normal world `add` stores a literal wildcard pair and `set` overwrites the first target's value | Name the target; iterate `world:targets` |

Topic mistakes are in each reference file.

## Before reporting done

Run what you wrote once: require the module from a throwaway script (`lune run`, or the Studio command bar) and call each function you added. Most JECS mistakes pass a read-through and fail on the first call: an id registered after the world raises on its first `set`.

## References

| File | Open when |
|---|---|
| [core-basics](references/core-basics.md) | World, ids, entities, components, handles; what the debug world catches |
| [core-queries](references/core-queries.md) | Queries, filters, caching, counting, column loops |
| [core-archetypes](references/core-archetypes.md) | How entities are stored; what a structural change is; fragmentation |
| [feature-pairs](references/feature-pairs.md) | Relationships, targets, wildcards, hierarchy |
| [feature-cleanup-traits](references/feature-cleanup-traits.md) | What deleting an id or target does to holders |
| [feature-hooks](references/feature-hooks.md) | `OnAdd`, `OnChange`, `OnRemove` |
| [feature-signals](references/feature-signals.md) | Listeners, pair signals |
| [feature-deferred](references/feature-deferred.md) | `world.deferred` |
| [best-practices-components](references/best-practices-components.md) | Splitting data; tag, value or pair; derived data |
| [best-practices-entities](references/best-practices-entities.md) | What is an entity; links between entities |
| [best-practices-queries](references/best-practices-queries.md) | Turning a question into a query; grouping |
| [best-practices-systems](references/best-practices-systems.md) | Systems, structure changes, events |
| [best-practices-change-tracking](references/best-practices-change-tracking.md) | Finding what changed |
| [performance](references/performance.md) | Measured cost of each choice and the setup behind it; when speed matters at all |
| [advanced-api](references/advanced-api.md) | `bulk_insert`, >256 components, `world:cleanup` |
| [flecs](references/flecs.md) | Flecs named: what carries over, what is missing |
| [upstream-differences](references/upstream-differences.md) | The project uses `ukendio/jecs` |

Rewritten from the `jecs` and `ecs-design` skills by christopher-buss.
