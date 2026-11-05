class_name Foreground
extends Node2D
# The Foreground: a location's silhouettes drawn in front of the ship, in parallax layers anchored
# on the pad that move faster than the world, so they can briefly hide the ship and its path as the
# view moves. Opaque and near-black, darker than all other scenery at every hour and a little darker
# at night; no collider, and no lights but the faint glows in some Valley crowns at night. A location places them so they never cover the Approach
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
# The Valley's stands: giant sequoias, alone and in groups, among spruces, broad trees, shrubs and a
# few oddly shaped crowns, all rising from one near ground on each side of its pad. Each side is one
# silhouette: the near ground's top edge starts and ends below the lowest point (so no side ever
# shows) and the trees stand on it, their feet hidden in it. Each tree is [kind, x, height above the
# near ground, crown half-width], in the layer's coordinates (the world's, with the camera on the
# pad's top).
const VALLEY_SCROLL := Vector2(1.45, 1.06)
enum Plant { SEQUOIA, SPRUCE, BROAD, SHRUB, LOBED, UMBRELLA }
# The near ground's top, how much it undulates, and how far down its two ends dip.
const VALLEY_GROUND_Y := 618.0
const VALLEY_GROUND_BUMP := 10.0
const VALLEY_GROUND_ENDS_Y := 720.0
# Each side's near ground, from x to y: the outer end well past the view however far the layer is
# shifted, the inner end far enough from the pad that, with the camera to either side of it, no
# tree reaches the ground's edge within ~250 px of the pad (and so the corridor), keeping the
# Valley open around its pad.
const VALLEY_LEFT_GROUND := Vector2(-1900, 716)
const VALLEY_RIGHT_GROUND := Vector2(1284, 3900)
const VALLEY_LEFT_TREES := [
	[Plant.SHRUB, 694, 30, 18], [Plant.SEQUOIA, 660, 1010, 38], [Plant.SEQUOIA, 598, 800, 34],
	[Plant.LOBED, 528, 640, 46], [Plant.BROAD, 452, 190, 46], [Plant.SPRUCE, 392, 360, 40],
	[Plant.SHRUB, 346, 40, 34], [Plant.SEQUOIA, 290, 1180, 48], [Plant.SPRUCE, 222, 290, 34],
	[Plant.BROAD, 150, 300, 66], [Plant.SEQUOIA, 70, 920, 42], [Plant.SEQUOIA, 4, 1090, 46],
	[Plant.SEQUOIA, -70, 760, 36], [Plant.SHRUB, -130, 36, 30], [Plant.UMBRELLA, -220, 560, 90],
	[Plant.SPRUCE, -300, 380, 42], [Plant.SEQUOIA, -400, 1040, 44], [Plant.BROAD, -520, 280, 62],
	[Plant.SEQUOIA, -650, 880, 40], [Plant.SEQUOIA, -716, 1150, 48], [Plant.SPRUCE, -840, 330, 38],
	[Plant.LOBED, -960, 700, 50], [Plant.SEQUOIA, -1100, 960, 44], [Plant.SHRUB, -1200, 40, 44],
	[Plant.SEQUOIA, -1320, 1060, 46], [Plant.SPRUCE, -1450, 360, 40], [Plant.SEQUOIA, -1580, 900, 42],
]
const VALLEY_RIGHT_TREES := [
	[Plant.SHRUB, 1306, 30, 18], [Plant.SEQUOIA, 1340, 900, 38], [Plant.LOBED, 1412, 1060, 48],
	[Plant.BROAD, 1490, 180, 44], [Plant.SPRUCE, 1556, 400, 42], [Plant.SPRUCE, 1606, 310, 34],
	[Plant.SHRUB, 1650, 36, 36], [Plant.SEQUOIA, 1720, 1220, 50], [Plant.SEQUOIA, 1790, 960, 42],
	[Plant.SEQUOIA, 1850, 820, 36], [Plant.UMBRELLA, 1960, 600, 96], [Plant.SHRUB, 2060, 40, 40],
	[Plant.BROAD, 2140, 280, 64], [Plant.SEQUOIA, 2210, 1100, 46], [Plant.SPRUCE, 2310, 360, 40],
	[Plant.SEQUOIA, 2400, 900, 42], [Plant.LOBED, 2520, 720, 50], [Plant.SEQUOIA, 2650, 1180, 48],
	[Plant.SEQUOIA, 2720, 940, 40], [Plant.SHRUB, 2820, 36, 40], [Plant.BROAD, 2930, 300, 64],
	[Plant.SEQUOIA, 3060, 1000, 44], [Plant.SPRUCE, 3180, 350, 40], [Plant.SEQUOIA, 3320, 1080, 46],
	[Plant.SEQUOIA, 3480, 880, 42],
]
const VALLEY_SEED := 75
# How far apart the foliage's clumps are along a crown's side.
const CLUMP_STEP := 26.0
# The faint glow in the odd crowns at night: its colour, and its opacity at full night (none by day).
const GLOW_COLOR := Color(0.55, 1.0, 0.82)
const GLOW_NIGHT_ALPHA := 0.22

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


# One Foreground silhouette: its top edge, left to right, how fast its layer scrolls with the camera
# (above 1: faster than the world), the shapes standing on it (drawn as part of it) and the faint
# glows drawn over them at night.
class Silhouette:
	var top_edge: PackedVector2Array
	var scroll_scale: Vector2
	var shapes: Array[PackedVector2Array] = []
	var glows: Array[PackedVector2Array] = []

	func _init(top: Array, scroll: Vector2) -> void:
		top_edge = PackedVector2Array(top)
		scroll_scale = scroll


static func valley() -> Array[Silhouette]:
	var rng := RandomNumberGenerator.new()
	rng.seed = VALLEY_SEED
	return [valley_stand(VALLEY_LEFT_GROUND, VALLEY_LEFT_TREES, rng), valley_stand(VALLEY_RIGHT_GROUND, VALLEY_RIGHT_TREES, rng)]


# One side's near ground, from ends.x to ends.y, and the trees standing on it.
static func valley_stand(ends: Vector2, trees: Array, rng: RandomNumberGenerator) -> Silhouette:
	var top := [Vector2(ends.x, VALLEY_GROUND_ENDS_Y)]
	var x := ends.x + 60.0
	while x < ends.y - 60.0:
		top.append(Vector2(x, VALLEY_GROUND_Y - rng.randf() * VALLEY_GROUND_BUMP))
		x += rng.randf_range(30.0, 60.0)
	top.append(Vector2(ends.y, VALLEY_GROUND_ENDS_Y))
	var stand := Silhouette.new(top, VALLEY_SCROLL)
	for tree: Array in trees:
		add_tree(stand, tree[0], tree[1], tree[2], tree[3], rng)
	return stand


static func add_tree(stand: Silhouette, kind: Plant, x: float, height: float, half_width: float, rng: RandomNumberGenerator) -> void:
	var foot := VALLEY_GROUND_Y + VALLEY_GROUND_BUMP
	var top_y := VALLEY_GROUND_Y - height
	match kind:
		Plant.SEQUOIA:
			# A column of clumped foliage, narrowing to a rounded top, high on a bare trunk that
			# flares at its foot.
			var crown_bottom := top_y + height * rng.randf_range(0.6, 0.7)
			stand.shapes.append(trunk(x, foot, crown_bottom - 40.0, half_width * 0.3))
			stand.shapes.append(crown(x, crown_bottom, top_y, half_width, 0.45, rng))
		Plant.SPRUCE:
			stand.shapes.append(spruce(x, foot, top_y, half_width, rng))
		Plant.BROAD:
			stand.shapes.append(trunk(x, foot, top_y + height * 0.38, half_width * 0.16))
			stand.shapes.append(blob(Vector2(x, top_y + height * 0.38), Vector2(half_width, height * 0.38), rng))
		Plant.SHRUB:
			stand.shapes.append(blob(Vector2(x, VALLEY_GROUND_Y), Vector2(half_width, height), rng))
		Plant.LOBED:
			# Alien: a thin trunk carrying round lobes, smaller toward the top, the upper two glowing
			# brighter at their hearts.
			stand.shapes.append(trunk(x, foot, top_y + half_width, half_width * 0.16))
			var y := top_y + half_width * 0.7
			var radius := half_width * 0.7
			for lobe in 3:
				var center := Vector2(x + rng.randf_range(-0.2, 0.2) * half_width, y)
				stand.shapes.append(blob(center, Vector2(radius * 1.1, radius), rng))
				if lobe < 2:
					stand.glows.append(ellipse(center, Vector2(radius * 0.6, radius * 0.55), 12))
					stand.glows.append(ellipse(center, Vector2(radius * 0.3, radius * 0.28), 10))
				y += radius * 2.6
				radius *= 1.25
		Plant.UMBRELLA:
			# Alien: a flat, wide canopy on a tall bare trunk, glowing faintly underneath.
			var canopy := Vector2(x, top_y + half_width * 0.25)
			stand.shapes.append(trunk(x, foot, canopy.y, half_width * 0.14))
			stand.shapes.append(blob(canopy, Vector2(half_width, half_width * 0.25), rng))
			stand.glows.append(ellipse(canopy + Vector2(0, half_width * 0.08), Vector2(half_width * 0.6, half_width * 0.1), 16))


# A trunk from foot (inside the near ground) up to top, flaring at its foot.
static func trunk(x: float, foot: float, top: float, half_width: float) -> PackedVector2Array:
	var flare := VALLEY_GROUND_Y - 20.0
	return PackedVector2Array([
		Vector2(x - half_width * 2.0, foot), Vector2(x - half_width * 1.1, flare), Vector2(x - half_width * 0.5, top),
		Vector2(x + half_width * 0.5, top), Vector2(x + half_width * 1.1, flare), Vector2(x + half_width * 2.0, foot),
	])


# A crown of clumps from bottom up to a rounded top, half_width wide at the bottom and narrowing
# by taper toward the top.
static func crown(x: float, bottom: float, top: float, half_width: float, taper: float, rng: RandomNumberGenerator) -> PackedVector2Array:
	var dome := half_width * (1.0 - taper)
	var steps := maxi(2, ceili((bottom - top - dome) / CLUMP_STEP))
	var step := (bottom - top - dome) / steps
	var left := PackedVector2Array([Vector2(x - half_width * 0.3, bottom + 8.0)])
	var right := PackedVector2Array([Vector2(x + half_width * 0.3, bottom + 8.0)])
	# Each clump bulges out between two notches.
	for i in steps:
		var y := bottom - step * i
		var width := half_width * (1.0 - taper * float(i) / steps)
		left.append_array(clump(x, y, -width, step, rng))
		right.append_array(clump(x, y, width, step, rng))
	var points := left
	for i in range(1, 6):
		var angle := PI + PI * i / 6.0
		points.append(Vector2(x, top + dome) + Vector2(cos(angle), sin(angle)) * dome)
	right.reverse()
	points.append_array(right)
	return points


# One clump on a crown's side, from a notch at y up to the next: width out from x (negative: to
# the left), step high.
static func clump(x: float, y: float, width: float, step: float, rng: RandomNumberGenerator) -> PackedVector2Array:
	var reach := width * rng.randf_range(0.75, 1.25)
	return PackedVector2Array([Vector2(x + width * rng.randf_range(0.55, 0.8), y), Vector2(x + reach, y - step * 0.3),
		Vector2(x + reach * rng.randf_range(0.8, 1.0), y - step * 0.75)])


# A Tatra spruce: stacked tiers narrowing to a spike.
static func spruce(x: float, foot: float, top: float, half_width: float, rng: RandomNumberGenerator) -> PackedVector2Array:
	var tiers := 5
	var lowest := VALLEY_GROUND_Y - 15.0
	var tier := (lowest - top) / (tiers + 0.5)
	var left := PackedVector2Array([Vector2(x - half_width * 0.15, foot)])
	var right := PackedVector2Array([Vector2(x + half_width * 0.15, foot)])
	for i in tiers:
		var y := lowest - tier * i
		var width := half_width * (1.0 - float(i) / tiers) * rng.randf_range(0.85, 1.05)
		left.append(Vector2(x - width, y))
		left.append(Vector2(x - width * 0.45, y - tier * 0.4))
		right.append(Vector2(x + width, y))
		right.append(Vector2(x + width * 0.45, y - tier * 0.4))
	left.append(Vector2(x, top))
	right.reverse()
	left.append_array(right)
	return left


# A lumpy round shape around center, size across and up.
static func blob(center: Vector2, size: Vector2, rng: RandomNumberGenerator) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 18:
		var angle := TAU * i / 18.0
		points.append(center + Vector2(cos(angle) * size.x, sin(angle) * size.y) * rng.randf_range(0.85, 1.05))
	return points


static func ellipse(center: Vector2, size: Vector2, sides: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in sides:
		var angle := TAU * i / sides
		points.append(center + Vector2(cos(angle) * size.x, sin(angle) * size.y))
	return points


static func metropolis() -> Array[Silhouette]:
	return [Silhouette.new(METROPOLIS_LEFT_ROOF, METROPOLIS_SCROLL), Silhouette.new(METROPOLIS_RIGHT_ROOF, METROPOLIS_SCROLL)]


static func mine() -> Array[Silhouette]:
	return [Silhouette.new(MINE_LEFT_HEAP, MINE_SCROLL), Silhouette.new(MINE_PIT_HEAP, MINE_SCROLL),
		Silhouette.new(MINE_RIGHT_CONVEYOR, MINE_SCROLL)]


# The silhouettes as drawn, and the glows over them.
var pieces: Array[Polygon2D] = []
var glows: Array[Polygon2D] = []


# Builds the Foreground afresh, each silhouette closing down past bottom_y in its own layer
# anchored on anchor, with the shapes standing on it and its glows.
func build(from: Array[Silhouette], bottom_y: float, anchor: Vector2) -> void:
	DecorKit.clear(self)
	pieces.clear()
	glows.clear()
	for silhouette in from:
		var outline := DecorKit.closed_down(silhouette.top_edge, bottom_y + BOTTOM_MARGIN)
		var visual := DecorKit.add_in_layer(self, outline, silhouette.scroll_scale, anchor)
		visual.color = COLOR
		if not silhouette.shapes.is_empty():
			# One piece, drawn as several polygons: its outline and each shape on it.
			var points := PackedVector2Array()
			var polygons := []
			for part: PackedVector2Array in [outline] + silhouette.shapes:
				polygons.append(PackedInt32Array(range(points.size(), points.size() + part.size())))
				points.append_array(part)
			visual.polygon = points
			visual.polygons = polygons
		pieces.append(visual)
		for shape in silhouette.glows:
			var glow := Polygon2D.new()
			glow.polygon = shape
			glow.color = GLOW_COLOR
			visual.get_parent().add_child(glow)
			glows.append(glow)


# The silhouettes and their glows, for World.shown_decor().
func listed_decor() -> Array[World.Listing]:
	return World.listings(pieces, World.DecorLayer.FOREGROUND, World.DecorPart.SILHOUETTE) \
		+ World.listings(glows, World.DecorLayer.FOREGROUND, World.DecorPart.GLOW)


func show_sky(sky: SkyLook) -> void:
	for piece in pieces:
		piece.self_modulate = Color.WHITE.darkened(NIGHT_DARKENING * sky.night())
	for glow in glows:
		glow.self_modulate.a = GLOW_NIGHT_ALPHA * sky.night()
