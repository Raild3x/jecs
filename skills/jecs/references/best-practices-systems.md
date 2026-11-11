# System design

A system is a function that runs one query and does one job. JECS has no scheduler: the game calls its systems in a fixed order each frame, and a phase is only a naming convention for a group of them.

- **Create each per-frame query once, at module scope, with `:cached()`.**
- **Put the condition in the query** with `:with` and `:without` where a tag exists for it, so the loop only visits what it will act on.
- **Write values with `world:set`.** Writing a column directly skips hooks and signals: keep it for a measured hot loop over a component nothing observes.
- **Keep state in components**, so a system can be removed, reordered or tested alone.
- **Do not yield inside a system.** A yield lets other code change the world in the middle of a loop. Start slow work with `task.spawn` and feed its result back in as an event.
- **Order by data flow:** systems that emit events, then systems that read them, then systems that mark, then the system that deletes, then the one that clears events.

## Changing structure from a loop

**Make structural changes after the loop, never inside it.** Deleting only the entity being visited skipped live entities in about 30% of randomised trials when that entity was a pair target, and adding to the visited entity can visit it twice. `world:set` of a component the entity already has is not structural and is fine inside the loop.

Collect, then apply. This works on both libraries:

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
		world:add(entity, Dead)
	end
end
```

On the fork, queue on `world.deferred` inside the loop and apply after it:

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

When collecting deletes by hand, check `world:contains` before each one: a cascade may already have deleted it, and a debug world raises on deleting a dead entity. `apply` does that check itself.

## Marker tags

`Dead` above is a marker tag. Between `markDead` and `despawnDead` the entity is still alive, and every query written `:without(Dead)` already skips it. A queued delete alone would be invisible to those systems.

Use a marker when another system runs between deciding an entity must go and deleting it. A system that decides and deletes in one go needs none.

## Structural changes from hooks and listeners

A remove hook or listener that wants a structural change queues it, and the change is made by the next `apply`:

```luau
world:removed(Shield, function(entity, _, deleted)
	if not deleted then
		world.deferred:add(entity, Exposed)
	end
end)
```

## Events

An event is a record in a plain array. Emitters call a helper, readers loop over the array, and one system clears it at the end of the frame:

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
			world:set(hit.target, Health, health - hit.amount) -- already has Health: not structural
		end
	end
end

local function clearEvents()
	table.clear(hits)
end

local function frame()
	applyDamage()
	markDead()
	dropDeadTargets()
	despawnDead()
	clearEvents()
end
```

Two hits on one target in one frame both land, because each is its own record. A "pending damage" component would keep only the last.

| The event | Model |
|---|---|
| Happens, is handled this frame, is gone | A record in an array |
| A fact that is the same however often it is stated (`Dead`) | A tag on the target |
| Something that outlives the frame (a burn that ticks for five seconds) | An entity |
