# Archetypes and measured costs

## Mental model

A columnar database:

| Database | JECS |
|---|---|
| Table | Archetype: entities with exactly the same ids |
| Column | Data component |
| Row | Entity |
| Foreign key | Entity stored in a component |
| Index | Pair: one table per target |
| Query | A scan over the matching tables |

- Queries are fast because they read whole columns of matching archetypes and never look at the others.
- **Structural change** (`add`, `remove`, `delete`, `clear`, `set` of a missing component) moves the entity to another archetype, reassigning one reference per column. Cost grows with component count.
- `set` of an existing component moves nothing.
- Archetypes stay when emptied. Deleting a pair target destroys the archetypes that held its pairs; `world:cleanup()` removes the other empty ones.

## Fragmentation

Every distinct pair is its own id, so a relation creates one archetype per target for each shape of holder: 100 targets across holders of 4 shapes is 400 archetypes.

How many archetypes a query walks depends on the query, not on the total:

| Query | Archetypes walked (100 targets, 4 holder shapes) |
|---|---|
| `world:query(Position):with(pair(InCell, cell))` | 4: only that target's |
| `world:query(Position):with(pair(InCell, jecs.Wildcard))` | 400 |
| `world:query(Position)` | 400 |

So:

- A relation whose queries name one target reads only that group, at any target count. That is the grouping benefit.
- Walking many archetypes is cheap: a broad query over 10,000 entities spread across 1,000 archetypes ran 1.2x the time of the same entities in a few (1.0x at 100). Fragmentation is not a reason to avoid a broad query.
- The cost is in creating archetypes and in moving entities between them: building is 3x dearer at 1,000 targets and 10-22x at 10,000, and every retarget is a structural change, dearest the first time a shape moves to a target. Keep targets times holder shapes in the hundreds.
- Emptied archetypes stay in the world and in cached queries: 1,000 of them made a cached query 1.2x slower until `world:cleanup()`. Call it after a mass delete or a wave of retargeting, mainly to release the memory.

## When speed matters

Thousands of entities, touched every frame, in code that shows up in the profiler. For a few hundred entities or work done a few times a second, every option in the table below is fast enough: choose for clarity and safety (pairs with cleanup traits, tags, filters) and measure before trading them away.

## Measured costs

Ratios from lune and from Roblox Studio (JECS native). Two figures = the two environments. Measure before optimising.

| Choice | Cost |
|---|---|
| Observing a `set`, vs none | hook 1.3-1.9x; 1 signal listener 1.8-2.1x; 3 listeners 2.5-2.6x |
| Debug world | component `set` about 3.7x; pair `set` about 9x; tag add + remove 1.6x (lune) |
| Uncached vs cached query, iterated once per call (lune) | 1.0x with 10,000 entities in 1 archetype; 1.3x in 1,000 archetypes; 2.6x for 100 entities in 100 archetypes; 4x for 10 entities among 1,000 |
| Switching state, vs `set` of a value | exclusive pair 4-5x (entity with 2 other components), 7-13x (10), 22-38x (30). Remove tag + add tag: 8-10x, 14-22x, 46-50x |
| Selecting one state among 10,000, vs a tag or pair filter | value + `if`: 4x when 25% match, about 100x when 1% match |
| Despawn, vs collect-then-delete | marker tag + cleanup query 1.2-2x; in-loop delete no faster |
| Deferred queue (lune), vs hand-written collect-then-apply | 1.0-1.6x; about 45 ns to queue a change |
| Pair vs component link, 10,000 holders: build | equal at 10 targets; 3x at 1,000; 10-19x at 10,000 |
| ... read one target | `world:target` 2-5x `world:get` |
| ... read the target for every row of a loop | wildcard query + `world:target` 7-15x a component column (lune), 6-10x (Studio) |
| ... same work as one query per target, vs a component column (lune) | 1.1x at 1,000 holders per target; 1.6x at 100; 5-6x at 10 |
| ... broad query over the holders (lune) | 1.0x at 100 archetypes; 1.2x at 1,000 |
| ... retarget | exclusive pair 4-5x a `set` on an entity with 2 other components, 7-11x with 10, at any target count once that move has happened before; 14-35x measured over a first pass at 10,000 targets, and 40-240x for a single first move (lune) |
| ... reverse lookup | pair query 9x faster than a scan at 10 targets; about 200x at 1,000 |
| ... delete all targets | 2-3x dearer from 10 to 1,000 targets; 15-30x again at 10,000 |
| Containment, 100 owners x 30 items: build (lune) | pair on item 3x an array on the owner (119 archetypes); pair on owner 90-180x (3,019 archetypes) |
| Events, 10,000/frame, vs direct change | array 1.3x (lune); pending component 4.4-6x; entity per event 6.4-12x |
| Pair signals (lune) | 12-20 ns per pair listener per event on the relation |
| `bulk_insert` vs `set` per component (lune) | slower at 3, equal at 6, 1.57x faster at 12 |

The figures come from one-off benchmarks in lune and Studio. `lune run bench_ops.luau` and `lune run bench_links.luau` in [`../verify/`](../verify/) re-measure most rows in lune and print each beside the table's figure; an independent run put about half inside the ranges above and the rest within 2x. Treat them as orders of magnitude.
