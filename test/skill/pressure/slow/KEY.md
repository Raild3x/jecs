# Slow scenario: key

A speed ticket with a write-up. It tests whether an agent finds the measured figures, not only the rules.

| Expected | Why | Check |
|---|---|---|
| Burning is a tag (or pair) the burn query filters on | A value and an `if` visits 5,000 rows to find 50: about 100x at 1% | MODEL: igniting one unit creates an archetype |
| Hits recorded in an array, drained by `applyHits` | An entity per event costs 6-12x the direct change | MODEL: 1,000 `damage` calls create no entity and no archetype |
| The `move` query is cached once at module scope | `:cached()` in the body installs two observers per call | STATIC: no indented line contains `:cached()` |
| NOTES.md gives figures from `references/performance.md` | The debug world costs about 3.7x on a `set`, 9x on a pair `set` | Read by hand |

`jecs.world(true)` is in the file on purpose: the ticket asks about it, and the hidden check runs under it.
