# Cleanup traits

Decide what happens to holders when an id or a pair target is deleted.

## When to use

- Holders must die with their target (items with owner, parts with vehicle): `(OnDeleteTarget, Delete)`.
- Everything tagged must die with the tag: `(OnDelete, Delete)`.
- Holders should just lose the link: nothing, it is the default.

## API

```luau
jecs.meta(OwnedBy, pair(jecs.OnDeleteTarget, jecs.Delete))
jecs.meta(Temporary, pair(jecs.OnDelete, jecs.Delete))
```

| Trait | Effect |
|---|---|
| `pair(jecs.OnDeleteTarget, jecs.Delete)` on a relation | Deleting a target deletes every holder of a pair to it |
| `pair(jecs.OnDelete, jecs.Delete)` on an id | Deleting the id deletes every entity that has it |
| none | Deleting an id or target removes it from holders; they survive |
| `jecs.ChildOf` | Built in: exclusive + `(OnDeleteTarget, Delete)` |

- Cascade order: the parent's remove callbacks run before its children's.
- `deleted` is true in remove callbacks for every cascaded entity.

## Mistakes

| Mistake | Result | Instead |
|---|---|---|
| Trait added after the id's first use | Ignored (**fork** debug world raises) | `jecs.meta` before the world |
| Expecting a component that stores an entity to be cleaned | Stale handle stays | Use a pair, or check `world:contains` on read |
| Collecting cascaded entities for a manual delete | Already dead; **fork** debug world raises | `world:contains` first, or `world.deferred` (**fork**) |
