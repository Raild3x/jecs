# Component design

## Split or combine

- Split when a system needs A but not B. Combine what is always read and written together (the parts of a position).
- Separate data that changes every frame from data that rarely changes.
- Optional data gets its own component; queries select on presence. If presence would flip every few frames, keep it and switch a value instead.
- A table value is fine for data one system owns. In-place mutation fires no `OnChange`: call `world:set` if something listens.
- Roblox instances live in a component, released in `OnRemove`: [feature-hooks](feature-hooks.md).

## Tag, value or pair

| Data | Model |
|---|---|
| Yes/no fact queries filter on (`Stunned`, `Dead`) | Tag |
| A measurement or payload (`Health`, `Position`) | Data component |
| Relationship to another entity | Pair: [feature-pairs](feature-pairs.md) |
| One-of-several state queries select on (`Team`, `Activity`) | Exclusive pair |
| One-of-several state rewritten on most entities every frame | Value component. A pair switch is a structural change: 4-38x a `set` |

## Components module

Ids, then config, then the world. Hooks and traits are read once at first use.

```luau
--!strict
local jecs = require(path.to.jecs)
local pair = jecs.pair

local Health = jecs.component<<number>>()
local Model = jecs.component<<Model>>()
local Dead = jecs.tag()
local OwnedBy = jecs.tag()
local Team = jecs.tag()
local Red, Blue = jecs.tag(), jecs.tag()

jecs.meta(Health, jecs.Name, "Health")
jecs.meta(OwnedBy, pair(jecs.OnDeleteTarget, jecs.Delete))
jecs.meta(Team, jecs.Exclusive)

local world = jecs.world(RunService:IsStudio())
```

With ids and world in separate modules, the world module requires the ids module first.

## Mistakes

| Mistake | Result | Instead |
|---|---|---|
| God component | Every system loads all of it; wide entities make structural changes dearer | Split by reader |
| One component per primitive field | Queries of five terms for one concept | Combine what travels together |
| A tag per state (`Idle`, `Walking`) | Two structural changes per switch; invalid combinations possible | Exclusive pair |
| Entity stored in a component for a relationship | No reverse lookup, no cleanup | Pair |
| `world:component()` for a marker | A column and one of 256 ids | `jecs.tag()` |
