# Lunar Lander

A minimal 2D Lunar Lander built in **Godot 4.7.2** with GDScript, targeting **browser (Web) export**.

This repo is a playground for the whole game-making process: trying mechanics and gameplay, then building, deploying, publishing, and running the game live. Features are added in small, playable increments. This README is the shared context every AI agent reads first, so it stays an index: detail lives where the table below says, and CI fails if this file passes 16 384 bytes. Commit messages, PR titles, versioning and releases follow `CLAUDE.md`. New contributors start with `CONTRIBUTING.md` (in Polish).

## Current state

Every start opens on the Office, a retro green-on-black Terminal where the player buys ships in the Shipyard, picks the ship in service from the Hangar (or sells one), browses Transport offers and accepts them as Contracts and starts loading them, and checks the Bank account. Contracts are flown down to the pad, unloaded and paid out into the Bank account. Then a scrolling two-area world: a surface with gravity, mountains and a landing pad, at one of three locations (the Valley, the Mine, an open-pit mine, or the Metropolis, a city with its pad on a rooftop), and gravity-free deep space with a maze-like station to dock in. Fuel, ship weight (with a Load that counts toward it), and refuelling on the pad and at the station. Touching terrain damages the ship's Condition by impact speed and bounces it; only a hard hit crashes. A crash doesn't end the Career: the ship becomes a Wreck, R recovers it to the Office for a fee (failing any Contracts aboard), and it's repaired on its Ship page, on credit if need be. Not yet set up: Web export preset, deployment, publishing, any live/production tooling.

## Where to read more

Read only what the task touches:

| Read | When the task touches |
|---|---|
| [`docs/gameplay/flight.md`](docs/gameplay/flight.md) | Controls, ship types, mass and fuel, the Border, steering, the station and docking, landing and crashing, Recovery, the HUD |
| [`docs/gameplay/office.md`](docs/gameplay/office.md) | The Terminal and its screens, the Shipyard, the Hangar and Ship pages, Transport offers and Contracts, loading, cancelling, free flight, unloading, payout, ship swap |
| [`docs/gameplay/world-and-scenery.md`](docs/gameplay/world-and-scenery.md) | The world's layout and locations, the planet clock and drift, the Backdrop, clouds, Foreground and Approach corridor, city lights, the sky |
| The header comment of a script | What that script does, its API and its local traps (read it before editing the script) |
| [`tests/README.md`](tests/README.md) | Writing or changing a test: runner behaviour, helpers and read-outs |
| [`GLOSSARY.md`](GLOSSARY.md) | What a domain term means |
| [`docs/README.md`](docs/README.md) | Architecture (scene tree, dependencies, owners of state), the domain model, ADRs, agent workflow, and which document a change must update |

## Files

Every script sits at the repo root.

- `main.tscn`: the only scene, and the main scene (F5 runs it). Its tree is in `docs/architecture/overview.md`.
- `project.godot`: renderer settings, black clear colour (deep space), main scene, the `restart` input action (R: Recovery after a crash; it never restarts), the enabled `godot_mcp` editor plugin. The Office uses Godot's built-in `ui_*` actions.
- **Flight:** `lander.gd` (flight physics, fuel, mass, Border, steering, landing and docking judgement, contact damage and bounce, Stranded, refuelling, the R key), `ship_type.gd` (the ship type table), `owned_ship.gd` (an Owned ship and its effective numbers), `hangar.gd` (the owned ships, the ship in service, wrecking, Recovery and repair), `station.gd` (the station maze and parking spot), `camera.gd` (follows, zooms, shakes), `hud.gd` (fuel bar, mass, Condition and its losses, clock line, deadline, payout).
- **Surface:** `world.gd` (layout constants, the current location's ground, pad, terrain and Mountains, hosts the decor and the sky), `location.gd` (the location table), `mountain_look.gd` (the Mountains' look per location).
- **Clock and sky:** `planet_clock.gd` (local time, current location, drift, time formatters), `sky_look.gd` (local time → sky look, one pure step).
- **Decor:** `backdrop.gd` (ridges behind the surface), `skyline.gd` (the Metropolis's skyline), `moons.gd`, `clouds.gd`, `foreground.gd` (silhouettes in front of the ship), `beacon.gd` (the pad's lights), `city_lights.gd`, `activity.gd` (the Mine's warning lights and slow movers), `vehicles.gd` (flying vehicles), `anchored_parallax.gd` (a parallax layer anchored on the pad), `decor_kit.gd` (shared helpers).
- **Economy:** `economy.gd` (balance, offer pool, Contracts, delivery phase, settlement, crash settlement, ship purchases, sales and repairs), `transport_offer.gd` (a Transport offer or Contract, and the offer generator), `transaction.gd` (one change of the balance and how it reads).
- **Office:** `office.gd` (the Terminal, its main screen, popups and notices, Recovery, and keeping a Wreck from leaving), `shipyard_screen.gd`, `hangar_screen.gd` (the berths table and each Ship page), `transport_offers_screen.gd`, `bank_account_screen.gd`, `expandable_list.gd` (a list whose rows open), `version.gd` (`GameVersion.VERSION`, bumped by release-please).
- `fonts/`: `Silkscreen-Regular.ttf` and its `OFL.txt` (ADR 0001).
- `addons/godot_mcp/`: the vendored Godot Editor MCP addon, editor-only, so agents can drive the editor (ADR 0007). Update it with its server, never edit it by hand.
- `tests/`: headless tests (`run_tests.gd`, `scene_test.gd`, `test_*.gd`). `tools/capture.gd`: the screenshot and frame-time tool. `tools/roadmap/`: builds the roadmap page from GitHub Issues (Python, run by CI; not part of the game).

## Constraints

- **Compatibility renderer only** (`gl_compatibility`). Godot's Web export supports only this renderer; keep it when changing project settings.
- **Godot-native nodes and GDScript only.** No external assets except bundled OFL fonts (see ADR 0001), and no addons or GDExtensions in the game; shapes are drawn with `Polygon2D` or `_draw`. The one exception is the editor-only `addons/godot_mcp` (ADR 0007): game code never depends on it.
- **Stay minimal:** the smallest change that makes a feature playable. Add a new scene or script only when one file genuinely stops being readable.
- **Read screen size at runtime** with `get_viewport_rect()`. The window uses `canvas_items` stretch with `expand` aspect, so the visible area changes with window shape.

## Code conventions

- Tuning values are `UPPER_SNAKE` constants at the top of the script, grouped by topic; those constants are the source of truth for the numbers. The ship types (`ShipType.SPARROW`, `MULE`, `HALO`, `ALL`) are named like constants too, but are `static var`s because GDScript can't build objects in a `const`; never reassign them (tests may append a temporary entry to `ALL` and remove it again).
- Each script opens with a header comment: its role, API and local traps. Keep it current when the script changes.
- Node references are `@onready var` with typed `$Path` lookups.
- Static typing everywhere (`:=`, typed parameters and return values).
- Comments only for non-obvious reasons (see the `move_and_slide()` note in `lander.gd`).

## Gotchas

Traps that span several scripts. Traps tied to one place are comments at that code.

- Only `Ground` on the pad is landed on: touching anything else (the ground off the pad, the mountains, a location's terrain, the station) is a hit that damages the ship by impact speed and bounces it (ADR 0009). Neither the pad nor the parking spot has a collider.
- The pad's position, the ground's height and width, and the lowest point all come from the current location (`World.location`, owned by the planet clock), never from a constant: `GROUND_TOP_Y`/`GROUND_BOTTOM_Y` are only the Valley's. Details in `world.gd`'s header.
- Siblings in `main.tscn` become ready in order: `Station` must stay above `Lander` (docking reads `station.parking_spot`), and `Hangar` below `Lander` (its `_ready()` docks SPARROW 1) and above `UI`, `Economy` and `Office` (they read the ship in service).
- The Office pauses the whole tree (`get_tree().paused`) while showing; only the Office (process mode Always) handles input then. R is handled by the Lander, so it does nothing while the Office is showing. `SceneTree.paused` survives a scene reload; the new Office sets it again in `_ready()`. Anything that must keep running behind the Office (the Economy) needs process mode Always too. Keep Career state in scene nodes (no autoload, no static state): a fresh start (a scene reload) wipes it, and a crash never reloads (ADR 0008). The planet clock is the opposite of the Economy: it must stop behind the Office, so it keeps the default (pausable) process mode.
- The Lander's `state` changes only through `enter()`, and the Office, Economy and Hangar drive it only through its public methods (`fly()`, `hold()`, `release()`, `start_docked()`, `start_loading()`, `show_status()`…). The rules are in `lander.gd`'s header.
- The sky is one pure step (`SkyLook.at()`), and the World only draws from it: keep time-of-day looks there, never in the clock. Solid scenery dims through `self_modulate`, so its own `color` stays the day colour; a new solid visual (such as a location's terrain) joins with `World.add_scenery(visual)` once it's in the tree. Don't put the pad (or anything under `Ground` other than its visual) in the scenery group, and don't modulate `Ground` itself: the pad is its child.
- Parallax decor goes in an `AnchoredParallax` (a `Parallax2D`), never moved by hand from the camera: anchored on the current pad's top, it's in its designed place with the camera centred there. `World.shown_decor()` places a parallax piece with `offset_for()` for the camera it's given (not the actual one), so a new parallax piece is listed right by just living in such a layer. Decor that must not show an edge (Backdrop ridges) reaches far past the side overhang and the lowest point; nothing in a parallax layer has a collider.
- Decor never redraws or rebuilds after it's built (ADR 0006). Moving and blinking decor only changes node positions or `modulate`; city windows and stars are one mesh each. Recolouring with the sky only sets tints (`self_modulate` or `modulate`): a `Polygon2D` re-triangulates whenever its `color` or `vertex_colors` change, which on the big ridge, skyline and cloud outlines costs a visible hitch (~20–50 ms) each in-game minute. So the Backdrop's ridges and structures, the vehicles' hulls and the Mine's movers are white polygons tinted by their `self_modulate` (`Backdrop.color_of()` reads it), and each cloud's shading is set once when it's built. A `Polygon2D` with `vertex_colors` ignores its `color` entirely.

## Running and validating

Godot 4.7.2 isn't assumed to be on `PATH`: `Godot` below stands for your editor binary (on the maintainer's Mac, `~/Downloads/Godot.app/Contents/MacOS/Godot`). The committed `.claude/settings.json` pre-allows these commands for agents.

- **Agents: prefer the Godot MCP server** whenever its editor bridge is connected (`godot_health_check`): use it to parse-check scripts, read scenes and nodes, edit scenes and smoke-run (`godot_runtime_run_and_capture`). Run the tests with the command below even then: MCP has no test runner, and that command is what CI runs. Screenshots of the running game also stay on the capture tool below, since MCP's runtime tools need a probe autoload the game doesn't register (ADR 0007). Without a connected editor, use the commands below.
- **Play:** open the project in the editor and press F5.
- **Import / parse check:** `Godot --headless --path . --import` (run it first in a fresh checkout).
- **Smoke run** (prints any script errors): `Godot --headless --path . --quit-after 600`
- **Tests:** `Godot --headless --path . --fixed-fps 60 -s tests/run_tests.gd` runs every test and exits non-zero if any fails. Writing tests: `tests/README.md`.
- **CI** (`.github/workflows/test.yml`, job `test`) checks this README's size, then runs the import and the tests on Linux on every PR and push to `main`; `main` requires it to pass before a merge.
- Headless runs don't render anything, so visuals and game feel need a human playtest.
- **Capture tool** (a review aid; no test depends on it): `Godot --path . -s tools/capture.gd -- --out=<dir>` (not `--headless`: it renders in a window). It saves screenshots of every location by day (13:00) and at night (01:00) with the ship on the pad and 300, 700, 1200 and 1800 px above it (`<location>_<day|night>_<height>.png`), plus one beside each Mountain (`<location>_<day|night>_mountains_<left|right>.png`), then prints the frame time at each location. Without `--out` they go to `captures/` in Godot's user data folder.

## What's next

The backlog is GitHub Issues; see `docs/agents/workflow.md`. The [roadmap page](https://pkopczynski.github.io/lunar-lander/) draws it as shipped, now, next and later, rebuilt from Issues by `.github/workflows/roadmap.yml`.
