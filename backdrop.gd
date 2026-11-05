class_name Backdrop
extends Node2D
# The Backdrop: the current location's scenery behind its surface, with no collision. The World
# builds it afresh from the location's ridges whenever it shows a location, and recolours it from
# the sky. Each ridge is one Polygon2D filled with the background gradient, darkened, so it reads
# as a shadow of the sky behind it, in its own parallax layer anchored on the pad.

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
# The Metropolis's far skyline, in two depths: each a list of blocks left to right, [right x, roof
# y], the first starting at the world's left side overhang and the last reaching its right one.
# Flat roofs and straight walls, staying below the mountain tops; the nearer one a little lower.
const SKYLINE_FAR := [
	[-200, 360], [-60, 300], [40, 340], [130, 285], [210, 320], [300, 250], [360, 300], [470, 270],
	[540, 330], [610, 235], [680, 290], [790, 310], [860, 255], [960, 330], [1040, 280], [1120, 245],
	[1210, 300], [1300, 270], [1380, 320], [1460, 240], [1540, 290], [1640, 265], [1720, 330], [1800, 275],
	[1900, 310], [2050, 260], [2400, 330], [World.WORLD_WIDTH + World.SIDE_OVERHANG, 300],
]
const SKYLINE_NEAR := [
	[-100, 420], [80, 380], [190, 430], [280, 360], [380, 410], [450, 345], [560, 395], [650, 370],
	[730, 420], [830, 350], [920, 400], [990, 330], [1080, 385], [1170, 420], [1260, 360], [1350, 405],
	[1450, 340], [1520, 395], [1610, 370], [1700, 430], [1790, 365], [1880, 410], [2100, 380],
	[World.WORLD_WIDTH + World.SIDE_OVERHANG, 420],
]
const SKYLINE_FAR_DARKENING := 0.1
const SKYLINE_NEAR_DARKENING := 0.2
# Tuning, expected to change in playtests.
const SKYLINE_FAR_SCROLL := Vector2(0.55, 0.97)
const SKYLINE_NEAR_SCROLL := Vector2(0.7, 0.98)
# How much darker than the background behind it each Tatra ridge is.
const TATRA_FAR_DARKENING := 0.08
const TATRA_NEAR_DARKENING := 0.16
# How fast each Tatra ridge scrolls with the camera, the world's being 1: mostly horizontal, so the
# ridges barely rise into the sky as the ship climbs. Tuning, expected to change in playtests.
const TATRA_FAR_SCROLL := Vector2(0.6, 0.97)
const TATRA_NEAR_SCROLL := Vector2(0.75, 0.98)
# How far below the location's lowest point each ridge reaches, so its bottom never shows as its
# layer rises with a camera above the pad.
const BOTTOM_MARGIN := 200.0
# How far past its first and last points each ridge carries on, level, so its ends never show as its
# layer shifts sideways (a layer anchored on a pad off the world's centre is shifted even with a
# window wider than the world).
const SIDE_MARGIN := 1000.0


# One ridge of a location's Backdrop: its top edge, left to right, how much darker than the
# background gradient behind it it's filled, and how fast it scrolls with the camera (by default
# with the world, as if fixed). Its top edge must reach far enough past both sides of the world to
# cover the view at the world's side overhang; the Backdrop carries it on further (SIDE_MARGIN).
class Ridge:
	var top_edge: PackedVector2Array
	var darkening: float
	var scroll_scale: Vector2

	func _init(top: Array, darker: float, scroll := Vector2.ONE) -> void:
		top_edge = PackedVector2Array(top)
		darkening = darker
		scroll_scale = scroll


# The Tatra-like ridges, farther first.
static func tatras() -> Array[Ridge]:
	return [Ridge.new(TATRA_FAR, TATRA_FAR_DARKENING, TATRA_FAR_SCROLL),
		Ridge.new(TATRA_NEAR, TATRA_NEAR_DARKENING, TATRA_NEAR_SCROLL)]


# The Metropolis's skyline in two depths, farther first.
static func skyline() -> Array[Ridge]:
	return [Ridge.new(skyline_edge(SKYLINE_FAR), SKYLINE_FAR_DARKENING, SKYLINE_FAR_SCROLL),
		Ridge.new(skyline_edge(SKYLINE_NEAR), SKYLINE_NEAR_DARKENING, SKYLINE_NEAR_SCROLL)]


# The top edge of a row of blocks ([right x, roof y] each, left to right), from the world's left
# side overhang: each roof flat, with a straight wall down or up to the next.
static func skyline_edge(blocks: Array) -> Array:
	var edge := []
	var left := -World.SIDE_OVERHANG
	for block in blocks:
		edge.append(Vector2(left, block[1]))
		edge.append(Vector2(block[0], block[1]))
		left = block[0]
	return edge


# The ridges as drawn, farther first.
var ridges: Array[Polygon2D] = []
var darkenings: Array[float] = []


# Builds the Backdrop afresh from a location's ridges, each carried on past both sides and closing
# down past bottom_y, in its own parallax layer anchored on anchor.
func build(from: Array[Ridge], bottom_y: float, anchor: Vector2) -> void:
	for layer in get_children():
		remove_child(layer)
		layer.queue_free()
	ridges.clear()
	darkenings.clear()
	for ridge in from:
		var outline := ridge.top_edge.duplicate()
		outline.insert(0, outline[0] - Vector2(SIDE_MARGIN, 0))
		outline.append(outline[-1] + Vector2(SIDE_MARGIN, 0))
		outline.append(Vector2(outline[-1].x, bottom_y + BOTTOM_MARGIN))
		outline.append(Vector2(outline[0].x, bottom_y + BOTTOM_MARGIN))
		var layer := AnchoredParallax.new(ridge.scroll_scale, anchor)
		add_child(layer)
		var visual := Polygon2D.new()
		visual.polygon = outline
		layer.add_child(visual)
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
