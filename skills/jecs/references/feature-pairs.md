# Pairs and relationships

`pair(relation, target)` is an id made of two ids. It keeps the slot of each and drops their generations.

```luau
local OwnedBy = jecs.tag()
jecs.meta(OwnedBy, pair(jecs.OnDeleteTarget, jecs.Delete))

world:add(sword, pair(OwnedBy, player))
for item in world:query(pair(OwnedBy, player)) do
end
```

## What a pair holds

| Pair | Holds |
|---|---|
| `pair(dataRelation, entity)` | A value, typed by the relation. |
| `pair(tagRelation, dataComponent)` | A value, typed by the target. |
| `pair(tagRelation, entity)` | Nothing: it is a tag, and `world:set` on it raises. |

## Calls

| Call | Does |
|---|---|
| `world:target(e, R, index?)` | The target of `e`'s `index`-th pair of `R`. The index starts at 0 and defaults to 0. Nil when there is none. |
| `world:targets(e, R)` | Iterator over every target of `R` on `e`. |
| `world:parent(e)` | `world:target(e, jecs.ChildOf)`. |
| `world:children(parent)` | Iterator over entities with `pair(jecs.ChildOf, parent)`. |
| `world:query(pair(R, jecs.Wildcard))` | Entities with any pair of `R`. One row per entity, however many targets it has. |
| `world:query(pair(jecs.Wildcard, T))` | Entities with any pair that targets `T`. |
| `jecs.pair_first(world, id)`, `jecs.pair_second(world, id)` | The live relation and target of a pair id. |
| `jecs.IS_PAIR(id)` | Whether an id is a pair. |

## Built-in relationships

- `jecs.ChildOf` is exclusive and deletes children with their parent, descendants included.
- `jecs.Exclusive` on a relation lets an entity hold one target of it: adding another replaces the first. Set it through `jecs.meta`, before the relation is first used.

Traits that decide what happens when a target is deleted are in [feature-cleanup-traits.md](feature-cleanup-traits.md).

## Rules

- **Build a pair only from a handle just checked with `world:contains`.** A pair keeps no generation, so a stale handle links to whatever entity now sits in that slot, even in a debug world.
- **Put the pair on the many side, pointing at the few.** Every distinct target is its own id and creates archetypes. When to use a pair and when to store the entity in a component is in [best-practices-entities.md](best-practices-entities.md).
- **A hook or signal on a relation runs for its pairs**, and receives the full pair id. Take it apart with `jecs.pair_second(world, id)`.
