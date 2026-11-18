# Architecture overview

How the game's scripts group into systems, which way they depend on each other, and who owns which state. Each script's role is in its header comment, the cross-cutting gotchas in the root [`README.md`](../../README.md), and the rules each system implements in [`docs/gameplay/`](../gameplay/); this page is the map between them. Terms are defined in [`GLOSSARY.md`](../../GLOSSARY.md), and their relationships in [`domain-model.md`](domain-model.md).

## Shape

One Godot 4.7 project, GDScript only, one scene (`main.tscn`). Every script sits at the repo root; tests in `tests/`, the capture tool in `tools/`. Each script either is attached to a node in `main.tscn`, is a node another script builds at runtime, or is a plain data class (`RefCounted`) with no node.

## Scene tree

`main.tscn`; names in parentheses are nodes a script adds at runtime.

```
Main (Node2D)                  world.gd; draws the surface gradient behind everything
├── (MeshInstance2D) ×2        world.gd adds the deep-space and night star layers at runtime
├── (Moons)                    moons.gd; world.gd adds it at runtime and builds the current location's Moons in it (an AnchoredParallax holding a Polygon2D each)
├── (Clouds)                   clouds.gd; world.gd adds it at runtime and builds the current location's clouds in it (one AnchoredParallax of Polygon2Ds per depth; its wisps go in its near node, added after the Foreground)
├── (Backdrop)                 backdrop.gd; world.gd adds it at runtime and builds the current location's ridges in it (an AnchoredParallax holding a Polygon2D each)
├── (Activity)                 activity.gd; world.gd adds it at runtime and builds the current location's warning lights and slow movers in it (one AnchoredParallax per Backdrop depth)
├── (Vehicles)                 vehicles.gd; world.gd adds it at runtime and builds the current location's flying vehicles in it (one AnchoredParallax per depth of hulls, each with its light and trail)
├── Ground (StaticBody2D)      flat floor, wider than the world; world.gd moves it to the current location's height
│   ├── Polygon2D              visual; scenery, dimmed at night
│   ├── CollisionShape2D
│   └── Pad (Polygon2D)        visual only; world.gd sets its shape and puts it at the current location's pad centre
│       └── (Beacon)           beacon.gd; world.gd adds it at runtime: the pad's edge lights and their glows
├── PlanetClock (Node)         planet_clock.gd; the local time, the current location and the drift count; pauses with the tree
├── Terrain (StaticBody2D)     empty; world.gd builds the current location's terrain (scenery) here, afresh on each location change
├── (CityLights)               city_lights.gd; world.gd adds it at runtime, just after Terrain: the window mesh, neon signs and warning lights
├── Mountains (StaticBody2D)   empty; world.gd adds both mountains' colliders and, per location, their visuals (scenery) at runtime
├── Station (StaticBody2D)     station.gd; adds its wall polygons at runtime
├── Lander (CharacterBody2D)   lander.gd; flies the ship in service, which the Hangar hands it (fly()) and docks (start_docked())
│   ├── Body (Polygon2D)       ship type's hull, set at runtime by fly()
│   ├── Flame (Polygon2D)      ship type's flame, shown while thrusting
│   ├── CollisionPolygon2D     same hull as Body
│   └── Camera (Camera2D)      camera.gd
├── Hangar (Node)              hangar.gd; the owned ships and the ship in service; its _ready() puts SPARROW 1 in service
├── UI (CanvasLayer)
│   ├── Message (Label)        shows Docked!/Landed!/Crashed!, hidden in flight
│   └── Hud (Control)          hud.gd; full-rect, draws itself on the right edge
├── Economy (Node)             economy.gd; process mode Always, so it keeps running while the Office pauses the tree
├── Office (CanvasLayer)       office.gd; layer 10, process mode Always; pauses the tree while showing
│   └── Terminal (Control)     full-rect; office.gd draws the Terminal and popups on it
└── (Foreground)               foreground.gd; world.gd adds it at runtime, last, so it's drawn over the ship; an AnchoredParallax holding a Polygon2D per silhouette
```

## Systems

| System | Scripts | Owns |
|---|---|---|
| **Flight** | `lander.gd`, `camera.gd`, `station.gd`, `ship_type.gd` | The ship's state (Flying, Landed, Docked, Crashed), position, mass and Load, and burning and refuelling the fuel in tank of the ship in service; the station maze and parking spot; the ship type table. |
| **Hangar** | `hangar.gd`, `owned_ship.gd` | The owned ships, the ship in service and the per-type name counters (run state, ADR 0003). `OwnedShip` is data: its Ship type, name, fuel in tank, Condition, and its effective numbers. |
| **Surface** | `world.gd`, `location.gd`, `mountain_look.gd` | Building the current location: ground, pad, terrain, the Mountains' look, and hosting the decor. The location table (pure data). |
| **Planet clock and sky** | `planet_clock.gd`, `sky_look.gd` | Local time, the current location and the drift count (`PlanetClock`); time → sky look, a pure step (`SkyLook`). |
| **Decor** | `backdrop.gd`, `skyline.gd`, `moons.gd`, `clouds.gd`, `foreground.gd`, `beacon.gd`, `city_lights.gd`, `activity.gd`, `vehicles.gd`, `anchored_parallax.gd`, `decor_kit.gd` | Collider-free scenery, built per location and tinted by the sky. |
| **Economy** | `economy.gd`, `transport_offer.gd` | Balance, transactions, offer pool, Contracts and the delivery phase. `TransportOffer` is pure data plus the offer generator. |
| **Office** | `office.gd`, `transport_offers_screen.gd`, `bank_account_screen.gd`, `expandable_list.gd`, `version.gd` | The Terminal UI: screens, popups, input while paused. Screens are `RefCounted` helpers the Office creates and draws on its one `Terminal` control. |
| **HUD** | `hud.gd` | Fuel bar, mass, clock line, deadline and payout float. Read-only. |

## Dependencies

Nodes find each other by fixed `NodePath`s (`$"../Lander"`); there is no autoload or service locator. Arrows mean "holds a reference to and calls":

```
Office ──► Lander, Hangar, Economy, PlanetClock
Hangar ──► Lander
Economy ─► Lander, PlanetClock
Hud ─────► Lander, Economy, PlanetClock          (read only)
World ───► PlanetClock, Lander, every decor script
Lander ──► World (current pad, World constants), Station, Ground
Camera ──► Lander (its parent), World and Station constants
```

- **Data tables sit at the bottom.** `Location`, `ShipType`, `TransportOffer`, `SkyLook`, `MountainLook` and `Skyline` hold no node references. `Location` does name the decor scripts' inner data types (`Backdrop.Ridge`, `Clouds.Cloud`, …), so the location table depends on the decor scripts' data shapes, not their nodes.
- **`World` has no per-location code.** Everything location-specific is data in `location.gd`; the World builds whatever the current `Location` lists.
- **The Lander flies an `OwnedShip`, never a bare `ShipType`.** It reads the ship in service's effective numbers (`ship.thrust()`, `ship.tank()`…), and its `ship_type`, `dry_mass` and `fuel` read through to that ship. It doesn't know the Hangar: the Hangar hands it the ship with `fly()` and docks it with `start_docked()`.
- **The Lander doesn't know the Economy, the Hangar or the Office.** They drive it through its public methods (`hold()`, `release()`, `start_docked()`, `start_loading()`, `finish_loading()`, `show_status()`, `lift_off_blocked`) and hear from it only through signals.
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
| Owned ships, the ship in service, name counters | `Hangar` | Its named operations: `replace_in_service()` (the Ship swap), `add_ship()`, `put_in_service()`. The Office calls them and never edits an `OwnedShip`. The one exception: the Lander burns and refuels the fuel in tank of the ship in service. |
| Sky | none (derived) | The World pulls `SkyLook.at(minutes)` once per in-game minute and pushes it to every decor script's `show_sky()`. |

## Frame and pause model

- **Gameplay ticks in `_physics_process`** (Lander, PlanetClock, Economy, World's sky check and drift feed), so `--fixed-fps 60` tests are deterministic. Decor movement (clouds, vehicles, Activity) and the Office's animations use `_process`.
- **The Office pauses the whole tree** while showing. The Economy runs with process mode Always (offer timers keep running); the planet clock stays pausable (time stops). See [ADR 0003](../adr/0003-run-state-in-scene-nodes.md).
- **Restart reloads the scene.** That is the whole reset mechanism; see ADR 0003.
- **Ready order matters:** `Station` must stay above `Lander`, and `Hangar` below `Lander` and above `UI`, `Economy` and `Office`, in `main.tscn` (see the README's Gotchas).

## Building a location

`PlanetClock.move_to()` → `location_changed` → `World.show_location(to)`:

1. Moves and resizes the `Ground` body (the only landable collider) and the pad on it.
2. Builds each decor script afresh from the location's data, anchored on `to.pad_top()`, then applies the current sky.
3. Dresses the Mountains in `to.mountains` (their colliders never change) and rebuilds `Terrain` (colliders and visuals) from `to.terrain`.

Adding a location means adding data to `location.gd` and listing it in `Location.ALL` (which is also the drift order); its Foreground must keep the Approach corridor rules in [`docs/gameplay/world-and-scenery.md`](../gameplay/world-and-scenery.md) (Foreground).

## Rendering rules

- **Solid vs decor** is a hard boundary: only `Ground`, `Mountains` and `Terrain` collide, and solids keep their own material colours. See [ADR 0005](../adr/0005-solid-terrain-vs-decor.md).
- **Parallax decor lives in an `AnchoredParallax` anchored on the pad's top**, never moved by hand from the camera. See ADR 0005.
- **Decor is built once per location, then only tinted or moved** until the location changes. See [ADR 0006](../adr/0006-decor-tinted-never-rebuilt.md).
- **`World.shown_decor()` and `World.shown_stars()`** list what's drawn, for tests; each decor script contributes through `listed_decor()`. See [ADR 0004](../adr/0004-one-test-seam-the-main-scene.md).

## Conventions without a recorded reason

These are consistent in the code but no issue or ADR says why. Treat them as the current pattern, and record a reason (or a change) in an ADR if you touch them:

- Game content (ship types, locations, decor layouts) is GDScript data in `static var` tables (`ShipType.ALL`, `Location.ALL`), not Godot resource files.
- The Terminal is drawn by hand on one `Control` (`_draw` calls), not built from Godot UI controls.
