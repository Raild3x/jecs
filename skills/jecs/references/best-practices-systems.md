# System design

A system is a function: one query, one job. JECS has no scheduler; the game calls systems in a fixed order. A phase is a naming convention.

## System or plain function

| Make it a system when | Make it a plain function when |
|---|---|
| It processes every entity matching a query | It acts on one entity the caller already holds |
| It runs every frame or on a fixed step | It runs once, on demand (`spawnNpc`, `equip`) |
| Its place in the frame order matters | Order does not matter |

A "spawn system" that polls for something to spawn is a function call with a frame of delay. Keep spawning, setup and one-off commands as functions.

## Rules

| Rule | Because |
|---|---|
| Cached query per system, created once at module scope | `:cached()` in the body installs new observers on every call |
| Conditions go in the query (`:with`, `:without`), not an `if` | The query skips whole archetypes; the `if` visits every row |
| One job per system | It can be removed, reordered, profiled and tested alone |
| State lives in components or a singleton, not in module variables | Other systems can read it, and a fresh world starts clean in tests |
| Write with `world:set` | Direct column writes skip hooks and signals |
| No yielding | Other code changes the world mid-loop. `task.spawn` slow work, mark the entity (`ComputingPath`) so it is not started twice, and feed the result back with a check that the entity is still alive |
| Order by data flow: input, emit events, apply events, mark, delete | A reader placed before its writer acts on last frame's data |

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

From a remove hook or listener, queue as well; one fixed `apply` after the last system picks it up.

```luau
world:removed(Shield, function(entity, _, deleted)
	if not deleted then
		world.deferred:add(entity, Exposed)
	end
end)
```

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
| A system for one-off work | A frame of delay and a query for one entity | Plain function |
