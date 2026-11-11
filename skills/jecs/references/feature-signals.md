# Signals

Any number of listeners on an id, connected and disconnected at any time.

## When to use

| Use | For | Because |
|---|---|---|
| Hook (`jecs.meta`) | The component's own invariant | One fixed slot, cheapest (1.3-1.9x a plain `set`) |
| Signal | Outside observers: debug, UI, change tracking, runtime toggles | Works on an id already in use; can be disconnected. One listener makes `set` about 2x, three 2.5x |
| System | Gameplay logic | Runs at a known point in the frame, free to change structure |

A listener runs inside the write that triggered it. Keep it to recording what happened; let a system act on the record.

## API

```luau
local disconnect = world:added(Health, function(entity, id, value) end)
world:changed(Health, function(entity, id, value) end)
world:removed(Health, function(entity, id, deleted) end)
disconnect()
```

- Same arguments and timing as the matching hook: [feature-hooks](feature-hooks.md).
- Works on an id already in use. Runs after the hook.
- A signal on a relation runs for its pairs; `id` is the pair id, `jecs.pair_second(world, id)` its target. In a `removed` listener that target may be mid-delete: it passes `world:contains`, reads as empty and loses writes ([feature-hooks](feature-hooks.md)).
- A listener may disconnect itself during dispatch; the others still run.
- The dispatcher stays installed after the last disconnect, so the `set` cost does not return to baseline.

### Pair signals

```luau
local disconnect = world:added(pair(Follows, leader), function(entity, id) end)
```

- Runs for that pair only. Stops matching once the target is deleted, even after its slot is reused.
- `pair(R, jecs.Wildcard)` equals `R`. `pair(jecs.Wildcard, t)` raises. A dead relation or target raises while its slot is free; once reused, the listener binds to the new occupant.
- Registered on `R`: every event on `R` costs 12-20 ns per pair listener, so 100 listeners add about 1.4 microseconds to each add on the relation.

## Patterns

Many targets: one listener on the relation and a table. A pair listener per target would be checked on every event of the relation.

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
| Structural change in a `removed` listener | Undefined behaviour | Queue on `world.deferred` |
| A listener that raises | Aborts the operation and the listeners after it | Keep listeners trivial |
| Calling `disconnect` twice | Raises "Listener not found" | Clear the variable |
| Trusting `value` when a hook corrects it | Last call carries the uncorrected value | `world:get` |
| A pair listener left after its target died | Dead weight on every event of `R` | Disconnect it |
