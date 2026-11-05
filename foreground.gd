class_name Foreground
extends Node2D
# The Foreground: a location's silhouettes drawn in front of the ship, in parallax layers anchored
# on the pad that move faster than the world, so they can briefly hide the ship and its path as the
# view moves. Opaque and near-black, darker than all other scenery at every hour and a little darker
# at night; no lights and no collider. A location places them so they never cover the Approach
# corridor (the column above its pad, CORRIDOR_MARGIN wider than the pad on each side) at any
# height up to the Border, nor its pad, its solid terrain's edge near it or the ship in the last
# ~250 px of the approach (FAIR_HEIGHT).

const COLOR := Color(0.02, 0.022, 0.026)
# How much darker it is at full night (the sky's night darkness), blended by the sky's darkness.
const NIGHT_DARKENING := 0.5
# How far above the pad's top a camera following the ship never has the pad covered.
const FAIR_HEIGHT := 250.0
# How far beyond each side of the pad the Approach corridor reaches.
const CORRIDOR_MARGIN := 40.0
# How far below the location's lowest point each silhouette reaches, so its bottom never shows.
const BOTTOM_MARGIN := 300.0

# Tuning, expected to change in playtests.
# The Valley's spruce stands, each the top edge of one silhouette (closed down below the ground),
# well to the sides of its pad. Tatra spruces: stacked tiers narrowing to a spike.
const VALLEY_SCROLL := Vector2(1.45, 1.06)
const VALLEY_LEFT_STAND := [
	Vector2(260, 600), Vector2(300, 560), Vector2(285, 560), Vector2(320, 515), Vector2(305, 515),
	Vector2(335, 465), Vector2(325, 465), Vector2(345, 420), Vector2(365, 465), Vector2(355, 465),
	Vector2(385, 515), Vector2(370, 515), Vector2(405, 560), Vector2(395, 560), Vector2(420, 545),
	Vector2(410, 545), Vector2(440, 505), Vector2(430, 505), Vector2(455, 470), Vector2(480, 505),
	Vector2(470, 505), Vector2(500, 545), Vector2(490, 545), Vector2(530, 600), Vector2(560, 610),
]
const VALLEY_RIGHT_STAND := [
	Vector2(1430, 610), Vector2(1470, 570), Vector2(1460, 570), Vector2(1495, 525), Vector2(1485, 525),
	Vector2(1515, 480), Vector2(1545, 525), Vector2(1535, 525), Vector2(1565, 560), Vector2(1580, 540),
	Vector2(1570, 540), Vector2(1600, 495), Vector2(1590, 495), Vector2(1615, 450), Vector2(1605, 450),
	Vector2(1630, 405), Vector2(1655, 450), Vector2(1645, 450), Vector2(1670, 495), Vector2(1660, 495),
	Vector2(1690, 540), Vector2(1680, 540), Vector2(1720, 600), Vector2(1760, 600),
]

# The Metropolis's near rooftops, rising from one continuous near strip on both sides of the
# Approach corridor, the tallest just beside it so they stay in view through the landing on the
# pad's roof. On the left a roof with a water tank and antennas, and a pagoda-like tower whose top
# reaches far above the pad; under the corridor only a low parapet with pipes, below the pad's roof
# on screen; on the right a tower with a sloped roof and antennas, then a roof with a billboard.
# Three pieces, so the tall ones stay left and right of the corridor.
const METROPOLIS_SCROLL := Vector2(1.4, 1.06)
const METROPOLIS_LEFT_ROOFS := [
	Vector2(-1200, 690), Vector2(80, 690), Vector2(80, 630), Vector2(205, 630), Vector2(205, 575),
	Vector2(212, 565), Vector2(258, 565), Vector2(265, 575), Vector2(265, 630), Vector2(330, 630),
	Vector2(330, 600), Vector2(520, 600), Vector2(520, 540), Vector2(640, 540), Vector2(640, 400),
	Vector2(646, 400), Vector2(646, 540), Vector2(700, 540), Vector2(700, 450), Vector2(704, 450),
	Vector2(704, 540), Vector2(880, 540),
	# The pagoda-like tower: three tiers of upturned eaves and a spire.
	Vector2(880, 425), Vector2(842, 418), Vector2(834, 404), Vector2(868, 396), Vector2(900, 372),
	Vector2(900, 330), Vector2(860, 322), Vector2(852, 308), Vector2(884, 300), Vector2(912, 280),
	Vector2(912, 240), Vector2(876, 232), Vector2(868, 218), Vector2(900, 208), Vector2(936, 170),
	Vector2(938, 90), Vector2(942, 90), Vector2(944, 170), Vector2(980, 208), Vector2(1012, 218),
	Vector2(1004, 232), Vector2(968, 240), Vector2(968, 280), Vector2(996, 300), Vector2(1028, 308),
	Vector2(1020, 322), Vector2(980, 330), Vector2(980, 372), Vector2(1012, 396), Vector2(1046, 404),
	Vector2(1038, 418), Vector2(1000, 425), Vector2(1000, 600), Vector2(1040, 600), Vector2(1040, 588),
	Vector2(1064, 588), Vector2(1064, 720),
]
const METROPOLIS_PARAPET := [
	Vector2(990, 720), Vector2(1080, 720), Vector2(1080, 700), Vector2(1120, 700), Vector2(1120, 712),
	Vector2(1240, 712), Vector2(1240, 704), Vector2(1290, 704), Vector2(1290, 712), Vector2(1380, 712),
	Vector2(1380, 696), Vector2(1396, 696), Vector2(1396, 712), Vector2(1520, 712),
]
const METROPOLIS_RIGHT_ROOFS := [
	Vector2(1440, 712), Vector2(1500, 712), Vector2(1500, 670), Vector2(1540, 670), Vector2(1540, 640),
	Vector2(1580, 640),
	# The tower with cornice ledges, its sloped roof and two antennas.
	Vector2(1580, 430), Vector2(1566, 426), Vector2(1566, 414), Vector2(1580, 414), Vector2(1580, 300),
	Vector2(1570, 296), Vector2(1570, 286), Vector2(1580, 286), Vector2(1580, 180), Vector2(1598, 189), Vector2(1598, 80), Vector2(1602, 80), Vector2(1602, 191),
	Vector2(1640, 210), Vector2(1640, 140), Vector2(1646, 140), Vector2(1646, 213), Vector2(1700, 240),
	Vector2(1700, 600),
	# The billboard, then a water tank.
	Vector2(1780, 600), Vector2(1780, 470), Vector2(1950, 470), Vector2(1950, 600), Vector2(2080, 600),
	Vector2(2080, 545), Vector2(2088, 535), Vector2(2132, 535), Vector2(2140, 545), Vector2(2140, 600),
	Vector2(2220, 600), Vector2(2220, 650), Vector2(3200, 650),
]

# The Mine's silhouettes, scrolling faster than the Valley's (stronger parallax): a spoil heap and a
# haul truck on the left benches, an ore heap on the pit floor left of the pad, and an ore heap with
# a conveyor's head tower on the right. All below the crane's arm, so as they only ever move down
# from where they were designed (the camera is never below the pad), they never hide it.
const MINE_SCROLL := Vector2(1.7, 1.1)
const MINE_LEFT_HEAP := [
	Vector2(40, 640), Vector2(90, 590), Vector2(140, 605), Vector2(190, 560), Vector2(240, 585),
	Vector2(290, 570), Vector2(330, 610), Vector2(380, 630), Vector2(420, 630), Vector2(420, 590),
	Vector2(445, 590), Vector2(445, 565), Vector2(480, 565), Vector2(480, 590), Vector2(500, 590),
	Vector2(505, 555), Vector2(640, 545), Vector2(650, 575), Vector2(660, 600), Vector2(660, 640),
	Vector2(700, 650),
]
const MINE_PIT_HEAP := [
	Vector2(820, 760), Vector2(870, 720), Vector2(910, 705), Vector2(950, 725), Vector2(1000, 770),
]
const MINE_RIGHT_CONVEYOR := [
	Vector2(1680, 720), Vector2(1720, 690), Vector2(1770, 650), Vector2(1800, 655), Vector2(1820, 640),
	Vector2(1840, 640), Vector2(1840, 520), Vector2(1880, 520), Vector2(1880, 560), Vector2(1960, 600),
	Vector2(2050, 640), Vector2(2200, 660),
]


# One Foreground silhouette: its top edge, left to right, and how fast its layer scrolls with the
# camera (above 1: faster than the world).
class Silhouette:
	var top_edge: PackedVector2Array
	var scroll_scale: Vector2

	func _init(top: Array, scroll: Vector2) -> void:
		top_edge = PackedVector2Array(top)
		scroll_scale = scroll


static func valley() -> Array[Silhouette]:
	return [Silhouette.new(VALLEY_LEFT_STAND, VALLEY_SCROLL), Silhouette.new(VALLEY_RIGHT_STAND, VALLEY_SCROLL)]


static func metropolis() -> Array[Silhouette]:
	return [Silhouette.new(METROPOLIS_LEFT_ROOFS, METROPOLIS_SCROLL), Silhouette.new(METROPOLIS_PARAPET, METROPOLIS_SCROLL),
		Silhouette.new(METROPOLIS_RIGHT_ROOFS, METROPOLIS_SCROLL)]


static func mine() -> Array[Silhouette]:
	return [Silhouette.new(MINE_LEFT_HEAP, MINE_SCROLL), Silhouette.new(MINE_PIT_HEAP, MINE_SCROLL),
		Silhouette.new(MINE_RIGHT_CONVEYOR, MINE_SCROLL)]


# The silhouettes as drawn.
var pieces: Array[Polygon2D] = []


# Builds the Foreground afresh, each silhouette closing down past bottom_y in its own layer
# anchored on anchor.
func build(from: Array[Silhouette], bottom_y: float, anchor: Vector2) -> void:
	DecorKit.clear(self)
	pieces.clear()
	for silhouette in from:
		var outline := DecorKit.closed_down(silhouette.top_edge, bottom_y + BOTTOM_MARGIN)
		var visual := DecorKit.add_in_layer(self, outline, silhouette.scroll_scale, anchor)
		visual.color = COLOR
		pieces.append(visual)


# The silhouettes, for World.shown_decor().
func listed_decor() -> Array[World.Listing]:
	return World.listings(pieces, World.DecorLayer.FOREGROUND, World.DecorPart.SILHOUETTE)


func show_sky(sky: SkyLook) -> void:
	for piece in pieces:
		piece.self_modulate = Color.WHITE.darkened(NIGHT_DARKENING * sky.night())
