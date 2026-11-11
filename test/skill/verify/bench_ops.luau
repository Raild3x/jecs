-- Re-measures the cost table in references/performance.md (writes, hooks, state switches, filters, the deferred queue, target reads, bulk_insert).
-- Copy the project's jecs.luau next to this file, then: lune run bench_ops.luau
-- Not a pass/fail check: it prints each ratio beside the table's figure. Ratios
-- move with the machine and the runtime; a figure off by more than about 2x,
-- or pointing the other way, means the table needs correcting.
-- The two bench files register their own ids, so each runs as its own process.
local jecs = require("./jecs")
local pair = jecs.pair
local N = 10000

local function best(fn, reps)
	reps = reps or 15
	fn() fn() -- warm-up
	local b = math.huge
	for _ = 1, reps do
		local t = os.clock()
		fn()
		local d = os.clock() - t
		if d < b then b = d end
	end
	return b
end
local function ns(t, n) return string.format("%.1f ns", t / (n or N) * 1e9) end
local function ratio(a, b) return string.format("%.2fx", a / b) end

local A = jecs.component()
local B = jecs.component()
local Hooked = jecs.component()
local Others = {}
for i = 1, 30 do Others[i] = jecs.component() end
local State = jecs.component()
local Team = jecs.tag()
local T1, T2 = jecs.tag(), jecs.tag()
local TagA, TagB = jecs.tag(), jecs.tag()
local Match = jecs.tag()
local Rel = jecs.tag()
local Link = jecs.component()
jecs.meta(Team, jecs.Exclusive)
jecs.meta(Hooked, jecs.OnChange, function() end)

local function spawn(world, n, comps)
	local es = table.create(n)
	for i = 1, n do
		local e = world:entity()
		for _, c in comps do world:set(e, c, i) end
		es[i] = e
	end
	return es
end

-- 1. debug world set
do
	local w, wd = jecs.world(), jecs.world(true)
	local es, esd = spawn(w, N, { A }), spawn(wd, N, { A })
	local plain = best(function() for i = 1, N do w:set(es[i], A, i) end end)
	local dbg = best(function() for i = 1, N do wd:set(esd[i], A, i) end end)
	print("debug set:", ns(plain), ns(dbg), ratio(dbg, plain), "(table: about 3.7x)")
	-- debug set of a pair id
	local tgt, tgtd = w:entity(), wd:entity()
	for i = 1, N do w:set(es[i], pair(B, tgt), i); wd:set(esd[i], pair(B, tgtd), i) end
	local pp = best(function() for i = 1, N do w:set(es[i], pair(B, tgt), i) end end)
	local pd = best(function() for i = 1, N do wd:set(esd[i], pair(B, tgtd), i) end end)
	print("debug set of a pair:", ns(pp), ns(pd), ratio(pd, pp))
	-- debug add (no-op) and structural add/remove
	local ap = best(function() for i = 1, N do w:add(es[i], TagA); w:remove(es[i], TagA) end end)
	local ad = best(function() for i = 1, N do wd:add(esd[i], TagA); wd:remove(esd[i], TagA) end end)
	print("debug add+remove tag:", ns(ap), ns(ad), ratio(ad, ap))
end

-- 2. hook / signals
do
	local w = jecs.world()
	local es = spawn(w, N, { A, Hooked })
	local plain = best(function() for i = 1, N do w:set(es[i], A, i) end end)
	local hook = best(function() for i = 1, N do w:set(es[i], Hooked, i) end end)
	print("hook set:", ratio(hook, plain), "(table 1.3-1.7x)")
	local d1 = w:changed(A, function() end)
	local one = best(function() for i = 1, N do w:set(es[i], A, i) end end)
	print("1 listener:", ratio(one, plain), "(table 1.8-2.1x)")
	local d2 = w:changed(A, function() end)
	local d3 = w:changed(A, function() end)
	local three = best(function() for i = 1, N do w:set(es[i], A, i) end end)
	print("3 listeners:", ratio(three, plain), "(table 2.5-2.6x)")
	d1() d2() d3()
	local zero = best(function() for i = 1, N do w:set(es[i], A, i) end end)
	print("0 listeners after disconnect:", ratio(zero, plain), "(table: does not return to baseline)")
end

-- 3. switching state
for _, extra in { 2, 10, 30 } do
	local w = jecs.world()
	local comps = { State }
	for i = 1, extra do comps[#comps + 1] = Others[i] end
	local es = spawn(w, N, comps)
	for i = 1, N do w:add(es[i], pair(Team, T1)); w:add(es[i], TagA) end
	local set = best(function() for i = 1, N do w:set(es[i], State, i) end end)
	local flip = false
	local ex = best(function()
		flip = not flip
		local p = if flip then pair(Team, T2) else pair(Team, T1)
		for i = 1, N do w:add(es[i], p) end
	end)
	local tg = best(function()
		flip = not flip
		local from, to = TagA, TagB
		if not flip then from, to = TagB, TagA end
		for i = 1, N do w:remove(es[i], from); w:add(es[i], to) end
	end)
	print(`switch state, {extra} other comps: exclusive {ratio(ex, set)}, remove+add tag {ratio(tg, set)}  (table 4-5/11-13/28-38 and 8-10/20-22/46-50)`)
end

-- 4. select by value+if vs tag filter ; 5. with vs term
for _, pct in { 25, 1 } do
	local w = jecs.world()
	local es = spawn(w, N, { A, State })
	for i = 1, N do
		local m = (i % 100) < pct
		w:set(es[i], State, if m then 1 else 0)
		if m then w:add(es[i], Match) end
	end
	local qv = w:query(A, State):cached()
	local qt = w:query(A):with(Match):cached()
	local sink = 0
	local v = best(function() for e, a, s in qv do if s == 1 then sink += a end end end, 30)
	local t = best(function() for e, a in qt do sink += a end end, 30)
	print(`select {pct}%: value+if is {ratio(v, t)} the tag filter (table: 4x at 25%, ~100x at 1%)`)
	if pct == 25 then
		local qterm = w:query(A, Match):cached()
		local tt = best(function() for e, a in qterm do sink += a end end, 30)
		print("term vs with:", ratio(tt, t), "(table 1.0x)")
		local qterm2 = w:query(A, State):cached()
		local qwith2 = w:query(A):with(State):cached()
		local t1 = best(function() for e, a in qterm2 do sink += a end end, 30)
		local t2 = best(function() for e, a in qwith2 do sink += a end end, 30)
		print("data term vs with (data comp):", ratio(t1, t2))
	end
end

-- 6. deferred
do
	local w = jecs.world()
	local es = spawn(w, N, { A })
	local d = w.deferred
	local direct = best(function() for i = 1, N do w:add(es[i], TagA) end for i = 1, N do w:remove(es[i], TagA) end end)
	local hand = best(function()
		local list = table.create(N)
		for i = 1, N do list[i] = es[i] end
		for i = 1, N do w:add(list[i], TagA) end
		for i = 1, N do list[i] = es[i] end
		for i = 1, N do w:remove(list[i], TagA) end
	end)
	local def = best(function()
		for i = 1, N do d:add(es[i], TagA) end
		d:apply()
		for i = 1, N do d:remove(es[i], TagA) end
		d:apply()
	end)
	print("deferred vs hand collect-then-apply:", ratio(def, hand), " overhead per queued change:", ns(def - direct, 2 * N), "(table 1.0-1.5x, ~45 ns)")
	-- non structural set through queue vs direct set
	local ds = best(function() for i = 1, N do w:set(es[i], A, i) end end)
	local dq = best(function() for i = 1, N do d:set(es[i], A, i) end d:apply() end)
	print("deferred set vs direct set (existing component):", ratio(dq, ds), ns(dq - ds))
end

-- 7. world:target vs world:get ; 8. per-row target vs column
for _, targets in { 10, 1000 } do
	local w = jecs.world()
	local ts = {}
	for i = 1, targets do ts[i] = w:entity() end
	local es = spawn(w, N, { A })
	for i = 1, N do
		local t = ts[(i % targets) + 1]
		w:add(es[i], pair(Rel, t))
		w:set(es[i], Link, t)
	end
	local sink
	local g = best(function() for i = 1, N do sink = w:get(es[i], Link) end end)
	local t = best(function() for i = 1, N do sink = w:target(es[i], Rel) end end)
	print(`{targets} targets: world:target {ratio(t, g)} world:get (table 2-5x)`)
	local qc = w:query(A, Link):cached()
	local qw = w:query(A, pair(Rel, jecs.Wildcard)):cached()
	local col = best(function() for e, a, l in qc do sink = l end end, 30)
	local wt = best(function() for e, a in qw do sink = w:target(e, Rel) end end, 30)
	print(`{targets} targets: wildcard query + world:target per row {ratio(wt, col)} a component column (table 8-15x lune)`)
	-- reverse lookup
	local one = ts[1]
	local cnt = 0
	local rq = best(function() for e in w:query(pair(Rel, one)) do cnt += 1 end end, 30)
	local scan = best(function() for e, a, l in qc do if l == one then cnt += 1 end end end, 30)
	local scanU = best(function() for e, l in w:query(Link) do if l == one then cnt += 1 end end end, 30)
	print(`{targets} targets: reverse lookup pair query is {ratio(scan, rq)} faster than cached scan, {ratio(scanU, rq)} than uncached scan (table 9x at 10, ~200x at 1000)`)
end

-- 17. bulk_insert vs set
for _, k in { 3, 6, 12 } do
	local ids, vals = {}, {}
	for i = 1, k do ids[i] = Others[i]; vals[i] = i end
	local M = 2000
	local w1, w2 = jecs.world(), jecs.world()
	local s = best(function()
		local es = table.create(M)
		for i = 1, M do
			local e = w1:entity()
			for j = 1, k do w1:set(e, ids[j], vals[j]) end
			es[i] = e
		end
		for i = 1, M do w1:delete(es[i]) end
	end)
	local delOnly1 = 0
	local b = best(function()
		local es = table.create(M)
		for i = 1, M do
			local e = w2:entity()
			jecs.bulk_insert(w2, e, ids, vals)
			es[i] = e
		end
		for i = 1, M do w2:delete(es[i]) end
	end)
	print(`bulk_insert {k} comps: set/bulk = {ratio(s, b)} incl. entity create+delete (table: slower at 3, equal at 6, 1.57x faster at 12)`)
end
