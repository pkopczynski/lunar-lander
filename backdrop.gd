class_name Backdrop
extends Node2D
# The Backdrop: the current location's scenery behind its surface, with no collision. The World
# builds it afresh from the location's ridges whenever it shows a location, and recolours it from
# the sky. Each ridge is one Polygon2D filled with the background gradient, darkened, so it reads
# as a shadow of the sky behind it, in its own parallax layer anchored on the pad.

# Tatra-like ridges, behind the Valley. Only the top edge is listed; each
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
# How fast each Tatra ridge scrolls with the camera, the world's being 1: mostly horizontal, so the
# ridges barely rise into the sky as the ship climbs. Tuning, expected to change in playtests.
const TATRA_FAR_SCROLL := Vector2(0.6, 0.97)
const TATRA_NEAR_SCROLL := Vector2(0.75, 0.98)
# The Metropolis's far skyline, in two depths: each a list of blocks left to right, each
# Vector2(right x, roof y), the first starting at the world's left side overhang and the last
# reaching its right one. Flat roofs and straight walls, staying below the mountain tops; the
# nearer one a little lower.
const SKYLINE_FAR: Array[Vector2] = [
	Vector2(-200, 360), Vector2(-60, 300), Vector2(40, 340), Vector2(130, 285), Vector2(210, 320),
	Vector2(300, 250), Vector2(360, 300), Vector2(470, 270), Vector2(540, 330), Vector2(610, 235),
	Vector2(680, 290), Vector2(790, 310), Vector2(860, 255), Vector2(960, 330), Vector2(1040, 280),
	Vector2(1120, 245), Vector2(1210, 300), Vector2(1300, 270), Vector2(1380, 320), Vector2(1460, 240),
	Vector2(1540, 290), Vector2(1640, 265), Vector2(1720, 330), Vector2(1800, 275), Vector2(1900, 310),
	Vector2(2050, 260), Vector2(2400, 330), Vector2(World.WORLD_WIDTH + World.SIDE_OVERHANG, 300),
]
const SKYLINE_NEAR: Array[Vector2] = [
	Vector2(-100, 420), Vector2(80, 380), Vector2(190, 430), Vector2(280, 360), Vector2(380, 410),
	Vector2(450, 345), Vector2(560, 395), Vector2(650, 370), Vector2(730, 420), Vector2(830, 350),
	Vector2(920, 400), Vector2(990, 330), Vector2(1080, 385), Vector2(1170, 420), Vector2(1260, 360),
	Vector2(1350, 405), Vector2(1450, 340), Vector2(1520, 395), Vector2(1610, 370), Vector2(1700, 430),
	Vector2(1790, 365), Vector2(1880, 410), Vector2(2100, 380),
	Vector2(World.WORLD_WIDTH + World.SIDE_OVERHANG, 420),
]
# How much darker than the background behind it each depth is, and how fast it scrolls. Tuning,
# expected to change in playtests.
const SKYLINE_FAR_DARKENING := 0.1
const SKYLINE_NEAR_DARKENING := 0.2
const SKYLINE_FAR_SCROLL := Vector2(0.55, 0.97)
const SKYLINE_NEAR_SCROLL := Vector2(0.7, 0.98)
# The Mine's Backdrop, farther first, with stronger parallax than the Tatras' (each layer slower).
# Tuning, expected to change in playtests.
# The farther ridge: tall, jagged Himalaya-like peaks towering above the mountain tops, the
# highest an Everest-like pyramid left of the pad.
const HIMALAYA_FAR := [
	Vector2(-World.SIDE_OVERHANG, 260), Vector2(100, 250), Vector2(180, 190), Vector2(240, 215),
	Vector2(330, 130), Vector2(380, 160), Vector2(450, 105), Vector2(520, 170), Vector2(600, 140),
	Vector2(690, 210), Vector2(760, 175), Vector2(850, 120), Vector2(920, 150), Vector2(1000, 75),
	Vector2(1060, 110), Vector2(1120, 95), Vector2(1200, 170), Vector2(1270, 140), Vector2(1360, 200),
	Vector2(1440, 150), Vector2(1520, 185), Vector2(1600, 130), Vector2(1680, 175), Vector2(1760, 210),
	Vector2(1850, 190), Vector2(1950, 240), Vector2(World.WORLD_WIDTH + World.SIDE_OVERHANG, 250),
]
# The nearer ridge: lower, sharp foothills.
const HIMALAYA_NEAR := [
	Vector2(-World.SIDE_OVERHANG, 360), Vector2(150, 350), Vector2(260, 300), Vector2(340, 320),
	Vector2(430, 270), Vector2(520, 310), Vector2(620, 285), Vector2(720, 330), Vector2(820, 300),
	Vector2(900, 340), Vector2(1000, 315), Vector2(1100, 350), Vector2(1200, 320), Vector2(1300, 290),
	Vector2(1380, 330), Vector2(1480, 300), Vector2(1580, 345), Vector2(1700, 320), Vector2(1820, 360),
	Vector2(World.WORLD_WIDTH + World.SIDE_OVERHANG, 360),
]
# The far walls: the open-pit mine's far side, terraced down well below the benches so it looks
# deep, with industrial silhouettes on its rim (a headframe, a chimney) and two cranes, one on a
# deep terrace and one on the right rim. Background only: the one solid crane is the Mine's terrain.
const FAR_WALLS := [
	Vector2(-World.SIDE_OVERHANG, 540), Vector2(300, 540),
	# The headframe.
	Vector2(300, 470), Vector2(315, 470), Vector2(330, 440), Vector2(345, 470), Vector2(360, 470), Vector2(360, 540),
	# The chimney.
	Vector2(420, 540), Vector2(420, 430), Vector2(432, 430), Vector2(432, 540),
	# The far walls' terraces, down to a deep floor.
	Vector2(560, 540), Vector2(560, 575), Vector2(680, 575), Vector2(680, 615), Vector2(800, 615),
	Vector2(800, 655), Vector2(940, 655), Vector2(940, 690),
	# The crane on the deep terrace: its mast, counter-jib and jib reaching right.
	Vector2(1000, 690), Vector2(1000, 618), Vector2(960, 618), Vector2(960, 610), Vector2(1000, 610),
	Vector2(1000, 590), Vector2(1010, 590), Vector2(1010, 610), Vector2(1180, 610), Vector2(1180, 617),
	Vector2(1010, 617), Vector2(1010, 690),
	Vector2(1500, 690), Vector2(1500, 650), Vector2(1580, 650), Vector2(1580, 610), Vector2(1640, 610),
	Vector2(1640, 575), Vector2(1700, 575), Vector2(1700, 540),
	# The crane on the right rim: its jib reaching left over the pit, its counter-jib right.
	Vector2(1780, 540), Vector2(1780, 438), Vector2(1600, 438), Vector2(1600, 430), Vector2(1780, 430),
	Vector2(1780, 400), Vector2(1790, 400), Vector2(1790, 430), Vector2(1850, 430), Vector2(1850, 445),
	Vector2(1790, 445), Vector2(1790, 540),
	Vector2(World.WORLD_WIDTH + World.SIDE_OVERHANG, 540),
]
const HIMALAYA_FAR_DARKENING := 0.06
const HIMALAYA_NEAR_DARKENING := 0.12
const FAR_WALLS_DARKENING := 0.22
const HIMALAYA_FAR_SCROLL := Vector2(0.4, 0.94)
const HIMALAYA_NEAR_SCROLL := Vector2(0.55, 0.96)
const FAR_WALLS_SCROLL := Vector2(0.7, 0.975)
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


# The top edge of a row of blocks (each Vector2(right x, roof y), left to right), from the world's
# left side overhang: each roof flat, with a straight wall down or up to the next.
static func skyline_edge(blocks: Array[Vector2]) -> Array[Vector2]:
	var edge: Array[Vector2] = []
	var left := -World.SIDE_OVERHANG
	for block in blocks:
		edge.append(Vector2(left, block.y))
		edge.append(block)
		left = block.x
	return edge


# The Mine's Backdrop, farther first: the Himalaya-like peaks, then the far walls.
static func mine() -> Array[Ridge]:
	return [Ridge.new(HIMALAYA_FAR, HIMALAYA_FAR_DARKENING, HIMALAYA_FAR_SCROLL),
		Ridge.new(HIMALAYA_NEAR, HIMALAYA_NEAR_DARKENING, HIMALAYA_NEAR_SCROLL),
		Ridge.new(FAR_WALLS, FAR_WALLS_DARKENING, FAR_WALLS_SCROLL)]


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
