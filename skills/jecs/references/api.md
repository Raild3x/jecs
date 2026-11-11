# JECS API

What each call does, including on tags, pairs and dead entities. Behaviour is that of `ukendio/jecs` 0.11.0 and `raild3x/jecs` 0.11.0-fork.1 unless a line says **fork** or **upstream**. Every behaviour stated here is asserted in [`../verify/facts.luau`](../verify/facts.luau) or [`../verify/examples.luau`](../verify/examples.luau).

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
| Entity generation | 24 bits | 16 bits |

## Ids

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
- `world:component()` raises after 256 component ids. For data beyond that, add the `jecs.Component` trait to an entity: `world:add(id, jecs.Component)`, then `world:set(e, id, value)` works.
- `jecs.is_tag(world, id)` tells a tag from a data component.
- An entity handle packs a slot index and a generation: `jecs.ECS_ID(e)`, `jecs.ECS_GENERATION(e)`. Deleting an entity frees its slot, and the next `world:entity()` reuses the most recently freed slot with the generation raised by one.

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
| `world:delete(e)` | Deletes `e`, removes it wherever it is used as a tag or target, and applies cleanup traits. Does nothing for a dead handle. |
| `world:contains(e)` | True only for a live handle. |
| `world:exists(e)` | True when the slot is in use by any generation. Use `contains` to validate a handle. |

A singleton is a component set on its own id: `world:set(Time, Time, 12.5)`, `world:get(Time, Time)`.

A normal world ignores `set`, `add` and `remove` on a dead entity. A debug world raises on them. `get` and `has` on a dead entity return nil and false in both.

## Queries

```luau
-- module scope: runs every frame, so cached once
local movers = world:query(Position, Velocity):without(Frozen):cached()

local function move(dt: number)
	for entity, position, velocity in movers do
		world:set(entity, Position, position + velocity * dt) -- already has Position: not structural
	end
end

-- one-off: built and iterated in place
for entity, health in world:query(Health):with(Burning, Poisoned) do
end
```

| Call | Does |
|---|---|
| `world:query(a, b, ...)` | Entities that have every term. The loop yields the entity, then one value per term. A tag term yields nil. |
| `:with(x, y)` | Also require these ids, without yielding their values. |
| `:without(x, y)` | Exclude entities that have any of these ids. |
| `:cached()` | A reusable query that tracks new archetypes. Apply `:with` and `:without` first: a cached query has neither. |
| `query:has(e)` | Whether the entity currently matches. |
| `query:archetypes()` | The matching archetypes, including empty ones. Each has `entities` and `columns_map[id]`. |
| `cached:fini()` | Removes the cached query's two observers. Call it for a cached query that is no longer needed. |
| `world:each(id)` | Iterator over entities that have one id. |
| `world:children(parent)` | Iterator over entities with `pair(jecs.ChildOf, parent)`. |

## Pairs

`pair(relation, target)` is an id made of two ids. It keeps the slot of each and drops their generations.

| Pair | Holds |
|---|---|
| `pair(dataRelation, entity)` | A value, typed by the relation. |
| `pair(tagRelation, dataComponent)` | A value, typed by the target. |
| `pair(tagRelation, entity)` | Nothing: it is a tag, and `world:set` on it raises. |

| Call | Does |
|---|---|
| `world:target(e, R, index?)` | The target of `e`'s `index`-th pair of `R`. The index starts at 0 and defaults to 0. Nil when there is none. |
| `world:targets(e, R)` | Iterator over every target of `R` on `e`. |
| `world:parent(e)` | `world:target(e, jecs.ChildOf)`. |
| `world:query(pair(R, jecs.Wildcard))` | Entities with any pair of `R`. One row per entity, however many targets it has. |
| `world:query(pair(jecs.Wildcard, T))` | Entities with any pair that targets `T`. |
| `jecs.pair_first(world, id)`, `jecs.pair_second(world, id)` | The live relation and target of a pair id. |
| `jecs.IS_PAIR(id)` | Whether an id is a pair. |

## Traits

Set a trait through `jecs.meta`, or with `world:add(id, trait)` before the id is first used.

| Trait | Effect |
|---|---|
| `jecs.Exclusive` on a relation | An entity holds one target of it. Adding another replaces the first. |
| `pair(jecs.OnDeleteTarget, jecs.Delete)` on a relation | Deleting a target deletes every entity that holds a pair to it. |
| `pair(jecs.OnDelete, jecs.Delete)` on an id | Deleting the id deletes every entity that has it. |
| none (the default) | Deleting an id or a target removes it from its holders, which survive. |
| `jecs.ChildOf` (built in) | Exclusive, with `(OnDeleteTarget, Delete)`: deleting a parent deletes its descendants. |
| `jecs.Component` on an entity | The entity can hold data when used as a component. |
| `jecs.Name` | A string name for an id: `jecs.meta(Health, jecs.Name, "Health")`. |

On a cascade delete the parent's remove callbacks run before its children's.

## Hooks and signals

A hook is the one callback an id's owner installs. A signal is any number of listeners that anyone connects.

```luau
jecs.meta(Health, jecs.OnAdd, function(entity, id, value) end)
jecs.meta(Health, jecs.OnChange, function(entity, id, value) end)
jecs.meta(Health, jecs.OnRemove, function(entity, id, deleted) end)

local disconnect = world:added(Health, function(entity, id, value) end)
world:changed(Health, function(entity, id, value) end)
world:removed(Health, function(entity, id, deleted) end)
disconnect() -- raises when called twice
```

- `OnAdd` and `added` run when the id is added, with the value given to `set` (nil for `add`). `OnChange` and `changed` run on every later `set`, including one that stores an equal value, and never for a table mutated in place. The first `set` runs only the add callbacks.
- `OnChange` runs after the new value is stored, so the value it replaced is gone. To release a replaced value, such as a Roblox instance, keep your own table from entity to the current value.
- `OnRemove` and `removed` run before the id leaves the entity, so `world:get(entity, id)` still returns the value. `deleted` is true when the whole entity is being deleted, cascades included, and nil for `remove` and `clear`.
- A hook or signal on a relation runs for its pairs, and `id` is then the full pair id.
- A hook installed first and signals connected later all run. A signal can be connected after the id is in use.
- A callback that raises aborts the operation where it stands: after a `set` the value is already stored, and a `delete` leaves the entity alive.
- A hook that needs the world closes over a variable assigned after `jecs.world()`: see the components module in [design.md](design.md).
- **fork:** `world:added(pair(R, target), fn)`, and the same for `changed` and `removed`, runs for that pair only, and stops matching once `target` is deleted. `pair(R, jecs.Wildcard)` is the same as `R`. `pair(jecs.Wildcard, target)` raises, as does a pair whose relation or target is dead. It is registered on `R`, so each event on `R` costs about 12 to 20 ns more per pair listener. For many targets connect one listener to `R` and look the pair id up in a table.

## Deferred changes (fork)

```luau
local deferred = world.deferred        -- the world's shared queue
for entity, health in world:query(Health) do
	if health <= 0 then
		deferred:delete(entity)
	end
end
deferred:apply()

local mine = jecs.deferred(world)      -- a separate queue, applied on its own
```

- `deferred:add(e, id)`, `:set(e, id, value)`, `:remove(e, id)` and `:delete(e)` queue the change. Nothing is visible until `:apply()`.
- `apply` makes the changes in the order queued, through the world's own methods, and skips a change whose entity is no longer alive.
- A change that a hook or listener queues during `apply` runs before the next queued change.
- An error during `apply` reaches the caller. The change that raised is dropped and the ones that have not run stay queued for the next `apply`.
- A value is captured when queued. A table is captured by reference, so later mutations show through.
- Code that queues on the shared queue calls `apply` right after its own loop. A change queued by a hook or listener is made by whichever `apply` comes next, so also give the frame one fixed `apply`, after the last system, to catch those.

## bulk_insert

`jecs.bulk_insert(world, entity, ids, values)` adds several ids in one archetype move, with `values[i]` going to `ids[i]`. Put data components first and tags last. `jecs.bulk_remove(world, entity, ids)` removes several.

It runs hooks, but skips the `Exclusive` trait and every debug-world check, and accepts fewer values than data components without an error (the rest are left nil).
