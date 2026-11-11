# Change tracking

## What JECS reports

- `OnChange` / `world:changed` = "set was called": fires on an equal value, never for in-place table mutation.
- The first `set` is an add: `OnAdd` / `world:added` only.
- Callbacks get the new value; the old one is gone.

## Choosing

| Situation | Use |
|---|---|
| Few entities change per frame | Recording listener |
| Most change every frame, or the component is written in a hot loop | Comparison |
| Must act immediately | The code making the change, or a hook |

## Patterns

Recording listener: several sets leave one entry. Costs about 2x on every `set` of that component.

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

Comparison: no cost on `set`, one read per entity per frame. Catches changes that fired no callback (store a copy for table values).

```luau
for entity, health, shown in world:query(Health, Shown) do
	if health ~= shown then
		-- update dependants
		world:set(entity, Shown, health) -- has Shown: not structural
	end
end
```

## Mistakes

| Mistake | Result | Instead |
|---|---|---|
| "Dirty" tag added and removed per change | Two structural changes per change | Recording table |
| Mutating a table value and expecting `changed` | Nothing fires | `world:set` again, or comparison |
| Only `changed` connected | First value missed | Also `added` |
