# Architecture overview

How the game's scripts group into systems, which way they depend on each other, and who owns which state. Per-file roles, the scene tree and the gotchas are in the root [`README.md`](../../README.md) (file table, "Scene tree", "Gotchas"); this page is the map between them. Terms are defined in [`GLOSSARY.md`](../../GLOSSARY.md), and their relationships in [`domain-model.md`](domain-model.md).

## Shape

One Godot 4.7 project, GDScript only, one scene (`main.tscn`). Every script sits at the repo root; tests in `tests/`, the capture tool in `tools/`. Each script either is attached to a node in `main.tscn`, is a node another script builds at runtime, or is a plain data class (`RefCounted`) with no node.

## Systems

| System | Scripts | Owns |
|---|---|---|
| **Flight** | `lander.gd`, `camera.gd`, `station.gd`, `ship_type.gd` | The ship's state (Flying, Landed, Docked, Crashed), position, fuel, mass and Load; the station maze and parking spot; the ship type table. |
| **Surface** | `world.gd`, `location.gd`, `mountain_look.gd` | Building the current location: ground, pad, terrain, the Mountains' look, and hosting the decor. The location table (pure data). |
| **Planet clock and sky** | `planet_clock.gd`, `sky_look.gd` | Local time, the current location and the drift count (`PlanetClock`); time → sky look, a pure step (`SkyLook`). |
| **Decor** | `backdrop.gd`, `skyline.gd`, `moons.gd`, `clouds.gd`, `foreground.gd`, `beacon.gd`, `city_lights.gd`, `activity.gd`, `vehicles.gd`, `anchored_parallax.gd`, `decor_kit.gd` | Collider-free scenery, built per location and tinted by the sky. |
| **Economy** | `economy.gd`, `transport_offer.gd` | Balance, transactions, offer pool, Contracts and the delivery phase. `TransportOffer` is pure data plus the offer generator. |
| **Office** | `office.gd`, `transport_offers_screen.gd`, `bank_account_screen.gd`, `expandable_list.gd`, `version.gd` | The Terminal UI: screens, popups, input while paused. Screens are `RefCounted` helpers the Office creates and draws on its one `Terminal` control. |
| **HUD** | `hud.gd` | Fuel bar, mass, clock line, deadline and payout float. Read-only. |

## Dependencies

Nodes find each other by fixed `NodePath`s (`$"../Lander"`); there is no autoload or service locator. Arrows mean "holds a reference to and calls":

```
Office ──► Lander, Economy, PlanetClock
Economy ─► Lander, PlanetClock
Hud ─────► Lander, Economy, PlanetClock          (read only)
World ───► PlanetClock, Lander, every decor script
Lander ──► World (current pad, World constants), Station, Ground
Camera ──► Lander (its parent), World and Station constants
```

- **Data tables sit at the bottom.** `Location`, `ShipType`, `TransportOffer`, `SkyLook`, `MountainLook` and `Skyline` hold no node references. `Location` does name the decor scripts' inner data types (`Backdrop.Ridge`, `Clouds.Cloud`, …), so the location table depends on the decor scripts' data shapes, not their nodes.
- **`World` has no per-location code.** Everything location-specific is data in `location.gd`; the World builds whatever the current `Location` lists.
- **The Lander doesn't know the Economy or the Office.** They drive it through its public methods (`hold()`, `release()`, `start_docked()`, `start_loading()`, `finish_loading()`, `show_status()`, `lift_off_blocked`) and hear from it only through signals.
- **`PlanetClock` and `SkyLook` know nothing of what reads them** (no sky, HUD or contracts in the clock; no clock or World in `SkyLook`).
- One reach upward: `economy.gd` and `office.gd` `preload("res://hud.gd")` for its `format_kg()` formatter.

## Signals

| Signal | Emitted when | Handled by |
|---|---|---|
| `PlanetClock.location_changed` | `move_to()`: a mission starts, or drift moves on | `World.show_location()` rebuilds the surface |
| `Lander.landed_on_pad` | Landed on the current pad (real landing or debug shortcut) | `Economy.start_unloading()` (ignored unless delivering) |
| `Lander.docked_at_station` | Docked and finished easing upright | `Office.ask_to_enter()` |
| `Economy.paid_out` | Unloading finished and Contracts were settled | `show_payout()` in `hud.gd` |
| `Economy.offer_expired` | An offer timed out | `TransportOffersScreen.on_offer_expired()` |

## Who may change what

| State | Owner | Changed only through |
|---|---|---|
| Current location | `PlanetClock.location` | `move_to()` (via `start_mission()` or drift). The World follows the signal; never set it elsewhere. |
| Local time | `PlanetClock.minutes` | Its own tick, and `start_mission()` re-rolling it within a start period. See [ADR 0002](../adr/0002-one-planet-clock.md). |
| Ship state | `Lander.state` | `Lander.enter()`. Held, loading and lift-off-blocked are flags beside the state, set by the Office or the Economy. |
| Delivery phase | `Economy.phase` | One function per transition, each checking the phase it leaves (see [domain-model.md](domain-model.md#mission-and-delivery-phase)). |
| Money, offers, Contracts | `Economy` | `accept()`, `remove_contract()`, `finish_unloading()`, `cancel_mission()`. |
| Sky | none (derived) | The World pulls `SkyLook.at(minutes)` once per in-game minute and pushes it to every decor script's `show_sky()`. |

## Frame and pause model

- **Gameplay ticks in `_physics_process`** (Lander, PlanetClock, Economy, World's sky check and drift feed), so `--fixed-fps 60` tests are deterministic. Decor movement (clouds, vehicles, Activity) and the Office's animations use `_process`.
- **The Office pauses the whole tree** while showing. The Economy runs with process mode Always (offer timers keep running); the planet clock stays pausable (time stops). See [ADR 0003](../adr/0003-run-state-in-scene-nodes.md).
- **Restart reloads the scene.** That is the whole reset mechanism; see ADR 0003.
- **Ready order matters:** `Station` must stay above `Lander` in `main.tscn` (README, Gotchas).

## Building a location

`PlanetClock.move_to()` → `location_changed` → `World.show_location(to)`:

1. Moves and resizes the `Ground` body (the only landable collider) and the pad on it.
2. Builds each decor script afresh from the location's data, anchored on `to.pad_top()`, then applies the current sky.
3. Dresses the Mountains in `to.mountains` (their colliders never change) and rebuilds `Terrain` (colliders and visuals) from `to.terrain`.

Adding a location means adding data to `location.gd` and listing it in `Location.ALL` (which is also the drift order); its Foreground must keep the Approach corridor rules in the README's Gameplay rules.

## Rendering rules

- **Solid vs decor** is a hard boundary: only `Ground`, `Mountains` and `Terrain` collide, and solids keep their own material colours. See [ADR 0005](../adr/0005-solid-terrain-vs-decor.md).
- **Parallax decor lives in an `AnchoredParallax` anchored on the pad's top**, never moved by hand from the camera. See ADR 0005.
- **Decor is built once per location, then only tinted or moved** until the location changes. See [ADR 0006](../adr/0006-decor-tinted-never-rebuilt.md).
- **`World.shown_decor()` and `World.shown_stars()`** list what's drawn, for tests; each decor script contributes through `listed_decor()`. See [ADR 0004](../adr/0004-one-test-seam-the-main-scene.md).

## Conventions without a recorded reason

These are consistent in the code but no issue or ADR says why. Treat them as the current pattern, and record a reason (or a change) in an ADR if you touch them:

- Game content (ship types, locations, decor layouts) is GDScript data in `static var` tables (`ShipType.ALL`, `Location.ALL`), not Godot resource files.
- The Terminal is drawn by hand on one `Control` (`_draw` calls), not built from Godot UI controls.
