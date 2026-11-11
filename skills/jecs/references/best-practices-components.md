# Component design

Start from the systems: list what each one reads and writes. Component boundaries follow from that, not from the nouns in the design document.

## Split or combine

| Rule | Because |
|---|---|
| Split when a system needs A but not B | Each query then names exactly what it uses, and entities that lack B still match |
| Combine what is always read and written together (the parts of a position) | Five terms for one concept make every query longer and allow half-set states |
| Separate data that changes every frame from data that rarely changes | Observers and change tracking on the rare part stop firing every frame |
| Optional data gets its own component | Queries select on presence, so no `if` and no visit to entities without it |
| If presence would flip every few frames, keep the component and switch a value | Each flip is a structural change |
| Compute what can be computed (speed from velocity). Store it only when it is costly or read by many systems each frame (a world transform in a hierarchy), with one system that owns the refresh | Every writer of the source would otherwise have to update the copy, and one that forgets leaves it stale |

## Values

- A table value is fine for data one system owns and reads as a unit (waypoints, a stat block).
- In-place mutation of a table fires no `OnChange`: call `world:set` if something listens.
- Make the elements entities instead when they need their own queries, lifetime or links (inventory items that can be dropped, traded, listed per owner): pair each to its holder ([feature-pairs](feature-pairs.md)).
- Roblox instances live in a component, released in `OnRemove` ([feature-hooks](feature-hooks.md)). Leave spatial hierarchy to the instance tree: store the `Model`, do not mirror its parts as entities.

## Tag, value or pair

| Data | Model | Because |
|---|---|---|
| Yes/no fact queries filter on (`Stunned`, `Dead`) | Tag | Selecting by presence is 4-100x faster than a value and an `if` |
| A measurement or payload (`Health`, `Position`) | Data component | |
| Relationship to another entity | Pair or entity in a component: [feature-pairs](feature-pairs.md) | |
| One-of-several state that systems select by and that changes rarely (`Team`, `Stance`) | Exclusive pair | One id per state to query on; switching replaces the old state in one step, so two states at once cannot happen |
| One-of-several state read inside a loop that visits everyone anyway, or switched often (animation state) | Value component | Nothing is saved by filtering, and each pair switch is a structural change costing 4-38x a `set` |

A state that is both selected on and switched often: measure both. The pair wins when few entities match the query; the value wins when most entities switch every frame.

## Components module

Ids, then config, then the world. Hooks and traits are read when an id is first used; set later they apply to some uses and not others.

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
| A tag per state (`Idle`, `Walking`) | Two structural changes per switch; invalid combinations possible | Value component, or exclusive pair if selected on |
| Entity in a component for something that belongs to it | No reverse lookup, no cleanup | Pair |
| `world:component()` for a marker | A column and one of 256 ids | `jecs.tag()` |
