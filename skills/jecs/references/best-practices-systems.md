# System design

A system is a function: one query, one job. JECS has no scheduler; the game calls systems in a fixed order. A phase is a naming convention.

Work done once, on demand, for an entity the caller already holds (`spawnNpc`, `equip`) is a plain function, not a system.

## Rules

| Rule | Because |
|---|---|
| Every query a system runs each frame is `:cached()`, created once at module scope, including the ones in code you are extending | An uncached query matches archetypes again on every call: no measurable cost with one archetype, 1.3x at 1,000, and 2.6-4x when few entities are spread over many. `:cached()` in the body is worse than either: it installs new observers on every call |
| Conditions go in the query (`:with`, `:without`), not an `if` | The query skips whole archetypes; the `if` visits every row |
| One job per system | It can be removed, reordered, profiled and tested alone |
| State another system must see lives in components or a singleton, not in a module variable | Any system can read the world; only one module can read its own locals |
| Write with `world:set` | Direct column writes skip hooks and signals |
| No yielding | Other code changes the world mid-loop. `task.spawn` slow work, mark the entity (`ComputingPath`) so it is not started twice, and feed the result back with a check that the entity is still alive |
| One function runs the frame and calls every system in a fixed order (below) | A reader placed before its writer acts on last frame's data |

## Structural changes

Never inside a loop over a query, `world:each` or `world:children`. Deleting the visited entity skips live entities when it is a pair target; adding to it can visit it twice. `set` of an existing component is safe.

Queue, then apply:

```luau
local doomed = world:query(Dead):cached()

local function despawnDead()
	local deferred = world.deferred
	for entity in doomed do
		deferred:delete(entity)
	end
	deferred:apply()
end
```

From a remove hook or listener, queue as well; the frame's runner applies it (below).

```luau
world:removed(Shield, function(entity, _, deleted)
	if not deleted then
		world.deferred:add(entity, Exposed)
	end
end)
```

## Frame order

JECS does not care what calls the frame (a `RunService` connection, a scheduler library's phases). The order is what matters:

| Step | What runs | Because |
|---|---|---|
| 1. Input | Player and AI input written into components | Everything after reads this frame's intent |
| 2. Simulate | Movement, combat, timers: they write values and emit events | Each reader comes after its writer |
| 3. Apply events | The consumers that drain the event arrays | Every hit of the frame lands before anything is judged dead |
| 4. Mark, then delete | Tag `Dead`; despawn | No system is left holding a handle that died earlier in its frame |
| 5. Present | Instances and UI, written only for entities that changed ([change tracking](best-practices-change-tracking.md)) | It sees the frame's final values, once |

The runner applies the shared queue after every system:

```luau
local systems = { readInput, move, applyDamage, markDead, despawnDead, present }

local function step(dt: number)
	for _, system in systems do
		system(dt)
		world.deferred:apply() -- about 15 ns when the queue is empty
	end
end
```

- What a hook or listener queued during one system is in the world before the next one runs. They cannot apply for themselves.
- No system has to remember to apply, and none applies while another loop is still running: an `apply` in the middle of a loop makes that loop visit entities twice.

A module with no frame of its own (it only installs hooks or listeners) still queues on `world.deferred`. It says in its header that the game's step applies the queue, and exports a `flush` that calls `apply` for tests and tools. Making the change directly in the remove callback is not a fallback: after `world:clear` the entity moves to the empty archetype and the change is lost, and during a delete a debug world raises.

## Marker tags

Use when another system runs between deciding an entity must go and deleting it: mark with `Dead`, others filter `:without(Dead)`. A queued delete is invisible until applied, so without the tag those systems still process the doomed entity. A system that decides and deletes at once needs none.

## Events

| Event | Model | Because |
|---|---|---|
| Handled this frame | Record in an array | No entity, no structural change; several per target are all kept |
| A fact, the same however often stated (`Dead`) | Tag on the target | Stating it twice changes nothing, and queries can select on it |
| Outlives the frame (a burn ticking 5 s) | Entity | It has its own changing state |

The consumer takes the array and puts a fresh one in its place before draining:

```luau
type Hit = { target: jecs.Entity, amount: number }
local hits: { Hit } = {}

local function dealDamage(target: jecs.Entity, amount: number)
	table.insert(hits, { target = target, amount = amount }) -- safe inside any loop
end

local function applyDamage()
	local batch = hits
	hits = {} -- hits emitted while draining land here: handled next frame
	for _, hit in batch do
		local health = world:get(hit.target, Health) -- nil if the target died
		if health then
			world:set(hit.target, Health, health - hit.amount)
		end
	end
end
```

Why swap instead of clearing at the end of the frame:

- A hit emitted during the drain (thorns, chain damage) is neither lost nor able to extend the loop forever.
- No separate "clear events" system has to be kept last in the order.

Several systems that read the same events: the first consumer swaps and stores the batch where the others read it (a module field or a singleton), and each reader runs after it.

## Mistakes

| Mistake | Result | Instead |
|---|---|---|
| Structural change in the loop | Skipped or repeated entities | Queue on `world.deferred` |
| `:cached()` inside the system | Two observers leaked per call | Module scope |
| "Pending" component for events | A second event in the frame overwrites the first | Array |
| An entity per event | 6-9x the direct change, and events emitted during the pass can be deleted unseen | Array |
| Draining with `while i <= #hits` | Events that emit events can loop without end in one frame | Swap, then drain the batch |
| Manual delete of a collected entity a cascade already removed | Debug world raises | `world.deferred`, or `world:contains` |
| Yielding mid-system | World changes under the loop | `task.spawn` + event |
