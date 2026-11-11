---
name: jecs
description: Use when writing, reviewing or debugging Luau that uses JECS (worlds, components, tags, queries, pairs, hooks, signals, deferred changes), when designing components, entities or systems for a Roblox game built on JECS, or when carrying a Flecs pattern over to JECS.
---

# JECS

JECS is an archetype entity-component-system for Luau. These rules are written for the fork `raild3x/jecs`. Each rule gives its reason, because most of them guard against a failure that is silent.

## Before writing code

1. **Find which JECS the project uses.** Read `wally.toml` for `raild3x/jecs` or `ukendio/jecs`. Rules marked **fork** rely on behaviour only `raild3x/jecs` has; on `ukendio/jecs` use the stated alternative.
2. **Confirm the place holds one copy of JECS.** Search for a second `jecs` module (a vendored copy, or a package that bundles its own). *Why:* ids are allocated from state inside the module, so two copies hand out the same ids for different things and corrupt each other.
3. **Write plain Luau under `--!strict`** with explicit type instantiation: `jecs.component<<number>>()`, `world:component<<Vector3>>()`. *Why:* the id carries its value type, so `world:get` and query loops come back typed.

## Rules

### Setup

- **Define every id in one module, configure it there, then create the world.** `jecs.component<<T>>()` for data, `jecs.tag()` for tags, `jecs.meta(id, ...)` for names, traits and hooks, and only then `jecs.world()`. *Why:* hooks and traits are read once, when an id is first used, and anything configured later is ignored without an error. A `jecs.component()` or `jecs.tag()` call made after a world exists returns an id that world has already handed out (**fork** raises; upstream stays silent).
- **Data is a component, a yes/no fact is a tag.** Tags come from `jecs.tag()` or `world:entity()`. `world:component()` always makes a data component. *Why:* a component takes a storage column and one of only 256 component ids. `world:set` with a value on a tag raises, and `world:add` of a data component leaves `get` returning nil.
- **Develop on `jecs.world(true)`, ship on `jecs.world()`**, for example `jecs.world(RunService:IsStudio())`. *Why:* a normal world ignores operations on dead entities without an error. The debug world raises on those, and on the **fork** also on late hooks, late traits, late registration and structural changes inside a remove hook. It makes `world:set` about 3.7 times slower.

### Hooks, signals and systems

- **Install hooks only through `jecs.meta` at definition. Outside observers use `world:added`, `world:changed` and `world:removed`. Gameplay logic goes in systems.** *Why:* `world:set(id, jecs.OnAdd, fn)` at runtime is ignored once the id is in use, and when the id already has signal listeners it either silences them or is ignored itself.
- **A remove hook or listener only reads and releases.** Queue any structural change it wants on `world.deferred` (**fork**). Keep every hook and listener too simple to raise. *Why:* the maintainer has said structural changes inside a remove hook are undefined behaviour. A listener that raises aborts the operation half way: the value is already written, or the entity being deleted stays alive.
- **Treat `OnChange` as "set was called".** *Why:* it fires when the new value equals the old one, and never when a table value is mutated in place.

### Structural changes

A **structural change** moves an entity between archetypes: `add`, `remove`, `delete`, `clear`, or `set` of a component the entity does not have yet. `world:set` of a component the entity already has is not structural.

- **Make structural changes after the loop, never inside it.** Inside a `for ... in` over a query, `world:each` or `world:children`, queue them on `world.deferred` and call `world.deferred:apply()` after the loop (**fork**), or collect entities into a table and change them after the loop. *Why:* deleting only the entity being visited skipped live entities in about 30% of randomised trials when that entity was a pair target, and adding to the visited entity can visit it twice.
- **When another system runs between deciding an entity must go and deleting it, mark the entity with a tag** such as `Dead`, have those systems filter `:without(Dead)`, and let one system delete the marked ones. *Why:* a queued delete is invisible to every other system until it is applied. A system that decides and deletes in one go needs no tag.

### Queries

- **Give every filter id in one call:** `:with(A, B)`, `:without(C, D)`. *Why:* on upstream a second `:with` replaces the first.
- **Call `:cached()` once, at module scope, for a query that runs every frame.** *Why:* each call registers two observers that stay until `:fini()`.
- **Iterate an uncached query where it is built.** *Why:* stored in a variable it yields nothing the second time.
- **Give a nested loop its own query.** *Why:* iterating a query inside its own loop ends the outer loop early.
- **Sort or key results yourself when order matters.** *Why:* iteration order follows archetype layout and differs between runs.
- **`world:has` and `world:get` take at most four ids.** Queries take more terms.

### Entities and handles

- **Check a stored entity with `world:contains` before writing to it or building a pair from it.** A read needs no check: `world:get` and `world:has` return nil and false for a dead handle. *Why:* a normal world ignores a write to a dead entity without an error, and for a deleted entity `contains` is false while `exists` stays true. A deleted slot is reused, and the old handle value itself is issued again after 16,777,216 reuses of one slot (**fork**; 65,536 on upstream).
- **Create entities with `world:entity()` and no argument, and leave `world:range` alone.** *Why:* in both libraries `world:entity(id)` can corrupt the entity index (one id issued to two entities, a live entity killed without an error), and `world:range` raises on the second entity created inside its own range.

### Decision guide

- **State that is one of several values: a value component.** A tag for an independent yes/no. An exclusive pair only where a per-frame system selects a minority state among thousands of entities, or where a measurement asks for it. *Why:* switching an exclusive pair costs 5 to 38 times a `set` and is a structural change.
- **A link where the holder belongs to the target: a pair on the many side pointing at the few, with a cleanup trait.** A link that merely points: the entity stored in a component, with a dead target read as no target. Keep targets times holder shapes in the hundreds. *Why:* every distinct target creates archetypes, and at 10,000 targets building the world is 10 to 19 times slower and deleting the targets far worse.
- **Build a pair only from a handle just checked with `world:contains`.** *Why:* a pair keeps no generation, so a stale handle links to whatever entity now sits in that slot, even in a debug world.
- **An event: a helper function that appends to a plain array.** Systems that read it run after the systems that emit, and one named system clears it last. Use a tag on the target only for a fact that is the same however often it is stated, and an entity only for something that outlives the frame. *Why:* with a "pending" component a second event in the same frame overwrites the first.
- **"Who points at me" over many changing targets: a table built on first use in a frame, inside the system that needs it, and dropped at frame end.** *Why:* pairs would create an archetype per target, and a scan per lookup reads every holder each time.
- **`jecs.bulk_insert` only to spawn a fresh entity with about eight or more plain components and tags, where measured.** *Why:* it is slower than `set` at three components and 1.57 times faster at twelve, it bypasses `Exclusive` and every debug check, and it stays silent when given fewer values than ids.
- **A signal on one pair, `world:added(pair(R, target), fn)`, is fork only.** Disconnect it when its target dies and keep them to a handful per relation. For many targets connect one listener to `R` and look the pair id up in a table. *Why:* it is registered on the relation, so every event on `R` runs every pair listener's filter: an add costs four times as much with 100 of them.

## References

| Read | When |
|---|---|
| [references/api.md](references/api.md) | Calling any JECS function: exact signatures, what each call does on tags, pairs and dead entities, and the fork and upstream differences in one table. |
| [references/design.md](references/design.md) | Deciding how to model something, or writing a system: tested code for each pattern above, and the measured cost of each alternative. |
| [references/flecs.md](references/flecs.md) | The user names Flecs or brings a Flecs pattern: what carries over and what JECS lacks. |
| [verify/](verify/) | A rule here seems wrong, or JECS was updated: copy the project's `jecs.luau` into `verify/` and run `lune run facts.luau` and `lune run examples.luau`. A failure names the fact that changed. Inside the JECS repository itself, `lune run run.luau` from `verify/` does both against `src/jecs.luau`. |

Rewritten from the `jecs` and `ecs-design` skills by christopher-buss.
