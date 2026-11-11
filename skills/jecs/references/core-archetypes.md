# Archetypes: how the world stores entities

## Mental model

A columnar database:

| Database | JECS |
|---|---|
| Table | Archetype: entities with exactly the same ids |
| Column | Data component |
| Row | Entity |
| Foreign key | Entity in a component |
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
- Walking many archetypes is cheap: a broad query over 10,000 entities spread across 1,000 archetypes ran 1.2x the time of the same entities in a few (1.0x at 100). Up to about 1,000 archetypes, fragmentation is not a reason to avoid a broad query; at 10,000 archetypes of one entity each it measured 2.4x cached and 3.6x uncached.
- The cost is in creating archetypes and in moving entities between them: building is 3x dearer at 1,000 targets and 10-24x at 10,000, and every retarget is a structural change, dearest the first time a shape moves to a target. Keep targets times holder shapes in the hundreds.
- Emptied archetypes stay in the world and in cached queries: 1,000 of them made a cached query 1.2x slower until `world:cleanup()`. Call it once shapes are gone for good (a level unloaded, a one-off mass delete), mainly to release the memory. It destroys every empty archetype, so the next entity of each shape rebuilds it: not on a timer, and not between waves that respawn the same shapes (a 200-shape respawn measured 3.9x slower after a cleanup each time).

Figures and the setups behind them: [performance](performance.md).
