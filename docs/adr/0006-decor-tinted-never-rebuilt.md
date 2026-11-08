# Decor is built once per location, then only tinted and moved

Decor is built when the World shows a location (`World.show_location()`), and is rebuilt only when the location changes. While a location stays current, nothing rebuilds or redraws its decor: the sky changes it only through `modulate` / `self_modulate`, and motion only through node positions. Recolourable polygons are white and tinted by `self_modulate`; cloud shading is set once at build. Repeated small lights (city and skyline windows, stars) are one mesh each, never drawn one by one.

**Status:** accepted. Recorded on 2026-11-06, after the fact.

## Why

Measured, and recorded in the README's Gotchas. A `Polygon2D` re-triangulates whenever its `color` or `vertex_colors` change: on the big ridge, skyline and cloud outlines that cost a ~20–50 ms hitch every in-game minute (every 0.5 s). Thousands of `draw_circle` stars cost ~8–13 ms every frame. [#68](https://github.com/pkopczynski/lunar-lander/issues/68) set the target: "Nothing is redrawn every frame… against a 60 fps target on an integrated-GPU laptop, and rechecked once a Web export exists." The fix that established the tint-only rule ("perf: stop the view stuttering every half second") shipped in [#67](https://github.com/pkopczynski/lunar-lander/pull/67).

## Consequences

- `Backdrop.color_of()` reads a ridge's `self_modulate`, not its `color`; a `Polygon2D` with `vertex_colors` ignores `color` entirely.
- `tools/capture.gd` prints frame times per location; use it to check a new decor piece's cost.
