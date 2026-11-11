# Signals

A signal is any number of listeners on an id, connected and disconnected at any time, including after the id is in use.

```luau
local disconnect = world:added(Health, function(entity, id, value) end)
world:changed(Health, function(entity, id, value) end)
world:removed(Health, function(entity, id, deleted) end)

disconnect() -- raises when called twice
```

Listeners receive the same arguments, at the same moments, as the matching hook: see the table in [feature-hooks.md](feature-hooks.md). A hook installed through `jecs.meta` and signals connected later all run.

## Hooks or signals

| Use | For |
|---|---|
| A hook, through `jecs.meta` | The component's own invariant, known when the component is defined. One per kind. |
| A signal | An outside observer: debugging, UI, change tracking, anything switched on and off at runtime. |
| A system | Gameplay logic. |

## Rules

- **A remove listener only reads and releases**, like a remove hook. Queue structural changes on `world.deferred` (**fork**).
- **Keep listeners too simple to raise.** A listener that raises aborts the operation half way and stops the listeners after it.
- **Each listener costs every `set`.** One listener makes `set` about twice as dear, three make it 2.5 times. Once a signal has been used on an id, a dispatcher stays installed there.

## A signal on one pair (fork)

```luau
local disconnect = world:added(pair(Follows, leader), function(entity, id) end)
```

- `world:added`, `world:changed` and `world:removed` accept `pair(R, target)` and then run for that pair only.
- The listener stops matching once `target` is deleted, even after another entity reuses its slot. It still runs for the removal that deleting `target` causes.
- `pair(R, jecs.Wildcard)` is the same as listening to `R`. `pair(jecs.Wildcard, target)` raises, as does a pair whose relation or target is dead.
- **Disconnect it when its target dies, and keep them to a handful per relation.** It is registered on `R`, so every event on `R` runs every pair listener's filter: 12 to 20 ns each, which makes an add four times as dear with 100 of them.
- **For many targets connect one listener to `R` and look the pair id up in a table.**

On upstream a listener given a pair id never runs for `added`: listen to the relation and compare the id.
