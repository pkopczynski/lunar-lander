# Touching a solid damages the ship by impact speed and it bounces, instead of crashing

Touching a solid (the ground off the pad, the Mountains, a location's terrain, the station) no longer always crashes the ship. The **impact speed**, its speed into the surface, sets what happens: below 15 px/s nothing (the ship settles), from 15 to 120 px/s (the **crash speed**) a loss of **Condition** rising in a straight line from 0% to 50%, above it a crash. A hit that takes Condition to 0% is a crash. A hit bounces the ship off at 35% of its impact speed, keeping 80% of its speed along the surface, with no disturbance of the controls; a ship on the ground slides to a stop at 60 px/s². A ship resting off a pad stays Flying and can take off again; resting tipped over (past 90° for 2 s) is a crash, and resting with an empty tank is **Stranded**, ended by Recovery for the normal fee, keeping Condition. The pad's ground keeps its landing judgement, and docking its single limit.

This amends [ADR 0005](0005-solid-terrain-vs-decor.md)'s consequence that a new solid is "a crash": the solid-vs-decor split stands, and only what touching a solid does changes.

**Status:** accepted. Decided in [#95](https://github.com/pkopczynski/lunar-lander/issues/95) (Minimal damage model) and [#101](https://github.com/pkopczynski/lunar-lander/issues/101) (How hitting terrain feels, the confirmed numbers), landed by [#114](https://github.com/pkopczynski/lunar-lander/issues/114).

## Why

With money and owned ships lasting across a Career (ADR 0008), a scrape that ends a mission was too harsh and gave Condition and Repair nothing to price. Damage by impact speed makes a scrape a cost, keeps a hard hit serious, and was playtested on a throwaway prototype at every location.

## Consequences

- The Lander wears the Condition of the ship in service in flight, as it burns its fuel: the one other change an `OwnedShip` takes outside the Hangar's named operations. It emits `damaged(loss)` for the HUD.
- Stranded settles like a crash (`Economy.settle_crash()`: Failed contracts, then the recovery fee) but doesn't make a Wreck: the Lander emits `stranded`, not `crashed`.
- Tipping and rolling on the ground ([#116](https://github.com/pkopczynski/lunar-lander/issues/116)) and Hard landings on the pad ([#115](https://github.com/pkopczynski/lunar-lander/issues/115)) build on this; until then a ship keeps its attitude on contact and a touchdown on the pad is still landed or crashed.
