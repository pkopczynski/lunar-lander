class_name Backdrop
extends Node2D
# The Backdrop: the current location's scenery behind its surface, with no collision. The World
# builds it afresh from the location's ridges whenever it shows a location, and recolours it from
# the sky. Each ridge is one Polygon2D filled with the background gradient, darkened, so it reads
# as a shadow of the sky behind it.

# Tatra-like ridges, behind the Valley and (for now) the Mine. Only the top edge is listed; each
# ridge closes down to the location's lowest point. Most of it sits between the mountains, which
# cover its ends.
# The farther ridge: jagged granite High Tatra peaks, tallest near Rysy.
const TATRA_FAR := [
	Vector2(-World.SIDE_OVERHANG, 300), Vector2(150, 300), Vector2(230, 260), Vector2(270, 285),
	Vector2(320, 225), Vector2(350, 250), Vector2(390, 208), Vector2(420, 240),
	Vector2(455, 222), Vector2(490, 270), Vector2(530, 245), Vector2(570, 290),
	Vector2(610, 255), Vector2(650, 300), Vector2(700, 275), Vector2(750, 320),
	Vector2(800, 300), Vector2(860, 340), Vector2(930, 320), Vector2(1000, 350),
	Vector2(1080, 330), Vector2(1160, 345), Vector2(1250, 320), Vector2(1330, 335),
	Vector2(1420, 300), Vector2(1500, 320), Vector2(1580, 285), Vector2(1650, 310),
	Vector2(1720, 290), Vector2(1800, 320), Vector2(1880, 300), Vector2(World.WORLD_WIDTH + World.SIDE_OVERHANG, 300),
]
# The nearer ridge: low rounded ridges and Giewont's sleeping knight (the steep Wielki Giewont,
# the long Długi Giewont, then the small bump of Mały Giewont).
const TATRA_NEAR := [
	Vector2(-World.SIDE_OVERHANG, 420), Vector2(200, 420), Vector2(280, 400), Vector2(360, 380),
	Vector2(440, 395), Vector2(520, 370), Vector2(600, 385), Vector2(680, 360),
	Vector2(760, 375), Vector2(840, 395), Vector2(920, 410), Vector2(1000, 415),
	Vector2(1080, 400), Vector2(1140, 370), Vector2(1180, 330), Vector2(1210, 290),
	Vector2(1235, 255), Vector2(1250, 248), Vector2(1270, 252), Vector2(1300, 268),
	Vector2(1360, 280), Vector2(1420, 292), Vector2(1470, 300), Vector2(1500, 315),
	Vector2(1530, 305), Vector2(1555, 300), Vector2(1590, 320), Vector2(1650, 345),
	Vector2(1720, 330), Vector2(1800, 350), Vector2(1880, 370), Vector2(World.WORLD_WIDTH + World.SIDE_OVERHANG, 380),
]
# How much darker than the background behind it each Tatra ridge is.
const TATRA_FAR_DARKENING := 0.08
const TATRA_NEAR_DARKENING := 0.16


# One ridge of a location's Backdrop: its top edge, left to right, and how much darker than the
# background gradient behind it it's filled.
class Ridge:
	var top_edge: PackedVector2Array
	var darkening: float

	func _init(top: Array, darker: float) -> void:
		top_edge = PackedVector2Array(top)
		darkening = darker


# The Tatra-like ridges, farther first.
static func tatras() -> Array[Ridge]:
	return [Ridge.new(TATRA_FAR, TATRA_FAR_DARKENING), Ridge.new(TATRA_NEAR, TATRA_NEAR_DARKENING)]


# The ridges as drawn, farther first.
var ridges: Array[Polygon2D] = []
var darkenings: Array[float] = []


# Builds the Backdrop afresh from a location's ridges, each closing down to bottom_y.
func build(from: Array[Ridge], bottom_y: float) -> void:
	for visual in ridges:
		remove_child(visual)
		visual.queue_free()
	ridges.clear()
	darkenings.clear()
	for ridge in from:
		var outline := ridge.top_edge.duplicate()
		outline.append(Vector2(outline[-1].x, bottom_y))
		outline.append(Vector2(outline[0].x, bottom_y))
		var visual := Polygon2D.new()
		visual.polygon = outline
		add_child(visual)
		ridges.append(visual)
		darkenings.append(ridge.darkening)


# Fills each ridge with the background gradient (background_color: a world y to its colour),
# darkened.
func show_sky(background_color: Callable) -> void:
	for i in ridges.size():
		var colors := PackedColorArray()
		for point in ridges[i].polygon:
			colors.append((background_color.call(point.y) as Color).darkened(darkenings[i]))
		ridges[i].vertex_colors = colors
