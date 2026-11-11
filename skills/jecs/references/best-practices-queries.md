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

Filter in the query, not with an `if`: at 1% matching the query is about 100x faster.

## Forward and reverse

| Question | Answer |
|---|---|
| What does E point at? | `world:target(e, R)` |
| What points at T? | `world:query(pair(R, T))` |
| Does E relate to anything? | `world:has(e, pair(R, jecs.Wildcard))` |
| Everything related to T by any relation | `world:query(pair(jecs.Wildcard, T))` |

A reverse question is the sign that the link should be a pair.

## Several entities in one question

A query matches one entity. For "units whose squad is retreating":

- Run the query on one side, `world:get` / `world:has` on the related entity inside the loop.
- Or query the pair directly when the other side is known: `world:query(Unit):with(pair(InSquad, squad))`.

No query traversal: walk `world:parent` / `world:children` by hand ([feature-pairs](feature-pairs.md)).

## Mistakes

| Mistake | Result | Instead |
|---|---|---|
| Broad query + `if` on a tag-like value | Visits everything | Tag or pair in the filter |
| Scanning all holders to find who points at T | Linear per lookup | Pair query |
| The same query nested in itself | Outer loop ends early | Second query |
