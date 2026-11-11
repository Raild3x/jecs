# Rival scenario: key

One decision, chosen to sit between the skill's two versions. The link merely points (nothing asks "whose rival is X"), is read for every NPC every frame, has thousands of distinct targets, and is set once per round.

| Expected | Why | Fails |
|---|---|---|
| Entity in a data component, `world:contains` on read | Read per row; one archetype per target otherwise; no reverse lookup wanted | A pair: the MODEL check counts about 1,000 new archetypes |

The pair-first skill named two exceptions, a target rewritten on most entities every frame and about 10,000 distinct targets. Neither applies here, so it points at a pair.
