-- Re-checks every JECS behaviour the skill's rules rest on.
-- Copy the project's jecs.luau next to this file, then: lune run facts.luau
-- A FAIL means JECS changed: correct the rule in the skill that cites the fact.
local jecs = require("./jecs")
local pair = jecs.pair

-- The fork (raild3x/jecs) is told apart by an export upstream lacks.
local FORK = (jecs :: any).deferred ~= nil
print(if FORK then "library: raild3x/jecs (fork)" else "library: ukendio/jecs (upstream)")

local passed, failed = 0, 0
local function check(fact: string, holds: any)
	if holds then
		passed += 1
	else
		failed += 1
		print("FAIL  " .. fact)
	end
end
local function raises(fn: () -> ()): boolean
	return not pcall(fn)
end
local function count(iterator: any): number
	local n = 0
	for _ in iterator do
		n += 1
	end
	return n
end

-- Preregistered ids, configured before the first world exists
local PreHealth = jecs.component()
local PreDead = jecs.tag()
local PrePerWorld = jecs.component()
local PreOwnedBy = jecs.tag()
local preAdds = 0
jecs.meta(PreHealth, jecs.Name, "Health")
jecs.meta(PreHealth, jecs.OnAdd, function()
	preAdds += 1
end)
jecs.meta(PreOwnedBy, pair(jecs.OnDeleteTarget, jecs.Delete))

print("ids and registration")
do
	local w = jecs.world()
	local e = w:entity()
	w:set(e, PreHealth, 10)
	check("jecs.meta before the world: the name is set and the hook fires", w:get(PreHealth, jecs.Name) == "Health" and preAdds == 1)
	check("jecs.tag() is a tag, jecs.component() is not", jecs.is_tag(w, PreDead) and not jecs.is_tag(w, PreHealth))

	local owner, item = w:entity(), w:entity()
	w:add(item, pair(PreOwnedBy, owner))
	w:delete(owner)
	check("a cleanup trait given through jecs.meta is honoured", not w:contains(item))

	local Late = jecs.tag()
	jecs.meta(PreDead, jecs.Name, "Dead")
	check("jecs.meta after the world was created does not reach that world", w:get(PreDead, jecs.Name) == nil)
	check("jecs.meta reaches a world created afterwards", jecs.world():get(PreDead, jecs.Name) == "Dead")
	local _ = Late
end
do
	local w = jecs.world()
	local C = w:component()
	local Tag = w:entity()
	check("world:component() is never a tag", not jecs.is_tag(w, C))
	check("world:entity() is a tag", jecs.is_tag(w, Tag))

	local e = w:entity()
	w:add(e, C)
	check("world:add of a data component: has is true, get is nil", w:has(e, C) and w:get(e, C) == nil)

	local e2 = w:entity()
	check("world:set of a value on a tag raises", raises(function()
		w:set(e2, Tag, 1)
	end))
	check("... after the entity already received the tag", w:has(e2, Tag))

	local Dyn = w:entity()
	w:add(Dyn, jecs.Component)
	w:set(e, Dyn, 42)
	check("an entity with the jecs.Component trait holds data", w:get(e, Dyn) == 42 and not jecs.is_tag(w, Dyn))

	local ids = {}
	for i = 1, 5 do
		ids[i] = w:component()
		w:set(e, ids[i], i)
	end
	check("world:has and world:get take four ids", pcall(w.has, w, e, ids[1], ids[2], ids[3], ids[4]) and pcall(w.get, w, e, ids[1], ids[2], ids[3], ids[4]))
	check("world:has and world:get raise on a fifth id", raises(function()
		w:has(e, ids[1], ids[2], ids[3], ids[4], ids[5])
	end) and raises(function()
		w:get(e, ids[1], ids[2], ids[3], ids[4], ids[5])
	end))
	check("world:has with five ids returns false without raising when one of the first four is missing", w:has(e, ids[1], Tag, ids[3], ids[4], ids[5]) == false)
	check("a query takes five terms", count(w:query(ids[1], ids[2], ids[3], ids[4], ids[5])) == 1)
end
do
	local w = jecs.world()
	local n = 0
	local ok = pcall(function()
		for _ = 1, 300 do
			w:component()
			n += 1
		end
	end)
	check("world:component() raises past 256 component ids", not ok and n <= 256)
end
do
	local w = jecs.world()
	local A = w:component()
	local e = w:entity()
	w:delete(e)
	check("a stale handle: contains is false, exists is true", not w:contains(e) and w:exists(e))
	check("a non-debug world ignores operations on a dead handle", pcall(w.set, w, e, A, 1) and w:get(e, A) == nil)
	check("a debug world raises on world:set of a dead handle", raises(function()
		local dw = jecs.world(true)
		local dead = dw:entity()
		dw:delete(dead)
		dw:set(dead, dw:component(), 1)
	end))

	local e2 = w:entity()
	check("a deleted slot is reused first, with the next generation", jecs.ECS_ID(e2) == jecs.ECS_ID(e) and jecs.ECS_GENERATION(e2) == 1 and e2 ~= e)

	local slot = jecs.ECS_ID(e)
	local at16 = jecs.ECS_GENERATION_INC((slot + (2 ^ 16 - 1) * 2 ^ 24) :: any)
	if FORK then
		check("fork: the generation is 24 bits wide", jecs.ECS_GENERATION(at16) == 2 ^ 16)
	else
		check("upstream: the generation wraps after 16 bits", jecs.ECS_GENERATION(at16) == 0)
	end
end
do
	local w = jecs.world()
	local A = w:component()
	local T = w:entity()
	local holder = w:entity()
	w:add(holder, T)
	w:set(T, A, 1)
	w:clear(T)
	check("world:clear(e) removes e's own components and keeps e", w:contains(T) and not w:has(T, A))
	check("world:clear(e) leaves e on the entities that have it", w:has(holder, T))
end
do
	local w = jecs.world()
	w:range(1000, 1002)
	check("world:range(a, b) hands out a + 1 up to b - 1, then raises", jecs.ECS_ID(w:entity()) == 1001 and raises(function()
		w:entity()
	end))

	local w2 = jecs.world()
	local C = w2:component()
	local live = w2:entity()
	w2:set(live, C, "old")
	local claimed = w2:entity(jecs.ECS_GENERATION_INC(live) :: any)
	check("world:entity(id) can kill a live entity and hand its components to the new one", not w2:contains(live) and w2:get(claimed, C) == "old")
end

print("queries")
do
	local w = jecs.world()
	local A = w:component()
	local T1, T2 = w:entity(), w:entity()
	local e1, e2, e3 = w:entity(), w:entity(), w:entity()
	w:set(e1, A, 1)
	w:add(e1, T1)
	w:set(e2, A, 1)
	w:add(e2, T1)
	w:add(e2, T2)
	w:set(e3, A, 1)
	w:add(e3, T2)
	check(":with(T1, T2) requires both", count(w:query(A):with(T1, T2)) == 1)
	check(":without(T1, T2) excludes both", count(w:query(A):without(T1, T2)) == 0)
	if FORK then
		check("fork: chained :with(T1):with(T2) extends the filter", count(w:query(A):with(T1):with(T2)) == 1)
	else
		check("upstream: chained :with(T1):with(T2) keeps only the last call", count(w:query(A):with(T1):with(T2)) == 2)
	end
	local e4 = w:entity()
	w:set(e4, A, 1)
	check(":without(T1):without(T2) chained: both apply on the fork, only the last on upstream", count(w:query(A):without(T1):without(T2)) == (if FORK then 1 else 2))
end
do
	local w = jecs.world()
	local A, B = w:component(), w:component()
	for i = 1, 3 do
		w:set(w:entity(), A, i)
	end
	local q = w:query(A)
	check("an uncached query stored in a variable yields nothing the second time", count(q) == 3 and count(q) == 0)

	local cq = w:query(A):cached()
	check("a cached query can be iterated again", count(cq) == 3 and count(cq) == 3)
	local e = w:entity()
	w:set(e, A, 1)
	w:set(e, B, 1)
	check("a cached query sees an archetype created after it", count(cq) == 4)

	local outer = 0
	for _ in cq do
		outer += 1
		for _ in cq do
		end
	end
	check("iterating a query inside its own loop ends the outer loop early", outer < 4)

	local creates = (w :: any).observable[jecs.ArchetypeCreate][A]
	local deletes = (w :: any).observable[jecs.ArchetypeDelete][A]
	local c0, d0 = #creates, #deletes
	local extra = w:query(A):cached()
	check("each :cached() call registers two observers", #creates == c0 + 1 and #deletes == d0 + 1)
	extra:fini()
	check(":fini() removes them", #creates == c0 and #deletes == d0)
end
do
	local w = jecs.world()
	local A, B = w:component(), w:component()
	local e = w:entity()
	w:set(e, A, 1)
	w:set(e, B, 1)
	local empties = 0
	for _, archetype in w:query(A):cached():archetypes() do
		if #archetype.entities == 0 then
			empties += 1
		end
	end
	check("query:archetypes() includes empty archetypes", empties == 1)
end
do
	local w = jecs.world()
	local Likes = w:entity()
	local e, a, b = w:entity(), w:entity(), w:entity()
	w:add(e, pair(Likes, a))
	w:add(e, pair(Likes, b))
	check("a wildcard query yields one row per entity", count(w:query(pair(Likes, jecs.Wildcard))) == 1)
	check("world:target is zero-based", w:target(e, Likes, 0) == a and w:target(e, Likes, 1) == b and w:target(e, Likes, 2) == nil)
	check("world:targets iterates every target", count(w:targets(e, Likes)) == 2)
	check("world:has accepts a wildcard pair on either side", w:has(e, pair(Likes, jecs.Wildcard)) and w:has(e, pair(jecs.Wildcard, a)))

	local function archetypes(): number
		local n = 0
		for _ in (w :: any).archetypes do
			n += 1
		end
		return n
	end
	local before = archetypes()
	w:delete(a)
	check("deleting a pair target destroys the archetypes that held the pair", archetypes() < before)
end
do
	-- Deleting only the entity being visited skips live entities when it is a pair target.
	local function missed(cached: boolean, unrelated: number): boolean
		local w = jecs.world()
		local Health = w:component()
		local Follows = w:entity()
		for _ = 1, unrelated do
			w:add(w:entity(), w:entity())
		end
		local leader = w:entity()
		w:set(leader, Health, 0)
		local others = {}
		for i = 1, 3 do
			others[i] = w:entity()
			w:set(others[i], Health, 10)
			if i < 3 then
				w:add(others[i], pair(Follows, leader))
			end
		end
		local q: any = w:query(Health)
		if cached then
			q = q:cached()
		end
		local seen = {}
		for e, health in q do
			seen[e] = true
			if health <= 0 then
				w:delete(e)
			end
		end
		for _, e in others do
			if not seen[e] then
				return true
			end
		end
		return false
	end
	for _, cached in { false, true } do
		local bad = 0
		for unrelated = 0, 40 do
			if missed(cached, unrelated) then
				bad += 1
			end
		end
		check(`deleting the visited entity in a {if cached then "cached" else "uncached"} query loop skips a live entity in some archetype layouts`, bad > 0)
	end
end
do
	local w = jecs.world()
	local A, B = w:component(), w:component()
	for i = 1, 10 do
		local e = w:entity()
		w:set(e, A, i)
		if i <= 5 then
			w:set(e, B, i)
		end
	end
	local visits = 0
	for e in w:query(A) do
		visits += 1
		w:remove(e, B)
	end
	check("a structural change to the visited entity makes the loop visit entities twice", visits > 10)

	local Tag = w:entity()
	local cq = w:query(A):cached()
	visits = 0
	for e in cq do
		visits += 1
		if visits > 100 then
			break
		end
		w:add(e, Tag)
	end
	check("adding a tag to the visited entity of a cached query visits every entity twice", visits == 20)
end

print("pairs and traits")
do
	local w = jecs.world()
	local Owns = w:component()
	local Likes, Begin = w:entity(), w:entity()
	local Transform = w:component()
	local bob, car = w:entity(), w:entity()
	w:set(bob, pair(Owns, car), 2024)
	w:set(bob, pair(Begin, Transform), "cf0")
	check("pair(dataRelation, entity) holds a value", w:get(bob, pair(Owns, car)) == 2024)
	check("pair(tagRelation, dataComponent) holds a value", w:get(bob, pair(Begin, Transform)) == "cf0")
	check("pair(tagRelation, entity) is a tag", jecs.is_tag(w, pair(Likes, car)) and raises(function()
		w:set(bob, pair(Likes, car), 1)
	end))
end
do
	local w = jecs.world(true)
	local R = w:entity()
	local holder, stale = w:entity(), w:entity()
	w:delete(stale)
	local newcomer = w:entity()
	check("a pair drops the generation of its ids", pair(R, stale) == pair(R, newcomer))
	local ok = pcall(function()
		w:add(holder, pair(R, stale))
	end)
	check("a pair built from a stale handle links to the slot's new occupant, even in a debug world", ok and w:target(holder, R) == newcomer)

	for _, debug in { false, true } do
		local w2 = jecs.world(debug)
		local R2 = w2:entity()
		local h2, dead = w2:entity(), w2:entity()
		w2:delete(dead)
		check(`a pair built from a dead handle raises while its slot is free (debug world: {debug})`, raises(function()
			w2:add(h2, pair(R2, dead))
		end))
	end
end
do
	local w = jecs.world()
	local p1, p2, child, grandchild = w:entity(), w:entity(), w:entity(), w:entity()
	w:add(child, pair(jecs.ChildOf, p1))
	w:add(child, pair(jecs.ChildOf, p2))
	check("ChildOf is exclusive", w:parent(child) == p2 and count(w:targets(child, jecs.ChildOf)) == 1)
	w:add(grandchild, pair(jecs.ChildOf, child))
	w:delete(p2)
	check("deleting a parent deletes its descendants", not w:contains(child) and not w:contains(grandchild))

	local Likes = w:entity()
	local holder, target = w:entity(), w:entity()
	w:add(holder, pair(Likes, target))
	w:delete(target)
	check("with no trait, deleting a target removes the pair and keeps the holder", w:contains(holder) and not w:has(holder, pair(Likes, jecs.Wildcard)))
end
do
	local w = jecs.world()
	local R = w:entity()
	local a, b, h = w:entity(), w:entity(), w:entity()
	w:add(h, pair(R, a))
	w:add(R, jecs.Exclusive)
	w:add(h, pair(R, b))
	check("Exclusive added after the relation's first use is ignored", count(w:targets(h, R)) == 2)

	local R2 = w:entity()
	local t, holder = w:entity(), w:entity()
	w:add(holder, pair(R2, t))
	w:add(R2, pair(jecs.OnDeleteTarget, jecs.Delete))
	w:delete(t)
	check("a cleanup trait added after the pair's first use is ignored", w:contains(holder))

	local A = w:component()
	w:set(w:entity(), A, 1)
	local fired = 0
	w:set(A, jecs.OnAdd, function()
		fired += 1
	end)
	w:set(w:entity(), A, 1)
	check("a hook set after the component's first use is ignored", fired == 0)

	if FORK then
		local dw = jecs.world(true)
		local DR = dw:entity()
		local DA = dw:component()
		dw:add(dw:entity(), pair(DR, dw:entity()))
		dw:set(dw:entity(), DA, 1)
		check("fork: a debug world raises on a trait or hook configured after first use", raises(function()
			dw:add(DR, jecs.Exclusive)
		end) and raises(function()
			dw:set(DA, jecs.OnAdd, function() end)
		end))
	end
end
do
	local w = jecs.world()
	local M = w:component()
	local order, flags = {}, {}
	w:set(M, jecs.OnRemove, function(e, _, deleted)
		table.insert(order, w:get(e, M))
		table.insert(flags, deleted)
	end)
	local parent, child = w:entity(), w:entity()
	w:set(parent, M, "parent")
	w:set(child, M, "child")
	w:add(child, pair(jecs.ChildOf, parent))
	w:delete(parent)
	check("on a cascade delete the parent's remove callback runs before the child's", order[1] == "parent" and order[2] == "child")
	check("the deleted flag is true for an entity that a cascade deletes", flags[1] == true and flags[2] == true)
end

print("hooks and signals")
do
	local w = jecs.world()
	local hook, signal = 0, 0
	local A = w:component()
	w:set(A, jecs.OnAdd, function()
		hook += 1
	end)
	w:added(A, function()
		signal += 1
	end)
	w:set(w:entity(), A, 1)
	check("a hook, then a signal: both fire", hook == 1 and signal == 1)

	local B = w:component()
	hook, signal = 0, 0
	w:added(B, function()
		signal += 1
	end)
	w:set(B, jecs.OnAdd, function()
		hook += 1
	end)
	w:set(w:entity(), B, 1)
	check("a signal, then a raw hook on an unused component: the signal goes dead", hook == 1 and signal == 0)

	local C = w:component()
	hook, signal = 0, 0
	w:set(w:entity(), C, 1)
	w:added(C, function()
		signal += 1
	end)
	w:set(C, jecs.OnAdd, function()
		hook += 1
	end)
	w:set(w:entity(), C, 1)
	check("a signal, then a raw hook on a used component: the hook is ignored", hook == 0 and signal == 1)

	local D = w:component()
	signal = 0
	w:set(w:entity(), D, 1)
	w:added(D, function()
		signal += 1
	end)
	w:set(w:entity(), D, 1)
	check("a signal connected after the component's first use fires", signal == 1)
end
do
	local w = jecs.world()
	local A = w:component()
	local changes = 0
	local seen = {}
	w:set(A, jecs.OnChange, function()
		changes += 1
	end)
	w:set(A, jecs.OnRemove, function(e, _, deleted)
		table.insert(seen, { value = w:get(e, A), deleted = deleted })
	end)
	local e = w:entity()
	w:set(e, A, 5)
	w:set(e, A, 5)
	check("OnChange fires when the new value equals the old one", changes == 1)
	w:remove(e, A)
	w:set(e, A, 7)
	w:delete(e)
	check("inside a remove callback the value is still readable", seen[1].value == 5 and seen[2].value == 7)
	check("the third argument is true only when the entity is being deleted", not seen[1].deleted and seen[2].deleted == true)

	local e3 = w:entity()
	w:set(e3, A, 1)
	w:clear(e3)
	check("world:clear passes no deleted flag to remove callbacks", seen[3].value == 1 and not seen[3].deleted)
	w:delete(e)
	check("world:delete of a dead handle does nothing", #seen == 3)

	local V = w:component()
	local during
	w:set(V, jecs.OnChange, function(entity)
		during = w:get(entity, V)
	end)
	w:set(e3, V, "old")
	w:set(e3, V, "new")
	check("OnChange runs after the new value is stored, so the old value is gone", during == "new")

	local T = w:component()
	local tableChanges = 0
	w:set(T, jecs.OnChange, function()
		tableChanges += 1
	end)
	local e2 = w:entity()
	w:set(e2, T, { hp = 1 })
	w:get(e2, T).hp = 2
	check("mutating a table value in place does not fire OnChange", tableChanges == 0)
end
do
	local w = jecs.world()
	local G = w:component()
	local second = 0
	w:added(G, function()
		error("boom")
	end)
	w:added(G, function()
		second += 1
	end)
	local e = w:entity()
	local ok = pcall(function()
		w:set(e, G, 1)
	end)
	check("a listener that raises aborts world:set after the value was written", not ok and w:get(e, G) == 1 and second == 0)

	local R = w:component()
	w:removed(R, function()
		error("boom")
	end)
	local e2 = w:entity()
	w:set(e2, R, 1)
	check("a remove listener that raises aborts world:delete and the entity stays alive", raises(function()
		w:delete(e2)
	end) and w:contains(e2))
end
do
	-- a hook that corrects the value it was given
	local w = jecs.world()
	local Health = w:component()
	local calls = {}
	local storedOnAdd
	w:set(Health, jecs.OnAdd, function(e, _, value)
		storedOnAdd = w:get(e, Health)
		if value > 100 then
			w:set(e, Health, 100)
		end
	end)
	w:set(Health, jecs.OnChange, function(e, _, value)
		table.insert(calls, "hook " .. value)
		if value > 100 then
			w:set(e, Health, 100)
		end
	end)
	w:changed(Health, function(_, _, value)
		table.insert(calls, "listener " .. value)
	end)
	local e = w:entity()
	w:set(e, Health, 300)
	check("the value is stored before OnAdd runs, and a hook can correct it with world:set", storedOnAdd == 300 and w:get(e, Health) == 100)
	table.clear(calls)
	w:set(e, Health, 300)
	check("a hook installed first runs before the signal listeners", calls[1] == "hook 300")
	check("after a hook corrects the value, listeners receive the correction first and the original last", w:get(e, Health) == 100 and calls[3] == "listener 100" and calls[4] == "listener 300")
end
do
	local dw = jecs.world(true)
	local dead = dw:entity()
	dw:delete(dead)
	local raised = raises(function()
		dw:delete(dead)
	end)
	if FORK then
		check("fork: a debug world raises on world:delete of a dead handle", raised)
	else
		check("upstream: a debug world ignores world:delete of a dead handle", not raised)
	end

	local w = jecs.world()
	local A, B = w:component(), w:component()
	local es = {}
	for i = 1, 6 do
		es[i] = w:entity()
		w:set(es[i], A, i)
		if i > 3 then
			w:set(es[i], B, i)
		end
	end
	w:delete(es[1])
	w:delete(es[5])
	local cq = w:query(A):cached()
	local total = 0
	for _, archetype in cq:archetypes() do
		total += #archetype.entities
	end
	check("summing #archetype.entities over a cached query counts its entities", total == 4 and count(cq) == 4)
end
if FORK then
	local w = jecs.world(true)
	local H = w:component()
	local T = w:entity()
	w:set(H, jecs.OnRemove, function(e)
		w:add(e, T)
	end)
	local e = w:entity()
	w:set(e, H, 1)
	check("fork: a debug world raises on a structural change inside OnRemove during world:delete", raises(function()
		w:delete(e)
	end))
end
do
	local w = jecs.world()
	local Likes = w:entity()
	local alice, bob, e = w:entity(), w:entity(), w:entity()
	local fired = 0
	local ok = pcall(function()
		w:added(pair(Likes, alice), function()
			fired += 1
		end)
	end)
	w:add(e, pair(Likes, bob))
	w:add(e, pair(Likes, alice))
	if FORK then
		check("fork: a signal on a pair id fires for that pair only", ok and fired == 1)
		local removed = 0
		w:removed(pair(Likes, alice), function()
			removed += 1
		end)
		w:delete(alice)
		check("fork: a pair's removed listener runs for the removal that deleting its target causes", removed == 1)
		local newcomer = w:entity()
		w:add(e, pair(Likes, newcomer))
		check("fork: it stops matching once another entity reuses the target's slot", jecs.ECS_ID(newcomer) == jecs.ECS_ID(alice) and fired == 1)
	else
		check("upstream: an added signal on a pair id never fires", ok and fired == 0)
		local removedFresh = 0
		w:removed(pair(Likes, bob), function()
			removedFresh += 1
		end)
		local carol = w:entity()
		local removedLate = 0
		w:removed(pair(Likes, carol), function()
			removedLate += 1
		end)
		w:add(e, pair(Likes, carol))
		w:remove(e, pair(Likes, carol))
		w:remove(e, pair(Likes, bob))
		check("upstream: a removed signal on a pair id fires only if the pair existed when it was connected", removedFresh == 1 and removedLate == 0)
	end
end

print("api reference")
do
	local w = jecs.world()
	local A = w:component()
	local Tag = w:entity()
	local a, b = w:entity(), w:entity()
	local slotB = jecs.ECS_ID(b)
	w:delete(a)
	w:delete(b)
	check("world:entity() reuses the most recently freed slot", jecs.ECS_ID(w:entity()) == slotB)

	local e = w:entity()
	local adds, changes = {}, 0
	w:added(A, function(_, _, value)
		table.insert(adds, if value == nil then "nil" else value)
	end)
	w:changed(A, function()
		changes += 1
	end)
	w:set(e, A, 5)
	check("the first set runs the add callbacks with the value, and no change callback", adds[1] == 5 and changes == 0)
	w:set(e, A, 6)
	check("a later set runs only the change callbacks", #adds == 1 and changes == 1)
	w:add(e, A)
	check("world:add of an id the entity has does nothing", #adds == 1 and w:get(e, A) == 6)
	w:add(w:entity(), A)
	check("world:add passes nil to the add callbacks", adds[2] == "nil")

	w:add(e, Tag)
	check("world:get of a tag is nil", w:get(e, Tag) == nil and w:has(e, Tag))
	local tagValue: any = "unset"
	for _, value in w:query(Tag) do
		tagValue = value
	end
	check("a tag term in a query yields nil", tagValue == nil)
	w:delete(Tag)
	check("deleting an id removes it from the entities that have it", w:contains(e) and not w:has(e, Tag))

	local dead = w:entity()
	w:delete(dead)
	check("world:get and world:has on a dead entity return nil and false", w:get(dead, A) == nil and w:has(dead, A) == false)
	local dw = jecs.world(true)
	local DA, DT = dw:component(), dw:entity()
	local ddead = dw:entity()
	dw:delete(ddead)
	check("... in a debug world too", pcall(function()
		assert(dw:get(ddead, DA) == nil and dw:has(ddead, DA) == false)
	end))
	check("a debug world raises on world:add and world:remove of a dead entity", raises(function()
		dw:add(ddead, DT)
	end) and raises(function()
		dw:remove(ddead, DT)
	end))
	local dlive, dtarget = dw:entity(), dw:entity()
	dw:add(dlive, pair(DT, dtarget))
	check("a debug world raises on adding a dead entity as an id, and on removing a wildcard pair", raises(function()
		dw:add(dlive, ddead)
	end) and raises(function()
		dw:remove(dlive, pair(DT, jecs.Wildcard))
	end))

	local Time = w:component()
	w:set(Time, Time, 12.5)
	check("a singleton is a component set on its own id", w:get(Time, Time) == 12.5)

	local disconnect = w:removed(A, function() end)
	disconnect()
	check("a disconnect function raises when called twice", raises(disconnect))
end
do
	local w = jecs.world()
	local A = w:component()
	local Likes = w:entity()
	local alice, bob, car = w:entity(), w:entity(), w:entity()
	w:set(bob, A, 1)
	w:add(bob, pair(Likes, alice))
	w:add(car, pair(jecs.ChildOf, alice))

	local cq = w:query(A):cached()
	check("a cached query has no :with or :without", (cq :: any).with == nil and (cq :: any).without == nil)
	check("query:has tells whether an entity matches", cq:has(bob) and not cq:has(car))
	local archetype = cq:archetypes()[1]
	check("an archetype exposes entities and columns_map", archetype.entities[1] == bob and archetype.columns_map[A][1] == 1)
	check("world:each iterates the entities that have one id", count(w:each(A)) == 1)
	check("world:children iterates the entities with a ChildOf pair", count(w:children(alice)) == 1 and w:parent(car) == alice)
	check("a query on pair(Wildcard, target) finds every pair that targets it", count(w:query(pair(jecs.Wildcard, alice))) == 2)

	check("query:has works on an uncached query", w:query(A):has(bob) and not w:query(A):has(car))
	local Owns = w:component()
	w:set(bob, pair(Owns, car), 7)
	local yielded
	for _, value in w:query(pair(Owns, car)) do
		yielded = value
	end
	check("a pair term yields the pair's value", yielded == 7)

	local E = w:component()
	local lone = w:entity()
	w:set(lone, A, 1)
	w:set(lone, E, 1)
	w:remove(lone, E)
	local before = #w:query(E):cached():archetypes()
	w:cleanup()
	check("world:cleanup removes empty archetypes and cached queries stay correct", before == 1 and #w:query(E):cached():archetypes() == 0 and count(cq) == 2)

	local Sig = w:component()
	w:added(Sig, function() end)()
	check("a signal's dispatcher stays installed after its last listener disconnects", w:get(Sig, jecs.OnAdd) ~= nil)

	local id = pair(Likes, alice)
	check("pair_first, pair_second and IS_PAIR take a pair id apart", jecs.IS_PAIR(id) and jecs.pair_first(w, id) == Likes and jecs.pair_second(w, id) == alice)

	local got
	w:added(Likes, function(_, pairId)
		got = pairId
	end)
	w:add(car, pair(Likes, bob))
	check("a signal on a relation runs for its pairs and receives the pair id", got == pair(Likes, bob))

	local Temp = w:entity()
	w:add(Temp, pair(jecs.OnDelete, jecs.Delete))
	local holder = w:entity()
	w:add(holder, Temp)
	w:delete(Temp)
	check("(OnDelete, Delete) on an id deletes the entities that have it", not w:contains(holder))
end
do
	local dw = jecs.world(true)
	local H = dw:component()
	local T = dw:entity()
	dw:set(H, jecs.OnRemove, function(e)
		dw:add(e, T)
	end)
	local parent, child = dw:entity(), dw:entity()
	dw:set(child, H, 1)
	dw:add(child, pair(jecs.ChildOf, parent))
	check("a debug world raises on a structural change inside OnRemove during a cascaded delete", raises(function()
		dw:delete(parent)
	end))
end
if FORK then
	local dw = jecs.world(true)
	local A = dw:component()
	dw:added(A, function() end)
	check("fork: a debug world raises on a raw hook set over signal listeners", raises(function()
		dw:set(A, jecs.OnAdd, function() end)
	end))
end

print("bulk_insert")
do
	local w = jecs.world(true)
	local A, B = w:component(), w:component()
	local hooked = 0
	w:set(A, jecs.OnAdd, function()
		hooked += 1
	end)
	jecs.bulk_insert(w, w:entity(), { A }, { 1 })
	check("bulk_insert runs hooks", hooked == 1)
	local p1, p2, child = w:entity(), w:entity(), w:entity()
	w:add(child, pair(jecs.ChildOf, p1))
	jecs.bulk_insert(w, child, { pair(jecs.ChildOf, p2) }, {})
	check("bulk_insert bypasses Exclusive: the entity has two parents", count(w:targets(child, jecs.ChildOf)) == 2)

	local e = w:entity()
	local ok = pcall(function()
		jecs.bulk_insert(w, e, { A, B }, { 1 })
	end)
	check("bulk_insert is silent when given fewer values than ids", ok and w:has(e, B) and w:get(e, B) == nil)

	local dead = w:entity()
	w:delete(dead)
	check("bulk_insert skips the debug world's dead-entity check", pcall(function()
		jecs.bulk_insert(w, dead, { A }, { 1 })
	end))
end

if FORK then
	print("deferred changes")
	local w = jecs.world()
	local A = w:component()
	local T = w:entity()
	local d = (w :: any).deferred
	local e, gone = w:entity(), w:entity()
	d:set(e, A, 1)
	d:add(e, T)
	d:set(gone, A, 1)
	d:delete(gone)
	check("fork: a queued change is not visible before apply", not w:has(e, A) and w:contains(gone))
	w:delete(gone)
	local newcomer = w:entity()
	d:apply()
	check("fork: apply makes the queued changes", w:get(e, A) == 1 and w:has(e, T))
	check("fork: a change whose entity died is skipped, and never reaches the slot's new occupant", w:contains(newcomer) and not w:has(newcomer, A))

	local order = {}
	w:added(T, function(entity)
		d:set(entity, A, 2)
	end)
	w:changed(A, function()
		table.insert(order, "A")
	end)
	local B = w:component()
	w:added(B, function()
		table.insert(order, "B")
	end)
	local e2 = w:entity()
	w:set(e2, A, 1)
	d:add(e2, T)
	d:set(e2, B, 1)
	d:apply()
	check("fork: a change queued by a listener during apply runs before the next queued change", order[1] == "A" and order[2] == "B")

	local private = (jecs :: any).deferred(w)
	private:set(e2, B, 5)
	d:apply()
	check("fork: jecs.deferred(world) is a separate queue", w:get(e2, B) == 1)
	private:apply()
	check("fork: ... applied on its own", w:get(e2, B) == 5)

	local C = w:component()
	local value = { hp = 1 }
	d:set(e2, C, value)
	value.hp = 2
	d:apply()
	check("fork: a queued table value is captured by reference", w:get(e2, C).hp == 2)

	local parent, child = w:entity(), w:entity()
	w:add(child, pair(jecs.ChildOf, parent))
	d:delete(parent)
	d:set(child, C, value)
	d:delete(child)
	check("fork: apply skips an entity that a cascade earlier in the same apply deleted", pcall(d.apply, d) and not w:contains(child))

	local dw = jecs.world(true)
	local DTag = dw:entity()
	dw.deferred:set(dw:entity(), DTag, 1)
	check("fork: apply runs a debug world's checks", raises(function()
		dw.deferred:apply()
	end))

	local Loop = w:component()
	local rounds = 0
	w:changed(Loop, function(entity)
		rounds += 1
		d:set(entity, Loop, rounds)
	end)
	local looper = w:entity()
	w:set(looper, Loop, 0)
	d:set(looper, Loop, 1)
	check("fork: a listener that queues the change that invokes it raises instead of hanging", raises(function()
		d:apply()
	end) and rounds > 1)
end

print("fragmentation")
do
	local w = jecs.world()
	local Pos, X1, X2 = w:component(), w:component(), w:component()
	local InCell = w:entity()
	local cells = {}
	for i = 1, 100 do
		cells[i] = w:entity()
	end
	local before = #w.archetypes
	for i = 1, 100 do
		for _, shape in { {}, { X1 }, { X2 }, { X1, X2 } } do
			local e = w:entity()
			w:set(e, Pos, i)
			for _, id in shape do
				w:set(e, id, 0)
			end
			w:add(e, pair(InCell, cells[i]))
		end
	end
	local function walked(q): number
		local n = 0
		for _, a in q:archetypes() do
			if #a.entities > 0 then
				n += 1
			end
		end
		return n
	end
	check("100 targets across 4 holder shapes create at least 400 archetypes", #w.archetypes - before >= 400)
	check("a query naming one target walks only the archetypes of that target", walked(w:query(Pos):with(pair(InCell, cells[42])):cached()) == 4)
	check("a wildcard query walks one archetype per target per shape", walked(w:query(Pos):with(pair(InCell, jecs.Wildcard)):cached()) == 400)
	check("a query on the plain component walks them all too", walked(w:query(Pos):cached()) == 400)

	local onOwner, onItem = jecs.world(), jecs.world()
	local startOwner, startItem = #onOwner.archetypes, #onItem.archetypes
	local R1, R2 = onOwner:entity(), onItem:entity()
	for _ = 1, 10 do
		local owner = onOwner:entity()
		for _ = 1, 5 do
			onOwner:add(owner, pair(R1, onOwner:entity()))
		end
		local owner2 = onItem:entity()
		for _ = 1, 5 do
			onItem:add(onItem:entity(), pair(R2, owner2))
		end
	end
	check("pairs on the owner: every owner passes through an archetype per item", #onOwner.archetypes - startOwner == 50)
	check("pairs on the items: one archetype per owner", #onItem.archetypes - startItem == 10)
end

print("removal, early exit, bulk")
do
	local w3 = jecs.world()
	local Data, Rel = w3:component(), w3:entity()
	local holder, t1, t2 = w3:entity(), w3:entity(), w3:entity()
	w3:set(holder, Data, 7)
	w3:add(holder, pair(Rel, t1))
	w3:add(holder, pair(Rel, t2))
	local held = {}
	for target in w3:targets(holder, Rel) do
		table.insert(held, target)
	end
	for _, target in held do
		w3:remove(holder, pair(Rel, target))
	end
	check("removing each collected target clears a relation and keeps the data", not w3:has(holder, pair(Rel, jecs.Wildcard)) and w3:get(holder, Data) == 7)
	local dbg = jecs.world(true)
	local dh, dt = dbg:entity(), dbg:entity()
	local DRel = dbg:entity()
	dbg:add(dh, pair(DRel, dt))
	check("debug world: removing a wildcard pair raises", raises(function()
		dbg:remove(dh, pair(DRel, jecs.Wildcard))
	end))
	local w4 = jecs.world()
	local D4, R4 = w4:component(), w4:entity()
	local h4, t4 = w4:entity(), w4:entity()
	w4:set(h4, D4, 7)
	w4:add(h4, pair(R4, t4))
	w4:remove(h4, pair(R4, jecs.Wildcard))
	check("normal world: removing a wildcard pair leaves the pair and loses the data", w4:has(h4, pair(R4, t4)) and w4:get(h4, D4) == nil)

	local w5 = jecs.world()
	local C5 = w5:component()
	for i = 1, 5 do
		w5:set(w5:entity(), C5, i)
	end
	local q5 = w5:query(C5):cached()
	for _ in q5 do
		break
	end
	check("a cached query iterated again after an early break yields every entity", count(q5) == 5)
	local bulkWorld = jecs.world()
	local B1, B2, B3 = bulkWorld:component(), bulkWorld:component(), bulkWorld:component()
	local startBulk = #bulkWorld.archetypes
	jecs.bulk_insert(bulkWorld, bulkWorld:entity(), { B1, B2, B3 }, { 1, 2, 3 })
	check("bulk_insert creates one archetype where three sets create three", #bulkWorld.archetypes - startBulk == 1)
end

print("review findings")
do
	local w = jecs.world()
	local Tag, Data, Rel = w:entity(), w:component(), w:entity()

	-- world:set on a tag raises only after the tag was added
	local e = w:entity()
	local added = 0
	w:added(Tag, function()
		added += 1
	end)
	check("world:set on a tag raises after the tag is already added, with no added signal", raises(function()
		w:set(e, Tag, 1)
	end) and w:has(e, Tag) and added == 0)

	-- pair() is arithmetic: only using the pair can raise
	local dead = w:entity()
	w:delete(dead)
	local stalePair
	check("pair() of a dead handle does not raise; adding it does", not raises(function()
		stalePair = pair(Rel, dead)
	end) and raises(function()
		w:add(e, stalePair)
	end))

	-- a stored uncached query resumes where it stopped
	for i = 1, 3 do
		w:set(w:entity(), Data, i)
	end
	local stored = w:query(Data)
	for _ in stored do
		break
	end
	check("a stored uncached query yields the remainder after a break", count(stored) == 2)
	check("... and nothing after a full pass", count(stored) == 0)

	-- a cleanup trait set late applies to pairs with new targets only
	local Owned = w:entity()
	local oldTarget, newTarget = w:entity(), w:entity()
	local oldHolder, newHolder = w:entity(), w:entity()
	w:add(oldHolder, pair(Owned, oldTarget))
	w:add(Owned, pair(jecs.OnDeleteTarget, jecs.Delete))
	w:add(newHolder, pair(Owned, newTarget))
	w:delete(oldTarget)
	w:delete(newTarget)
	check("a cleanup trait added late is ignored for the pair in use and honoured for a new target", w:contains(oldHolder) and not w:contains(newHolder))

	-- world:clear on a dead handle is not a debug check
	local dbg = jecs.world(true)
	local gone = dbg:entity()
	dbg:delete(gone)
	check("debug world: world:clear on a dead handle is silent", not raises(function()
		dbg:clear(gone)
	end))

	-- an entity that lost its last component and gets one again
	local w2 = jecs.world()
	local B = w2:component()
	local e1, e2, e3 = w2:entity(), w2:entity(), w2:entity()
	w2:set(e3, B, "e3")
	w2:set(e1, B, "e1")
	w2:remove(e1, B)
	w2:set(e2, B, "e2")
	w2:remove(e2, B)
	w2:set(e2, B, "e2-again")
	w2:delete(e1)
	if FORK then
		check("fork: an emptied entity given a component again keeps its own data", w2:get(e2, B) == "e2-again")
	else
		check("upstream: an emptied entity given a component again reads another entity's data", w2:get(e2, B) == "e3")
	end
	-- the same sequence with a permanent tag on every entity
	local w3 = jecs.world()
	local B3, Keep = w3:component(), w3:entity()
	local k1, k2, k3 = w3:entity(), w3:entity(), w3:entity()
	for _, k in { k1, k2, k3 } do
		w3:add(k, Keep)
	end
	w3:set(k3, B3, "e3")
	w3:set(k1, B3, "e1")
	w3:remove(k1, B3)
	w3:set(k2, B3, "e2")
	w3:remove(k2, B3)
	w3:set(k2, B3, "e2-again")
	w3:delete(k1)
	check("with a permanent tag the same sequence keeps the data on both libraries", w3:get(k2, B3) == "e2-again" and w3:get(k3, B3) == "e3")

	local w4 = jecs.world()
	local Flag, Num = w4:component(), w4:component()
	local f = w4:entity()
	jecs.bulk_insert(w4, f, { Flag, Num }, { false, 1 })
	if FORK then
		check("fork: bulk_insert stores a false value", w4:get(f, Flag) == false)
	else
		check("upstream: bulk_insert drops a false value", w4:get(f, Flag) == nil)
	end
end

if FORK then
	print("review findings: deferred and debug")
	local w = jecs.world()
	local Health, InSquad = w:component(), w:entity()
	local deferred = (w :: any).deferred
	local unit, other, squad = w:entity(), w:entity(), w:entity()
	deferred:add(unit, pair(InSquad, squad))
	deferred:set(other, Health, 9)
	w:delete(squad)
	check("deferred: a queued pair whose target died raises at apply", raises(function()
		deferred:apply()
	end) and w:get(other, Health) == nil)
	deferred:apply()
	check("deferred: ... and the changes after it are made by the next apply", w:get(other, Health) == 9)

	local unit2, squad2 = w:entity(), w:entity()
	deferred:add(unit2, pair(InSquad, squad2))
	w:delete(squad2)
	local stranger = w:entity()
	deferred:apply()
	check("deferred: once the slot is reused the queued pair links to the new occupant", w:target(unit2, InSquad) == stranger)

	local dbg = jecs.world(true)
	local D = dbg:component()
	local victim = dbg:entity()
	dbg:set(D, jecs.OnRemove, function(entity)
		dbg:set(entity, D, 0) -- not structural: the entity has D
	end)
	dbg:set(victim, D, 1)
	check("debug world: any write to an entity from its OnRemove during a delete raises and abandons the delete", raises(function()
		dbg:delete(victim)
	end) and dbg:contains(victim))
end

print("several worlds")
do
	local w1, w2 = jecs.world(), jecs.world()
	local startAdds = preAdds
	w1:set(w1:entity(), PreHealth, 1)
	w2:set(w2:entity(), PreHealth, 1)
	check("a jecs.meta hook runs in every world created after it", preAdds - startAdds == 2)

	local PerWorld = PrePerWorld
	local d1, d2 = jecs.world(true), jecs.world(true)
	local hits1, hits2 = 0, 0
	d1:set(PerWorld, jecs.OnAdd, function()
		hits1 += 1
	end)
	d2:set(PerWorld, jecs.OnAdd, function()
		hits2 += 1
	end)
	d1:set(d1:entity(), PerWorld, 1)
	d2:set(d2:entity(), PerWorld, 1)
	d2:set(d2:entity(), PerWorld, 1)
	check("world:set of a hook before the first use of the id is per world", hits1 == 1 and hits2 == 2)

	local Follows = d1:entity()
	local leader, unit = d1:entity(), d1:entity()
	local seen
	d1:added(Follows, function(_, id)
		seen = jecs.pair_second(d1, id)
	end)
	d1:add(unit, pair(Follows, leader))
	check("pair_second on the id a relation listener receives gives the target", seen == leader)
end

-- Last, because it leaves the world it runs against unusable on the fork.
print("late registration")
do
	local w = jecs.world()
	local dw = jecs.world(true)
	local de = dw:entity()
	local before = w:component()
	local late = jecs.component()
	if FORK then
		check("fork: world:component() raises after a late jecs.component()", raises(function()
			w:component()
		end))
		check("fork: ... and a debug world raises from world:add", raises(function()
			dw:add(de, dw:entity())
		end))
	else
		check("upstream: a late jecs.component() returns an id the world already handed out", late == before)
	end
end

print(`{passed} passed, {failed} failed`)
if failed > 0 then
	require("@lune/process").exit(1)
end
