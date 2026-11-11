# Pressure tests

For whoever maintains the skill. Agents using the skill do not need this folder.

## Method

Each scenario runs once without the skill and once with it, per model. The agent gets a project, a task under time pressure ("playtest in 20 minutes, keep the diff small"), and no hint where the library is. A hidden `check.luau` and a blind grader score the result.

Project layout:

```
wally.toml                 names the jecs package
rokit.toml                 lune
Packages/jecs.luau         return require("./_Index/<scope>_jecs@<version>/jecs/src/jecs")
Packages/_Index/<scope>_jecs@<version>/jecs/src/jecs.luau
src/game.luau              the scenario's game.luau
```

After the run, copy the scenario's `check.luau` to the project root and `lune run check.luau`. Copy answers under neutral names before grading so the grader cannot tell the arms apart.

## Scenarios

| Folder | Library | Task | Probes |
|---|---|---|---|
| `tickets/` | fork | stun tag, Health cap hook, deaths, per-frame count | hooks, structural changes, counting |
| `squads/` | fork | squad membership, disband, one-of-three stance, per-frame count | pairs, exclusivity, cleanup traits |
| `upstream/` | `ukendio/jecs` | freeze tag beside an existing `:without`, boss-follower callback, deaths with follower cascade | upstream-only silent failures |
| `events/` | fork | queued damage, per-hit callback, changed-Health list, inventory notify | events, change tracking |
| `review/` | fork | find the defects in `game.luau`, write `REVIEW.md` | recognising mistakes |

Ticket wording for each scenario is in the "Tickets" section at the end.

## Rubric

Implementation answers, 0-2 each, total 10:

1. **Correctness:** hidden checks pass, no other behavioural bug.
2. **Silent failures:** no library trap present.
3. **Built-ins over custom:** pairs, traits, queries, signals, deferred queue used where they fit.
4. **Conventions:** ids and config before the world, cached queries at module scope.
5. **Economy:** smallest change, existing exports intact.

Reviews: `found / 14 * 8`, minus 1 per defect dismissed, minus 0.5 per false positive, plus up to 2 for correct fixes.

Review key (14): late `jecs.tag()`; `world:component()` as a marker; late raw hook; `OnChange` without `OnAdd`; in-place table mutation never fires `changed`; dirty table never drained; structural change in a `removed` listener; `pair()` from an unchecked handle; five ids to `world:has`; reused uncached query; `:cached()` inside `step`; `delete` in a query loop; `remove` in a query loop; `world:exists` to validate.

## Results, 2026-11-10

Sonnet and Opus at medium effort, one run per cell, blind-graded.

| Scenario | Sonnet, no skill | Sonnet, skill | Opus, no skill | Opus, skill |
|---|---|---|---|---|
| squads | 3 | 10 | 6 | 10 |
| upstream | 5 | 10 | 9 | 10 |
| events | 8 | 10 | 9 | 10 |
| review | 6.6 (8/14) | 10 (14/14) | 6.1 (8/14) | 10 (14/14) |

What lost points without the skill:

- `jecs.tag()` after `jecs.world()` (Sonnet: squads, upstream, and an earlier tickets run). The tag shares an id with an entity; deleting that entity strips the tag from everything. Silent on upstream.
- `pair(R, squad)` from an unchecked handle (Sonnet and Opus, squads): joining a disbanded squad linked the unit to the slot's new occupant.
- Three hand-swapped tags instead of an exclusive pair; a query rebuilt every frame (Sonnet, squads).
- Traits set with `world:add` after the world rather than `jecs.meta` before it.
- Reviews missed the defects a quick test does not show: in-loop structural changes, the remove listener, the unchecked pair, the marker component.

`tickets/` (hidden checks only, earlier skill version): every run 8/8 except one Sonnet baseline at 7/8, the same late-tag bug. On the top model both arms passed everything; the skill arm used about 20% fewer tokens.

Without the skill, agents found the library unprompted and read about 150 of 4,400 lines by search. With it, most did not open the library.

Limits: one run per cell; every skill run scored the maximum, so this rubric cannot rank further improvements.

## Tickets

**tickets:** (1) `Game.stun(unit)` / `Game.unstun(unit)`; a stunned unit takes no poison in `Game.step`. (2) No unit's Health may exceed 100, whoever writes it; other modules call `Game.world:set` directly, so enforce it with a hook. (3) At the end of `Game.step` remove every unit with Health <= 0; followers of a removed unit stay alive. (4) `Game.countPoisoned()`, called every frame.

**squads:** (1) `Game.createSquad()`, `Game.join(unit, squad)`, `Game.squadOf(unit)`, `Game.membersOf(squad)`; one squad per unit, joining another leaves the first; hundreds of squads, thousands of units. (2) `Game.disband(squad)` removes the squad and its units; other code may delete a squad directly and its units must still go; `disband` / `membersOf` on a disbanded squad are harmless. (3) A unit with a stance has exactly one of "idle", "guarding", "charging"; `Game.setStance(unit, stance)`; `Game.step(dt)` heals guarding units 1 Health per second; stances change a few times a minute. (4) `Game.countInSquad(squad)`, called every frame.

**upstream:** (1) `Game.freeze(unit)` / `Game.thaw(unit)`; a frozen unit takes no poison; shielded units must still take none. (2) `Game.onBossFollower(callback)`: `callback(unit)` whenever a unit starts following `Game.boss`, not for others. (3) At the end of `Game.step` remove every unit with Health <= 0; followers of a removed unit go with it, also when other code deletes a leader.

**events:** (1) `Game.damage(target, amount)`: many calls per frame, from inside query loops, several per target; nothing changes until `Game.step`, which applies every hit. (2) `Game.onHit(callback)`: `callback(target, amount)` once per applied hit. (3) `Game.takeChangedHealth()`: live units whose Health was written since the last call, each once, new spawns included; others write Health directly; thousands of units, few change. (4) `Game.addItem(unit, item)`: listeners on `world:changed(Inventory)` must be notified per item.

**review:** "`src/game.luau` ships in 20 minutes. Review it for defects in how it uses JECS. Write findings to `REVIEW.md`: line, what is wrong, what happens at runtime, the fix. Real defects only."
