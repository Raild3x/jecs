# Cleanup traits

Decide what happens to holders when an id or a pair target is deleted. They are the reason to prefer a pair for anything that belongs to something else: the library keeps the link honest, so no code has to remember to.

## When to use

| Want | Trait |
|---|---|
| Holders die with their target (items with owner, parts with vehicle) | `(OnDeleteTarget, Delete)` on the relation |
| Everything tagged dies with the tag | `(OnDelete, Delete)` on the id |
| Holders just lose the link (a unit whose squad disbands stays alive) | None: it is the default |

## API

```luau
jecs.meta(OwnedBy, pair(jecs.OnDeleteTarget, jecs.Delete))
jecs.meta(Temporary, pair(jecs.OnDelete, jecs.Delete))
```

| Trait | Effect |
|---|---|
| `pair(jecs.OnDeleteTarget, jecs.Delete)` on a relation | Deleting a target deletes every holder of a pair to it |
| `pair(jecs.OnDelete, jecs.Delete)` on an id | Deleting the id deletes every entity that has it |
| none (the same as `pair(jecs.OnDeleteTarget, jecs.Remove)`) | Deleting an id or target removes it from holders; they survive |
| `pair(jecs.OnDelete, jecs.Delete)` on a relation | Also deletes holders when a target of the relation is deleted |
| Deleting a relation that has `(OnDeleteTarget, Delete)` | Deletes every holder of its pairs |
| `jecs.ChildOf` | Built in: exclusive + `(OnDeleteTarget, Delete)` |

- Cascade order: the parent's remove callbacks run before its children's.
- `deleted` is true in remove callbacks for every cascaded entity.

`ChildOf` or your own relation: `ChildOf` when there is one true parent and the child is nothing without it. A separate relation when the entity already has a parent, or the link should be queried apart from the hierarchy (`OwnedBy` and `ChildOf` on the same item).

## Mistakes

| Mistake | Result | Instead |
|---|---|---|
| Trait added after the id's first use | Debug world raises. Normal world: a cleanup trait is ignored for pairs already in use and honoured for pairs to new targets, so some holders die with their target and others do not. `Exclusive` is ignored until every pair archetype of the relation is gone, then honoured | `jecs.meta` before the world |
| Expecting a component that stores an entity to be cleaned | Stale handle stays | Use a pair, or check `world:contains` on read |
| Collecting cascaded entities for a manual delete | Already dead; debug world raises | `world.deferred:delete`, which skips dead entities, or `world:contains` first |
