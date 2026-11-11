# System design

A system is a function: one query, one job. JECS has no scheduler; the game calls systems in a fixed order. A phase is a naming convention.

- Cached query per system, created once at module scope.
- Conditions go in the query (`:with`, `:without`), not an `if`.
- State lives in components, so a system can be removed, reordered, tested alone.
- Write with `world:set`. Direct column writes skip hooks and signals.
- No yielding: other code would change the world mid-loop. `task.spawn` slow work and feed the result back as an event.
- Order by data flow: emit events, read events, mark, delete, clear events.

## Structural changes

Never inside a loop over a query, `world:each` or `world:children`. Deleting the visited entity skips live entities when it is a pair target; adding to it can visit it twice. `set` of an existing component is safe.

Fork: queue, then apply.

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

Both libraries: collect, then apply.

```luau
local living = world:query(Health):without(Dead):cached()

local function markDead()
	local dying: { jecs.Entity } = {}
	for entity, health in living do
		if health <= 0 then
			table.insert(dying, entity)
		end
	end
	for _, entity in dying do
		world:add(entity, Dead) -- for deletes: check world:contains first
	end
end
```

From a remove hook or listener: queue it (**fork**).

```luau
world:removed(Shield, function(entity, _, deleted)
	if not deleted then
		world.deferred:add(entity, Exposed)
	end
end)
```

## Marker tags

Use when another system runs between deciding an entity must go and deleting it: mark with `Dead`, others filter `:without(Dead)`. A queued delete is invisible until applied. A system that decides and deletes at once needs none.

## Events

| Event | Model |
|---|---|
| Handled this frame | Record in an array |
| A fact, the same however often stated (`Dead`) | Tag on the target |
| Outlives the frame (a burn ticking 5 s) | Entity |

```luau
type Hit = { target: jecs.Entity, amount: number }
local hits: { Hit } = {}

local function dealDamage(target: jecs.Entity, amount: number)
	table.insert(hits, { target = target, amount = amount })
end

local function applyDamage()
	for _, hit in hits do
		local health = world:get(hit.target, Health)
		if health then
			world:set(hit.target, Health, health - hit.amount)
		end
	end
end

local function clearEvents()
	table.clear(hits) -- last system of the frame
end
```

## Mistakes

| Mistake | Result | Instead |
|---|---|---|
| Structural change in the loop | Skipped or repeated entities | Queue or collect |
| `:cached()` inside the system | Two observers leaked per call | Module scope |
| "Pending" component for events | A second event in the frame overwrites the first | Array |
| Manual delete of a collected entity a cascade already removed | Debug world raises (**fork**) | `world:contains`, or `world.deferred` (**fork**) |
| Yielding mid-system | World changes under the loop | `task.spawn` + event |
