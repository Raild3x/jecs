# Flecs and JECS

JECS borrows its model from Flecs: archetypes, pairs, wildcards, cleanup traits, hooks. Flecs documentation is a good guide to design, and a poor guide to what JECS can do. This file says which Flecs patterns carry over and which features JECS lacks, so a Flecs idea is translated instead of copied.

## What carries over

| Flecs | JECS |
|---|---|
| Component | `jecs.component<<T>>()` or `world:component<<T>>()` |
| Tag | `jecs.tag()` or `world:entity()` |
| `ecs_set`, `ecs_add`, `ecs_remove`, `ecs_get`, `ecs_has` | `world:set`, `world:add`, `world:remove`, `world:get`, `world:has` (at most four ids for the last two) |
| `ecs_is_alive` | `world:contains` |
| Pair `(Relationship, Target)` | `pair(Relationship, Target)` |
| `ChildOf`, `ecs_get_parent`, children iterator | `jecs.ChildOf`, `world:parent`, `world:children` |
| `ecs_get_target(e, R, index)` | `world:target(e, R, index)`, zero-based |
| Wildcard `*` | `jecs.Wildcard` |
| `Exclusive` trait | `jecs.Exclusive` |
| `(OnDelete, Delete)`, `(OnDeleteTarget, Delete)`, `Remove` | `pair(jecs.OnDelete, jecs.Delete)`, `pair(jecs.OnDeleteTarget, jecs.Delete)`, `jecs.Remove` |
| Component hooks `on_add`, `on_set`, `on_remove` | `jecs.OnAdd`, `jecs.OnChange`, `jecs.OnRemove`, installed with `jecs.meta` |
| Observer on one component | `world:added`, `world:changed`, `world:removed` |
| Cached query | `world:query(...):cached()`, created once |
| Uncached query | `world:query(...)`, iterated where it is built |
| `with`, `without` terms | `:with(A, B)`, `:without(C)` |
| Singleton | a component set on its own id: `world:set(Time, Time, value)` |
| Stage and merge, `ecs_defer_begin` / `ecs_defer_end` | `world.deferred` and `world.deferred:apply()` (fork), queued by hand |
| Entity name | `jecs.Name`, a plain string with no lookup |

Flecs design advice that holds in JECS:

- Keep components small and split by what systems read together.
- Give a system one responsibility.
- Create cached queries ahead of time, never inside a system.
- Check a stored entity handle is alive before using it.
- Reach for a relationship when the reverse lookup or the grouping is needed, and keep the number of targets small.
- Group ids and systems by feature, with the ids of a feature importable apart from its systems.

## What JECS lacks

Each of these is a Flecs feature with no JECS equivalent. When a Flecs pattern depends on one, use the substitute.

| Flecs feature | In JECS |
|---|---|
| Prefabs and `IsA` inheritance | A plain function that spawns an entity and sets its components. Shared data is one table referenced from a component. |
| Automatic deferral of changes made while iterating | Nothing is deferred for you. Queue on `world.deferred` (fork) or collect and apply after the loop. |
| Systems, pipelines and phases | Systems are functions the game calls in a fixed order. A phase is a naming convention for a group of them. |
| Query traversal (`up`, `cascade`) and query variables | Walk the hierarchy by hand with `world:parent` and `world:children`. Join by running one query and calling `world:get` on the related entity. |
| `order_by`, `group_by` | Collect the results and sort them. Iteration order is not stable between runs. |
| Non-fragmenting relationships (`DontFragment`) and sparse components | Every pair fragments. For a link with many targets store the entity in a component. |
| Observers over several terms, and custom events | Signals watch one id. Send game events through an array that systems read. |
| `in` / `out` annotations and built-in change detection | `changed` signals, or a dirty tag that a system sets and clears. |
| Entity lookup by name or path | Keep your own table from name to entity. |
| Modules, the REST API, the explorer, timers, the meta addon | Plain Luau modules. Debugging tools are separate projects. |
| Bulk and batched creation APIs | `jecs.bulk_insert` for one entity, with the limits in the API reference. |
| `Symmetric`, `Transitive`, `Traversable`, `With`, `OneOf` and other relationship traits | Only `Exclusive` and the cleanup traits exist. Enforce anything else in the code that adds the pair. |
| Multithreading and staged worlds | One world, one thread. Parallel Luau needs its own copy of the data. |

## Differences that look the same

- **`on_set` against `OnChange`.** Flecs `on_set` runs for the first value too. JECS runs `OnAdd` with the value for the first `set` and `OnChange` only for later ones.
- **Hooks are frozen at first use.** Flecs lets hooks be registered when the component is registered. JECS reads them when the id is first used, so they must come through `jecs.meta` before the world exists.
- **Remove order on cascade.** JECS runs the parent's remove callbacks before its children's.
- **Structural changes in a remove hook.** Flecs defers operations made from observers. In JECS they run at once and are undefined behaviour inside a remove hook: queue them.
- **A pair forgets generations.** A JECS pair built from a stale handle points at the slot's new occupant.
- **Tags must be made as tags.** In JECS `world:component()` always has storage. A Flecs-style empty struct maps to `jecs.tag()`.
