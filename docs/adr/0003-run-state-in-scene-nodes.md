# Run state lives in scene nodes, and restart reloads the scene

All of a run's state (the Bank account, offers, Contracts, the planet clock, the ship) lives in nodes of `main.tscn`, with no autoloads and no mutable static state. Restart is `reload_current_scene()`, so a new run starts clean just because the scene reloads. The Office pauses the tree while it shows. Whatever must keep running behind it opts in with process mode Always (the Economy, so offer timers run on). Whatever must stop stays pausable (the planet clock).

**Status:** accepted. Recorded on 2026-11-06, after the fact.

## Why

Stated in [#16](https://github.com/pkopczynski/lunar-lander/issues/16) (Implementation Decisions): "Restart stays a scene reload. All economy state lives in scene nodes: no autoload, no static state. A new run starts clean simply because the scene reloads." The pause split is stated in #16 (Economy "process mode Always, so the Office pausing the tree never freezes it") and [#39](https://github.com/pkopczynski/lunar-lander/issues/39) (the clock "pauses with the tree, so it stops while the office shows").

Reconstructed, not recorded: the alternative was an autoload singleton, which survives a reload and would need its own reset code for every field.

## Consequences

- Nothing persists across runs; adding save data or a high score would break this rule, so it needs a new decision.
- Static state is limited to data built once when its script loads and only read after that: the tables `ShipType.SPARROW`/`MULE`/`HALO`/`ALL`, `Location.VALLEY`/`MINE`/`METROPOLIS`/`ALL`, `SkyLook.KEYFRAMES` and `Skyline.DEPTHS`, and the shared `Clouds.shading_texture`. Game code never reassigns them or changes their entries or fields, so they carry nothing from one run to the next. Nothing enforces this (they're `static var`s because GDScript can't build objects in a `const`; README, Code conventions). The one exception is a test: `tests/test_office.gd` appends a temporary ship type to `ShipType.ALL` and erases it again.
- `SceneTree.paused` survives a reload, so the new Office sets it again in `_ready()` (README, Gotchas).
