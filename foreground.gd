class_name Foreground
extends Node2D
# The Foreground: a location's silhouettes drawn in front of the ship, in parallax layers anchored
# on the pad that move faster than the world, so they can briefly hide the ship and its path as the
# view moves. Opaque and near-black, darker than all other scenery at every hour and a little darker
# at night; no lights and no collider. A location places them so they never cover its pad, its
# solid terrain's edge near it or the ship in the last ~250 px of the approach (FAIR_HEIGHT).

const COLOR := Color(0.02, 0.022, 0.026)
# How much darker it is at full night (the sky's night darkness), blended by the sky's darkness.
const NIGHT_DARKENING := 0.5
# How far above the pad's top a camera following the ship never has the pad covered.
const FAIR_HEIGHT := 250.0
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

# The Metropolis's near rooftops, well to the sides of its pad's building: on the left a roof with
# a water tank and a mast, on the right one with a billboard.
const METROPOLIS_SCROLL := Vector2(1.4, 1.06)
const METROPOLIS_LEFT_ROOF := [
	Vector2(430, 720), Vector2(430, 670), Vector2(470, 670), Vector2(470, 610), Vector2(480, 600),
	Vector2(530, 600), Vector2(540, 610), Vector2(540, 670), Vector2(600, 670), Vector2(600, 560),
	Vector2(606, 560), Vector2(606, 670), Vector2(680, 670), Vector2(680, 700), Vector2(720, 700),
]
const METROPOLIS_RIGHT_ROOF := [
	Vector2(1640, 720), Vector2(1640, 660), Vector2(1690, 660), Vector2(1690, 580), Vector2(1860, 580),
	Vector2(1860, 660), Vector2(1900, 660), Vector2(1900, 700), Vector2(1960, 700),
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
	return [Silhouette.new(METROPOLIS_LEFT_ROOF, METROPOLIS_SCROLL), Silhouette.new(METROPOLIS_RIGHT_ROOF, METROPOLIS_SCROLL)]


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
