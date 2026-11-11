# Performance: measured costs

What each modelling choice costs, with the setup it was measured in. The other reference files quote single figures from here; this file has the conditions.

## When speed matters

Thousands of entities, touched every frame, in code that shows up in the profiler. For a few hundred entities, or work done a few times a second, every option below is fast enough: choose for clarity and safety (pairs with cleanup traits, tags, filters) and measure before trading them away.

Scale, in lune: a `world:set` of an existing component takes about 40 ns, so 10,000 of them cost 0.4 ms of a 16.7 ms frame. A 4x choice on that loop costs 1.2 ms more; a 100x choice does not fit in the frame.

## How to read the figures

- A ratio compares two ways of doing the same work: 3x means three times the time of the cheaper way named in the row.
- Two figures joined by a dash are the lune and the Roblox Studio (JECS native) results, or the range over repeated runs. A row marked (lune) was not measured in Studio.
- Unless a row says otherwise: 10,000 entities, a normal (non-debug) world, each entity holding one or two other components.
- Treat every figure as an order of magnitude. A second machine put about half the rows inside these ranges and the rest within 2x. Profile the real game before optimising.

## Writes and observers

| Choice | Setup | Cost |
|---|---|---|
| Debug world, vs a normal world (lune) | `set` of an existing component | about 3.7x (40 ns to 140 ns) |
| | `set` of a pair's value | about 9x (58 ns to 510 ns) |
| | add then remove a tag | 1.6x (400 ns to 625 ns) |
| A hook on the component, vs none | `set` with an `OnChange` hook that does nothing | 1.3-1.9x |
| Signal listeners, vs none | `set` with 1 listener | 1.8-2.1x |
| | `set` with 3 listeners | 2.5-2.6x |
| | after every listener disconnected | about 1.7x: the dispatcher stays installed |
| Pair signal listeners on a relation (lune) | 100 listeners, each on a different `pair(R, target)`; cost falls on every add to `R` | 12-20 ns per listener per event: an add goes from 100 ns to 1,200 ns |
| `world.deferred`, vs collecting into a table and applying by hand (lune) | add then remove a tag on 10,000 entities | about 1.7x; 100-125 ns per queued change |
| `world.deferred:set`, vs a direct `set` of an existing component (lune) | 10,000 sets | 3.5x. The direct `set` is safe in a loop, so do not queue it |
| An empty `world.deferred:apply()` (lune) | called after every system | about 15 ns |
| Ids added one at a time, vs one `bulk_insert` (lune) | 5,000 entities with 2 components and 3 of 12 tags | 300 archetypes against 220: one extra for each partial combination |
| `bulk_insert`, vs one `set` per component (lune) | spawning a new entity with 3 / 6 / 12 components | 1.5x slower / equal / 1.3-1.6x faster |

## State

| Choice | Setup | Cost |
|---|---|---|
| Switching an exclusive pair, vs `set` of a value component | entity with 2 other components | 4-5x |
| | 10 other components | 7-13x |
| | 30 other components | 22-38x |
| Remove one tag and add another, vs `set` of a value | 2 / 10 / 30 other components | 8-10x / 14-22x / 41-50x |
| Value component and an `if`, vs a tag or pair in the query filter | 25% of 10,000 entities match | 4x |
| | 1% match | about 100x |

The switch is a structural change: every column of the entity is moved, so the cost grows with the component count. The filter wins by never visiting non-matching archetypes, so its gain grows as fewer entities match.

## Queries

| Choice | Setup | Cost |
|---|---|---|
| Uncached query, vs cached, each iterated once per call (lune) | 10,000 entities in 1 archetype | 1.0x |
| | 10,000 entities in 1,000 archetypes | 1.3x |
| | 100 entities in 100 archetypes | 2.6x |
| | 10 entities among 1,000 archetypes | 4x |
| A term in `world:query(...)`, vs the same id in `:with(...)` (lune) | tag or data component | 1.0-1.2x: choose by what the loop reads |
| Broad query over fragmented storage, vs the same entities in one archetype (lune) | 10,000 entities in 100 archetypes | 1.0x |
| | in 1,000 archetypes | 1.2-1.5x |
| | in 10,000 archetypes, one entity each | 2.4x cached, 3.6x uncached |
| Cached query with emptied archetypes still in it (lune) | 1,000 empty archetypes | 1.1-1.2x until `world:cleanup()` |
| Respawning after a `world:cleanup()`, vs with the archetypes kept (lune) | 200 entities in 200 shapes, every wave | 3.9x: each archetype is rebuilt |

`:cached()` called inside a system is not in this table because it is not a speed choice: it installs two observers per call that stay until `:fini()`, so memory and every later archetype change get dearer each frame.

## Links: pair or entity in a component

10,000 holders, each linked to one of N targets.

| Operation | Setup | Pair, against an entity in a component |
|---|---|---|
| Build the links | 10 targets | equal |
| | 1,000 targets | 3x |
| | 10,000 targets (one per holder) | 10-24x |
| Read one holder's target | `world:target` vs `world:get` | 2-5x |
| Read the target on every row of a loop | wildcard query + `world:target`, vs a component column | 7-15x (lune), 6-10x (Studio) |
| Same work done as one query per target (lune) | 1,000 holders per target | 1.1x |
| | 100 holders per target | 1.4-1.6x |
| | 10 holders per target | 5-6x |
| Retarget, to a target this entity shape has held before | 2 other components / 10 | 4-5x / 7-11x a `set`, at any target count |
| Retarget, first move of a shape to a target (lune) | a first pass over 10,000 targets | 14-35x; a single first move 40-240x |
| Reverse lookup: who points at X | pair query, vs scanning every holder; 10 targets | pair 9x faster |
| | 1,000 targets | pair 200-300x faster |
| Delete every target | 10 to 1,000 targets | 2-3x dearer |
| | 10,000 targets | 15-30x dearer again |

Reading the rows together: a pair pays for itself when something asks the reverse question or works one target's group at a time, and loses when the link is only read forward, row by row, across many targets.

Which side holds the pair (lune), 100 owners with 30 items each, against an array of items in a component on the owner:

| Model | Archetypes | Build cost |
|---|---|---|
| Pair on each item pointing at its owner | about 110 | 3x |
| Pairs on the owner pointing at each item | about 3,000 | 90-180x |

## Events and despawning

| Choice | Setup | Cost |
|---|---|---|
| Events through an array, vs applying the change directly | 10,000 events per frame | 1.3x (lune) |
| Events as a "pending" component on the target | same | 4.4-6x |
| An entity per event | same | 6.4-12x |
| Marker tag then a cleanup query, vs collect-then-delete | despawning 10,000 entities | 1.2-2x |
| `world.deferred:delete`, vs collect-then-delete (lune) | same | 1.3x |
| Deleting inside the loop | same | no faster, and it skips entities when the deleted one is a pair target |
| A `Dirty` tag added from a listener and removed after, vs a recording listener (lune) | 1,000 or 10,000 of 10,000 entities change | 3.3x, and a cached loop visits the moved entities twice |

## Re-measuring

`lune run bench_ops.luau` and `lune run bench_links.luau` in `test/skill/verify/` in the `raild3x/jecs` repository re-measure most rows in lune and print each beside the figure given here. The lune figures were last run on 2026-11-11 with lune 0.11.1; the Studio figures are older and have not been re-run since the fork's fixes to the deferred queue and cascade delete.
