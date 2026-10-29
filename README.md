# Lunar Lander

A minimal 2D Lunar Lander built in **Godot 4.7.2** with GDScript, targeting **browser (Web) export**.

This repo is a playground for the whole game-making process: trying mechanics and gameplay, then building, deploying, publishing, and running the game live. Features are added in small, playable increments. This README is the shared context for AI agents generating new features; keep it current when a rule, convention, or constraint changes.

## Current state

Every run opens on the Office, a retro green-on-black Terminal where the player picks a ship type. Then a scrolling two-area world: a surface with gravity, mountains and a landing pad, and gravity-free deep space with a maze-like station to dock in. Fuel, ship weight, and refuelling on the pad and at the station. Domain terms are defined in `GLOSSARY.md`. Not yet set up: Web export preset, deployment, publishing, any live/production tooling.

| File | Role |
|---|---|
| `main.tscn` | The only scene, and the main scene (F5 runs it). |
| `world.gd` | World layout constants (`class_name World`), mountains, and the background: surface gradient, the Backdrop's two Tatra-like ridges, and stars. Attached to `Main`. |
| `station.gd` | Builds the station maze and picks the parking spot (`class_name Station`). Attached to `Station`. |
| `ship_type.gd` | The ship type table (`class_name ShipType`): each ship type's name, flavour line, hull and flame shapes, default dry mass, Maximum weight, Tank, thrust, fuel burn, turn rate, and the Offer's THRUST and HANDLING ratings (out of 5 blocks). The Sparrow, the Mule and the Halo (`ShipType.SPARROW`, `ShipType.MULE`, `ShipType.HALO`, listed in `ShipType.ALL` in Offer order). |
| `office.gd` | The Office (`class_name Office`): the Terminal's Offers, browsing, the "ARE YOU SURE?" and Ship swap popups, pausing the world while showing, and drawing the Terminal. Attached to `Office`. |
| `fonts/` | `Silkscreen-Regular.ttf` (the Terminal's pixel font) and its licence `OFL.txt`. See `docs/adr/0001-bundled-pixel-font.md`. |
| `lander.gd` | Flight physics, fuel and mass, border crossing, steering, landing and docking judgement, refuelling, result display, restart. Attached to `Lander` (`class_name Lander`). `start_docked(type)` turns it into a ship type (hull, collision shape and flame, default dry mass, full Tank) Docked in the parking spot. |
| `camera.gd` | Follows the lander, zooms with speed, shakes on border crossings (`class_name FollowCamera`). Attached to `Lander/Camera`. |
| `hud.gd` | Draws the fuel bar and weight readout from the lander's state. Attached to `UI/Hud`. |
| `tests/` | Committed headless tests: `run_tests.gd` (runner), `scene_test.gd` (base class), `test_*.gd` (tests). See "Running and validating". |
| `project.godot` | Renderer settings, black clear colour (deep space), main scene, and the `restart`, `weight_up`, `weight_down` input actions. The Office uses Godot's built-in `ui_left`, `ui_right`, `ui_accept` (Return) and `ui_cancel` (Escape). |

Scene tree (`main.tscn`):

```
Main (Node2D)                  world.gd; draws the background (gradient, Backdrop, stars) behind everything
├── Ground (StaticBody2D)      flat floor, wider than the world
│   ├── Polygon2D              visual
│   ├── CollisionShape2D
│   └── Pad (Polygon2D)        visual only; shape/position set from constants in lander.gd
├── Mountains (StaticBody2D)   empty; world.gd adds both mountains' polygons at runtime
├── Station (StaticBody2D)     station.gd; adds its wall polygons at runtime
├── Lander (CharacterBody2D)   lander.gd; moved into the parking spot by start_docked(type) in _ready()
│   ├── Body (Polygon2D)       ship type's hull, set at runtime by become()
│   ├── Flame (Polygon2D)      ship type's flame, shown while thrusting
│   ├── CollisionPolygon2D     same hull as Body
│   └── Camera (Camera2D)      camera.gd
├── UI (CanvasLayer)
│   ├── Message (Label)        shows Docked!/Landed!/Crashed!, hidden in flight
│   └── Hud (Control)          hud.gd; full-rect, draws itself on the right edge
└── Office (CanvasLayer)       office.gd; layer 10, process mode Always; pauses the tree while showing
    └── Terminal (Control)     full-rect; office.gd draws the Terminal and popups on it
```

## Gameplay rules

Tuning values are constants at the top of each script: world layout in `world.gd`, station shape in `station.gd`, per-ship values in `ship_type.gd`, rules shared by every ship type in `lander.gd`, camera in `camera.gd`. Those files are the source of truth for the numbers.

- **World:** a 2000 px wide column. From the bottom: the ground, the surface (with gravity), the border ~2270 px above the pad, deep space (no gravity, ~2600 px tall), and the station, which spans the full width and forms the ceiling.
- **Camera:** follows the lander with smoothing and stays inside the world. Zoom is 1.0 at ≤ 50 px/s, easing out to 0.65 at ≥ 400 px/s.

- **Controls:** in flight, Left/Right rotate, Up thrusts along the lander's nose, R restarts in deep space (any time, including after a crash; in debug builds, R on the Surface only puts the ship back on the pad, see Restart), `+`/`-` (also numpad) change the ship's dry mass (a test control). In the Office, Left/Right browse Offers or move between popup buttons, Return selects or confirms, Escape counts as No in a popup, and cancels a Ship swap on the Offer screen. Arrows, Return and Escape use Godot's built-in `ui_*` actions; `restart`, `weight_up`, `weight_down` are custom actions bound by physical key.
- **Office:** every run opens on the Office: a full-window Terminal (black, green outlines and text in the Silkscreen pixel font, a border, scanlines) with the header `ORBITAL FREIGHT CO. // FLEET OFFERS` and the key hint `← → BROWSE   RETURN SELECT` (the arrows are drawn, Silkscreen has no arrow glyphs). It shows one Offer at a time: name, flavour line, a wireframe picture of the hull, TANK, DRY MASS and MAX WEIGHT in kg, THRUST and HANDLING as 5-block bars, and a `< n/N >` indicator. Browsing wraps at both ends. Return opens "ARE YOU SURE?" (Yes selected; the selected button is inverted). Yes closes the Office and puts that ship type Docked in the parking spot; No or Escape returns to the same Offer. Escape on the Offer screen does nothing at run start (it cancels a Ship swap, see below). The world is paused while the Office is showing. The Terminal powers on with a ~0.3 s CRT effect (a dot stretches into a bright line, which opens into the picture) and powers off with the reverse; the flight view shows only once power-off is over, and Office input is ignored during the effect. The swap popup over the flight view opens and closes without it.
- **Start:** once a ship type is chosen, the lander is Docked in the centre of the station's parking spot (re-picked at random each run), facing up, at rest, with a full tank. The pad is a destination only: fly out of the maze and down to the surface to land there.
- **Ship types:** each ship type has its own hull, flame, default dry mass, Maximum weight, Tank, thrust, fuel burn and turn rate. Thrust and burn are given at the reference mass. The Sparrow: 10 000 kg default dry mass, 17 000 kg Maximum weight, 5 000 kg Tank, 150 px/s² thrust, 250 kg/s burn, 3.0 rad/s turn rate. The Halo: a C-shaped ring 40 px across with a 16 px hole, open at the nose (concave hull, gap included in the collision shape), flame at the back; 14 000 kg default dry mass, 24 000 kg Maximum weight, 8 000 kg Tank, 214 px/s² thrust, 231 kg/s burn, 2.2 rad/s turn rate (climbs off the pad at ~80% of the Sparrow's rate, and a full tank lasts ~1.2× as long as the Sparrow's). The Mule: a 42×68 px box with its two nose corners rounded to 4 px (back corners square), long axis along the thrust, flame on the short side at the back; 20 000 kg default dry mass, 29 000 kg Maximum weight, 12 000 kg Tank, 316 px/s² thrust, 207 kg/s burn, 1.5 rad/s turn rate (climbs off the pad at ~60% of the Sparrow's rate, and a full tank lasts ~1.4× as long as the Sparrow's). The issue's 35 000 kg Maximum weight for the Mule is superseded: 29 000 kg is the highest at which it still hovers and reaches the border crossing speed at that climb. Thrust-time targets are ratios to the Sparrow's measured full-tank thrust time (~24 s; its nominal Tank / burn is 20 s), not absolute seconds; `tests/test_halo.gd` and `tests/test_mule.gd` check them that way.
- **Mass:** total mass = dry mass (the ship type's default, 5 000 kg up to its Maximum weight) + fuel (up to the Tank). The factor `w = total / 15 000 kg` divides thrust acceleration, scales gravity by half as much (`1 + 0.5·(w−1)`), and multiplies fuel burn. It changes live as fuel burns or refills. Maximum weight is chosen so every ship type can still hover and cross the border.
- **Fuel:** thrust burns fuel; a default full ship empties the tank in ~20 s of thrust. Burn is ×2 for the first 1 s after lifting off the pad (not after undocking), and up to ×2 more when thrusting against the motion (scaled by how directly, and by speed up to 150 px/s). At 0 fuel the engine doesn't fire.
- **Border:** gravity fades smoothly to zero over the 200 px below the border and is zero above it. Deep space flight is pure Newtonian: thrust is still divided by `w`, and there's no drag. Crossing the border either way needs ≥ 150 px/s vertical speed. A slower ship is sprung back to the side it came from. A real crossing shakes the screen for 2 s and starts steering until the ship is 150 px past the line.
- **Steering:** the game takes over rotation, turning the nose up (climbing or nearly still) or down (descending at > 20 px/s). Rotate input is ignored; thrust still works. After a border crossing, speed is also damped to 100 px/s.
- **Sides:** below the mountain tops, the mountains wall both sides and touching them crashes the ship. Above them, both sides are soft walls: within 150 px of an edge, sideways speed toward the edge is damped, the ship is pushed back inward and steered, and it can never pass the edge.
- **Station:** a straight 100 px entry corridor leads from the station's bottom face into a vertical shaft. Three arms branch left and three right, like two back-to-back E letters. On each run, one of the six arm endings, picked at random, holds a chamber with the 120×136 px parking spot (cyan outline). Touching any station wall crashes the ship.
- **Docked** needs the whole ship inside the parking spot, at ≤ 40 px/s, while not thrusting. It then behaves like Landed: the ship zeroes velocity, eases upright, refuels after 2 s, and shows "Docked!". While docked, Left/Right turn the ship in place so it can face the way out. Up undocks it. The ship must leave the spot before it can dock again.
- **Ship swap:** every time the ship docks (not at run start, not on the pad), a popup over the flight view asks "WOULD YOU LIKE TO CHOOSE A DIFFERENT SHIP?" with No selected. Until it's answered the ship is frozen: Up doesn't undock, Left/Right don't turn it, `+`/`-` don't change its dry mass, and the refuel timer doesn't run; R still restarts (the station is in deep space). No or Escape closes it and refuelling starts after the usual 2 s. Yes opens the Office with the current ship type selected and tagged IN SERVICE. Choosing another ship type (through "ARE YOU SURE?") puts it Docked in the same parking spot with a full Tank and its default dry mass; the station isn't rebuilt. Return on the IN SERVICE Offer, or Escape on the Offer screen, cancels the swap and leaves the ship Docked in the parking spot, as if the answer had been No.
- **Judged on every touchdown:** the result is decided the moment the lander touches the ground. Nothing can save a bounce.
- **Landed** needs all of these at touchdown:
  - vertical speed within its limit
  - horizontal speed within its limit
  - tilt from upright within its limit (angle is wrapped, so any number of full spins doesn't count)
  - lander center within the pad
- **Crashed** is any other touchdown, or touching the mountains or the station.
- **Landed:** the lander turns green, zeroes its velocity, eases upright over 0.3 s and rests (no gravity, no rotation). After 2 s it refuels at half a Tank per 6 s until full, showing "Refueling…". Up lifts off at any time, cancelling refuelling. A ship too heavy to climb just settles back, which counts as another landing.
- **Crashed:** physics stops, the lander turns red, and the label shows "Crashed!" plus "Press R to retry". A crash is final.
- **HUD:** right edge, a vertical fuel bar showing how full the current ship type's Tank is, with a brown, wavy, eased fill (frame flashes red when empty), "FUEL" above, total mass in kg below.
- **Restart** reloads the whole scene, so every run starts from the scene's initial state: back on the Office, with the parking spot re-picked. In debug builds (a testing shortcut), R on the Surface (below the border, whether flying, Landed or Crashed) instead puts the ship Landed on the pad, upright and at rest, keeping its ship type, dry mass and fuel; the crash clears. In deep space, and always in release builds, R restarts.
- **Backdrop:** two Tatra-like ridges drawn behind the Surface, with no collision: a farther, jagged High Tatra ridge peaking at the mountain tops near Rysy, and a nearer, rounded ridge with Giewont's sleeping knight. Each is filled with the background gradient, darkened (`FAR_RIDGE_DARKENING`, `NEAR_RIDGE_DARKENING` in `world.gd`). They're fixed in the world (no parallax); the mountains cover their ends.
- There is no win state: you can fly between the station and the pad, docking and landing as often as you like.

Deliberately not built yet: score, HUD readouts (speed, altitude), terrain generation, sound, explosions, multiple levels.

## Constraints

- **Compatibility renderer only** (`gl_compatibility`). Godot's Web export supports only this renderer; keep it when changing project settings.
- **Godot-native nodes and GDScript only.** No external assets except bundled OFL fonts (see ADR 0001), and no addons or GDExtensions; shapes are drawn with `Polygon2D` or `_draw`.
- **Stay minimal:** the smallest change that makes a feature playable. Add a new scene or script only when one file genuinely stops being readable.
- **Read screen size at runtime** with `get_viewport_rect()`. The window uses `canvas_items` stretch with `expand` aspect, so the visible area changes with window shape.

## Code conventions

- Tuning values are `UPPER_SNAKE` constants at the top of the script, grouped by topic. The ship types (`ShipType.SPARROW`, `MULE`, `HALO`, `ALL`) are named like constants too, but are `static var`s because GDScript can't build objects in a `const`; never reassign them (tests may append a temporary entry to `ALL` and remove it again).
- Node references are `@onready var` with typed `$Path` lookups.
- Static typing everywhere (`:=`, typed parameters and return values).
- Comments only for non-obvious reasons (see the `move_and_slide()` note in `lander.gd`).

## Gotchas

- `move_and_slide()` removes the velocity pushing into the ground, so the impact velocity is saved *before* the call. Any new touchdown rule must read that saved value.
- Any collision with something other than `Ground` (mountains, station) is a crash; only ground contacts go to landing judgement.
- The parking spot has no collider either; docking checks that every hull vertex is inside the spot's `Rect2`.
- The station's walls are the station block minus the union of passage rectangles (`Geometry2D`). The entry cut reaches below the block so that the result is one polygon with no holes. Keep passages overlapping when changing the layout.
- The pad has no collider; landing is judged against the ground collider, and the "on the pad" check compares x positions. The pad only appears at runtime, because `_ready()` builds its shape.
- `Station` must stay above `Lander` in `main.tscn`: siblings become ready in order, and the Lander's `_ready()` reads `station.parking_spot` to place the docked start.
- The Office pauses the whole tree (`get_tree().paused`) while showing; only the Office (process mode Always) handles input then. R is handled by the Lander, so it does nothing while the Office is showing. `SceneTree.paused` survives a scene reload; the new Office sets it again in `_ready()`.
- The Lander's `_ready()` still makes it a Docked Sparrow behind the Office; choosing an Offer calls `start_docked(type)` again. `start_docked()` never asks about a swap; only `dock()` does, by emitting `docked_at_station`. The Office answers with the swap popup and calls `lander.hold()`, which freezes `_physics_process` and the weight keys; the Lander doesn't know why it's held. Declining calls `release()`; the refuel delay starts over because docking zeroed it and a held ship doesn't count it down. Choosing a ship type calls `start_docked(type)`, and entering Docked releases the hold.
- The Lander's `state` (Flying, Landed, Docked, Crashed) changes only through `enter()`, which starts every state fresh: not held, no lift-off burn, docking armed, leveling stopped, with the state's colour and message. `start_docked()`, `reset_to_pad()` and `fly_from()` also move the ship and clear any border bounce or steering. `lift_off()` is the only transition that looks at the state it leaves (the lift-off burn from the pad, no re-docking from the spot). Crashed and held make `_physics_process` return early; Landed and Docked skip gravity and judging. Restart and weight keys are handled in `_unhandled_input`.
- Leveling after a landing lifts the corner that touched down, so the level tween ends with a `move_and_collide()` back onto the ground.

## Running and validating

Godot isn't on `PATH`; the editor binary is `~/Downloads/Godot.app/Contents/MacOS/Godot`.

- **Play:** open the project in the editor and press F5.
- **Import / parse check:** `Godot --headless --path . --import`
- **Smoke run** (prints any script errors): `Godot --headless --path . --quit-after 600`
- **Tests:** `Godot --headless --path . --fixed-fps 60 -s tests/run_tests.gd` runs every test and exits non-zero if any fails. In a fresh checkout, run `--import` first. `--fixed-fps 60` makes each frame one physics step without waiting for real time; the tests count physics frames, so they give the same results without it, just slower.
  - The runner loads every `tests/test_*.gd` and calls each `test_*` method on a fresh main scene. A test fails if a `check` fails, if no checks ran, or if any script error is logged while it runs.
  - Every run opens on the Office, so a test that flies calls `await choose_ship()` (or `choose_ship(ShipType.MULE)` etc.) first: it browses to that Offer with `browse_to(type)`, presses Return and confirms Yes, leaving the ship Docked. Office tests read `office()`: `showing`, `selected_offer()`, `offer_lines()` (the Offer's text, ratings as ■/□ blocks), `offer_picture()`, `in_service_shown()`, `popup` (`Office.PopupKind`) and `selected_button` (`Office.Choice`). The Terminal powers on (opening) and off (closing) with a ~0.3 s CRT effect, during which `office().powering` is true and Office input is ignored; `start()`, `choose_ship()` and `restart()` wait it out, and `wait_for_terminal()` does so elsewhere (`restart(false)` skips the wait). `dock_in_spot()` places the ship in the parking spot so it docks, which opens the swap popup: answer it (e.g. `press(&"ui_accept")` for the default No) before testing refuelling.
  - Tests extend `res://tests/scene_test.gd`. They drive the game with real input actions (`press`, `hold`, `release`), wait with `frames(n)` or `seconds(t)`, and check only what a player could observe: the lander's state, position, velocity, fuel, total mass and ship type, and the message text (`message()`, empty while hidden).
  - To set up a start position, call `place(position, velocity)`: it puts the lander Flying there through `fly_from()`, the same transition the game uses. For anything else, set the lander's public state directly. `restart()` presses R and waits for the reloaded scene; since R on the Surface only teleports to the pad, it first moves a ship that's below the border into deep space. `crash_in_deep_space()` crashes the ship into the station's underside.
  - Headless runs don't render anything, so visuals and game feel need a human playtest.

## Roadmap

Rough order; each step should stay playable:

1. Web export preset and a local browser test.
2. Gameplay depth: a HUD with speed and altitude, terrain, and a reason to replay (score or levels).
3. Deploying and publishing (e.g. itch.io or GitHub Pages) through a repeatable build.
4. Live production: versioning, release notes, analytics or error reporting, and handling hotfixes.
