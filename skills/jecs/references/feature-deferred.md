# Deferred changes (fork)

A queue of world changes that are held back until `apply`. It is how a query loop, a hook or a listener makes a structural change safely. On `ukendio/jecs` it does not exist: collect entities into a table inside the loop and change them after it.

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

| Call | Does |
|---|---|
| `deferred:add(e, id)` | Queues `world:add`. |
| `deferred:set(e, id, value)` | Queues `world:set`. |
| `deferred:remove(e, id)` | Queues `world:remove`. |
| `deferred:delete(e)` | Queues `world:delete`. |
| `deferred:apply()` | Makes the queued changes and empties the queue. |

## Behaviour

- Nothing queued is visible until `apply`.
- `apply` makes the changes in the order queued, through the world's own methods, so a debug world's checks still run.
- A change whose entity is no longer alive is skipped. This covers an entity that a cascade earlier in the same `apply` deleted, and it never reaches a new entity in the reused slot.
- A change that a hook or listener queues during `apply` runs before the next queued change.
- An error during `apply` reaches the caller. The change that raised is dropped and the ones that have not run stay queued for the next `apply`.
- A listener that queues the very change that invokes it raises a stack overflow instead of hanging.
- A value is captured when queued. A table is captured by reference, so later mutations show through.

## Who calls apply

- Code that queues on the shared queue calls `apply` right after its own loop.
- A change queued by a hook or listener is made by whichever `apply` comes next. Give the frame one fixed `apply`, after the last system, to catch those.
- A module whose functions are called by code it does not control uses its own `jecs.deferred(world)`, so it neither applies changes others queued on the shared queue nor has its own applied early.

## Cost

Queuing a change costs about 45 ns, and a queued batch runs 1.0 to 1.5 times as long as a hand-written collect-then-apply loop (measured in lune).

A queued delete is invisible to other systems until it is applied. When they must skip a doomed entity sooner, mark it with a tag: see [best-practices-systems.md](best-practices-systems.md).
