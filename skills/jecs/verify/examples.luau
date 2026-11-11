--!strict
-- Runs the patterns the skill teaches, end to end.
-- Copy the project's jecs.luau next to this file, then: lune run examples.luau
local jecs = require("./jecs")
local pair = jecs.pair

local FORK = (jecs :: any).deferred ~= nil

local passed, failed = 0, 0
local function check(pattern: string, holds: any)
	if holds then
		passed += 1
	else
		failed += 1
		print("FAIL  " .. pattern)
	end
end

-- components module: ids, then names, traits and hooks, then the world ----------
type Hit = { target: jecs.Entity, amount: number }

local Health = jecs.component<<number>>()
local Thorns = jecs.component<<number>>()
local Resource = jecs.component<<{ released: boolean }>>()
local Previous = jecs.tag()
local Begin, End = jecs.tag(), jecs.tag()
local InSquad = jecs.tag()
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

-- queries: created once, at module scope ---------------------------------------
local living = world:query(Health):without(Dead):cached()
local doomed = world:query(Dead):cached()
local targeting = world:query(Target):cached()

-- events: a plain array, filled through a helper, swapped out by its consumer ---
local hits: { Hit } = {}
local function dealDamage(target: jecs.Entity, amount: number)
	table.insert(hits, { target = target, amount = amount })
end

-- systems, in the order they run -----------------------------------------------
local function applyDamage()
	local batch = hits
	hits = {} -- hits emitted while draining land here: handled next frame
	for _, hit in batch do
		local health = world:get(hit.target, Health)
		if health then
			-- the entity already has Health, so this set is not structural
			world:set(hit.target, Health, health - hit.amount)
			local thorns = world:get(hit.target, Thorns)
			if thorns then
				dealDamage(hit.target, thorns) -- an event emitted by an event
			end
		end
	end
end

local function markDead()
	local dying: { jecs.Entity } = {}
	for entity, health in living do
		if health <= 0 then
			table.insert(dying, entity)
		end
	end
	-- collect, then apply: works on upstream and on the fork
	for _, entity in dying do
		world:add(entity, Dead)
	end
end

local function dropDeadTargets()
	if FORK then
		local deferred = (world :: any).deferred
		for entity, target in targeting do
			if not world:contains(target) or world:has(target, Dead) then
				deferred:remove(entity, Target)
			end
		end
		deferred:apply()
		return
	end
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

local function despawnDead()
	if FORK then
		-- fork: queue inside the loop, apply after it
		local deferred = (world :: any).deferred
		for entity in doomed do
			deferred:delete(entity)
		end
		deferred:apply()
	else
		local dead: { jecs.Entity } = {}
		for entity in doomed do
			table.insert(dead, entity)
		end
		for _, entity in dead do
			if world:contains(entity) then
				world:delete(entity)
			end
		end
	end
end

local function frame()
	applyDamage()
	markDead()
	dropDeadTargets()
	despawnDead()
end

-- the patterns, exercised ------------------------------------------------------
do
	local victim = world:entity()
	world:set(victim, Health, 100)
	dealDamage(victim, 30)
	dealDamage(victim, 20)
	frame()
	check("events: two hits in one frame both land", world:get(victim, Health) == 50)
	check("events: the queue is empty after the frame", #hits == 0)

	-- an event emitted while draining waits for the next frame, and is not lost
	local thorny = world:entity()
	world:set(thorny, Health, 100)
	world:set(thorny, Thorns, 1)
	dealDamage(thorny, 10)
	frame()
	check("events: a hit emitted during the drain is deferred to the next frame", world:get(thorny, Health) == 90 and #hits == 1)
	frame()
	check("events: ... and lands then", world:get(thorny, Health) == 89)
	world:remove(thorny, Thorns)
	frame()
end
do
	local model = { destroyed = false }
	local npc, sword, hunter = world:entity(), world:entity(), world:entity()
	world:set(npc, Health, 10)
	world:set(npc, Model, model)
	world:add(sword, pair(OwnedBy, npc))
	world:set(hunter, Target, npc)

	dealDamage(npc, 10)
	applyDamage()
	markDead()
	check("marker tag: a dead entity is still alive, and leaves :without(Dead) queries", world:contains(npc) and not living:has(npc))
	dropDeadTargets()
	check("entity reference: a dead target is treated as no target", not world:has(hunter, Target))
	despawnDead()
	check("despawn: the marked entity is deleted after the loop", not world:contains(npc))
	check("owned link: the item is deleted with its owner", not world:contains(sword))
	check("remove hook: the model is released when the entity is deleted", model.destroyed)
end
do
	local npc = world:entity()
	world:set(npc, MoveState, "idle")
	world:set(npc, MoveState, "walking")
	check("state: a value component holds one of several states", world:get(npc, MoveState) == "walking")

	world:add(npc, Stunned)
	local moving = 0
	for _ in world:query(MoveState):without(Stunned) do
		moving += 1
	end
	check("state: a tag is an independent yes/no that queries filter on", moving == 0)

	world:add(npc, pair(Team, Red))
	world:add(npc, pair(Team, Blue))
	check("state: an exclusive pair replaces its previous target", world:target(npc, Team) == Blue and not world:has(npc, pair(Team, Red)))
	local blue = 0
	for _ in world:query(pair(Team, Blue)) do
		blue += 1
	end
	check("state: a query selects one target of an exclusive pair", blue == 1)
end
do
	-- "who points at me": a query on the pair
	local owner, other = world:entity(), world:entity()
	local a, b, c = world:entity(), world:entity(), world:entity()
	world:add(a, pair(OwnedBy, owner))
	world:add(b, pair(OwnedBy, owner))
	world:add(c, pair(OwnedBy, other))
	local owned = 0
	for _ in world:query(pair(OwnedBy, owner)) do
		owned += 1
	end
	check("reverse lookup: a pair query finds the holders of one target", owned == 2)
	check("forward lookup: world:target reads the owner", world:target(a, OwnedBy) == owner)
end
do
	-- hierarchy: a value inherited from the nearest ancestor that has it
	local Faction = world:component<<string>>()
	local function inherited<T>(entity: jecs.Entity, id: jecs.Id<T>): T?
		local current: jecs.Entity? = entity
		while current do
			local value = world:get(current, id)
			if value ~= nil then
				return value
			end
			current = world:parent(current)
		end
		return nil
	end
	local squad, soldier, weapon = world:entity(), world:entity(), world:entity()
	world:set(squad, Faction, "red")
	world:add(soldier, pair(jecs.ChildOf, squad))
	world:add(weapon, pair(jecs.ChildOf, soldier))
	check("hierarchy: a value is found by walking world:parent", inherited(weapon, Faction) == "red" and inherited(squad, Health) == nil)

	-- composite: ChildOf owns the lifetime, a component holds direct handles
	local Parts = world:component<<{ hull: jecs.Entity, motor: jecs.Entity }>>()
	local car, hull, motor = world:entity(), world:entity(), world:entity()
	world:add(hull, pair(jecs.ChildOf, car))
	world:add(motor, pair(jecs.ChildOf, car))
	world:set(car, Parts, { hull = hull, motor = motor })
	local parts = world:get(car, Parts)
	check("composite: parts are reached directly through stored handles", parts ~= nil and parts.motor == motor)
	world:delete(car)
	check("composite: ChildOf deletes the parts with the whole", not world:contains(hull) and not world:contains(motor))
end
do
	local Speed = world:component<<number>>()
	local Armor = world:component<<number>>()
	local e = world:entity()
	-- data components first, with their values in the same order; tags last
	jecs.bulk_insert(world, e, { Speed, Armor, Stunned } :: { any }, { 16, 5 })
	check("bulk_insert: spawns a fresh entity with plain components and tags", world:get(e, Speed) == 16 and world:get(e, Armor) == 5 and world:has(e, Stunned))
end
do
	-- change tracking: a listener records which entities changed, a system drains the set
	local changedHealth: { [jecs.Entity]: true } = {}
	local stop = world:changed(Health, function(entity)
		changedHealth[entity] = true
	end)
	local a, b = world:entity(), world:entity()
	world:set(a, Health, 10) -- the first set is an add, not a change
	world:set(b, Health, 10)
	world:set(a, Health, 9)
	world:set(a, Health, 8)
	local drained = 0
	for entity in changedHealth do
		if world:contains(entity) then
			drained += 1
		end
	end
	table.clear(changedHealth)
	stop()
	check("change tracking: several sets in a frame leave one entry per entity", drained == 1)

	-- change tracking without a listener: compare against the value last handled,
	-- kept in a pair so no extra component is declared per tracked component
	local c = world:entity()
	world:set(c, Health, 5)
	local tracked = world:query(Health, pair(Previous, Health)):cached()
	local untracked = world:query(Health):without(pair(Previous, Health)):cached()
	local redrawn, fresh = 0, {}
	local function showHealth()
		redrawn = 0
		for entity, health, shown in tracked do
			if health ~= shown then
				redrawn += 1
				world:set(entity, pair(Previous, Health), health) -- already present: not structural
			end
		end
		table.clear(fresh)
		for entity in untracked do
			table.insert(fresh, entity)
		end
		for _, entity in fresh do
			world:set(entity, pair(Previous, Health), world:get(entity, Health) :: number)
		end
	end
	showHealth()
	check("change tracking: entities without a previous value are the newly added ones", #fresh >= 3 and world:get(c, pair(Previous, Health)) == 5)
	world:set(c, Health, 4)
	showHealth()
	check("change tracking: comparing with the previous-value pair finds what differs", redrawn == 1 and #fresh == 0 and world:get(c, pair(Previous, Health)) == 4)
	world:remove(c, Health)
	local lost = 0
	for entity in world:query(pair(Previous, Health)):without(Health) do
		lost += if entity == c then 1 else 0
	end
	check("change tracking: a previous value without the component marks a removal", lost == 1)
end
do
	-- grouped work: loop over the targets, query each group
	local Squad = world:entity()
	local Position = world:component<<number>>()
	local alpha, bravo = world:entity(), world:entity()
	world:add(alpha, Squad)
	world:add(bravo, Squad)
	for i = 1, 6 do
		local unit = world:entity()
		world:set(unit, Position, i)
		world:add(unit, pair(InSquad, if i % 2 == 0 then alpha else bravo))
	end
	local squads: { jecs.Entity } = {}
	for squad in world:query(Squad) do
		table.insert(squads, squad)
	end
	local visited, mismatched = 0, 0
	for _, squad in squads do
		for unit in world:query(Position):with(pair(InSquad, squad)) do
			visited += 1
			if world:target(unit, InSquad) ~= squad then
				mismatched += 1
			end
		end
	end
	check("grouping: a loop per target visits every member with its target known", visited == 6 and mismatched == 0)

	-- several values of one type: a tag relation with the component as target
	local beam = world:entity()
	world:set(beam, pair(Begin, Position), 1)
	world:set(beam, pair(End, Position), 9)
	local span = 0
	for _, from, to in world:query(pair(Begin, Position), pair(End, Position)) do
		span += to - from
	end
	check("pairs: pair(tag, component) holds a second value of the component type", span == 8 and world:get(beam, Position) == nil)

	-- column loop: direct reads and writes, no hook or signal
	local heard = 0
	local stop = world:changed(Position, function()
		heard += 1
	end)
	local movers = world:query(Position):cached()
	for _, archetype in movers:archetypes() do
		local entities = archetype.entities
		local positions = archetype.columns_map[Position]
		for row = #entities, 1, -1 do
			positions[row] += 100
		end
	end
	stop()
	local moved = 0
	for _, position in world:query(Position) do
		moved += if position > 100 then 1 else 0
	end
	check("column loop: writes land and no listener hears them", moved == 6 and heard == 0)

	-- first match
	local function firstSquad(): jecs.Entity?
		for squad in world:query(Squad) do
			return squad
		end
		return nil
	end
	check("first match: returning from the loop yields one entity", firstSquad() == alpha or firstSquad() == bravo)
end
do
	-- several worlds: a hook installed per world, before the id is used there
	local function newWorld(): jecs.World
		local w = jecs.world(true)
		w:set(Resource, jecs.OnRemove, function(entity)
			local resource = w:get(entity, Resource)
			if resource then
				resource.released = true
			end
		end)
		return w
	end
	local w1, w2 = newWorld(), newWorld()
	local r1, r2 = { released = false }, { released = false }
	local e1, e2 = w1:entity(), w2:entity()
	w1:set(e1, Resource, r1)
	w2:set(e2, Resource, r2)
	w2:delete(e2)
	check("hooks: a per-world hook acts on its own world only", r2.released and not r1.released)
end
if FORK then
	local deferred = (world :: any).deferred
	local Shield = world:component<<number>>()
	local Exposed = world:entity()
	-- a remove listener must not change structure: it queues the change instead
	world:removed(Shield, function(entity, _, deleted)
		if not deleted then
			deferred:add(entity, Exposed)
		end
	end)
	local e = world:entity()
	world:set(e, Shield, 1)
	world:remove(e, Shield)
	check("deferred: a change queued by a remove listener waits for apply", not world:has(e, Exposed))
	deferred:apply()
	check("deferred: ... and is made by it", world:has(e, Exposed))

	-- a signal on one pair, disconnected when its target dies
	local leader, follower = world:entity(), world:entity()
	local Follows = world:entity()
	local joined = 0
	local disconnect: (() -> ())?
	disconnect = world:added(pair(Follows, leader) :: any, function()
		joined += 1
	end)
	world:added(Dead, function(entity)
		if entity == leader and disconnect then
			disconnect()
			disconnect = nil
		end
	end)
	world:add(follower, pair(Follows, leader))
	world:add(leader, Dead)
	check("pair signal: fires for its pair and is disconnected with its target", joined == 1 and disconnect == nil)
end

print(`{passed} passed, {failed} failed`)
if failed > 0 then
	require("@lune/process").exit(1)
end
