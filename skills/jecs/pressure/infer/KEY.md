# Infer scenario: key

The tickets give no rates. How each function is used is only visible in the caller modules, and `check.luau` detects the model chosen by counting archetypes.

| Ticket | Visible in | Expected | A wrong model shows as |
|---|---|---|---|
| 1 Focus | `ai.luau` sets it for every NPC every frame; `render.luau` reads it for every NPC every frame; nothing asks the reverse | Entity in a data component, `world:contains` on read and on set | 1,000 distinct focuses create about 1,000 archetypes |
| 2 Mood | `ai.luau` sets it for every NPC every frame; `render.luau` reads it for every NPC | Value component | The NPC changes archetype when its mood changes |
| 3 Squads | `orders.luau` works one squad at a time each frame; reassignment comes from a UI drag | Exclusive pair, no cleanup trait, `world:contains(squad)` before `pair()` | 20 squads create no archetypes |
| 4 Alarm | `alarm.luau`: set from events, a handful alarmed among thousands, the list read every frame | A tag, listed with a cached query | Alarming an NPC leaves it in the same archetype |
