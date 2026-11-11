# Component hooks

One callback per kind per id, installed by the id's owner, read once at the id's first use.

## When to use

- The component's own invariant: clamp or validate a value, release what the value owns.
- Not for gameplay logic (a system) or observers added later (a signal: [feature-signals](feature-signals.md)).

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
- A hook on a relation runs for its pairs; `id` is the pair id.
- `bulk_insert` runs hooks.

## Patterns

Clamp. Needs both hooks to cover every write; the nested `set` is not structural.

```luau
local world: jecs.World
local function capHealth(entity, id, value: number)
	if value > 100 then
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

## Mistakes

| Mistake | Result | Instead |
|---|---|---|
| `world:set(id, jecs.OnAdd, fn)` after the id is in use | Ignored (**fork** debug world raises) | `jecs.meta` before the world |
| Raw hook on an id that has signal listeners | Silences them, or is ignored | `jecs.meta`, or another signal |
| Only `OnChange` installed | First `set` is missed | Both `OnAdd` and `OnChange` |
| Structural change in `OnRemove` | Undefined behaviour | Queue on `world.deferred` (**fork**); upstream: do it after the operation |
| A hook that raises | Operation aborts: value already stored, or entity left alive | Keep hooks trivial |
| `OnChange` as "value differs" | Fires on equal values; never for in-place table mutation | [change tracking](best-practices-change-tracking.md) |
