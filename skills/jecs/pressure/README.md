# Pressure tests

How the skill was tested with agents, what happened, and how to run it again after the skill changes. This folder is for whoever maintains the skill; an agent using the skill does not need it.

## The test

An agent gets an existing game module and four tickets under time pressure, once without the skill and once with it. A hidden check then grades the result.

Project layout given to the agent:

```
wally.toml                 names raild3x/jecs
rokit.toml                 lune
Packages/jecs.luau         one line: return require("./_Index/raild3x_jecs@<version>/jecs/src/jecs")
Packages/_Index/raild3x_jecs@<version>/jecs/   src/jecs.luau, CHANGELOG.md, README.md, wally.toml
src/game.luau              game.luau from this folder
```

Tickets, given word for word, after "The playtest starts in 20 minutes ... keep the diff small and do not restructure the file":

1. Stun: add `Game.stun(unit)` and `Game.unstun(unit)`. A stunned unit takes no poison damage in `Game.step`.
2. Health cap: no unit's Health may ever be above 100, whoever writes it. Other modules call `Game.world:set(unit, Game.Health, value)` directly, so enforce it with a hook on Health rather than in `Game.spawn`.
3. Deaths: at the end of `Game.step`, remove every unit whose Health is 0 or less. When a removed unit had followers, the followers stay alive.
4. HUD: add `Game.countPoisoned(): number`, the number of units that have Poison. The HUD calls it every frame.

The prompt does not say where the library is. The with-skill prompt adds only that the skill is installed, and its path. Ask each agent to list the files it opened.

Grading: copy `check.luau` into the project root once the agent has finished and run `lune run check.luau`. It has eight checks: the cap on a first and a later write and on units that existed at load, stun, deaths across 40 archetype layouts, the count, no new query observers after 100 count calls, and no id registered after the world was created. The agent never sees it.

## Results, 2026-11-10

Each cell is one run unless two figures are given. "Hinted" runs were told where the library file was and had it one folder away; "fair" runs used the layout above.

| Round | Model | Without skill | With skill |
|---|---|---|---|
| Hinted | top model | 8/8, 8/8 | 8/8, 8/8 |
| Hinted | Sonnet, medium effort | **7/8** | 8/8 |
| Hinted | Opus, medium effort | 8/8 | 8/8 |
| Fair | Sonnet, medium effort | 8/8 | 8/8 |
| Fair | Opus, medium effort | 8/8 | 8/8 |

- **The one failure:** the Sonnet baseline called `jecs.tag()` after `jecs.world()`. The tag got the id of the first lobby dummy, so stunning a unit attached that dummy as a component, and stunned units lost their stun when the dummy died. Its own tests passed. In the fair round the same model reached for the same call, found the fork's guard while reading the changelog, and used `world:entity()`.
- **Reading the library:** without the skill, agents found the library unprompted and read about 150 of 4,400 lines by search. With the skill, the fair-round agents did not open it. These file lists are the agents' own reports.
- **Conventions:** without the skill every run installed hooks with `world:set` before first use, which works. With it every run used `jecs.meta` before the world.
- **Cost:** on the top model the skill runs used about 20% fewer tokens. On Sonnet and Opus the totals were within 4,000 tokens either way and the skill runs finished 11 to 20 seconds sooner.

An earlier round of four build-from-nothing scenarios (combat, hooks, links, events) on the top model showed no known trap in either arm.

## What this does and does not show

It shows the skill produces the agreed conventions and removes the need to read the library. It shows one case of a silent id collision that the skill prevented. One run per cell is too few to call that a rate, and no run tested `ukendio/jecs`, where the fork's guard does not exist.
