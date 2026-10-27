# Lunar Lander

A minimal 2D Lunar Lander built in **Godot 4.7.2** with GDScript, targeting **browser (Web) export**.

This repo is a playground for the whole game-making process: trying mechanics and gameplay, then building, deploying, publishing, and running the game live. Features are added in small, playable increments. This README is the shared context for AI agents generating new features; keep it current when a rule, convention, or constraint changes.

## Current state

A scrolling two-area world: a surface with gravity, mountains and a landing pad, and gravity-free deep space with a maze-like station to dock in. Fuel, ship weight, and refuelling on the pad and at the station. Domain terms are defined in `GLOSSARY.md`. Not yet set up: Web export preset, deployment, publishing, any live/production tooling.

| File | Role |
|---|---|
| `main.tscn` | The only scene, and the main scene (F5 runs it). |
| `world.gd` | World layout constants (`class_name World`), mountains, and the background: surface gradient and stars. Attached to `Main`. |
| `station.gd` | Builds the station maze and picks the parking spot (`class_name Station`). Attached to `Station`. |
| `lander.gd` | Flight physics, fuel and mass, border crossing, steering, landing and docking judgement, refuelling, result display, restart. Attached to `Lander` (`class_name Lander`). |
| `camera.gd` | Follows the lander, zooms with speed, shakes on border crossings (`class_name FollowCamera`). Attached to `Lander/Camera`. |
| `hud.gd` | Draws the fuel bar and weight readout from the lander's state. Attached to `UI/Hud`. |
| `project.godot` | Renderer settings, black clear colour (deep space), main scene, and the `restart`, `weight_up`, `weight_down` input actions. |

Scene tree (`main.tscn`):

```
Main (Node2D)                  world.gd; draws the background behind everything
├── Ground (StaticBody2D)      flat floor, wider than the world
│   ├── Polygon2D              visual
│   ├── CollisionShape2D
│   └── Pad (Polygon2D)        visual only; shape/position set from constants in lander.gd
├── Mountains (StaticBody2D)   empty; world.gd adds both mountains' polygons at runtime
├── Station (StaticBody2D)     station.gd; adds its wall polygons at runtime
├── Lander (CharacterBody2D)   lander.gd
│   ├── Body (Polygon2D)       triangle
│   ├── Flame (Polygon2D)      shown while thrusting
│   ├── CollisionPolygon2D     same triangle as Body
│   └── Camera (Camera2D)      camera.gd
└── UI (CanvasLayer)
    ├── Message (Label)        hidden until a landing or crash
    └── Hud (Control)          hud.gd; full-rect, draws itself on the right edge
```

## Gameplay rules

Tuning values are constants at the top of each script: world layout in `world.gd`, station shape in `station.gd`, flight rules in `lander.gd`, camera in `camera.gd`. Those files are the source of truth for the numbers.

- **World:** a 2000 px wide column. From the bottom: the ground, the surface (with gravity), the border ~2270 px above the pad, deep space (no gravity, ~2600 px tall), and the station, which spans the full width and forms the ceiling.
- **Camera:** follows the lander with smoothing and stays inside the world. Zoom is 1.0 at ≤ 50 px/s, easing out to 0.65 at ≥ 400 px/s.

- **Controls:** Left/Right rotate, Up thrusts along the lander's nose, R restarts (any time), `+`/`-` (also numpad) change the ship's dry mass (a test control, any time). Arrows use Godot's built-in `ui_*` actions; `restart`, `weight_up`, `weight_down` are custom actions bound by physical key.
- **Start:** the lander starts landed on the pad, in the middle of the world, with a full tank.
- **Mass:** total mass = dry mass (default 10 000 kg, 5 000–17 000 kg) + fuel (tank holds 5 000 kg). The factor `w = total / 15 000 kg` divides thrust acceleration, scales gravity by half as much (`1 + 0.5·(w−1)`), and multiplies fuel burn. It changes live as fuel burns or refills. The mass range is chosen so the heaviest ship can still hover.
- **Fuel:** thrust burns fuel; a default full ship empties the tank in ~20 s of thrust. Burn is ×2 for the first 1 s after lifting off the pad (not after undocking), and up to ×2 more when thrusting against the motion (scaled by how directly, and by speed up to 150 px/s). At 0 fuel the engine doesn't fire.
- **Border:** gravity fades smoothly to zero over the 200 px below the border and is zero above it. Deep space flight is pure Newtonian: thrust is still divided by `w`, and there's no drag. Crossing the border either way needs ≥ 150 px/s vertical speed. A slower ship is sprung back to the side it came from. A real crossing shakes the screen for 2 s and starts steering until the ship is 150 px past the line.
- **Steering:** the game takes over rotation, turning the nose up (climbing or nearly still) or down (descending at > 20 px/s). Rotate input is ignored; thrust still works. After a border crossing, speed is also damped to 100 px/s.
- **Sides:** below the mountain tops, the mountains wall both sides and touching them crashes the ship. Above them, both sides are soft walls: within 150 px of an edge, sideways speed toward the edge is damped, the ship is pushed back inward and steered, and it can never pass the edge.
- **Station:** a straight 100 px entry corridor leads from the station's bottom face into a vertical shaft. Three arms branch left and three right, like two back-to-back E letters. On each run, one of the six arm endings, picked at random, holds a chamber with the 120×136 px parking spot (cyan outline). Touching any station wall crashes the ship.
- **Docked** needs the whole ship inside the parking spot, at ≤ 40 px/s, while not thrusting. It then behaves like Landed: the ship zeroes velocity, eases upright, refuels after 2 s, and shows "Docked!". While docked, Left/Right turn the ship in place so it can face the way out. Up undocks it. The ship must leave the spot before it can dock again.
- **Judged on every touchdown:** the result is decided the moment the lander touches the ground. Nothing can save a bounce.
- **Landed** needs all of these at touchdown:
  - vertical speed within its limit
  - horizontal speed within its limit
  - tilt from upright within its limit (angle is wrapped, so any number of full spins doesn't count)
  - lander center within the pad
- **Crashed** is any other touchdown, or touching the mountains or the station.
- **Landed:** the lander turns green, zeroes its velocity, eases upright over 0.3 s and rests (no gravity, no rotation). After 2 s it refuels at half a tank per 6 s until full, showing "Refueling…". Up lifts off at any time, cancelling refuelling. A ship too heavy to climb just settles back, which counts as another landing.
- **Crashed:** physics stops, the lander turns red, and the label shows "Crashed!" plus "Press R to retry". A crash is final.
- **HUD:** right edge, a vertical fuel bar with a brown, wavy, eased fill (frame flashes red when empty), "FUEL" above, total mass in kg below.
- **Restart** reloads the whole scene, so every run starts from the scene's initial state (and the parking spot is re-picked).
- There is no win state: you can fly back down and land on the pad again, as often as you like.

Deliberately not built yet: score, HUD readouts (speed, altitude), terrain generation, sound, explosions, multiple levels.

## Constraints

- **Compatibility renderer only** (`gl_compatibility`). Godot's Web export supports only this renderer; keep it when changing project settings.
- **Godot-native nodes and GDScript only.** No external assets, addons, or GDExtensions; shapes are drawn with `Polygon2D`.
- **Stay minimal:** the smallest change that makes a feature playable. Add a new scene or script only when one file genuinely stops being readable.
- **Read screen size at runtime** with `get_viewport_rect()`. The window uses `canvas_items` stretch with `expand` aspect, so the visible area changes with window shape.

## Code conventions

- Tuning values are `UPPER_SNAKE` constants at the top of the script, grouped by topic.
- Node references are `@onready var` with typed `$Path` lookups.
- Static typing everywhere (`:=`, typed parameters and return values).
- Comments only for non-obvious reasons (see the `move_and_slide()` note in `lander.gd`).

## Gotchas

- `move_and_slide()` removes the velocity pushing into the ground, so the impact velocity is saved *before* the call. Any new touchdown rule must read that saved value.
- Any collision with something other than `Ground` (mountains, station) is a crash; only ground contacts go to landing judgement.
- The parking spot has no collider either; docking checks that every hull vertex is inside the spot's `Rect2`.
- The station's walls are the station block minus the union of passage rectangles (`Geometry2D`). The entry cut reaches below the block so that the result is one polygon with no holes. Keep passages overlapping when changing the layout.
- The pad has no collider; landing is judged against the ground collider, and the "on the pad" check compares x positions. The pad only appears at runtime, because `_ready()` builds its shape.
- After a crash, `set_physics_process(false)` freezes the lander. Restart and weight keys are handled in `_unhandled_input`, which keeps running. A landing doesn't freeze physics; the `landed` flag skips gravity and judging instead.
- Leveling after a landing lifts the corner that touched down, so the level tween ends with a `move_and_collide()` back onto the ground.

## Running and validating

Godot isn't on `PATH`; the editor binary is `~/Downloads/Godot.app/Contents/MacOS/Godot`.

- **Play:** open the project in the editor and press F5.
- **Import / parse check:** `Godot --headless --path . --import`
- **Smoke run** (prints any script errors): `Godot --headless --path . --quit-after 600`
- **Rule tests:** there's no test suite in the repo yet. For rule changes, write a temporary `extends SceneTree` script, run it with `Godot --headless --path . -s <script>`, and have it instantiate `main.tscn`, set `landed = false` (runs start landed) and the lander's position, velocity and rotation (and `in_deep_space` when placing it above the border), step physics frames, and read `UI/Message`. Headless runs don't render anything, so visuals and game feel need a human playtest.

## Roadmap

Rough order; each step should stay playable:

1. Web export preset and a local browser test.
2. Gameplay depth: a HUD with speed and altitude, terrain, and a reason to replay (score or levels).
3. Deploying and publishing (e.g. itch.io or GitHub Pages) through a repeatable build.
4. Live production: versioning, release notes, analytics or error reporting, and handling hotfixes.
