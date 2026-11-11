# Queries

## When to use

- Per-frame work over many entities: a cached query at module scope.
- A one-off lookup: an uncached query, iterated where it is built.
- One entity you already hold: `world:get` / `world:has`, no query.

## API

```luau
local movers = world:query(Position, Velocity):without(Frozen):cached() -- module scope

local function move(dt: number)
	for entity, position, velocity in movers do
		world:set(entity, Position, position + velocity * dt) -- has Position: not structural
	end
end

for entity, health in world:query(Health):with(Burning, Poisoned) do -- one-off
end
```

| Call | Does |
|---|---|
| `world:query(a, b, ...)` | Entities with every term. Yields entity, then a value per term (nil for a tag) |
| `:with(x, y)` | Require, without yielding values |
| `:without(x, y)` | Exclude |
| `:cached()` | Reusable; tracks new archetypes. Call after `:with` / `:without` |
| `query:has(e)` | Does `e` match now |
| `query:archetypes()` | Matching archetypes, empty ones included. Each has `entities`, `columns_map[id]` |
| `cached:fini()` | Releases a cached query |
| `world:each(id)` | Entities with one id |
| `world:children(parent)` | Entities with `pair(jecs.ChildOf, parent)` |

Pair terms: `pair(R, t)` (yields the pair's value if it has one), `pair(R, jecs.Wildcard)` (any target; one row per entity), `pair(jecs.Wildcard, t)` (any relation to `t`).

## Patterns

Count without visiting entities:

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

Direct column writes via `columns_map[id][row]` skip hooks and signals. Only for a measured hot loop on an unobserved component.

## Mistakes

| Mistake | Result | Instead |
|---|---|---|
| `:with(A):with(B)`, `:without(A):without(B)` | Upstream keeps only the last call | `:with(A, B)` |
| `:cached()` inside a function that runs repeatedly | Two observers per call, kept until `:fini()` | Once, at module scope |
| Uncached query stored in a variable | Yields nothing the second time | Iterate in place, or cache |
| A query iterated inside its own loop | Outer loop ends early | Separate query |
| Structural change inside the loop | Skips or repeats entities | After the loop: [best-practices-systems](best-practices-systems.md) |
| Relying on order | Follows archetype layout and history; not a contract | Sort |
