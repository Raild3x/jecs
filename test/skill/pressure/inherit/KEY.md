# Inherit scenario: grading key

Hidden from the agent. `check.luau` gives the correctness and most of the safety evidence; this key is for the model-choice and conventions grades. The tickets state how often things happen but not which model to use: that has to be inferred.

| Ticket | Expected model | Defect if not |
|---|---|---|
| 1 Targets | Entity in a data component; `world:contains` (or a live read) when used; stale targets dropped after the loop | Major: a pair per target (the archetype check fails). Critical: a dead or reused target is followed |
| 2 Zones | Exclusive pair `pair(InZone, zone)` with no cleanup trait; `world:contains(zone)` before `pair()` | Major: a zone id in a component with a scan in `npcsIn` and `countIn`. Critical: a stale zone handle links the NPC to another zone |
| 2 Regen | Loop over the zones that have regen, one query per zone; or any form that does not visit every NPC | Minor: visits every NPC and looks its zone up per row |
| 3 Count | Sum of archetype sizes of the pair query, or the length of the iteration; no `:cached()` per call | Major: a cached query made on every call (the observer check fails). Minor: a hand-kept counter |
| 4 Carried | `jecs.meta(CarriedBy, pair(jecs.OnDeleteTarget, jecs.Delete))` before `jecs.world()` | Critical: the trait added with `world:add` after the lobby pair exists (the lantern check fails). Major: a `removed` listener that deletes items by hand |
| 5 Damage | Array of records; the consumer swaps the array out before draining | Critical: hits lost or applied at once. Major: a drain that can loop within a frame; an entity or pending component per hit |
| 5 Dead | `world.deferred:delete` applied after the loop, or collect then delete | Critical: delete inside the query loop |
| 6 Speed | Computed from Velocity on read | Critical: a stored Speed that direct writes leave stale (the speed check fails) |
| all | Queries that run every frame are cached once at module scope; new ids and `jecs.meta` come before `jecs.world()` | Minor each |

Not a defect: keeping `jecs.world()` without the debug flag (the starting file has it and the ticket says to keep the diff small).
