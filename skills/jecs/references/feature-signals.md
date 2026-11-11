# Signals

Any number of listeners on an id, connected and disconnected at any time.

## When to use

| Use | For |
|---|---|
| Hook (`jecs.meta`) | The component's own invariant |
| Signal | Outside observers: debug, UI, change tracking, runtime toggles |
| System | Gameplay logic |

## API

```luau
local disconnect = world:added(Health, function(entity, id, value) end)
world:changed(Health, function(entity, id, value) end)
world:removed(Health, function(entity, id, deleted) end)
disconnect()
```

- Same arguments and timing as the matching hook: [feature-hooks](feature-hooks.md).
- Works on an id already in use. Runs after the hook.
- A signal on a relation runs for its pairs; `id` is the pair id.
- One listener makes `set` about 2x; three, 2.5x. The dispatcher stays installed after the last disconnect.

### Pair signals (fork)

```luau
local disconnect = world:added(pair(Follows, leader), function(entity, id) end)
```

- Runs for that pair only. Stops matching once the target is deleted, even after its slot is reused.
- `pair(R, jecs.Wildcard)` equals `R`. `pair(jecs.Wildcard, t)` raises. A dead relation or target raises while its slot is free; once reused, the listener binds to the new occupant.
- Registered on `R`: every event on `R` costs 12-20 ns per pair listener (an add is 4x with 100).
- Upstream: `added` never fires, and `changed`/`removed` only if the pair existed when connected. Listen to `R` and compare the id.

## Patterns

Many targets: one listener on the relation and a table.

```luau
local handlers: { [jecs.Id]: (jecs.Entity) -> () } = {}
world:added(Follows, function(entity, id)
	local handler = handlers[id]
	if handler then
		handler(entity)
	end
end)
```

## Mistakes

| Mistake | Result | Instead |
|---|---|---|
| Structural change in a `removed` listener | Undefined behaviour | Queue on `world.deferred` (**fork**) |
| A listener disconnecting itself during dispatch (upstream) | Another listener misses that event | Disconnect outside the callback |
| A listener that raises | Aborts the operation and the listeners after it | Keep listeners trivial |
| Calling `disconnect` twice | Raises "Listener not found" | Clear the variable |
| Trusting `value` when a hook corrects it | Last call carries the uncorrected value | `world:get` |
| A pair listener left after its target died (**fork**) | Dead weight on every event of `R` | Disconnect it |
