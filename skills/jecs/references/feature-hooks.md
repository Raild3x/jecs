# Component hooks

A hook is the one callback of each kind that an id's owner installs. It is read once, when the id is first used.

```luau
local Health = jecs.component<<number>>()

jecs.meta(Health, jecs.OnAdd, function(entity, id, value) end)
jecs.meta(Health, jecs.OnChange, function(entity, id, value) end)
jecs.meta(Health, jecs.OnRemove, function(entity, id, deleted) end)

local world = jecs.world()
```

**Install hooks only through `jecs.meta`, before the world exists.** `world:set(id, jecs.OnAdd, fn)` at runtime is ignored once the id is in use, and when the id already has signal listeners it either silences them or is ignored itself (**fork:** a debug world raises in both cases). For a callback that is connected later or can be disconnected, use a signal: [feature-signals.md](feature-signals.md).

## When each runs

| Hook | Runs | Arguments |
|---|---|---|
| `OnAdd` | when the id is added | the value given to `set`, nil for `add` |
| `OnChange` | on every later `set` | the new value |
| `OnRemove` | before the id leaves the entity | `deleted`: true when the whole entity is being deleted, cascades included; nil for `remove` and `clear` |

- The first `set` runs only `OnAdd`. `world:add` of an id the entity already has runs nothing. **To see every write, install both `OnAdd` and `OnChange`.**
- The value is stored before `OnAdd` and `OnChange` run. A hook installed through `jecs.meta` runs before the signal listeners.
- `OnChange` means "set was called": it runs when the new value equals the old one, and never when a table value is mutated in place.
- `OnChange` runs after the new value is stored, so the value it replaced is gone. To release a replaced value, such as a Roblox instance, keep your own table from entity to the current value.
- Inside `OnRemove`, `world:get(entity, id)` still returns the value.
- A hook on a relation runs for its pairs, and `id` is then the full pair id.
- `jecs.bulk_insert` runs hooks too.

## Rules

- **A remove hook only reads and releases.** A structural change inside it is undefined behaviour. Queue it on `world.deferred` (**fork**): [feature-deferred.md](feature-deferred.md).
- **Keep every hook too simple to raise.** A hook that raises aborts the operation where it stands: after a `set` the value is already stored, and a `delete` leaves the entity alive.
- **Gameplay logic goes in systems.** A hook is for an invariant of the component itself, such as releasing what the value owns.

## A hook that corrects its value

A hook may call `world:set` on its own component to clamp or validate what was written. The component is already on the entity, so this is not structural:

```luau
local world: jecs.World
local function capHealth(entity, id, value: number)
	if value > 100 then
		world:set(entity, id, 100)
	end
end
jecs.meta(Health, jecs.OnAdd, capHealth)    -- the first set
jecs.meta(Health, jecs.OnChange, capHealth) -- every later set

world = jecs.world()
```

The correction runs the callbacks again, inside the first call. A `world:changed` listener is therefore called with the corrected value first and the original value last, while the stored value is the corrected one. **A listener on a component whose hook corrects it reads `world:get`, not its value argument.**

## A hook that needs the world

A hook is installed before the world exists, so it closes over a variable that is assigned afterwards:

```luau
local world: jecs.World
jecs.meta(Model, jecs.OnRemove, function(entity, id)
	local model = world:get(entity, id)
	if model then
		model:Destroy()
	end
end)

world = jecs.world()
```
