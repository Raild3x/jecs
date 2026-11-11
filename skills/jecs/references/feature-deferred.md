# Deferred changes

A queue of world changes applied later.

## When to use

A structural change wanted from inside a query loop, a hook or a listener. Queuing keeps the storage still while it is being walked, which is what makes the loop visit every entity exactly once.

Not needed for `set` of a component the entity already has: that is not structural and is safe in a loop. Two exceptions, both in remove callbacks: a debug world raises on any write to an entity from its own `OnRemove` while it is being deleted, and a write to an entity that is mid-delete (a parent, a pair's target) is thrown away.

## API

```luau
local hurt = world:query(Health):cached() -- module scope

local deferred = world.deferred        -- shared queue
for entity, health in hurt do
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
- A change whose entity is dead at `apply` is skipped, including one a cascade just deleted. No `world:contains` check on the entity is needed.
- A queued change on `pair(R, target)` is also skipped when the relation or the target died after it was queued, even if another entity has reused the slot. The queue records both entities when the change is queued. The `pair()` you pass must still be built from live handles.
- A change queued by a hook or listener during `apply`, on the queue being applied, runs before the next queued change. One queued on another queue waits for that queue's `apply`.
- A plain id that is itself an entity (a tag made with `world:entity()`) is not checked: if it is deleted before `apply`, a normal world adds the dead id and a debug world raises.
- An error reaches the caller; the failing change is dropped, the rest stay queued. A change can fail half done: a `set` on a tag raises after adding the tag.
- Runs through the world's methods: debug checks apply.
- Tables are captured by reference: a table mutated after queuing is stored as mutated.
- Cost: 100-125 ns to queue a change; about 1.7x a hand-written collect-then-apply ([performance](performance.md)).

## Patterns

Who calls `apply`:

| Code | Does | Because |
|---|---|---|
| A system that queues | Nothing when the frame's runner applies after every system; otherwise applies after its own loop, never inside it | The next system sees the result |
| A hook or listener that queues | Nothing: the frame's runner applies after every system ([best-practices-systems](best-practices-systems.md)) | It cannot apply mid-operation |
| A module called by code it does not control | Uses its own `jecs.deferred(world)` | Applying the shared queue would run other code's changes at an unexpected time |

## Mistakes

| Mistake | Result | Instead |
|---|---|---|
| Queuing and never applying | Nothing happens | `apply` after the loop |
| Expecting other systems to see a queued delete | Invisible until applied | Marker tag: [best-practices-systems](best-practices-systems.md) |
| A listener queuing the change that triggers it | Stack overflow | Guard the listener |
