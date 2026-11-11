# Cleanup traits

A trait is an id added to another id to change how it behaves. Cleanup traits decide what happens to the entities that hold an id, or point at a target, when that id or target is deleted.

Set a trait through `jecs.meta`, or with `world:add(id, trait)` before the id is first used. A trait added later is ignored without an error (**fork:** a debug world raises).

```luau
local OwnedBy = jecs.tag()
jecs.meta(OwnedBy, pair(jecs.OnDeleteTarget, jecs.Delete)) -- deleting an owner deletes its items

local Temporary = jecs.tag()
jecs.meta(Temporary, pair(jecs.OnDelete, jecs.Delete))      -- deleting the tag deletes everything tagged
```

| Trait | Effect |
|---|---|
| `pair(jecs.OnDeleteTarget, jecs.Delete)` on a relation | Deleting a target deletes every entity that holds a pair to it. |
| `pair(jecs.OnDelete, jecs.Delete)` on an id | Deleting the id deletes every entity that has it. |
| none (the default) | Deleting an id or a target removes it from its holders, which survive. |
| `jecs.ChildOf` (built in) | Exclusive, with `(OnDeleteTarget, Delete)`: deleting a parent deletes its descendants. |

## Behaviour to know

- On a cascade delete the parent's remove callbacks run before its children's.
- A remove callback's `deleted` argument is true for every entity a cascade deletes.
- A component that stores an entity as its value is not cleaned up: the stale handle stays, and the reader checks it. See [best-practices-entities.md](best-practices-entities.md).
- Deleting many targets is the costly direction: see the cost table in [best-practices-archetypes.md](best-practices-archetypes.md).
