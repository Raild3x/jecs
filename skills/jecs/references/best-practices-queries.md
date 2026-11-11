# Query design

Turn the question into constraints, then put each constraint where JECS can answer it.

## Decompose

"Which living enemies on the red team are near the player?"

| Constraint | Where |
|---|---|
| is an enemy | `:with(Enemy)` |
| living | `:without(Dead)` |
| red team | `:with(pair(Team, Red))` |
| position | term: `Position` |
| near the player | code in the loop (not expressible as a filter) |

```luau
local redEnemies = world:query(Position):with(Enemy, pair(Team, Red)):without(Dead):cached()
```

Filter in the query, not with an `if`. A filter rejects whole archetypes without touching their entities; an `if` visits every row first. At 1% matching the query is about 100x faster.

When the same `if` on a value shows up in a hot query, that value wants to be a tag or a pair ([best-practices-components](best-practices-components.md)).

## Forward and reverse

| Question | Answer |
|---|---|
| What does E point at? | `world:target(e, R)`, or `world:get(e, Link)` for an entity in a component |
| What points at T? | `world:query(pair(R, T))` |
| Does E relate to anything? | `world:has(e, pair(R, jecs.Wildcard))` |
| Everything related to T by any relation | `world:query(pair(jecs.Wildcard, T))` |

A reverse question is the sign that the link should be a pair. A link only ever read forward does not need one.

## Grouping

A pair partitions entities by target, so a query for one target reads only that group:

```luau
-- only the entities in the cells near the player, not the whole map
for _, cell in nearbyCells do
	for entity, position in world:query(Position):with(pair(InCell, cell)) do
	end
end
```

Use it when work is naturally done one group at a time (a cell, a squad, a team), groups are large, and entities change group rarely. Each inner query has a fixed cost, so against one pass over a component column the loop per target is 1.1x at 1,000 entities per group, 1.6x at 100 and 5-6x at 10. Moving to another group is a structural change, so a grid whose entities cross cells every frame costs more than it saves: keep a plain spatial table for those.

## Several entities in one question

A query matches one entity. For "units whose squad is retreating":

- Loop over the related side and query each group: `for squad in retreating do for unit in world:query(Unit):with(pair(InSquad, squad))`. Skips every unit of the other squads.
- Or run the query on one side and `world:get` / `world:has` on the related entity inside the loop. Simpler; fine when most rows pass.

No query traversal: walk `world:parent` / `world:children` by hand ([feature-pairs](feature-pairs.md)).

## Mistakes

| Mistake | Result | Instead |
|---|---|---|
| Broad query + `if` on a tag-like value | Visits everything | Tag or pair in the filter |
| Scanning all holders to find who points at T | Linear per lookup | Pair query |
| `world:target` per row to learn each entity's group | 6-15x a column read | Loop per target when groups are large, or keep the link in a component |
| The same query nested in itself | Outer loop ends early | Second query |
