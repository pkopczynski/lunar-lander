class_name Beacon
extends Node2D
# The pad's Beacon: a small light on each of the pad's edges, pulsing slowly, with a soft glow
# around it that grows as the sky darkens. It's a child of the pad, so it follows the pad to
# every location. It has no collider, and it's never dimmed: the sky only strengthens its glow.

# Tuning, expected to change in playtests.
const LIGHT_COLOR := Color(1.0, 0.85, 0.3)
const LIGHT_RADIUS := 3.0
const GLOW_RADIUS := 16.0
# The glow's opacity by day and at full night, blended by the sky's darkness.
const GLOW_DAY_ALPHA := 0.12
const GLOW_NIGHT_ALPHA := 0.45
# One slow pulse, light and glow together, between PULSE_MIN and full opacity.
const PULSE_PERIOD := 2.4
const PULSE_MIN := 0.55
# Sides of the polygon each light and glow is drawn as.
const SIDES := 16

# The pieces World.shown_decor() lists, lights first.
var lights: Array[Polygon2D] = []
var glows: Array[Polygon2D] = []
var pulse_time := 0.0


func _ready() -> void:
	for edge in [-Lander.PAD_WIDTH / 2.0, Lander.PAD_WIDTH / 2.0]:
		# Each light stands on the pad's top, at its edge.
		var at := Vector2(edge, -Lander.PAD_HEIGHT - LIGHT_RADIUS)
		var glow := disc(at, GLOW_RADIUS, LIGHT_COLOR)
		glow.self_modulate.a = GLOW_DAY_ALPHA
		glows.append(glow)
		lights.append(disc(at, LIGHT_RADIUS, LIGHT_COLOR))
	pulse(0.0)


# The pulse only changes this node's modulate, so nothing is redrawn as it pulses.
func _process(delta: float) -> void:
	pulse(delta)


func pulse(delta: float) -> void:
	pulse_time = fposmod(pulse_time + delta, PULSE_PERIOD)
	var wave := (1.0 - cos(TAU * pulse_time / PULSE_PERIOD)) / 2.0
	modulate.a = lerpf(PULSE_MIN, 1.0, wave)


# Strengthens the glow with the sky's darkness; the lights themselves are never dimmed.
func show_sky(sky: SkyLook) -> void:
	for glow in glows:
		glow.self_modulate.a = lerpf(GLOW_DAY_ALPHA, GLOW_NIGHT_ALPHA, sky.night())


func disc(at: Vector2, radius: float, color: Color) -> Polygon2D:
	var points := PackedVector2Array()
	for side in SIDES:
		points.append(at + Vector2.from_angle(TAU * side / SIDES) * radius)
	var visual := Polygon2D.new()
	visual.polygon = points
	visual.color = color
	add_child(visual)
	return visual
