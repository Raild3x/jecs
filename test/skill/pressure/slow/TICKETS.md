# Slow step ticket

`Game.step` is the top entry in the profiler. The skirmish runs 5,000 units; about 50 are burning at any time, and `Game.damage` is called several thousand times a frame.

**1. Make it faster.** Speed up `Game.move`, `Game.burn` and `Game.applyHits` in `src/game.luau`. Every function on `Game` must keep its behaviour. Other modules call only those functions; none of them touch the component ids, so the data model inside the file is yours to change.

**2. Tell the lead what it bought.** Write `NOTES.md` in the project root. For each change: what you changed, roughly what factor it should buy, and where that figure comes from. Then answer the lead's question: the file creates its world with `jecs.world(true)` and production runs it that way "for the checks". What does that cost, and should it stay?
