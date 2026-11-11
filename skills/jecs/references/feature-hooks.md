# Component hooks

One callback per kind per id, installed by the id's owner. JECS reads it when the id (or each pair of a relation) is first used, so install it before then. Think of them as the component's constructor and destructor.

## When to use

| Logic | Put it in | Because |
|---|---|---|
| The component's own invariant: clamp or validate a value, release what the value owns | Hook | It runs for every writer of that id, including code that calls `world:set` directly. It does not run for a pair that uses the component as its target (`pair(Begin, Position)`): hook the relation for those |
| Other code wants to know (UI, audio, tracking) | Signal: [feature-signals](feature-signals.md) | Several listeners, added and removed at run time; a hook slot is single and fixed |
| Gameplay rules | System | A hook runs in the middle of someone else's write, where order and structure changes are unsafe |

## API

```luau
jecs.meta(Health, jecs.OnAdd, function(entity, id, value) end)
jecs.meta(Health, jecs.OnChange, function(entity, id, value) end)
jecs.meta(Health, jecs.OnRemove, function(entity, id, deleted) end)
local world = jecs.world()
```

| Hook | Runs | Gets |
|---|---|---|
| `OnAdd` | Id added (first `set`, or `add`) | The value; nil for `add` |
| `OnChange` | Every later `set` | The new value |
| `OnRemove` | Before the id leaves | `deleted`: true if the entity is being deleted (cascades too); nil for `remove`, `clear` |

- The value is stored before `OnAdd` / `OnChange` run. The old value is gone.
- In `OnRemove`, `world:get(entity, id)` still returns the value.
- A hook runs before signal listeners.
- A hook on a relation runs for its pairs; `id` is the pair id, `jecs.pair_second(world, id)` its target.
- Installing a hook where one of that kind exists replaces it silently.
- In a remove hook, another entity you reach (a parent, a pair's target) may be the one being deleted. It then still passes `world:contains`, reads as empty (`get` nil) and loses anything written to it. Do not update a parent from a child's `OnRemove`: queue it or do it after the delete.
- `bulk_insert` runs hooks.

## Patterns

Clamp. Needs both hooks to cover every write; the nested `set` is not structural.

```luau
local world: jecs.World
local function capHealth(entity, id, value: number)
	if value and value > 100 then -- nil when the component was added with world:add
		world:set(entity, id, 100)
	end
end
jecs.meta(Health, jecs.OnAdd, capHealth :: any)
jecs.meta(Health, jecs.OnChange, capHealth :: any)
world = jecs.world()
```

`:: any` is needed under `--!strict`: the hook type is generic over every component.

Listeners then see the corrected value first and the original last: they must read `world:get`.

Release what the value owns. The hook closes over `world`, assigned after.

```luau
local world: jecs.World
jecs.meta(Model, jecs.OnRemove, function(entity)
	local model = world:get(entity, Model)
	if model then
		model:Destroy()
	end
end)
world = jecs.world()
```

If the component can be set again, track the current instance per entity and release the old one in `OnChange`.

More than one world (tests that build a fresh world each): a `jecs.meta` hook is shared by every world created afterwards, and the examples above reach only the one `world` variable. Install the hook per world instead, right after creating it and before the id is used there:

```luau
local function newWorld(): jecs.World
	local world = jecs.world(true)
	world:set(Model, jecs.OnRemove, function(entity)
		local model = world:get(entity, Model)
		if model then
			model:Destroy()
		end
	end)
	return world
end
```

## Mistakes

| Mistake | Result | Instead |
|---|---|---|
| `world:set(id, jecs.OnAdd, fn)` after the id is in use | Debug world raises. Normal world: applied unevenly: nothing fires for the id or for pairs already in use; for pairs to new targets `OnChange` and `OnRemove` fire but `OnAdd` never does; all of it is picked up once the id's archetypes are gone (targets deleted, or `world:cleanup()` with no holder left) | `jecs.meta` before the world, or `world:set` before first use |
| Raw hook on an id that has signal listeners | Debug world raises; otherwise silences them, or is ignored | `jecs.meta`, or another signal |
| Only `OnChange` installed | First `set` is missed | Both `OnAdd` and `OnChange` |
| Structural change in `OnRemove` | Undefined behaviour | Queue on `world.deferred` |
| A hook that raises | Operation aborts: value already stored, or entity left alive | Keep hooks trivial |
| `OnChange` as "value differs" | Fires on equal values; never for in-place table mutation | [change tracking](best-practices-change-tracking.md) |
| A `jecs.meta` hook closing over one `world`, with several worlds alive | Acts on the wrong world | Per-world hook (above) |
