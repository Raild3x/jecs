# Archetypes and measured costs

## Mental model

A columnar database:

| Database | JECS |
|---|---|
| Table | Archetype: entities with exactly the same ids |
| Column | Data component |
| Row | Entity |
| Query | A scan over the matching tables |

- Queries are fast because they read whole columns of matching archetypes.
- **Structural change** (`add`, `remove`, `delete`, `clear`, `set` of a missing component) moves the entity to another archetype and copies every value. Cost grows with component count.
- `set` of an existing component copies nothing.
- Every distinct pair is its own id, so each target of a relation creates archetypes (fragmentation). That is what makes "everything pointing at T" a direct lookup.
- Archetypes stay when emptied. Deleting a pair target destroys the archetypes that held its pairs; `world:cleanup()` removes the other empty ones.

## Measured costs

Ratios from lune and from Roblox Studio (JECS native). Two figures = the two environments. Measure before optimising.

| Choice | Cost |
|---|---|
| Observing a `set`, vs none | hook 1.3-1.7x; 1 signal listener 1.8-2.1x; 3 listeners 2.5-2.6x |
| Debug world `set` | about 3.7x |
| Switching state, vs `set` of a value | exclusive pair 4-5x (entity with 2 other components), 11-13x (10), 28-38x (30). Remove tag + add tag: 8-10x, 20-22x, 46-50x |
| Selecting one state among 10,000, vs a tag or pair filter | value + `if`: 4x when 25% match, about 100x when 1% match |
| Despawn, vs collect-then-delete | marker tag + cleanup query 1.2-1.4x; in-loop delete no faster |
| Deferred queue (fork, lune), vs hand-written collect-then-apply | 1.0-1.5x; about 45 ns per queued change |
| Pair vs component link, 10,000 holders: build | equal at 10 targets; 3x at 1,000; 10-19x at 10,000 |
| ... read target | `world:target` 2-5x `world:get` |
| ... retarget | exclusive pair about 4x a `set` at 10 targets; 14-22x at 10,000 |
| ... reverse lookup | pair query 9x faster than a scan at 10 targets; about 200x at 1,000 |
| ... delete all targets | 2-3x dearer from 10 to 1,000 targets; 15-30x again at 10,000 |
| Events, 10,000/frame, vs direct change | pending component 4.4-6x; entity per event 6.4-9x |
| Pair signals (fork, lune) | 12-20 ns per pair listener per event on the relation |
| `bulk_insert` vs `set` per component (lune) | slower at 3, equal at 6, 1.57x faster at 12 |
