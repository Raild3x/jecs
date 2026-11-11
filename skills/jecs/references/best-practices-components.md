# Component design

## Splitting and combining

- **Split by which systems read the data together.** Ask "is there a system that needs A but not B?" If yes, they are two components. If they are always read and written together, such as the parts of one position, they are one. *Why:* a query loads whole columns, and a wide entity makes every structural change dearer.
- **Give data that is sometimes absent its own component** and let queries select on its presence, when it comes and goes rarely. When it toggles every few frames, keep the component on the entity and switch a value, because presence is a structural change.
- **A table as a value is fine** for data one system owns. Mutating it in place fires no `OnChange`, so call `world:set` again when something listens for changes.

## Tag, value or pair

| The data | Model | Why |
|---|---|---|
| A yes/no fact that queries filter on (`Stunned`, `Dead`) | A tag: `jecs.tag()` | No storage, and `:with` / `:without` select on it. |
| One of several states (`"idle"`, `"walking"`, `"attacking"`) | One value component, and a system branches on the value | Changing it is a plain `set`. An exclusive pair costs 4 to 38 times as much per change. |
| One of several states, where a per-frame system must pick out a small share of thousands of entities | An exclusive pair: `pair(Team, Red)` with `jecs.meta(Team, jecs.Exclusive)` | A query on the pair visits only the matching entities: about 100 times faster than testing a value when 1% match. |

Make tags with `jecs.tag()` or `world:entity()`. `world:component()` always makes a data component: it takes a storage column and one of 256 component ids.

## Values that own something

**Keep Roblox instances in a component and release them in an `OnRemove` hook.** If the component can be set again on the same entity, also remember the current instance per entity and release the old one in `OnChange`, which cannot see the value it replaced.

## The components module

Define every id in one module, configure it there, then create the world. Hooks and traits are read once, when an id is first used, so anything configured later is ignored without an error.

```luau
--!strict
local jecs = require(path.to.jecs)
local pair = jecs.pair

local Health = jecs.component<<number>>()
local MoveState = jecs.component<<"idle" | "walking" | "attacking">>()
local Target = jecs.component<<jecs.Entity>>()
local Model = jecs.component<<{ destroyed: boolean }>>()
local Dead = jecs.tag()
local Stunned = jecs.tag()
local OwnedBy = jecs.tag()
local Team = jecs.tag()
local Red, Blue = jecs.tag(), jecs.tag()

jecs.meta(Health, jecs.Name, "Health")
jecs.meta(OwnedBy, pair(jecs.OnDeleteTarget, jecs.Delete))
jecs.meta(Team, jecs.Exclusive)

-- a hook that needs the world closes over a variable that is assigned below
local world: jecs.World
jecs.meta(Model, jecs.OnRemove, function(entity, id)
	-- the value is still readable here; no structural change, nothing that can raise
	local model = world:get(entity, id)
	if model then
		model.destroyed = true
	end
end)

world = jecs.world(true) -- debug world: for development only
```

When the ids and the world live in separate modules, the module that creates the world requires the ids module first. A hook that needs the world then belongs in the world's module, or becomes a `world:removed` listener connected right after the world is created.
