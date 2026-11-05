class_name CityLights
extends Node2D
# A location's city lights, drawn over its buildings: lit windows, neon signs and blinking warning
# lights on roofs and the antenna. The World builds them afresh from the location whenever it shows
# one. They have no collider and are never dimmed: by day they're faint, and they grow brighter as
# the sky darkens. All the windows are one mesh built once; the sky only sets this node's
# modulate, and the warning lights blink through their own, so nothing is redrawn as time passes.

# Tuning, expected to change in playtests.
# How bright the lights are by day, full night being 1, blended by the sky's darkness.
const DAY_BRIGHTNESS := 0.4
const WINDOW_SIZE := Vector2(8, 10)
# From one window to the next, across and down a facade.
const WINDOW_SPACING := Vector2(22, 28)
# The share of a facade's windows that are lit.
const LIT_SHARE := 0.55
const WINDOW_SEED := 65
# Lit windows' tints: warm lamps, pale ones and the odd screen's cool glow.
const WINDOW_TINTS: Array[Color] = [Color(1.0, 0.85, 0.5), Color(1.0, 0.95, 0.75), Color(0.6, 0.85, 1.0)]
const WARNING_COLOR := Color(1.0, 0.15, 0.1)
const WARNING_RADIUS := 3.0
# Each warning light is on for the first half of its blink and faint for the rest.
const BLINK_PERIOD := 1.6
const BLINK_OFF_ALPHA := 0.15
# Each warning light blinks this much later than the one before it.
const BLINK_STAGGER := BLINK_PERIOD / 5.0
# Sides of the polygon each warning light is drawn as.
const SIDES := 12


# One neon sign: the bar it lights on a building's face, and its colour.
class Sign:
	var area: Rect2
	var color: Color

	func _init(at: Rect2, tint: Color) -> void:
		area = at
		color = tint


# The lit windows in a grid on each facade (a building's face, inside its walls), some lit and some
# not, the same every run.
static func windows_on(facades: Array[Rect2]) -> Array[Rect2]:
	var rng := RandomNumberGenerator.new()
	rng.seed = WINDOW_SEED
	var windows: Array[Rect2] = []
	for facade in facades:
		var columns := floori((facade.size.x - WINDOW_SIZE.x) / WINDOW_SPACING.x) + 1
		var rows := floori((facade.size.y - WINDOW_SIZE.y) / WINDOW_SPACING.y) + 1
		for row in rows:
			for column in columns:
				if rng.randf() < LIT_SHARE:
					windows.append(Rect2(facade.position + Vector2(column, row) * WINDOW_SPACING, WINDOW_SIZE))
	return windows


# The pieces World.shown_decor() lists.
var windows := MeshInstance2D.new()
var signs: Array[Polygon2D] = []
var warning_lights: Array[Polygon2D] = []
var blink_time := 0.0


func _ready() -> void:
	add_child(windows)


# Builds the lights afresh from a location's windows, neon signs and warning lights.
func build(to: Location) -> void:
	for piece in signs + warning_lights:
		remove_child(piece)
		piece.queue_free()
	signs.clear()
	warning_lights.clear()
	windows.mesh = window_mesh(to.windows)
	for neon in to.neon_signs:
		var area := neon.area
		signs.append(add_piece(PackedVector2Array([area.position, Vector2(area.end.x, area.position.y), area.end,
			Vector2(area.position.x, area.end.y)]), neon.color))
	for at in to.warning_lights:
		var points := PackedVector2Array()
		for side in SIDES:
			points.append(at + Vector2.from_angle(TAU * side / SIDES) * WARNING_RADIUS)
		warning_lights.append(add_piece(points, WARNING_COLOR))
	blink(0.0)


func add_piece(outline: PackedVector2Array, color: Color) -> Polygon2D:
	var visual := Polygon2D.new()
	visual.polygon = outline
	visual.color = color
	add_child(visual)
	return visual


# One mesh of all the windows, each tinted in its vertex colours; none when there are no windows.
func window_mesh(rects: Array[Rect2]) -> ArrayMesh:
	if rects.is_empty():
		return null
	var vertices := PackedVector2Array()
	var colors := PackedColorArray()
	for i in rects.size():
		var rect := rects[i]
		var corners := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end,
			Vector2(rect.position.x, rect.end.y)])
		for corner: int in [0, 1, 2, 0, 2, 3]:
			vertices.append(corners[corner])
			colors.append(WINDOW_TINTS[i % WINDOW_TINTS.size()])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _process(delta: float) -> void:
	blink(delta)


# Each warning light blinks through its own modulate, a little out of step with the others.
func blink(delta: float) -> void:
	blink_time = fposmod(blink_time + delta, BLINK_PERIOD)
	for i in warning_lights.size():
		var phase := fposmod(blink_time + i * BLINK_STAGGER, BLINK_PERIOD)
		warning_lights[i].modulate.a = 1.0 if phase < BLINK_PERIOD / 2.0 else BLINK_OFF_ALPHA


# Brightens every light with the sky's darkness; they're never dimmed.
func show_sky(sky: SkyLook) -> void:
	modulate = brightness(sky)


# How bright city lights are under a sky: faint by day, full at night, as a modulate.
static func brightness(sky: SkyLook) -> Color:
	var level := lerpf(DAY_BRIGHTNESS, 1.0, sky.night())
	return Color(level, level, level)
