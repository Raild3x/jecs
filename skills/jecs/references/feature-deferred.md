# Deferred changes

A queue of world changes applied later.

## When to use

A structural change wanted from inside a query loop, a hook or a listener. Queuing keeps the storage still while it is being walked, which is what makes the loop visit every entity exactly once.

Not needed for `set` of a component the entity already has: that is not structural and is safe in a loop. One exception: inside `OnRemove` while the entity is being deleted, a debug world raises on any write to that entity and the delete is abandoned.

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
- A change whose entity is dead at `apply` is skipped, including one a cascade just deleted. No `world:contains` check on the entity is needed.
- Only the entity is checked, not a pair's target. A queued `add` or `set` of `pair(R, target)` whose target dies before `apply` raises while the slot is free (the changes queued after it wait for the next `apply`) and links to the new occupant once the slot is reused. Queue the pair after anything that can delete its target, or apply before the delete.
- A change queued by a hook or listener during `apply` runs before the next queued change.
- An error reaches the caller; the failing change is dropped, the rest stay queued. A change can fail half done: a `set` on a tag raises after adding the tag.
- Runs through the world's methods: debug checks apply.
- Tables are captured by reference: a table mutated after queuing is stored as mutated.
- Cost: about 45 ns to queue a change; 1.0-1.6x a hand-written collect-then-apply.

## Patterns

Who calls `apply`:

| Code | Does | Because |
|---|---|---|
| A system that queues | Applies right after its own loop | The next system sees the result |
| A hook or listener that queues | Nothing: add one fixed `apply` after the last system | It cannot apply mid-operation |
| A module called by code it does not control | Uses its own `jecs.deferred(world)` | Applying the shared queue would run other code's changes at an unexpected time |

## Mistakes

| Mistake | Result | Instead |
|---|---|---|
| Queuing and never applying | Nothing happens | `apply` after the loop |
| Expecting other systems to see a queued delete | Invisible until applied | Marker tag: [best-practices-systems](best-practices-systems.md) |
| A listener queuing the change that triggers it | Stack overflow | Guard the listener |
| Queuing a pair, then deleting its target before `apply` | Raises, or links to the slot's next occupant | Apply first, or check `world:contains(target)` in the code that applies |
