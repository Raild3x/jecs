# Change tracking

How a system finds out which entities changed since it last looked.

## What JECS reports

- `OnChange` and `world:changed` mean "set was called". They run when the new value equals the old one, and never when a table value is mutated in place.
- The first `set` of a component is an add: it runs `OnAdd` and `world:added` only.
- A change callback receives the new value. The old one is already gone.

## A listener that records, a system that drains

Connect a listener that only notes the entity, and let a system process the set once a frame:

```luau
local changedHealth: { [jecs.Entity]: true } = {}
world:changed(Health, function(entity)
	changedHealth[entity] = true
end)

local function showHealth()
	for entity in changedHealth do
		if world:contains(entity) then
			-- update what depends on Health
		end
	end
	table.clear(changedHealth)
end
```

Several sets in one frame leave one entry. Connect `world:added` as well when the first value matters, and `world:removed` to record entities that lost the component. The listener makes every `set` of that component about twice as dear.

## Comparing against the value last handled

Keep a second component holding the value the system last acted on, and compare in the loop:

```luau
for entity, health, shown in world:query(Health, Shown) do
	if health ~= shown then
		-- update what depends on Health
		world:set(entity, Shown, health) -- already has Shown: not structural
	end
end
```

This costs a read per entity per frame and nothing on `set`. It also catches a change that fired no callback, as long as the value is compared by content: for a table value, store a copy.

## Choosing

| Situation | Use |
|---|---|
| Few entities change per frame, many exist | The recording listener |
| Most entities change every frame, or the component is written in a hot loop | The comparison |
| A change must be acted on immediately | Neither: do it in the code that makes the change, or in a hook |

A "dirty" tag added on change and removed after handling is a structural change twice per change: prefer the recording table.
