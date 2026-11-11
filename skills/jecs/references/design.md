# Designing with JECS

How to model a game in components, entities and systems, with code for each pattern and the measured cost of the alternatives. The code is the code in [`../verify/examples.luau`](../verify/examples.luau), which runs it.

## The model

An **archetype** is the set of entities that have exactly the same ids. Each archetype stores one column per data component. A query walks the archetypes that match it and reads their columns, which is why iteration is fast. Giving an entity a new id, or taking one away, moves it to another archetype and copies every one of its values: that is a **structural change**, and its cost grows with the number of components on the entity. Writing a new value into a component the entity already has copies nothing.

Two consequences drive every choice below:

- Prefer changing a value over changing an entity's shape.
- Every distinct pair is its own id, so every distinct target of a relation creates new archetypes.

## Components

- **Split by which systems read the data together.** Ask "is there a system that needs A but not B?" If yes, they are two components. If they are always read and written together, such as the parts of one position, they are one. *Why:* a query loads whole columns, and a wide entity makes every structural change dearer.
- **Give data that is sometimes absent its own component** and let queries select on its presence, instead of an optional field checked inside the loop.
- **A table as a value is fine** for data one system owns. Mutating it in place fires no `OnChange`, so call `world:set` again when something listens for changes.
- **Keep Roblox instances in a component and release them in an `OnRemove` hook**, as `Model` is below. If the component can be set again on the same entity, also remember the current instance per entity and release the old one in `OnChange`, which cannot see the value it replaced.
- **State with several values is one value component**, and a system branches on the value. Use an exclusive pair only when a per-frame system must select a small share of thousands of entities (see the cost table).

### The components module

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

## Entities

- **An entity is anything with its own changing state** that systems process: a character, a projectile, a status effect that lasts.
- **Something that lasts one frame is an event**, kept in an array (below).
- **Shared, unchanging data is one table**, referenced from a component, with no entity per copy.
- **Store an entity handle freely, and check it with `world:contains` when read.** A deleted entity's handle stays unequal to its slot's next occupant.

### Links between entities

| The link | Model | Why |
|---|---|---|
| The holder belongs to the target: an item to its owner, a part to its vehicle | A pair on the many side pointing at the few, with a cleanup trait: `pair(OwnedBy, owner)` | The pair gives the reverse lookup `world:query(pair(OwnedBy, owner))` and deletes the holders with the target. |
| The holder merely points at the target: an aim target, a last attacker | The entity stored in a component: `world:set(npc, Target, enemy)` | Retargeting is a plain `set`, and no archetype is created per target. |
| One entity pointing at many | A pair or component on each of the many, pointing back | Pairs on the one side put every target's id in that one entity's archetype. |

"Few" means the number of targets times the number of different holder shapes stays in the hundreds. Past that, store the owner in a component and keep the reverse table and the delete cascade by hand. Build a pair only from a handle just checked with `world:contains`: a pair keeps no generation, so a stale handle links to the slot's new occupant.

A component does not clear itself when its target dies, so the reader treats a dead target as none:

```luau
local targeting = world:query(Target):cached()

local function dropDeadTargets()
	local stale: { jecs.Entity } = {}
	for entity, target in targeting do
		if not world:contains(target) or world:has(target, Dead) then
			table.insert(stale, entity)
		end
	end
	for _, entity in stale do
		world:remove(entity, Target)
	end
end
```

"Who points at me" over many changing targets is a table built from the forward component, on first use in a frame, inside the system that needs it, and dropped at frame end:

```luau
local hunters: { [jecs.Entity]: { jecs.Entity } } = {}
for entity, target in targeting do
	local list = hunters[target]
	if not list then
		list = {}
		hunters[target] = list
	end
	table.insert(list, entity)
end
```

## Systems

A system is a function that runs one query and does one job. JECS has no scheduler: the game calls its systems in a fixed order each frame, and a phase is only a naming convention for a group of them.

- **Create each per-frame query once, at module scope, with `:cached()`.**
- **Put the condition in the query** with `:with` and `:without` where a tag exists for it, so the loop only visits what it will act on.
- **Write values with `world:set`.** Writing a column directly through `query:archetypes()` and `columns_map` skips hooks and signals: keep it for a measured hot loop over a component nothing observes.
- **Keep state in components**, so a system can be removed, reordered or tested alone.
- **Do not yield inside a system.** A yield lets other code change the world in the middle of a loop.
- **Order by data flow:** systems that emit events, then systems that read them, then systems that mark, then the system that deletes, then the one that clears events.

### Changing structure from a loop

Collect, then apply. This works on both libraries:

```luau
local living = world:query(Health):without(Dead):cached()

local function markDead()
	local dying: { jecs.Entity } = {}
	for entity, health in living do
		if health <= 0 then
			table.insert(dying, entity)
		end
	end
	for _, entity in dying do
		world:add(entity, Dead)
	end
end
```

On the fork, queue on `world.deferred` inside the loop and apply after it:

```luau
local doomed = world:query(Dead):cached()

local function despawnDead()
	local deferred = world.deferred
	for entity in doomed do
		deferred:delete(entity)
	end
	deferred:apply()
end
```

`Dead` is a marker tag. Between `markDead` and `despawnDead` the entity is still alive, and every query written `:without(Dead)` already skips it. A queued delete alone would be invisible to those systems. When collecting deletes by hand, check `world:contains` before each one, since a cascade may already have deleted it.

A remove hook or listener that wants a structural change queues it the same way, and the change is made by the next `apply`:

```luau
world:removed(Shield, function(entity, _, deleted)
	if not deleted then
		world.deferred:add(entity, Exposed)
	end
end)
```

### Events

An event is a record in a plain array. Emitters call a helper, readers loop over the array, and one system clears it at the end of the frame:

```luau
type Hit = { target: jecs.Entity, amount: number }
local hits: { Hit } = {}

local function dealDamage(target: jecs.Entity, amount: number)
	table.insert(hits, { target = target, amount = amount })
end

local function applyDamage()
	for _, hit in hits do
		local health = world:get(hit.target, Health)
		if health then
			world:set(hit.target, Health, health - hit.amount) -- already has Health: not structural
		end
	end
end

local function clearEvents()
	table.clear(hits)
end

local function frame()
	applyDamage()
	markDead()
	dropDeadTargets()
	despawnDead()
	clearEvents()
end
```

Two hits on one target in one frame both land, because each is its own record. A "pending damage" component would keep only the last. Use a tag on the target for a fact that is the same however often it is stated (`Dead`), and an entity for something that outlives the frame (a burn that ticks for five seconds).

### Spawning with bulk_insert

```luau
-- data components first, with their values in the same order; tags last
jecs.bulk_insert(world, world:entity(), { Speed, Armor, Stunned }, { 16, 5 })
```

Only for a fresh entity with about eight or more plain components and tags, and only where a measurement shows the gain. Use `world:set` and `world:add` for anything with an exclusive pair, such as `ChildOf`.

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
