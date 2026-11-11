# Design scenario: grading key

Hidden from the agent. One point per requirement, half for a right model with a wrong or missing reason. Total 10.

| # | Expected | Fails |
|---|---|---|
| 1 | Entity in a data component, checked with `world:contains` (or dropped) on read. Forward-only, read every row, retargeted often | A pair |
| 2 | Exclusive pair `pair(Faction, X)`, `jecs.Exclusive` through `jecs.meta` before the world. Selected on by queries, changes rarely | Value + `if`; a tag per faction |
| 3 | One value component. Read in a loop that visits every NPC anyway; switches often | Exclusive pair; a tag per state |
| 4 | Pair on the item, `pair(OwnedBy, player)`, with `(OnDeleteTarget, Delete)` through `jecs.meta` | Array on the player; pairs on the player; entity in a component with hand-written cleanup |
| 5 | Not stored: each system computes `velocity.Magnitude`. A cached `Speed` only if named as a measured exception | A `Speed` component kept in step by hand |
| 6 | Entity in a data component, `world:contains` when read | A pair |
| 7 | Array of records. The consumer takes the array and replaces it before draining, so thorns hits land in the next frame | Entity per hit; pending component; a clear that drops hits or a drain that can loop |
| 8 | `spawnNpc` is a plain function; movement is a system with a cached query at module scope | Both systems |
| 9 | Grass: no entities. Bush: an entity only while harvested | An entity per blade; 300 permanent bush entities with idle progress |
| 10 | Presence: a `Poisoned` tag or a `Poison` data component, selected by the query | A boolean field tested with `if` |

Also note, without scoring: ids and `jecs.meta` before `jecs.world()`; `jecs.tag()` for tags; `components.luau` runs.
