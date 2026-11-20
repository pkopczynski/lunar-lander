# Solid terrain and decor are kept strictly apart

Only four bodies collide: `Ground` (the one thing a ship lands on), `Mountains`, `Terrain` (a location's solid polygons) and the `Station`. Solids keep their own opaque material colour, only dimmed by the sky. Everything else is decor: no collider, sky-tinted behind the surface, near-black in the Foreground, and clearly distinct from every solid colour at every hour. Parallax decor lives in an `AnchoredParallax` anchored on the current pad's top, sitting exactly where it was designed with the camera centred there, and is never moved by hand from the camera.

**Status:** accepted. Recorded on 2026-11-06, after the fact. Amended by [ADR 0009](0009-contact-damages-and-bounces.md): touching a solid now damages the ship by impact speed and bounces it, crashing it only above the crash speed; the split itself stands.

## Why

Stated in the "Solid vs decor" rule in [`docs/gameplay/world-and-scenery.md`](../gameplay/world-and-scenery.md) ("a hard rule, so the player never mistakes what crashes them for scenery") and in [#68](https://github.com/pkopczynski/lunar-lander/issues/68) (user stories 11–15; Testing Decisions: "Parallax stays anchored on the pad… never moved by hand from the camera"), implemented by [#72](https://github.com/pkopczynski/lunar-lander/issues/72). Anchoring on the pad lets `World.shown_decor()` place every parallax piece for any camera through `offset_for()`, so tests can check decor at heights the game never has to reach (root README, Gotchas).

## Consequences

- A new solid must be a `Location` terrain polygon (touching it damages the ship, ADR 0009) or the ground (landable on the pad); a new visual piece without a collider is decor and must follow the colour rules.
- `tests/test_tonal_depth.gd` and `tests/test_mountains.gd` check every solid colour against every decor piece across the day, which is why solid colours are light or clearly saturated.
- The Foreground must keep the Approach corridor clear ([`docs/gameplay/world-and-scenery.md`](../gameplay/world-and-scenery.md), Foreground; `tests/test_approach_corridor.gd`).
