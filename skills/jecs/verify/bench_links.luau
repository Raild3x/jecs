-- Re-measures the cost table in references/best-practices-archetypes.md (links, fragmentation, containment, events, pair signals, despawn, empty archetypes).
-- Copy the project's jecs.luau next to this file, then: lune run bench_links.luau
-- Not a pass/fail check: it prints each ratio beside the table's figure. Ratios
-- move with the machine and the runtime; a figure off by more than about 2x,
-- or pointing the other way, means the table needs correcting.
-- The two bench files register their own ids, so each runs as its own process.
local jecs = require("./jecs")
local pair = jecs.pair
local N = 10000

local function best(fn, reps)
	reps = reps or 15
	fn() fn()
	local b = math.huge
	for _ = 1, reps do
		local t = os.clock()
		fn()
		local d = os.clock() - t
		if d < b then b = d end
	end
	return b
end
-- for one-shot work: setup() builds state, fn(state) is timed; best of reps
local function bestOnce(setup, fn, reps)
	local b = math.huge
	for _ = 1, reps or 5 do
		local s = setup()
		local t = os.clock()
		fn(s)
		local d = os.clock() - t
		if d < b then b = d end
	end
	return b
end
local function ns(t, n) return string.format("%.1f ns", t / (n or N) * 1e9) end
local function ratio(a, b) return string.format("%.2fx", a / b) end
local function countArchetypes(w) local c = 0 for _ in w.archetypes do c += 1 end return c end

local A = jecs.component()
local Bc = jecs.component()
local Link = jecs.component()
local Items = jecs.component()
local Pending = jecs.component()
local Health = jecs.component()
local Rel = jecs.tag()
local ExRel = jecs.tag()
local Owns = jecs.tag()
local OwnedBy = jecs.tag()
local Dead = jecs.tag()
local Event = jecs.tag()
local EvTarget = jecs.component()
local EvAmount = jecs.component()
local Follows = jecs.tag()
jecs.meta(ExRel, jecs.Exclusive)

-- 13 build, 11 retarget, 20 delete all targets, 10 broad query
local buildBase
for _, targets in { 10, 1000, 10000 } do
	local function setup()
		local w = jecs.world()
		local ts = table.create(targets)
		for i = 1, targets do ts[i] = w:entity() end
		return { w = w, ts = ts }
	end
	local comp = bestOnce(setup, function(s)
		local w, ts = s.w, s.ts
		for i = 1, N do
			local e = w:entity()
			w:set(e, A, i)
			w:set(e, Link, ts[(i % targets) + 1])
		end
	end)
	local pr = bestOnce(setup, function(s)
		local w, ts = s.w, s.ts
		for i = 1, N do
			local e = w:entity()
			w:set(e, A, i)
			w:add(e, pair(Rel, ts[(i % targets) + 1]))
		end
	end)
	print(`build {targets} targets: pair {ratio(pr, comp)} component link (table: equal at 10; 3x at 1,000; 10-19x at 10,000)`)

	-- retarget
	local w = jecs.world()
	local ts = table.create(targets)
	for i = 1, targets do ts[i] = w:entity() end
	local es = table.create(N)
	for i = 1, N do
		local e = w:entity()
		w:set(e, A, i); w:set(e, Link, ts[(i % targets) + 1]); w:add(e, pair(ExRel, ts[(i % targets) + 1]))
		es[i] = e
	end
	local k = 0
	local set = best(function() k += 1 for i = 1, N do w:set(es[i], Link, ts[((i + k) % targets) + 1]) end end)
	local ret = best(function() k += 1 for i = 1, N do w:add(es[i], pair(ExRel, ts[((i + k) % targets) + 1])) end end)
	-- steady state: toggle between two fixed assignments only (edges warmed)
	local ret2 = best(function() k = 1 - (k % 2) for i = 1, N do w:add(es[i], pair(ExRel, ts[((i + k) % targets) + 1])) end end)
	print(`retarget {targets} targets: exclusive pair {ratio(ret, set)} a set (rotating), {ratio(ret2, set)} (toggling between two warmed targets) (table: ~4x at 10; 14-22x at 10,000)`)
end

-- 10 broad query across fragmentation ; 9 per-target query vs column
for _, targets in { 10, 100, 1000 } do
	local w = jecs.world()
	local ts = table.create(targets)
	for i = 1, targets do ts[i] = w:entity() end
	local w0 = jecs.world()
	for i = 1, N do
		local e = w:entity()
		w:set(e, A, i); w:set(e, Link, ts[(i % targets) + 1]); w:add(e, pair(Rel, ts[(i % targets) + 1]))
		local e0 = w0:entity()
		w0:set(e0, A, i); w0:set(e0, Link, i)
	end
	local q = w:query(A):cached()
	local q0 = w0:query(A):cached()
	local sink = 0
	local frag = best(function() for e, a in q do sink += a end end, 30)
	local flat = best(function() for e, a in q0 do sink += a end end, 30)
	local qc = w0:query(A, Link):cached()
	local col = best(function() for e, a, l in qc do sink += a end end, 30)
	local per = best(function()
		for i = 1, targets do
			for e, a in w:query(A):with(pair(Rel, ts[i])) do sink += a end
		end
	end, 30)
	print(`{targets} targets ({N // targets} holders each): broad query {ratio(frag, flat)} flat (table 1.0x at 100, 1.2x at 1000); query-per-target {ratio(per, col)} a component column (table 1.1x at 1000/target, 1.6x at 100, 5-6x at 10)`)
end

-- 14 containment
do
	local owners, items = 100, 30
	local function mk() return jecs.world() end
	local arr = bestOnce(mk, function(w)
		for o = 1, owners do
			local owner = w:entity(); w:set(owner, A, o)
			local list = table.create(items)
			for i = 1, items do local it = w:entity(); w:set(it, Bc, i); list[i] = it end
			w:set(owner, Items, list)
		end
	end, 7)
	local base = countArchetypes(jecs.world())
	local n1, n2
	local onItem = bestOnce(mk, function(w)
		for o = 1, owners do
			local owner = w:entity(); w:set(owner, A, o)
			for i = 1, items do local it = w:entity(); w:set(it, Bc, i); w:add(it, pair(OwnedBy, owner)) end
		end
		n1 = countArchetypes(w)
	end, 7)
	local onOwner = bestOnce(mk, function(w)
		for o = 1, owners do
			local owner = w:entity(); w:set(owner, A, o)
			for i = 1, items do local it = w:entity(); w:set(it, Bc, i); w:add(owner, pair(Owns, it)) end
		end
		n2 = countArchetypes(w)
	end, 7)
	print(`containment: pair on item {ratio(onItem, arr)} array ({n1} archetypes, empty world has {base}); pair on owner {ratio(onOwner, arr)} ({n2} archetypes) (table 3x/119, 90x/3,019)`)
end

-- 15 events
do
	local w = jecs.world()
	local es = table.create(N)
	for i = 1, N do local e = w:entity(); w:set(e, Health, 100); es[i] = e end
	local direct = best(function() for i = 1, N do local e = es[i]; w:set(e, Health, w:get(e, Health) - 1) end end)
	local hits = {}
	local array = best(function()
		for i = 1, N do table.insert(hits, { target = es[i], amount = 1 }) end
		local batch = hits; hits = {}
		for _, hit in batch do
			local h = w:get(hit.target, Health)
			if h then w:set(hit.target, Health, h - hit.amount) end
		end
	end)
	local pq = w:query(Health, Pending):cached()
	local pending = best(function()
		for i = 1, N do w:set(es[i], Pending, 1) end
		local d = w.deferred
		for e, h, p in pq do w:set(e, Health, h - p); d:remove(e, Pending) end
		d:apply()
	end)
	local eq = w:query(EvTarget, EvAmount):cached()
	local ent = best(function()
		for i = 1, N do local ev = w:entity(); w:set(ev, EvTarget, es[i]); w:set(ev, EvAmount, 1) end
		local d = w.deferred
		for ev, t, a in eq do
			local h = w:get(t, Health)
			if h then w:set(t, Health, h - a) end
			d:delete(ev)
		end
		d:apply()
	end)
	print(`events: array {ratio(array, direct)}, pending component {ratio(pending, direct)}, entity per event {ratio(ent, direct)} (table 1.3x, 4.4-6x, 6.4-9x)`)
end

-- 16 pair signals
do
	local w = jecs.world()
	local es = table.create(N)
	for i = 1, N do es[i] = w:entity() end
	local t0 = w:entity()
	local p = pair(Follows, t0)
	local function run() for i = 1, N do w:add(es[i], p) end for i = 1, N do w:remove(es[i], p) end end
	local none = best(run)
	local leaders = {}
	for i = 1, 100 do leaders[i] = w:entity(); w:added(pair(Follows, leaders[i]), function() end) end
	local with100 = best(run)
	print(`pair signals: add+remove with 100 pair listeners on 'added' = {ratio(with100, none)}; per listener per add event {ns((with100 - none) / 100)} (table 12-20 ns; an add is 4x with 100)`)
	local addOnly0, addOnly100
	local w2 = jecs.world()
	local es2 = table.create(N)
	for i = 1, N do es2[i] = w2:entity() end
	local t2 = w2:entity()
	local p2 = pair(Follows, t2)
	local function addT() for i = 1, N do w2:add(es2[i], p2) end end
	local function remT() for i = 1, N do w2:remove(es2[i], p2) end end
	local function timeAdd()
		local b = math.huge
		for _ = 1, 15 do
			local t = os.clock(); addT(); local d = os.clock() - t
			remT()
			if d < b then b = d end
		end
		return b
	end
	timeAdd()
	addOnly0 = timeAdd()
	for i = 1, 100 do w2:added(pair(Follows, w2:entity()), function() end) end
	addOnly100 = timeAdd()
	print(`  add only: {ns(addOnly0)} -> {ns(addOnly100)} = {ratio(addOnly100, addOnly0)}`)
end

-- 18 despawn
do
	local M = N
	local function setup()
		local w = jecs.world()
		local es = table.create(M)
		for i = 1, M do local e = w:entity(); w:set(e, Health, if i % 2 == 0 then 0 else 10); w:set(e, A, i); es[i] = e end
		return { w = w, q = w:query(Health):cached(), dq = w:query(Dead):cached() }
	end
	local collect = bestOnce(setup, function(s)
		local w = s.w
		local list = {}
		for e, h in s.q do if h <= 0 then table.insert(list, e) end end
		for _, e in list do w:delete(e) end
	end, 7)
	local marker = bestOnce(setup, function(s)
		local w = s.w
		local d = w.deferred
		for e, h in s.q do if h <= 0 then d:add(e, Dead) end end
		d:apply()
		for e in s.dq do d:delete(e) end
		d:apply()
	end, 7)
	local deferredDel = bestOnce(setup, function(s)
		local w = s.w
		local d = w.deferred
		for e, h in s.q do if h <= 0 then d:delete(e) end end
		d:apply()
	end, 7)
	print(`despawn: marker tag + cleanup query {ratio(marker, collect)} collect-then-delete; deferred delete {ratio(deferredDel, collect)} (table 1.2-1.4x)`)
end

-- 19 empty archetypes in cached query
do
	local w = jecs.world()
	local es = table.create(N)
	for i = 1, N do local e = w:entity(); w:set(e, A, i); es[i] = e end
	local q = w:query(A):cached()
	local sink = 0
	local clean = best(function() for e, a in q do sink += a end end, 30)
	local tags = {}
	for i = 1, 1000 do tags[i] = w:entity() end
	local tmp = w:entity(); w:set(tmp, A, 1)
	for i = 1, 1000 do w:add(tmp, tags[i]); w:remove(tmp, tags[i]) end
	local dirty = best(function() for e, a in q do sink += a end end, 30)
	w:cleanup()
	local after = best(function() for e, a in q do sink += a end end, 30)
	print(`1,000 empty archetypes: cached query {ratio(dirty, clean)} slower; after cleanup {ratio(after, clean)} (table 1.2x)`)
end
