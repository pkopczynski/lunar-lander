# Lunar Lander

A minimal 2D Lunar Lander built in **Godot 4.7.2** with GDScript, targeting **browser (Web) export**.

This repo is a playground for the whole game-making process: trying mechanics and gameplay, then building, deploying, publishing, and running the game live. Features are added in small, playable increments. This README is the shared context for AI agents generating new features; keep it current when a rule, convention, or constraint changes.

## Current state

A single-screen prototype with landing and crash rules, fuel, ship weight, and refuelling on the pad. Not yet set up: Web export preset, deployment, publishing, any live/production tooling.

| File | Role |
|---|---|
| `main.tscn` | The only scene, and the main scene (F5 runs it). |
| `lander.gd` | Flight physics, fuel and mass, landing judgement, refuelling, result display, restart. Attached to `Lander` (`class_name Lander`). |
| `hud.gd` | Draws the fuel bar and weight readout from the lander's state. Attached to `UI/Hud`. |
| `project.godot` | Renderer settings, main scene, and the `restart`, `weight_up`, `weight_down` input actions. |

Scene tree (`main.tscn`):

```
Main (Node2D)
├── Ground (StaticBody2D)      flat floor, wider than any window
│   ├── Polygon2D              visual
│   ├── CollisionShape2D
│   └── Pad (Polygon2D)        visual only; shape/position set from constants in lander.gd
├── Lander (CharacterBody2D)   lander.gd
│   ├── Body (Polygon2D)       triangle
│   ├── Flame (Polygon2D)      shown while thrusting
│   └── CollisionPolygon2D     same triangle as Body
└── UI (CanvasLayer)
    ├── Message (Label)        hidden until a landing or crash
    └── Hud (Control)          hud.gd; full-rect, draws itself on the right edge
```

## Gameplay rules

All tuning values are constants at the top of `lander.gd`; that file is the source of truth for the numbers.

- **Controls:** Left/Right rotate, Up thrusts along the lander's nose, R restarts (any time), `+`/`-` (also numpad) change the ship's dry mass (a test control, any time). Arrows use Godot's built-in `ui_*` actions; `restart`, `weight_up`, `weight_down` are custom actions bound by physical key.
- **Start:** the lander starts high in the middle with a fixed sideways drift toward the pad. With no input it overshoots the pad and crashes.
- **Mass:** total mass = dry mass (default 10 000 kg, 5 000–17 000 kg) + fuel (tank holds 5 000 kg). The factor `w = total / 15 000 kg` divides thrust acceleration, scales gravity by half as much (`1 + 0.5·(w−1)`), and multiplies fuel burn. It changes live as fuel burns or refills. The mass range is chosen so the heaviest ship can still hover.
- **Fuel:** thrust burns fuel; a default full ship empties the tank in ~20 s of thrust. Burn is ×2 for the first 1 s after lifting off the pad, and up to ×2 more when thrusting against the motion (scaled by how directly, and by speed up to 150 px/s). At 0 fuel the engine doesn't fire.
- **Judged on every touchdown:** the result is decided the moment the lander touches the ground. Nothing can save a bounce.
- **Landed** needs all of these at touchdown:
  - vertical speed within its limit
  - horizontal speed within its limit
  - tilt from upright within its limit (angle is wrapped, so any number of full spins doesn't count)
  - lander center within the pad
- **Crashed** is any other touchdown, or the lander leaving past the left, right, or bottom edge of the viewport. Flying above the top is allowed.
- **Landed:** the lander turns green, zeroes its velocity, eases upright over 0.3 s and rests (no gravity, no rotation). After 2 s it refuels at half a tank per 6 s until full, showing "Refueling…". Up lifts off at any time, cancelling refuelling. A ship too heavy to climb just settles back, which counts as another landing.
- **Crashed:** physics stops, the lander turns red, and the label shows "Crashed!" plus "Press R to retry". A crash is final.
- **HUD:** right edge, a vertical fuel bar with a brown, wavy, eased fill (frame flashes red when empty), "FUEL" above, total mass in kg below.
- **Restart** reloads the whole scene, so every run starts from the scene's initial state.

Deliberately not built yet: score, HUD readouts (speed, altitude), terrain generation, sound, explosions, camera, multiple levels.

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
- The pad has no collider; landing is judged against the ground collider, and the "on the pad" check compares x positions. The pad only appears at runtime, because `_ready()` builds its shape.
- After a crash, `set_physics_process(false)` freezes the lander. Restart and weight keys are handled in `_unhandled_input`, which keeps running. A landing doesn't freeze physics; the `landed` flag skips gravity and judging instead.
- Leveling after a landing lifts the corner that touched down, so the level tween ends with a `move_and_collide()` back onto the ground.
- In `--headless` mode, `get_viewport_rect()` reports 1152×1152, not the windowed 1152×648. Edge tests that depend on the bottom edge need to take this into account.

## Running and validating

Godot isn't on `PATH`; the editor binary is `~/Downloads/Godot.app/Contents/MacOS/Godot`.

- **Play:** open the project in the editor and press F5.
- **Import / parse check:** `Godot --headless --path . --import`
- **Smoke run** (prints any script errors): `Godot --headless --path . --quit-after 600`
- **Rule tests:** there's no test suite in the repo yet. For rule changes, write a temporary `extends SceneTree` script, run it with `Godot --headless --path . -s <script>`, and have it instantiate `main.tscn`, set the lander's position, velocity and rotation, step physics frames, and read `UI/Message`. Headless runs don't render anything, so visuals and game feel need a human playtest.

## Roadmap

Rough order; each step should stay playable:

1. Web export preset and a local browser test.
2. Gameplay depth: a HUD with speed and altitude, terrain, and a reason to replay (score or levels).
3. Deploying and publishing (e.g. itch.io or GitHub Pages) through a repeatable build.
4. Live production: versioning, release notes, analytics or error reporting, and handling hotfixes.
