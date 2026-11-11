# Archetypes and measured costs

## The model

An **archetype** is the set of entities that have exactly the same ids. Each archetype stores one column per data component, and a query walks the archetypes that match it and reads their columns. That is why iteration is fast.

Giving an entity a new id, or taking one away, moves it to another archetype and copies every one of its values. This is a **structural change**: `add`, `remove`, `delete`, `clear`, or `set` of a component the entity does not have yet. Its cost grows with the number of components on the entity. Writing a new value into a component the entity already has copies nothing.

Two consequences drive the design advice in the other best-practices files:

- **Prefer changing a value over changing an entity's shape.**
- **Every distinct pair is its own id**, so every distinct target of a relation creates new archetypes. This is fragmentation: it speeds up "everything that points at T" and slows down building, retargeting and deleting when targets are many.

Archetypes are created on demand and stay when they empty out. Deleting a pair target destroys the archetypes that held its pairs, and `world:cleanup()` removes the other empty ones.

## Measured costs

Ratios from benchmarks in lune and in Roblox Studio with JECS compiled native. Where two figures are given they are the two environments. Treat them as the size of an effect, and measure before optimising.

| Choice | Cost |
|---|---|
| **Observing a `set`**, against no listener | one hook 1.3 to 1.7 times; one signal listener 1.8 to 2.1; three signal listeners 2.5 to 2.6 |
| **Debug world**, `world:set` | about 3.7 times a normal world |
| **Changing state**, against `set` of a value component | exclusive pair 4 to 5 times on an entity with 2 other components, 11 to 13 with 10, 28 to 38 with 30. Removing one tag and adding another: 8 to 10, 20 to 22, 46 to 50 |
| **Selecting one state** among 10,000 entities, against a query filtered by a tag or exclusive pair | value component with an `if` in the loop: 4 times when a quarter match, about 100 times when 1% match |
| **Despawning**, against collect-then-delete | marker tag plus a cleanup query 1.2 to 1.4 times; deleting inside the loop is no faster |
| **Deferred queue** (fork, lune only), against a hand-written collect-then-apply | 1.0 to 1.5 times; about 45 ns to queue a change |
| **Pair against component for a link**, 10,000 holders | building the world: equal at 10 targets, 3 times slower at 1,000, 10 to 19 at 10,000. Reading the target: `world:target` 2 to 5 times `world:get`. Retargeting: exclusive pair about 4 times a `set` at 10 targets, 14 to 22 at 10,000. Reverse lookup: the pair query is 9 times faster than scanning at 10 targets and about 200 times at 1,000. Deleting all targets: 2 to 3 times dearer going from 10 to 1,000 targets, then 15 to 30 times dearer again at 10,000 |
| **Events**, 10,000 a frame, against applying the change directly | pending component consumed and removed by a system 4.4 to 6 times; an entity per event 6.4 to 9 |
| **Pair signals** (fork, lune only) | each pair listener on a relation adds 12 to 20 ns to every event on it: about half as much again as an unobserved add with 10, four times with 100 |
| **`bulk_insert`**, against `set` per component (lune only) | slower at 3 components, equal at 6, 1.57 times faster at 12 |
