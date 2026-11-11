---
name: jecs
description: Use when writing, reviewing or debugging Luau that uses JECS (worlds, components, tags, queries, pairs, hooks, signals, deferred changes), when designing ECS components, entities or systems for a Roblox game, when a JECS hook never fires, a query yields nothing or a loop skips entities, or when carrying a Flecs pattern over to JECS.
---

# JECS

Archetype ECS for Luau. Most mistakes fail silently.

**Core principle: configure every id before the world exists; change structure only after a loop ends; model relationships as pairs.**

For the fork `raild3x/jecs`. **fork** marks fork-only behaviour. Not covered: roblox-ts, replication, scheduler choice.

## Before writing code

1. Read `wally.toml`: `raild3x/jecs` or `ukendio/jecs`. Upstream lacks the **fork** features: see [core-basics](references/core-basics.md).
2. One copy of JECS per place. Ids come from module state; two copies collide.
3. `--!strict`, explicit types: `jecs.component<<number>>()`. `world:get` comes back typed; query values only under the new type solver.
4. `jecs.world(RunService:IsStudio())`. The debug world raises where a normal one is silent; `set` costs 3.7x.

## Quick reference

| Need | Use |
|---|---|
| Data | `jecs.component<<T>>()` + `world:set` |
| Yes/no fact | `jecs.tag()` + `world:add` |
| Hierarchy, ownership, membership, grouping | Pair + cleanup trait |
| "Who points at me" | `world:query(pair(R, target))` |
| One-of-several state | Exclusive pair |
| State or target rewritten on most entities every frame | Value component (pair switch costs 4-38x a `set`) |
| Event handled this frame | Record in an array |
| Component's own invariant | Hook via `jecs.meta` |
| Observer, runtime toggle | `world:added/changed/removed` |
| Structural change from a loop, hook or listener | `world.deferred` then `apply()` (**fork**); else collect, apply after |

**Structural change:** `add`, `remove`, `delete`, `clear`, or `set` of a component the entity lacks.

## Mistakes that cut across topics

| Mistake | Result | Instead |
|---|---|---|
| Structural change inside a query, `each` or `children` loop | Entities skipped or visited twice | After the loop |
| Structural change or a raise in a remove hook/listener | Undefined; operation aborts half done | Queue on `world.deferred` (**fork**), else do it after the operation; keep callbacks trivial |
| `jecs.component/tag/meta` after `jecs.world()` | Id collides with a world id (**fork**: `world:component()` raises, debug world raises on writes); `meta` ignored | Ids and config in one module, then the world |
| Hook or trait set at runtime | Ignored once the id is in use | `jecs.meta`, or a signal |
| Write or `pair()` through a stored handle | Write ignored; pair raises, or once the slot is reused links to its new occupant | `world:contains` first |

Topic mistakes are in each reference file.

## References

| File | Open when |
|---|---|
| [core-basics](references/core-basics.md) | World, ids, entities, components, handles, fork vs upstream |
| [core-queries](references/core-queries.md) | Queries, filters, caching, counting |
| [feature-pairs](references/feature-pairs.md) | Relationships, targets, wildcards, hierarchy |
| [feature-cleanup-traits](references/feature-cleanup-traits.md) | What deleting an id or target does to holders |
| [feature-hooks](references/feature-hooks.md) | `OnAdd`, `OnChange`, `OnRemove` |
| [feature-signals](references/feature-signals.md) | Listeners, pair signals |
| [feature-deferred](references/feature-deferred.md) | `world.deferred` |
| [best-practices-components](references/best-practices-components.md) | Splitting data; tag, value or pair |
| [best-practices-entities](references/best-practices-entities.md) | What is an entity; links between entities |
| [best-practices-queries](references/best-practices-queries.md) | Turning a question into a query |
| [best-practices-systems](references/best-practices-systems.md) | Systems, structure changes, events |
| [best-practices-change-tracking](references/best-practices-change-tracking.md) | Finding what changed |
| [best-practices-archetypes](references/best-practices-archetypes.md) | Mental model, measured costs |
| [advanced-api](references/advanced-api.md) | `bulk_insert`, >256 components, debug world |
| [flecs](references/flecs.md) | Flecs named: what carries over, what is missing |
| [verify/](verify/) | A rule looks wrong or JECS changed: copy `jecs.luau` in, `lune run facts.luau`, `lune run examples.luau` |

Rewritten from the `jecs` and `ecs-design` skills by christopher-buss.
