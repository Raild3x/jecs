# Queries

```luau
-- module scope: runs every frame, so cached once
local movers = world:query(Position, Velocity):without(Frozen):cached()

local function move(dt: number)
	for entity, position, velocity in movers do
		world:set(entity, Position, position + velocity * dt) -- already has Position: not structural
	end
end

-- one-off: built and iterated in place
for entity, health in world:query(Health):with(Burning, Poisoned) do
end
```

| Call | Does |
|---|---|
| `world:query(a, b, ...)` | Entities that have every term. The loop yields the entity, then one value per term. A tag term yields nil. |
| `:with(x, y)` | Also require these ids, without yielding their values. |
| `:without(x, y)` | Exclude entities that have any of these ids. |
| `:cached()` | A reusable query that tracks new archetypes. Apply `:with` and `:without` first: a cached query has neither. |
| `query:has(e)` | Whether the entity currently matches. Works on cached and uncached queries. |
| `query:archetypes()` | The matching archetypes, including empty ones. Each has `entities` and `columns_map[id]`. |
| `cached:fini()` | Removes the cached query's two observers. Call it for a cached query that is no longer needed. |
| `world:each(id)` | Iterator over entities that have one id. |
| `world:children(parent)` | Iterator over entities with `pair(jecs.ChildOf, parent)`. |

## Rules

- **Give every filter id in one call**, `:with(A, B)`, `:without(C, D)`. On upstream a second `:with` or `:without` replaces the first.
- **Call `:cached()` once, at module scope**, for a query that runs every frame, after `:with` and `:without`. Each call registers two observers that stay until `:fini()`.
- **Iterate an uncached query where it is built.** Stored in a variable it yields nothing the second time.
- **Give a nested loop its own query.** Iterating a query inside its own loop ends the outer loop early.
- **Make structural changes after the loop**, for queries, `world:each` and `world:children` alike. See [best-practices-systems.md](best-practices-systems.md).
- **Sort or key the results yourself when order matters.** Iteration order follows archetype layout and differs between runs.

## Pair terms

- `world:query(pair(R, target))` finds the entities with that pair, and yields its value when the pair holds one.
- `world:query(pair(R, jecs.Wildcard))` finds entities with any pair of `R`: one row per entity, however many targets it has.
- `world:query(pair(jecs.Wildcard, T))` finds entities with any pair that targets `T`.

## Counting

To count the entities a query matches without visiting them, sum `#archetype.entities` over a cached query's archetypes:

```luau
local withPoison = world:query(Poison):cached()

local function countPoisoned(): number
	local total = 0
	for _, archetype in withPoison:archetypes() do
		total += #archetype.entities
	end
	return total
end
```

## Direct column access

`query:archetypes()` gives each matching archetype's `entities` array and `columns_map[id]` column, indexed by the same row. Writing a column directly skips hooks and signals, so keep it for a measured hot loop over a component nothing observes, and skip archetypes whose `entities` is empty.
