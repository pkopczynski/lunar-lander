# Tests drive the whole main scene and check only what a player could observe

Every committed test loads a fresh `main.tscn` headless, drives it with the real input actions, waits by counting frames, and checks observable state: ship state, position, velocity, fuel, mass, message text, what the Terminal and HUD show, and what the World draws. There are no unit tests of internal classes; even pure steps such as `SkyLook.at()` are tested through the World's readings. Allowed setup is direct public state (`place()`, seeding RNGs, `economy().put_offer()`, `clock().move_to()`).

**Status:** accepted. Recorded on 2026-11-06, after the fact.

## Why

Stated in the Testing Decisions of [#1](https://github.com/pkopczynski/lunar-lander/issues/1) ("One seam: the whole main scene driven by input events"), [#16](https://github.com/pkopczynski/lunar-lander/issues/16) ("No separate unit tests for the Transport offer or the generator") and [#39](https://github.com/pkopczynski/lunar-lander/issues/39) ("There are no unit tests on internal classes, and the pure sky function isn't tested directly"). [#68](https://github.com/pkopczynski/lunar-lander/issues/68) extends the same seam to scenery: "One seam for decor: the World's decor listing for a given camera".

Reconstructed, not recorded: one seam keeps tests valid through refactors, which this repo does often (its "prefactor" issues must pass every existing test unchanged).

## Consequences

- Production scripts carry read-only accessors that exist for tests: the Office's and screens' observable text, the HUD's `clock_text()`, `World.shown_decor()` and `shown_stars()`. A new decor script joins `shown_decor()` through its `listed_decor()`.
- Gameplay ticks in `_physics_process` so `--fixed-fps 60` runs are deterministic.
- Visuals and game feel still need a human playtest; `tools/capture.gd` produces screenshots for review but no test depends on it.
- How to run and write tests: README, "Running and validating".
