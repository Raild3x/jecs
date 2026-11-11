# Deferred changes (fork)

A queue of world changes applied later. Upstream has none: collect into a table, apply after the loop.

## When to use

A structural change wanted from inside a query loop, a hook or a listener.

## API

```luau
local deferred = world.deferred        -- shared queue
for entity, health in world:query(Health) do
	if health <= 0 then
		deferred:delete(entity)
	end
end
deferred:apply()

local mine = jecs.deferred(world)      -- separate queue
```

| Call | Queues |
|---|---|
| `deferred:add(e, id)` | `world:add` |
| `deferred:set(e, id, value)` | `world:set` |
| `deferred:remove(e, id)` | `world:remove` |
| `deferred:delete(e)` | `world:delete` |
| `deferred:apply()` | Runs the queue in order, empties it |

- Nothing is visible before `apply`.
- A change whose entity is dead at `apply` is skipped, including one a cascade just deleted.
- A change queued by a hook or listener during `apply` runs before the next queued change.
- An error reaches the caller; the failing change is dropped, the rest stay queued.
- Runs through the world's methods: debug checks apply.
- Tables are captured by reference.
- Cost: about 45 ns per queued change; 1.0-1.5x a hand-written collect-then-apply.

## Patterns

Who calls `apply`:

- Code that queues applies right after its own loop.
- Hook-queued changes ride the next `apply`: add one fixed `apply` after the last system.
- A module called by code it does not control uses its own `jecs.deferred(world)`.

## Mistakes

| Mistake | Result | Instead |
|---|---|---|
| Queuing and never applying | Nothing happens | `apply` after the loop |
| Expecting other systems to see a queued delete | Invisible until applied | Marker tag: [best-practices-systems](best-practices-systems.md) |
| A listener queuing the change that triggers it | Stack overflow | Guard the listener |
