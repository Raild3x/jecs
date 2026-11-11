# Change tracking

## What JECS reports

- `OnChange` / `world:changed` = "set was called": fires on an equal value, never for in-place table mutation.
- The first `set` is an add: `OnAdd` / `world:added` only.
- Callbacks get the new value; the old one is gone.

## Choosing

| Situation | Use | Because |
|---|---|---|
| Few entities change per frame | Recording listener | Work is proportional to the changes, not the entity count |
| Most change every frame, or the component is written in a hot loop | Comparison | A listener would make every `set` about 2x; the comparison costs one read per entity |
| The old value is needed, or changes arrive without `set` (table mutation, column writes) | Comparison | It keeps the previous value and sees every difference |
| Must act immediately | The code making the change. A hook only when the reaction is the component's own invariant | A listener or hook runs mid-write, where structural changes are unsafe and other entities may be mid-delete |

## Patterns

Recording listener: several sets leave one entry.

```luau
local changedHealth: { [jecs.Entity]: true } = {}
world:changed(Health, function(entity)
	changedHealth[entity] = true
end)
-- also world:added for first values, world:removed for losses

local function showHealth()
	for entity in changedHealth do
		if world:contains(entity) then
			-- update dependants
		end
	end
	table.clear(changedHealth)
end
```

The listener only records; the system acts later, when the world is not mid-write.

Comparison: keep the last value handled in a pair, so no extra component is declared per tracked component. Store a copy for table values.

```luau
local Previous = jecs.tag() -- before jecs.world()

local tracked = world:query(Health, pair(Previous, Health)):cached()
local untracked = world:query(Health):without(pair(Previous, Health)):cached()

local function showHealth()
	for entity, health, shown in tracked do
		if health ~= shown then
			-- update dependants; `shown` is the old value
			world:set(entity, pair(Previous, Health), health) -- already present: not structural
		end
	end
	local deferred = world.deferred
	for entity, health in untracked do -- newly added
		deferred:set(entity, pair(Previous, Health), health)
	end
	deferred:apply()
end
```

Removal shows up as `world:query(pair(Previous, Health)):without(Health)`.

## Mistakes

| Mistake | Result | Instead |
|---|---|---|
| "Dirty" tag added and removed per change | Two structural changes per change | Recording table |
| Mutating a table value and expecting `changed` | Nothing fires | `world:set` again, or comparison |
| Only `changed` connected | First value missed | Also `added` |
| Acting inside the listener | Runs mid-write, once per `set` even when several happen in a frame | Record, act in a system |
