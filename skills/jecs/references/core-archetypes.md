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
- A structural change moves the entity to another archetype, reassigning one reference per column, so its cost grows with the entity's component count.
- `set` of an existing component moves nothing.
- Archetypes stay when emptied. Deleting a pair target destroys the archetypes that held its pairs; `world:cleanup()` removes the other empty ones.

## Fragmentation

Every distinct pair is its own id, so a relation creates one archetype per target for each shape of holder (the holder is the entity carrying the pair; its shape is the set of other ids it has): 100 targets across holders of 4 shapes is 400 archetypes.

How many archetypes a query walks depends on the query, not on the total:

| Query | Archetypes walked (100 targets, 4 holder shapes) |
|---|---|
| `world:query(Position):with(pair(InCell, cell))` | 4: only that target's |
| `world:query(Position):with(pair(InCell, jecs.Wildcard))` | 400 |
| `world:query(Position)` | 400 |

So:

- A relation whose queries name one target reads only that group, at any target count. That is the grouping benefit.
- Walking many archetypes is cheap up to about 1,000 of them. Fragmentation is not a reason to avoid a broad query until archetypes approach one per entity.
- The cost is in creating archetypes and in moving entities between them, and every retarget is a structural change, dearest the first time a shape moves to a target. Keep targets times holder shapes in the hundreds.
- Emptied archetypes stay in the world and in cached queries, at a small cost. `world:cleanup()` destroys them; cached queries stay correct. Call it once shapes are gone for good (a level unloaded, a one-off mass delete), mainly to release the memory. The next entity of each destroyed shape rebuilds its archetype, so not on a timer, and not between waves that respawn the same shapes. It is not needed after deleting pair targets, which destroys their archetypes already.

Figures and the setups behind them: [performance](performance.md).
