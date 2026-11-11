# Differences from upstream `ukendio/jecs`

The rest of this skill describes the fork `raild3x/jecs` 0.11.0-fork.1. Read this file only when the project's `wally.toml` names `ukendio/jecs` 0.11.0. The table lists the differences that were tested; the fork carries further bug fixes (cascade deletes, cached-query bookkeeping) not listed here, so on upstream run the checks at the end before relying on a rule.

## Missing or different upstream

| Behaviour | Fork | Upstream | Do this upstream |
|---|---|---|---|
| `world.deferred`, `jecs.deferred(world)` | Present | Absent | Collect into a table, apply after the loop (below) |
| Signal on `pair(R, target)` | Fires for that pair | `added` never fires; `changed`/`removed` only if the pair existed when connected | Listen on `R` and compare the id |
| Listener disconnecting itself during dispatch | Others still run | Another listener can miss the event | Disconnect outside the callback |
| Chained `:with(A):with(B)`, `:without(A):without(B)` | Both apply | Only the last call | One call: `:with(A, B)` |
| `jecs.component()` / `jecs.tag()` after a world exists | `world:component()` raises; debug world raises on `add`/`set`/`remove` | Silent id collision | Nothing warns: keep ids before the world |
| Hook or trait set after first use | Debug world raises | Ignored silently | Same rule, no safety net |
| Raw hook on an id that has signal listeners | Debug world raises | Silences them, or is ignored | `jecs.meta`, or another signal |
| Structural change in `OnRemove` during `delete` | Debug world raises | Raises only on cascades | Same rule |
| `delete` of a dead handle, debug world | Raises | Ignored | `world:contains` first |
| A queued pair whose target dies before `apply` | Skipped | No queue upstream | In collect-then-apply, check `world:contains(target)` before adding the pair |
| `world:remove(e, pair(R, jecs.Wildcard))`, normal world | Raises, nothing changes | The pairs stay and the entity is corrupted: `get` returns nil, queries yield it twice | Collect `world:targets(e, R)`, remove each |
| A pair with a wildcard relation, `pair(jecs.Wildcard, t)`, in a debug world | Rejected like a wildcard target | Not detected | Never pass one to `add`, `set` or `remove` |
| An entity that lost its last component and then gets one again | Correct | Its data is silently swapped with another entity's when a second emptied entity is deleted | Avoid removing an entity's last component; keep a permanent tag on it |
| `bulk_insert` with a `false` value | Stored | Dropped: `get` returns nil | `world:set` for boolean values |
| Generation | 24 bits: a handle stays unequal for 16,777,216 reuses of its slot | 16 bits: 65,536 | Do not keep handles across very long sessions without `world:contains` |

## Collect, then apply

The upstream replacement for `world.deferred`. It also works on the fork.

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
		world:add(entity, Dead) -- for deletes: check world:contains first, a cascade may have removed it
	end
end
```

A structural change wanted from a remove hook or listener has no queue to go to: do it in the code that started the removal, after the call returns.

## Checking

Copy the project's `jecs.luau` into [`../verify/`](../verify/) and run `lune run facts.luau` and `lune run examples.luau`. The scripts detect upstream and assert the upstream column above (136 and 28 assertions pass there; 154 and 31 on the fork).
