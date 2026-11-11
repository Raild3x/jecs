# Pressure tests

For whoever maintains the skill in `skills/jecs/`. Kept outside the skill folder, with `../verify/`, so an agent using the skill cannot wander into the keys and hidden checks.

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
| `design/` | fork | ten modelling decisions from `BRIEF.md`: write `components.luau` and `DESIGN.md` | choosing pair, component, tag, value, entity, event queue |
| `inherit/` | fork | six tickets on an existing `game.luau`: targets, zones, a per-frame count, carried items, queued damage with thorns, speed | inferring the model from stated use; stale handles; late traits; event queues |
| `infer/` | fork | four tickets with no rates: the caller modules show how each function is used | choosing component, value, pair or tag from usage in code; model detected by archetype counts |
| `rival/` | fork | one link that merely points, is read every frame, and is set once | the case where the pair-first skill and the by-need skill disagree |
| `slow/` | fork | speed up a step that caches a query per call, selects a state with an `if` and makes an entity per hit; write up what each change buys | finding the measured figures; model detected by archetypes and entity counts |

Ticket wording for each scenario is in the "Tickets" section at the end.

## Rubric

Used from 2026-11-11. The earlier rubric (next heading) gave every correct answer the maximum, so it could not rank skill versions.

Each category is graded 0-4, then weighted into a percentage.

| Grade | Meaning |
|---|---|
| 4 | Correct, and handles a case the ticket did not name (see "Earns the 4") |
| 3 | Correct, no defect. A flawless answer that does only what was asked scores 75% |
| 2 | One minor defect |
| 1 | One major defect, or two minor |
| 0 | A critical defect, or major and minor together |

Start at 3, add 1 if the answer earns it, subtract per defect, floor at 0:

| Severity | Subtract | Test |
|---|---|---|
| Critical | 3 | Silently wrong in play: lost or corrupted state, a change that never happens, an id collision |
| Major | 2 | Works, at a cost someone will have to pay: wrong model for the stated use, a leak, a trap the debug world would catch |
| Minor | 1 | Works; a reviewer would ask for a change: inconsistency with the skill, a missed convention, unrequested extras |

| Category | Weight | Graded on | Earns the 4 |
|---|---|---|---|
| Correctness | 30% | Hidden checks pass; the code runs; no behavioural bug | Covers an input the ticket did not name |
| Silent-failure safety | 25% | No library trap: late ids or config, in-loop structural change, unchecked handle in a write or `pair()`, unapplied queue | Guards a stale handle or dead target nobody asked about |
| Model choice | 20% | Pair, component, tag, value, entity or event queue chosen as the skill's tables say for the stated use | Uses a built-in to remove code the ticket implied (a cleanup trait instead of a handler) |
| Reasoning | 10% | Each decision names the fact that decides it. Scenarios with no written answer: drop this row and rescale | Gives the measured cost of the rejected option |
| Conventions | 10% | Ids, then `jecs.meta`, then the world; `jecs.tag()` for tags; cached queries at module scope; `--!strict` | Names on ids and a debug world wired to Studio |
| Economy | 5% | Smallest change; existing exports intact; nothing unrequested | Clearly less code than the other arms for the same result |

Report with every result table: the grade per category, the weighted total, the subagent's total tokens, its wall-clock time and its tool calls. Tokens and time are reported, not scored: they vary with the model more than with the skill.

Grade arms under neutral names. State when the grader was not blind.

### Rubric before 2026-11-11

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

## Results, 2026-11-11: design scenario

Run for the rewrite that made link and state choices depend on use (pair when the holder belongs to the target or the reverse lookup is needed; entity in a component when it merely points; exclusive pair when selected on and rarely changed; value component when read by everyone or switched often) and changed the event queue to a buffer swap. One run per cell, medium effort. Model choice is graded against `design/KEY.md`. The grader knew which arm was which.

| Arm | Correct 30% | Safety 25% | Model 20% | Reasoning 10% | Conventions 10% | Economy 5% | Total | Tokens | Time | Tool calls |
|---|---|---|---|---|---|---|---|---|---|---|
| Sonnet, no skill | 3 | 0 | 1 | 2 | 0 | 2 | 35% | 70,065 | 82 s | 14 |
| Sonnet, skill before | 3 | 4 | 2 | 4 | 3 | 2 | 78% | 64,503 | 55 s | 8 |
| Opus, skill before | 3 | 4 | 2 | 4 | 4 | 3 | 81% | 69,240 | 82 s | 12 |
| Sonnet, skill after | 3 | 3 | 3 | 3 | 3 | 2 | 74% | 69,840 | 51 s | 14 |
| Opus, skill after | 3 | 4 | 4 | 3 | 4 | 3 | 89% | 72,173 | 83 s | 22 |
| `squads/`, Sonnet, skill after | 3 | 3 | 3 | n/a | 3 | 3 | 75% | 61,535 | 24 s | 5 |

What moved each grade:

| Arm | Defects and credits |
|---|---|
| Sonnet, no skill | Safety: the poison system queues removals and never applies them (critical). Model: 20,000 grass entities (major). Reasoning: the grass reason is wrong (minor). Conventions: world before the ids, `world:component()` for tags, `Exclusive` added with `world:add`, per-frame query not cached, no `--!strict`. Economy: systems and a smoke test in the components file (minor) |
| Sonnet, skill before | Safety +1: checks the attacker is alive before crediting it. Model: 300 permanent bush entities (minor). Reasoning +1: gives the measured cost of each rejected option. Economy: an extra `check.luau` nobody asked for (minor) |
| Opus, skill before | Safety +1: same attacker check. Model: permanent bush entities (minor). Reasoning +1: measured costs. Conventions +1: names on ids, debug world wired to Studio |
| Sonnet, skill after | No defect in the first five categories and nothing beyond the brief. Reasons name the deciding fact but no cost. Economy: systems and tests in the components file (minor) |
| Opus, skill after | Safety +1: attacker check. Model +1: a cleanup trait ends a harvest when the player leaves. Conventions +1: names and debug world. Reasons give no measured cost |
| `squads/` | 7 of 7 hidden checks; correct, nothing beyond the tickets. Reasoning dropped and the rest rescaled |

Reading the totals:

- The skill is worth about 40 points over no skill, nearly all of it in safety and conventions.
- The rewrite fixed model choice (2 to 3 and 2 to 4) and cost a point of reasoning on both models: answers stopped quoting measured costs. One run per cell, so that may be noise, but it is the first thing to check in a repeat.
- Tokens and time did not move with the skill version. Opus took about 1.5x Sonnet's time for a higher total.
- The after-rewrite runs used the skill before its later corrections (the `:with` reason, fragmentation cost, `world:cleanup`). Not re-run.

The same runs under the key alone, one point per requirement, scored 9, 9.5, 9, 10 and 10: that scale could not separate them.

- The brief states how each piece of data is read and how often it changes, and with those facts given every arm chose the right model for links and state, the control included. The scenario does not show that the old pair-first wording caused wrong choices; that change rests on the measured costs, not on a failing run.
- No skill: 20,000 grass entities; in code, the world was created before the ids, `world:component()` was used for tags, `Exclusive` was added late with `world:add`, the per-frame query was not cached and the deferred queue was never applied.
- Skill before the rewrite: both models kept 300 permanent bush entities. Event queues differed: one swapped the buffer inside a bounded number of rounds, one drained in the same frame with `while i <= #hits`.
- Skill after the rewrite: both models created the harvest entity on demand and wrote the same plain buffer swap.
- Regression: `squads/` on Sonnet with the rewritten skill passed 7 of 7 hidden checks, with exclusive pairs for membership and stance.

Limits: one run per cell, and a brief that spells out read and change rates. A harder version would leave those to be inferred from the code.

## Results, 2026-11-11: re-run and adversarial review

Re-run against the skill after its first round of corrections (the `:with` reason, fragmentation cost, `world:cleanup`). Same conditions and rubric as above; the grader knew the arms.

| Arm | Correct 30% | Safety 25% | Model 20% | Reasoning 10% | Conventions 10% | Economy 5% | Total | Tokens | Time | Tool calls |
|---|---|---|---|---|---|---|---|---|---|---|
| `design/`, Sonnet, run 1 | 3 | 4 | 3 | 3 | 2 | 2 | 78% | 71,587 | 64 s | 10 |
| `design/`, Sonnet, run 2 | 3 | 4 | 3 | 3 | 2 | 2 | 78% | 67,768 | 55 s | 9 |
| `design/`, Opus | 2 | 4 | 4 | 3 | 4 | 3 | 81% | 71,351 | 90 s | 18 |
| `squads/`, Sonnet | 3 | 3 | 3 | n/a | 2 | 3 | 72% | 62,002 | 27 s | 6 |

| Arm | Defects and credits |
|---|---|
| Sonnet, both runs | Safety +1: checks the attacker is alive. Conventions: `jecs.world()` with no debug flag (minor). Economy: systems and tests in the components file (minor). One measured cost quoted |
| Opus | Correctness: thorns left as a placeholder (`local thorns = 0`), so it never triggers (minor). Safety +1: attacker check. Model +1: cleanup trait ends a harvest when the player leaves. Conventions +1: names, debug world wired to Studio |
| `squads/` | 7 of 7 hidden checks. Conventions: the per-frame heal query is rebuilt uncached in `Game.step` (minor) |

- The two Sonnet runs gave the same ten decisions, the same buffer swap and the same two defects: the wording binds.
- Both dropped the debug world because the skill said `jecs.world(RunService:IsStudio())` and lune has no `RunService`. The skill now says to pass `true` outside Roblox. Not re-tested.
- Mean across the five design runs after the rewrite: 80% (74, 78, 78 Sonnet; 89, 81 Opus), against 78% and 81% before it.

Adversarial review, same day: one reviewer on the session's model, told to assume the skill was badly made and to prove it by running code. 201,411 tokens, 11 minutes, 39 tool calls. One critical, two major and eight minor findings, all reproduced and corrected, each with a new assertion in `verify/facts.luau` where it is a library behaviour:

| Severity | Finding | Now |
|---|---|---|
| Critical | "No `world:contains` check is needed" for the deferred queue: only the entity is checked. A queued pair whose target dies raises at `apply`, or links to the slot's next occupant | feature-deferred states it, with a mistake row |
| Major | upstream-differences claimed everything unlisted behaves the same. Upstream silently swaps data on an entity that lost its last component and gets one again, and `bulk_insert` drops `false` | Sentence removed, both rows added with a tested workaround |
| Major | A hook or trait set late is not simply ignored: it applies to pairs with new targets and after the id's archetypes are destroyed | Four files corrected |
| Minor | `set` of an existing component raises in a debug world from `OnRemove` during a delete; `world:set` on a tag raises after adding it; a stored uncached query resumes after a `break`; `pair()` never raises, adding the pair does; debug cost is 9x on a pair `set`; the retarget cost depends on whether the move happened before, not on target count; the "4x with 100 listeners" ratio depended on the baseline; `modules/OB` gives multi-term observers | Corrected in place |

The reviewer could not break any code example, and re-measured 20 cost figures: about half inside the skill's ranges, the rest within about 2x (ranges widened), and one wrong in kind (retarget cost, corrected above).

## Results, 2026-11-11: inherit scenario, blind graded

Sonnet at medium effort, three runs per arm. Hidden checks are `inherit/check.luau` (23). A separate grader on the session's model scored the nine answers under neutral names against `inherit/KEY.md`, without knowing arms existed, and ran its own probes for defects the checks miss (110,236 tokens, 4 minutes, 20 tool calls). For this scenario the weights are correctness 30, safety 25, model choice 25, conventions 15, economy 5: there is no written answer to grade reasoning on.

| Arm | Run | Correct | Safety | Model | Conventions | Economy | Total | Hidden checks | Tokens | Time | Tool calls |
|---|---|---|---|---|---|---|---|---|---|---|---|
| No skill | 1 | 3 | 3 | 3 | 1 | 3 | 68% | 23/23 | 57,718 | 48 s | 6 |
| No skill | 4 | 2 | 3 | 3 | 0 | 3 | 56% | 23/23 | 60,038 | 49 s | 10 |
| No skill | 7 | 0 | 3 | 3 | 1 | 3 | 45% | 22/23 | 58,214 | 53 s | 10 |
| Skill before the rewrite | 2 | 0 | 4 | 3 | 3 | 3 | 59% | 23/23 | 65,120 | 42 s | 7 |
| Skill before the rewrite | 5 | 3 | 4 | 3 | 3 | 3 | 81% | 23/23 | 67,007 | 57 s | 10 |
| Skill before the rewrite | 8 | 1 | 4 | 3 | 3 | 3 | 66% | 23/23 | 65,736 | 42 s | 7 |
| Skill after the rewrite | 3 | 1 | 4 | 3 | 3 | 3 | 66% | 23/23 | 68,905 | 48 s | 11 |
| Skill after the rewrite | 6 | 4 | 4 | 3 | 3 | 3 | 89% | 23/23 | 71,237 | 51 s | 8 |
| Skill after the rewrite | 9 | 2 | 3 | 3 | 2 | 3 | 64% | 23/23 | 66,995 | 46 s | 15 |

Arm means: no skill 56%, skill before 69%, skill after 73%.

- A skill is worth 13 to 17 points, in conventions and safety: every no-skill run set its traits with `world:add` after the world and cached no query.
- The two skill versions are 4 points apart with a 25-point spread inside each arm. Three runs do not separate them.
- Model choice was the same in all nine answers, the no-skill ones included. The tickets say how often things happen, and that was enough for Sonnet to choose the component for the target and the pair for the zone unaided. This scenario does not test the link and state guidance either; a scenario that does would have to hide the rates in existing code or in a profile.
- The hidden checks passed almost everywhere. The spread comes from defects the grader found by probing:

| Defect | Runs | Severity given |
|---|---|---|
| `setTarget` with a dead target returns early, so the NPC keeps its old target | 2, 3 | Critical |
| A stale target is never dropped: Velocity is forced to 0 every frame | 1, 4, 5, 7, 8, 9 | Minor |
| `countIn` returns the number of archetypes | 7 | Critical |
| The death query lacks `Npc`: any entity with Health at 0 is deleted | 8 | Minor |
| A live target without Position is treated as gone | 2 | Minor |
| Applies the shared `world.deferred` and so flushes other modules' changes | 9 | Minor |
| Traits set with `world:add` after the world | 1, 4, 7 | Minor |
| Per-frame queries not cached | 1, 4, 7, 9 | Minor |

The first row is a guard the skill asks for (`world:contains` before a write) written so that it hides the failure. The skill now says to decide what a dead handle means. Not re-tested in this table.

Re-test after the corrections, same day: six more Sonnet runs on the skill, not graded blind. Hidden checks and the grader's probe script (`probe.luau`, not shipped) were run on each; the columns are the defects from the table above.

| Skill version | Run | Hidden checks | Dead target clears | Stale zone guarded | Stale target dropped | Per-frame queries cached | Tokens | Time | Tool calls |
|---|---|---|---|---|---|---|---|---|---|
| After the first nine | 3, 6, 9 | 23, 23, 23 | 2 of 3 | 1 of 3 | 2 of 3 | 2 of 3 | 69,046 mean | 48 s | 11 |
| + "decide what a dead handle means", second-review corrections | 10 | 23/23 | yes | yes | no | none | 68,786 | 53 s | 11 |
| | 11 | 23/23 | yes | yes | no | none | 66,832 | 37 s | 12 |
| | 12 | 23/23 | yes | yes | no | none | 73,998 | 52 s | 9 |
| + caching and the stale-link drop in SKILL.md's quick reference | 13 | 23/23 | yes | yes | yes | all | 74,168 | 52 s | 17 |
| | 14 | 23/23 | yes | yes | no | all | 68,112 | 56 s | 7 |
| | 15 | 23/23 | yes | yes | yes | all but the starting file's | 70,555 | 55 s | 15 |

- Runs 10 to 12 fixed the dead-handle guard and lost query caching in all three. The second-review correction had hedged module-scope cached queries with a note about several worlds; with the hedge removed and the rule in the quick reference, all three of the next runs cached.
- What reaches every run is SKILL.md. A rule that lives only in a reference file was followed by some runs and not others; the same rule as a quick-reference row was followed by all three.
- Measured while fixing this: an uncached query costs nothing extra with one archetype, 1.3x at 1,000, and 2.6 to 4x when few entities are spread over many. The skill's reason for caching now says that.
- Run 15 queries `Health` without `Npc` for deaths, as run 8 did. Left as is: the ticket says "every NPC", and no rule would have caught it.

Second adversarial review, same day: 227,464 tokens, 12 minutes, 40 tool calls. One critical, eight major and eleven minor findings; all reproduced.

| Severity | Finding | Now |
|---|---|---|
| Critical | During `world:delete` the dying entity passed `world:contains` while its row belonged to another entity: a child's `OnRemove` or a `removed` listener read and overwrote that other entity | Fixed in the library; the skill says not to touch other entities from a remove callback, and why |
| Major | A hook set late on a relation: `OnChange` and `OnRemove` fire for new targets, `OnAdd` never | Corrected |
| Major | `Exclusive` set late is ignored only while a pair of the relation exists | Corrected |
| Major | Wildcard pairs in `add`, `set` and `bulk_remove` fail silently on a normal world | `bulk_remove` fixed in the library; the others documented |
| Major | The deferred queue does not guard a plain id that dies | Documented |
| Major | A component's hooks do not run for `pair(tag, component)` | Documented |
| Major | "Every statement is asserted in verify/" was false; one assertion passed for the wrong reason | Sentence corrected, assertion replaced, 16 added |
| Major | The upstream emptied-entity row named too narrow a trigger | Corrected |
| Minor | A debug world left an entity marked as being deleted after its hook raised (fixed in the library); an abandoned delete has already run earlier hooks; retarget cost depends on entity width; the symptom table missed causes; module-scope state against several worlds; and six more | Corrected in place |

Not verified by either reviewer: the typing claim in SKILL.md (checked later, see below) and the Studio figures.

## Results, 2026-11-11: infer and rival, model detected by the checks

Sonnet at medium effort. No grader: `check.luau` reports behaviour and model separately, and the model checks were validated against a reference answer (4 of 4) and a deliberately wrong one (0 of 4).

`infer/`, three runs per arm:

| Arm | Run | Behaviour (11) | Model (4) | Tokens | Time | Tool calls |
|---|---|---|---|---|---|---|
| No skill | 1 | 10 | 3 | 58,042 | 40 s | 7 |
| No skill | 4 | 10 | 3 | 55,415 | 42 s | 8 |
| No skill | 7 | 11 | 4 | 59,263 | 64 s | 11 |
| Skill before the rewrite | 2 | 11 | 4 | 57,271 | 27 s | 7 |
| Skill before the rewrite | 5 | 11 | 4 | 57,237 | 25 s | 7 |
| Skill before the rewrite | 8 | 11 | 4 | 58,209 | 25 s | 7 |
| Current skill | 3 | 11 | 4 | 63,691 | 35 s | 16 |
| Current skill | 6 | 11 | 4 | 65,113 | 38 s | 16 |
| Current skill | 9 | 11 | 4 | 56,355 | 25 s | 7 |

- Without a skill, two of three runs made focus a pair: about 1,000 archetypes for 1,000 NPCs, and `setFocus` with a dead handle linked the NPC to whatever reused the slot. This is the first scenario in which the skill changes the model an agent chooses.
- Both skill versions got everything. The pair-first skill's exception (a target rewritten on most entities every frame) applies to focus, so this scenario does not separate the two.

`rival/`, the case between the two rules (read every frame, thousands of targets, set once, no reverse lookup):

| Arm | Run | Model | Dead handle on set | Tokens | Time | Tool calls |
|---|---|---|---|---|---|---|
| Skill before the rewrite | 1 | pair | links to the slot's next occupant | 58,873 | 31 s | 13 |
| Skill before the rewrite | 2 | component | cleared | 55,349 | 29 s | 11 |
| Skill before the rewrite | 3 | component | cleared | 55,392 | 27 s | 7 |
| Current skill | 4 | component | cleared | 56,958 | 26 s | 12 |
| Current skill | 5 | component | cleared | 56,667 | 21 s | 7 |
| Current skill | 6 | component | cleared | 54,370 | 21 s | 6 |

One of three pair-first runs chose the pair, with the stale-handle bug that comes with it; none of three current-skill runs did. Three runs per arm is a direction, not a rate.

Typing: `verify/types.luau` under `luau-lsp analyze` 1.70.1 confirms SKILL.md. `world:get` and `world:set` are typed under both solvers; query values only under the new one; `jecs.component<<T>>()` parses under both.

Studio: not re-measured. Studio's MCP server answered with no open instance.

## Results, 2026-11-11: which reference files agents open

Sonnet at medium effort, two runs of each fork scenario (16 runs per round), against a copy of the skill holding only `SKILL.md` and `references/`. Reads were taken from the subagent transcripts and each run's own list; agents often read several files in one shell command, so the two were merged. Not graded: hidden checks only, and the design answers read by hand.

Round 1 is the skill at `284a592`. Round 2 added a 35-line module example to SKILL.md (ids, `jecs.meta`, world, cached query, deferred delete, count by archetype) and cut the system-or-function table, the composition paragraph and two derived-data rows.

| Round | Hidden checks | Reference files opened per run | Tokens per run | Time per run |
|---|---|---|---|---|
| 1 | all pass (12 of 12 runs that have a check) | 4.4 | 62,789 | 53 s |
| 2 | all pass (12 of 12) | 3.8 | 61,865 | 47 s |

Runs that opened each file, of 16:

| File | Round 1 | Round 2 |
|---|---|---|
| feature-cleanup-traits | 11 | 10 |
| core-queries | 10 | 10 |
| feature-pairs | 9 | 7 |
| feature-deferred | 8 | 6 |
| best-practices-entities | 6 | 5 |
| core-basics | 5 | 3 |
| best-practices-systems | 5 | 4 |
| feature-hooks | 4 | 4 |
| feature-signals | 4 | 5 |
| best-practices-change-tracking | 4 | 3 |
| best-practices-components | 3 | 4 |
| best-practices-queries | 1 | 0 |
| best-practices-archetypes, advanced-api | 0 | 0 |
| flecs, upstream-differences | 0 | 0 (no scenario calls for them) |

- No run worked from SKILL.md alone. The commonest reasons to open a file were one snippet each: the default when a pair's target is deleted, counting through `archetypes()`, the `deferred` loop, `Exclusive`.
- The example did not pay for itself: tokens moved 1.5%, inside the spread between two runs of one scenario. One round-2 design run opened neither best-practices-entities nor best-practices-systems and gave 20,000 grass entities and a drain by index, the two answers those files exist to prevent; the earlier design runs on the rewritten skill, round 1's two included, had both right. One run is not a rate, but the example was removed: it bought nothing measurable and may make SKILL.md look sufficient.
- The cuts stayed. All four design runs across both rounds made `spawnNpc` a plain function and computed speed, as the no-skill run had.
- The two rules that design run missed (what deserves an entity; swap the array before draining) live only in reference files. Promoting them to the quick reference is the next thing to test.
- Several runs left `jecs.world()` without the debug flag "to keep the diff small".

Tooling for this is not in the repo: a project builder and a transcript reader (`setup.sh`, `nav_reads.py`).

Follow-up, same day: four more design runs on the committed skill (no example) all kept grass out of the world and swapped the array before draining. With no failing run there is nothing for a quick-reference row to fix, so the two rules were not promoted.

## Results, 2026-11-11: does the description trigger

The first test in which nothing told the agent to read the skill. The skill was installed as a project skill in an otherwise empty folder and `claude -p <query>` run on Sonnet, three times per query, beside the tester's other installed skills. A run counts when the Skill tool is called with `jecs` or its SKILL.md is read.

| Queries | Should trigger | Triggered |
|---|---|---|
| A hook that misses the first `set`; pair or component for a target; a stored query empty on the second pass; reviewing a delete inside a query loop; porting a Flecs pattern; adding a stun tag to a file with a jecs world; ECS design for a Roblox game with no library named; cascade on squad delete; a deferred change that never applies; a loop that skips entities | yes | 30 of 30 runs |
| roblox-ts with `@rbxts/jecs`; Matter; Flecs in C++; Bevy; Luau generics; Unity DOTS; metatable classes; Python `esper`; react-lua; PathfindingService | no | 0 of 30 runs |

- The description needs no change. The suspected false trigger on roblox-ts did not happen.
- Limits: one model, an empty project folder (no `wally.toml` to hint either way), 20 queries, and no query about replication or scheduler choice, which the skill also excludes.
- The queries and the runner (`trigger_queries.json`, `trigger_eval.py`) are not in the repo. The runner passes the query on stdin: on Windows a multi-line query on the command line never starts.

## Results, 2026-11-11: rival at ten runs per arm

Sonnet at medium effort, graded by `rival/check.luau` only. The current skill is the text at `1cbef9f`; the skill before the rewrite is the tree at `7226e18`. Counts include the earlier runs above (three per skill arm) and the three run after the terminology change.

| Arm | Runs | Chose a pair | `setRival` with a dead handle wrong | Id registered after the world | All five checks pass | Tokens per run | Time per run |
|---|---|---|---|---|---|---|---|
| No skill | 3 | 0 | 0 | 1 | 2 | 49,187 | 29 s |
| Skill before the rewrite | 13 | 2 | 3 | 0 | 10 | 56,456 | 29 s |
| Current skill | 13 | 0 | 0 | 1 | 12 | 55,788 | 30 s |

Tokens and time are the means of this round's runs (10, 7 and 3).

- The scenario does not rank the two skills on the model chosen. Two pairs in 13 against none in 13 is not a difference at this size (Fisher's exact test, p = 0.48), and all three runs without a skill chose the component.
- The dead-handle rule is where the versions differ most: 3 of 13 against 0 of 12 that loaded. Two of the three failures are the pair runs; the third kept the old rival when handed a dead one. This is also short of a reliable difference (p = 0.22).
- One current-skill run and one no-skill run declared `Rival` with `jecs.component()` below `jecs.world()`. Under lune the module then fails on the first `set` ("attempt to modify a readonly table"), so every check fails. The current-skill run read SKILL.md, which states the rule in its core principle and in the mistakes table, and no run on the older skill made the mistake. Neither failing run had executed its code.
- Reference files opened: the current skill's runs opened one (`best-practices-entities`) in all seven; the older skill's runs opened three to five.
- Two runs returned without doing any work and were replaced; they are not counted.

## Results, 2026-11-11: a finishing check in SKILL.md

Added one section, "Before reporting done": run what you wrote once and call each function you added. Tested on `rival`, Sonnet at medium effort, against the seven current-skill runs of the round above as the control.

| Arm | Runs | Executed its code | All five checks pass | Tokens per run | Time per run | Tool calls per run |
|---|---|---|---|---|---|---|
| Current skill | 7 | 0 | 6 | 55,788 | 30 s | 7.1 |
| With the finishing check | 10 | 10 | 10 | 55,255 | 36 s | 10.0 |

- Every run with the section wrote a throwaway lune script, ran it and deleted it; none left a file behind. No control run executed anything (Fisher's exact test, p < 0.001).
- The pass rate is 10 of 10 against 6 of 7, which is not a difference at this size. The one control failure, an id registered after the world, is the kind a first call catches.
- Cost: six seconds and three tool calls per run; tokens unchanged.
- One run returned without doing any work and was replaced. Limits: one scenario, one model, and lune was on the path; nothing here shows what an agent does when it has no way to run Luau.

## Results, 2026-11-11: a performance page

The cost table moved out of `best-practices-archetypes.md` into a new `references/performance.md`, grouped by topic with the setup behind each figure; the rest of the old file became `core-archetypes.md`. Tested on the new `slow/` scenario, Sonnet at medium effort, six runs per arm. "Before" is the skill at `2fe0a54`.

| Arm | Runs | All eight checks pass | Opened the file holding the cost table | NOTES.md gives the table's figures | Tokens per run | Time per run | Tool calls per run |
|---|---|---|---|---|---|---|---|
| Before | 6 | 6 | 6 (`best-practices-archetypes`) | 6 | 61,459 | 64 s | 11.7 |
| After | 6 | 6 | 6 (`performance`) | 6 | 61,988 | 55 s | 10.5 |

- No difference. Every run in both arms fixed all three defects, found the cost table and quoted its figures (3.7x and 9x for the debug world, about 100x for the filter at 1%, 6-12x for an entity per event). The move is safe; this scenario does not show it helps.
- The earlier navigation runs opened the archetypes file in 0 of 32 runs because none of those tickets asked about speed. Given a speed ticket, agents found the table under the old name too.
- `slow/check.luau` was validated first: the untouched file passes 5 of 8 (the three model and static checks fail) and a reference answer passes 8 of 8.
- While rewriting the table both lune benchmarks were re-run. One figure was stale: the deferred queue now costs about 1.7x a hand-written collect-then-apply and 100-125 ns per queued change, against 1.0-1.6x and 45 ns before the queue gained its pair checks. Corrected in `performance.md` and `feature-deferred.md`.

## Results, 2026-11-11: practices from the original skills, and what agents do unprompted

Three steps. An Opus agent listed the practices the two original skills (`ecs-design`, `jecs`) state that this one does not: 5 missing, 10 partly covered, 12 contradicted, 51 covered. A second Opus agent checked all 27 open entries, with a lune script against the fork's source for each factual claim: 3 true, 7 true with conditions, 6 false, 6 sound judgement, 4 weak judgement, 1 not testable without Studio. Then Sonnet agents at medium effort were given tasks that touch each surviving practice without naming it, with no skill and with the current skill. The tasks are not in the repo.

What agents chose, one run per arm unless a count is given:

| Practice | No skill | Current skill | Taught? |
|---|---|---|---|
| Systems built per world, for tests on fresh worlds | Constructor taking the world | Same | No |
| Instances written late, only for changed entities, first value covered | Recording listener and a late flush | Same | No |
| Derived value read by many systems | Cached, invalidated on change | Same, against the skill's "compute it" | Rule softened |
| Spatial search | Hash grid | Hash grid | No |
| Composition for enemy variants (3 runs per arm) | Components per capability, no type branches, 3 of 3 | 3 of 3 | No |
| Declaring persisted components beside their definition (3 runs per arm) | A wrapper that fills a list, 3 of 3; exact write counts | Same, 3 of 3 | No: nobody tagged ids, and the list is simpler |
| Five rules added to one step function (3 runs per arm) | One cached query per rule, 3 of 3 | 3 of 3 | No |
| Deaths that other modules must hear about | Callbacks run inside the kill | A list later systems read | Already taught |
| `world:cleanup()` in a 200-wave session | Called every wave, unmeasured | Left out, after a 296 s benchmark | Yes |
| A structural change wanted from a remove hook, with no game loop | Added directly in the listener | Read the rule and broke it: "nothing would ever call `apply`" | Yes |

The two that needed teaching, tested on copies of the skill:

| Task | Arm | Runs | Changed the world in the hook, or patched world methods | Queued and exported a flush |
|---|---|---|---|---|
| Release owned objects; tag a unit that loses its shield | Skill at `fbbc2ea` | 5 | 4 | 1 |
| | With the frame-order section | 5 | 0 | 5 |

- Fisher's exact test on 4 of 5 against 0 of 5: p = 0.048. All ten files were read, not only the reports.
- `cleanup()`: three runs with the new sentence left it out and cited the reason, in 60 to 89 s.
- Applying the queue after every system: an empty `apply()` costs about 15 ns, and an `apply()` made while another loop runs made that loop visit 10,001 of 10,000 entities. With the rule written as "the frame's runner applies after every system", 2 of 3 runs wrote that loop and the third applied at the start and end of the step; with the earlier wording 0 of 3 applied between systems.

Corrections to the skill that came from the verification, each with its script in the verifier's notes: `world:range` is no longer "avoid"; "fragmentation is not a reason to avoid a broad query" now stops at about 1,000 archetypes; the dirty-tag row gives the double visit as its reason; `cleanup()` says it forces archetypes to be rebuilt. One addition from a run, checked separately: ids added one at a time leave an archetype per partial combination (300 against 220 for the same 5,000 entities with `bulk_insert`).

Not taken from the original skills: an entity per event, a dirty tag set from a hook, syncing instances from a hook, always preferring `bulk_insert`, children's remove hooks running first, and empty archetypes costing nothing all tested false on this fork. A system-count rule of thumb was judged too weak to teach.

## Tickets

**tickets:** (1) `Game.stun(unit)` / `Game.unstun(unit)`; a stunned unit takes no poison in `Game.step`. (2) No unit's Health may exceed 100, whoever writes it; other modules call `Game.world:set` directly, so enforce it with a hook. (3) At the end of `Game.step` remove every unit with Health <= 0; followers of a removed unit stay alive. (4) `Game.countPoisoned()`, called every frame.

**squads:** (1) `Game.createSquad()`, `Game.join(unit, squad)`, `Game.squadOf(unit)`, `Game.membersOf(squad)`; one squad per unit, joining another leaves the first; hundreds of squads, thousands of units. (2) `Game.disband(squad)` removes the squad and its units; other code may delete a squad directly and its units must still go; `disband` / `membersOf` on a disbanded squad are harmless. (3) A unit with a stance has exactly one of "idle", "guarding", "charging"; `Game.setStance(unit, stance)`; `Game.step(dt)` heals guarding units 1 Health per second; stances change a few times a minute. (4) `Game.countInSquad(squad)`, called every frame.

**upstream:** (1) `Game.freeze(unit)` / `Game.thaw(unit)`; a frozen unit takes no poison; shielded units must still take none. (2) `Game.onBossFollower(callback)`: `callback(unit)` whenever a unit starts following `Game.boss`, not for others. (3) At the end of `Game.step` remove every unit with Health <= 0; followers of a removed unit go with it, also when other code deletes a leader.

**events:** (1) `Game.damage(target, amount)`: many calls per frame, from inside query loops, several per target; nothing changes until `Game.step`, which applies every hit. (2) `Game.onHit(callback)`: `callback(target, amount)` once per applied hit. (3) `Game.takeChangedHealth()`: live units whose Health was written since the last call, each once, new spawns included; others write Health directly; thousands of units, few change. (4) `Game.addItem(unit, item)`: listeners on `world:changed(Inventory)` must be notified per item.

**design:** the brief is `design/BRIEF.md`, handed over as is.

**inherit:** the tickets are `inherit/TICKETS.md`, handed over as is with `inherit/game.luau` as `src/game.luau`. Run `check.luau` under a time limit.

**infer, rival, slow:** the ticket file in each folder, handed over as is with the folder's `src/`.

**review:** "`src/game.luau` ships in 20 minutes. Review it for defects in how it uses JECS. Write findings to `REVIEW.md`: line, what is wrong, what happens at runtime, the fix. Real defects only."
