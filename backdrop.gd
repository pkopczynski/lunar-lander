class_name Backdrop
extends Node2D
# The Backdrop: the current location's scenery behind its surface, with no collision. The World
# builds it afresh from the location's ridges whenever it shows a location, and recolours it from
# the sky. Each ridge is one Polygon2D filled with the background gradient, darkened, so it reads
# as a shadow of the sky behind it, in its own parallax layer anchored on the pad.

# The shapes of the trees a forested ridge carries on its top edge.
enum TreeKind { SPRUCE, SEQUOIA, FORKED }
# How finely a tree's outline is traced, in px: trees that overlap merge into one canopy.
const TREE_STEP := 2.0
# The Valley's Backdrop, farther first: distant ranges, high Tatra-like peaks, the nearer ridge with
# Giewont, then rolling hills. Only each top edge is listed; each closes down to the location's
# lowest point. Most of it sits between the mountains, which cover its ends.
# The distant ranges: long, soft ranges far away, showing between and above the high peaks' saddles.
const VALLEY_RANGES := [
	Vector2(-World.SIDE_OVERHANG, 280), Vector2(60, 270), Vector2(160, 235), Vector2(260, 250),
	Vector2(380, 205), Vector2(470, 215), Vector2(560, 190), Vector2(640, 230), Vector2(730, 245),
	Vector2(820, 215), Vector2(900, 170), Vector2(960, 160), Vector2(1030, 185), Vector2(1120, 230),
	Vector2(1210, 255), Vector2(1300, 225), Vector2(1400, 240), Vector2(1500, 205), Vector2(1600, 180),
	Vector2(1680, 195), Vector2(1780, 240), Vector2(1880, 255), Vector2(1980, 230),
	Vector2(World.WORLD_WIDTH + World.SIDE_OVERHANG, 265),
]
# The high peaks: jagged granite High Tatra peaks towering above the mountain tops, tallest near
# Rysy, with a lone, oddly thin needle on the right and low saddles the distant ranges show over.
const TATRA_FAR := [
	Vector2(-World.SIDE_OVERHANG, 320), Vector2(120, 320), Vector2(200, 250), Vector2(250, 280),
	Vector2(300, 190), Vector2(335, 225), Vector2(380, 150), Vector2(405, 175), Vector2(440, 128),
	Vector2(480, 200), Vector2(520, 170), Vector2(570, 250), Vector2(620, 215), Vector2(680, 300),
	Vector2(740, 285), Vector2(800, 330), Vector2(880, 315), Vector2(960, 345), Vector2(1040, 320),
	Vector2(1120, 340), Vector2(1200, 300), Vector2(1270, 315), Vector2(1350, 240), Vector2(1390, 265),
	Vector2(1440, 185), Vector2(1475, 215), Vector2(1520, 165), Vector2(1570, 240), Vector2(1610, 230),
	Vector2(1640, 150), Vector2(1652, 120), Vector2(1664, 155), Vector2(1700, 260), Vector2(1760, 290),
	Vector2(1840, 275), Vector2(1920, 310), Vector2(World.WORLD_WIDTH + World.SIDE_OVERHANG, 310),
]
# The nearer ridge: low rounded ridges and Giewont's sleeping knight (the steep Wielki Giewont,
# the long Długi Giewont, then the small bump of Mały Giewont), spruce forest on its far slopes.
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
# The nearer ridge's forest: Vector3(x, height, TreeKind), spruces on its left slopes and below
# Giewont on the right, none on the knight himself.
const TATRA_NEAR_TREES := [
	Vector3(300, 26, TreeKind.SPRUCE), Vector3(318, 32, TreeKind.SPRUCE), Vector3(338, 24, TreeKind.SPRUCE),
	Vector3(470, 30, TreeKind.SPRUCE), Vector3(488, 36, TreeKind.SPRUCE), Vector3(505, 28, TreeKind.SPRUCE),
	Vector3(524, 34, TreeKind.SPRUCE), Vector3(545, 26, TreeKind.SPRUCE), Vector3(640, 28, TreeKind.SPRUCE),
	Vector3(660, 34, TreeKind.SPRUCE), Vector3(678, 30, TreeKind.SPRUCE), Vector3(1610, 30, TreeKind.SPRUCE),
	Vector3(1630, 36, TreeKind.SPRUCE), Vector3(1650, 28, TreeKind.SPRUCE), Vector3(1700, 34, TreeKind.SPRUCE),
	Vector3(1722, 28, TreeKind.SPRUCE),
]
# The rolling hills, nearest: low and open around the pad, rising toward the mountains' feet.
const VALLEY_HILLS := [
	Vector2(-World.SIDE_OVERHANG, 470), Vector2(150, 470), Vector2(260, 485), Vector2(360, 470),
	Vector2(460, 500), Vector2(560, 495), Vector2(660, 525), Vector2(760, 545), Vector2(860, 560),
	Vector2(1000, 565), Vector2(1140, 560), Vector2(1240, 545), Vector2(1340, 520), Vector2(1440, 500),
	Vector2(1540, 505), Vector2(1640, 480), Vector2(1760, 470), Vector2(1880, 480),
	Vector2(World.WORLD_WIDTH + World.SIDE_OVERHANG, 470),
]
# The hills' forest, away from the pad: giant sequoias alone and in groups, taller than any tree on
# Earth, one with an oddly forked crown, among spruces.
const VALLEY_HILLS_TREES := [
	Vector3(285, 34, TreeKind.SPRUCE), Vector3(305, 150, TreeKind.SEQUOIA), Vector3(330, 40, TreeKind.SPRUCE),
	Vector3(350, 190, TreeKind.SEQUOIA), Vector3(378, 130, TreeKind.FORKED), Vector3(405, 36, TreeKind.SPRUCE),
	Vector3(425, 30, TreeKind.SPRUCE), Vector3(560, 120, TreeKind.SEQUOIA), Vector3(585, 30, TreeKind.SPRUCE),
	Vector3(605, 26, TreeKind.SPRUCE), Vector3(1370, 28, TreeKind.SPRUCE), Vector3(1392, 34, TreeKind.SPRUCE),
	Vector3(1440, 140, TreeKind.SEQUOIA), Vector3(1530, 36, TreeKind.SPRUCE), Vector3(1555, 170, TreeKind.FORKED),
	Vector3(1585, 210, TreeKind.SEQUOIA), Vector3(1612, 160, TreeKind.SEQUOIA), Vector3(1640, 40, TreeKind.SPRUCE),
	Vector3(1662, 32, TreeKind.SPRUCE), Vector3(1700, 120, TreeKind.SEQUOIA),
]
# How much darker than the sky behind the peaks each Valley depth is, by day.
const VALLEY_RANGES_DARKENING := 0.05
const TATRA_FAR_DARKENING := 0.14
const TATRA_NEAR_DARKENING := 0.28
const VALLEY_HILLS_DARKENING := 0.42
# How fast each Valley depth scrolls with the camera, the world's being 1. Sideways each nearer one
# a little faster; vertically they stay planted on the ground but part clearly as the ship climbs
# or drops, the farthest well slower than the world. Tuning, expected to change in playtests.
const VALLEY_RANGES_SCROLL := Vector2(0.45, 0.85)
const TATRA_FAR_SCROLL := Vector2(0.58, 0.89)
const TATRA_NEAR_SCROLL := Vector2(0.7, 0.93)
const VALLEY_HILLS_SCROLL := Vector2(0.82, 0.97)
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
# The upper walls: the pit's far walls carrying on high above the far walls' rim, in a depth of
# their own between them and the peaks. Benches stack up on both sides of the pit, each a tier
# above the last, to high rims carrying the mine's factories and facilities: on the left a factory
# with a sawtooth roof, a chimney and a tank, on the right a processing plant and two chimneys. A
# headframe and a crane stand on the benches, and two towers carry the ropeway across the sky.
# Lower in the middle, behind the pad, so the sky shows above the pit from the pad.
const UPPER_WALLS := [
	Vector2(-World.SIDE_OVERHANG, -260), Vector2(150, -260),
	# A silo.
	Vector2(150, -300), Vector2(180, -300), Vector2(180, -260),
	# The factory's sawtooth roof, then its chimney.
	Vector2(220, -260), Vector2(220, -320), Vector2(260, -350), Vector2(260, -320), Vector2(300, -350),
	Vector2(300, -320), Vector2(340, -350), Vector2(340, -320), Vector2(380, -350), Vector2(380, -320),
	Vector2(420, -320), Vector2(420, -410), Vector2(436, -410), Vector2(436, -320), Vector2(470, -320),
	Vector2(470, -260),
	# A tank on legs.
	Vector2(560, -260), Vector2(560, -300), Vector2(575, -310), Vector2(615, -310), Vector2(630, -300),
	Vector2(630, -260),
	# The ropeway's left tower.
	Vector2(740, -260), Vector2(740, -330), Vector2(730, -340), Vector2(762, -340), Vector2(752, -330),
	Vector2(752, -260),
	# The left benches stepping down to the pit, a headframe on the second.
	Vector2(790, -260), Vector2(790, -170), Vector2(850, -170), Vector2(850, -80),
	Vector2(860, -80), Vector2(865, -130), Vector2(880, -150), Vector2(895, -130), Vector2(900, -80),
	Vector2(910, -80), Vector2(910, 20), Vector2(960, 20), Vector2(960, 120), Vector2(1010, 120),
	Vector2(1010, 220), Vector2(1060, 220), Vector2(1060, 320), Vector2(1110, 320), Vector2(1110, 450),
	# Behind the pad, then the right benches stepping up, a crane on the second, its jib reaching
	# left over the pit.
	Vector2(1500, 450), Vector2(1500, 310), Vector2(1550, 310), Vector2(1550, 210),
	Vector2(1600, 210), Vector2(1600, 126), Vector2(1500, 126), Vector2(1500, 120), Vector2(1600, 120),
	Vector2(1600, 105), Vector2(1608, 105), Vector2(1608, 120), Vector2(1645, 120), Vector2(1645, 130),
	Vector2(1608, 130), Vector2(1608, 210),
	Vector2(1650, 210), Vector2(1650, 110), Vector2(1700, 110), Vector2(1700, 10), Vector2(1750, 10),
	Vector2(1750, -90), Vector2(1800, -90), Vector2(1800, -180),
	# The ropeway's right tower.
	Vector2(1850, -180), Vector2(1850, -250), Vector2(1840, -260), Vector2(1872, -260), Vector2(1862, -250),
	Vector2(1862, -180),
	# The right rim: a processing plant and two chimneys.
	Vector2(1900, -180), Vector2(1900, -280), Vector2(1960, -280), Vector2(1960, -340), Vector2(2060, -340),
	Vector2(2060, -370), Vector2(2100, -370), Vector2(2100, -340), Vector2(2140, -340), Vector2(2140, -280),
	Vector2(2200, -280), Vector2(2200, -390), Vector2(2214, -390), Vector2(2214, -280),
	Vector2(2250, -280), Vector2(2250, -360), Vector2(2262, -360), Vector2(2262, -280),
	Vector2(World.WORLD_WIDTH + World.SIDE_OVERHANG, -280),
]
# The ropeway's two ropes, from the left tower's top to the right one's, sagging in the middle.
const ROPEWAY_FROM := Vector2(746, -338)
const ROPEWAY_TO := Vector2(1856, -258)
const ROPEWAY_SAG := 60.0
const ROPEWAY_GAP := 8.0
const ROPE_THICKNESS := 2.5
const ROPE_SEGMENTS := 24
# A conveyor gallery climbing the left benches, from the lowest one to the fourth.
const CONVEYOR := [Vector2(965, 112), Vector2(1105, 312), Vector2(1105, 321), Vector2(965, 121)]
const UPPER_WALLS_DARKENING := 0.3
# The upper walls scroll up with the camera more than the far walls (a smaller vertical scale), so
# they still tower around the ship well above the pad.
const UPPER_WALLS_SCROLL := Vector2(0.62, 0.85)
const HIMALAYA_FAR_DARKENING := 0.08
const HIMALAYA_NEAR_DARKENING := 0.23
const FAR_WALLS_DARKENING := 0.37
const HIMALAYA_FAR_SCROLL := Vector2(0.4, 0.94)
const HIMALAYA_NEAR_SCROLL := Vector2(0.55, 0.96)
const FAR_WALLS_SCROLL := Vector2(0.7, 0.975)
# How far below the location's lowest point each ridge reaches, on top of how far its layer rises
# by the Border, so its bottom never shows as its layer rises with a camera above the pad.
const BOTTOM_MARGIN := 200.0
# How far past its first and last points each ridge carries on, level, so its ends never show as its
# layer shifts sideways (a layer anchored on a pad off the world's centre is shifted even with a
# window wider than the world).
const SIDE_MARGIN := 1000.0
# The tonal steps between depths, in luminance. Each ridge is at least MIN_STEP darker than the one
# behind it at every hour, and never darker than NEAR_FLOOR plus a MIN_STEP for each ridge in front
# of it, which keeps the nearest one clear of the near-black Foreground and lifts the farther ones,
# faintly moonlit, out of the night. Each nearer ridge is also SATURATION_STEP more saturated, up to
# MAX_SATURATION_STEPS.
# Tuning, expected to change in playtests.
const MIN_STEP := 0.032
const NEAR_FLOOR := 0.056
const SATURATION_STEP := 0.12
# Depths past this many in front of the farthest are no more saturated, so a Location with many
# depths (the Mine) doesn't turn its nearest ones vivid.
const MAX_SATURATION_STEPS := 2
# The highest a Backdrop takes its sky colour from: a skyline towering far above the mountains is
# coloured as if it peaked here, so it doesn't turn near-black by day.
const HIGHEST_SKY_Y := 0.0
# How opaque haze is at its bottom, fading out to its top.
const HAZE_ALPHA := 0.45


# One ridge of a location's Backdrop: its top edge, left to right, how much darker than the sky
# behind the peaks it's filled by day (Backdrop.depth_colors() keeps the steps between ridges), and how fast it scrolls with the camera (by default
# with the world, as if fixed). Its top edge must reach far enough past both sides of the world to
# cover the view at the world's side overhang; the Backdrop carries it on further (SIDE_MARGIN).
# It may carry structures that stand free of its top edge, such as a ropeway's ropes: outlines
# drawn in its depth and colour, not closed down.
# A ridge may also hold lit windows (each a rect, all in one colour), beacons (spots), and a band
# of haze behind it, from haze_top_y (clear) down to haze_bottom_y (HAZE_ALPHA), across the whole
# layer: it veils the farther depths just above its roofs.
class Ridge:
	var top_edge: PackedVector2Array
	var darkening: float
	var scroll_scale: Vector2
	var structures: Array[PackedVector2Array] = []
	var windows: Array[Rect2] = []
	var window_color := Color.WHITE
	var beacons := PackedVector2Array()
	var haze_top_y := NAN
	var haze_bottom_y := NAN

	func _init(top: Array, darker: float, scroll := Vector2.ONE, free_standing: Array[PackedVector2Array] = []) -> void:
		top_edge = PackedVector2Array(top)
		darkening = darker
		scroll_scale = scroll
		structures = free_standing


# The Valley's Backdrop, farther first: distant ranges, the high Tatra-like peaks, the forested
# ridge with Giewont and the rolling hills with their sequoias.
static func valley() -> Array[Ridge]:
	return [Ridge.new(VALLEY_RANGES, VALLEY_RANGES_DARKENING, VALLEY_RANGES_SCROLL),
		Ridge.new(TATRA_FAR, TATRA_FAR_DARKENING, TATRA_FAR_SCROLL),
		Ridge.new(forested(TATRA_NEAR, TATRA_NEAR_TREES), TATRA_NEAR_DARKENING, TATRA_NEAR_SCROLL),
		Ridge.new(forested(VALLEY_HILLS, VALLEY_HILLS_TREES), VALLEY_HILLS_DARKENING, VALLEY_HILLS_SCROLL)]


# A top edge with trees standing on it (each Vector3(x, height, TreeKind)): wherever a tree rises
# above the edge, the edge follows the tree's outline, so neighbouring trees merge into a forest.
static func forested(edge: Array, trees: Array) -> Array[Vector2]:
	var xs := {}
	for point: Vector2 in edge:
		xs[point.x] = true
	for tree: Vector3 in trees:
		var half := tree_half_width(tree)
		var x := tree.x - half
		while x < tree.x + half:
			xs[x] = true
			x += TREE_STEP
		xs[tree.x + half] = true
		xs[tree.x] = true
		# Just beside it, back on the ground, so its sides drop straight down.
		xs[tree.x - half - 0.5] = true
		xs[tree.x + half + 0.5] = true
	var sorted := xs.keys()
	sorted.sort()
	var result: Array[Vector2] = []
	for x: float in sorted:
		var ground := edge_y(edge, x)
		var top := ground
		for tree: Vector3 in trees:
			top = minf(top, tree_top(tree, edge_y(edge, tree.x), x))
		result.append(Vector2(x, top))
	return result


# A top edge's height at x, between its points.
static func edge_y(edge: Array, x: float) -> float:
	for i in edge.size() - 1:
		var from: Vector2 = edge[i]
		var to: Vector2 = edge[i + 1]
		if x >= from.x and x <= to.x:
			return from.y if to.x == from.x else lerpf(from.y, to.y, (x - from.x) / (to.x - from.x))
	return edge[0].y if x < edge[0].x else edge[-1].y


static func tree_half_width(tree: Vector3) -> float:
	match int(tree.z):
		TreeKind.SPRUCE:
			return tree.y * 0.3
		_:
			return tree.y * 0.1


# The top of a tree standing at base_y, at x (INF beside it): a spruce a narrow cone with ragged
# tiers, a sequoia a tall, slightly lumpy column with a domed crown, a forked one a column whose
# crown splits in two rounded lobes.
static func tree_top(tree: Vector3, base_y: float, x: float) -> float:
	var half := tree_half_width(tree)
	var across := absf(x - tree.x) / half
	if across > 1.0:
		return INF
	var height := tree.y
	match int(tree.z):
		TreeKind.SPRUCE:
			var tiers := 0.12 * height * absf(sin(across * PI * 2.0))
			return base_y - height * (1.0 - across) + tiers * across
		TreeKind.SEQUOIA:
			return base_y - height + height * (0.16 * across * across + 0.02 * absf(sin(across * 7.0)))
		_:
			# Two rounded lobes, one each side of a notch.
			var side := absf(x - tree.x) / half
			var lobe := side - 0.5
			var notch := height * 0.12 * maxf(0.0, 1.0 - side / 0.25)
			return base_y - height + half * (0.5 - sqrt(maxf(0.0, 0.25 - lobe * lobe))) + notch


# The Mine's Backdrop, farther first: the Himalaya-like peaks, the upper walls with the ropeway
# and a conveyor, then the far walls.
static func mine() -> Array[Ridge]:
	var structures: Array[PackedVector2Array] = [
		rope(ROPEWAY_FROM, ROPEWAY_TO), rope(ROPEWAY_FROM + Vector2(0, ROPEWAY_GAP), ROPEWAY_TO + Vector2(0, ROPEWAY_GAP)),
		PackedVector2Array(CONVEYOR)]
	return [Ridge.new(HIMALAYA_FAR, HIMALAYA_FAR_DARKENING, HIMALAYA_FAR_SCROLL),
		Ridge.new(HIMALAYA_NEAR, HIMALAYA_NEAR_DARKENING, HIMALAYA_NEAR_SCROLL),
		Ridge.new(UPPER_WALLS, UPPER_WALLS_DARKENING, UPPER_WALLS_SCROLL, structures),
		Ridge.new(FAR_WALLS, FAR_WALLS_DARKENING, FAR_WALLS_SCROLL)]


# A rope from one point to another, sagging ROPEWAY_SAG in the middle: a thin strip, ROPE_THICKNESS
# thick, along a parabola.
static func rope(from: Vector2, to: Vector2) -> PackedVector2Array:
	var upper := PackedVector2Array()
	var lower := PackedVector2Array()
	for i in ROPE_SEGMENTS + 1:
		var t := float(i) / ROPE_SEGMENTS
		var point := from.lerp(to, t) + Vector2(0, ROPEWAY_SAG * 4.0 * t * (1.0 - t))
		upper.append(point)
		lower.insert(0, point + Vector2(0, ROPE_THICKNESS))
	return upper + lower


# The ridges as drawn, farther first, their structures, each with the index of its ridge, and their
# lights and haze.
var ridges: Array[Polygon2D] = []
var windows: Array[MeshInstance2D] = []
var beacons: Array[MeshInstance2D] = []
var hazes: Array[Polygon2D] = []
var darkenings: Array[float] = []
var structures: Array[Polygon2D] = []
var structure_ridges: Array[int] = []
# The world y of the farthest ridge's highest peak: the sky there is the one they're all coloured
# from. Taller nearer depths (the Mine's upper walls) don't change it.
var peak_y := 0.0


# Builds the Backdrop afresh from a location's ridges, each carried on past both sides and closing
# down past bottom_y, in its own parallax layer anchored on anchor.
func build(from: Array[Ridge], bottom_y: float, anchor: Vector2) -> void:
	DecorKit.clear(self)
	ridges.clear()
	windows.clear()
	beacons.clear()
	hazes.clear()
	darkenings.clear()
	structures.clear()
	structure_ridges.clear()
	peak_y = INF
	if not from.is_empty():
		for point in from[0].top_edge:
			peak_y = minf(peak_y, point.y)
	for ridge in from:
		var top := ridge.top_edge.duplicate()
		top.insert(0, top[0] - Vector2(SIDE_MARGIN, 0))
		top.append(top[-1] + Vector2(SIDE_MARGIN, 0))
		# A layer rising faster with the camera reaches further down, so its bottom never shows with
		# the camera up at the Border.
		var rise := maxf(anchor.y - World.BORDER_Y, 0.0) * (1.0 - ridge.scroll_scale.y)
		var visual := DecorKit.add_in_layer(self, DecorKit.closed_down(top, bottom_y + BOTTOM_MARGIN + rise),
			ridge.scroll_scale, anchor)
		for outline in ridge.structures:
			var structure := Polygon2D.new()
			structure.polygon = outline
			visual.get_parent().add_child(structure)
			structures.append(structure)
			structure_ridges.append(ridges.size())
		ridges.append(visual)
		darkenings.append(ridge.darkening)
		var layer := visual.get_parent()
		if not is_nan(ridge.haze_top_y):
			var haze := Polygon2D.new()
			haze.polygon = PackedVector2Array([Vector2(top[0].x, ridge.haze_top_y), Vector2(top[-1].x, ridge.haze_top_y),
				Vector2(top[-1].x, ridge.haze_bottom_y), Vector2(top[0].x, ridge.haze_bottom_y)])
			var clear := Color(1, 1, 1, 0)
			var veiled := Color(1, 1, 1, HAZE_ALPHA)
			haze.vertex_colors = PackedColorArray([clear, clear, veiled, veiled])
			layer.add_child(haze)
			layer.move_child(haze, 0)
			hazes.append(haze)
		if not ridge.windows.is_empty():
			windows.append(add_lights(layer, ridge.windows, ridge.window_color))
		if not ridge.beacons.is_empty():
			var spots: Array[Rect2] = []
			for spot in ridge.beacons:
				spots.append(Rect2(spot - Skyline.BEACON_SIZE / 2.0, Skyline.BEACON_SIZE))
			beacons.append(add_lights(layer, spots, Skyline.BEACON_COLOR))
	peak_y = maxf(peak_y, HIGHEST_SKY_Y)


# Adds one mesh of lights in a colour to a ridge's layer, over the ridge.
func add_lights(layer: Node, rects: Array[Rect2], color: Color) -> MeshInstance2D:
	var tints: Array[Color] = [color]
	var lights := MeshInstance2D.new()
	lights.mesh = CityLights.mesh_of(rects, tints)
	layer.add_child(lights)
	return lights


# The ridges, their structures (silhouettes), their haze and their lights, for World.shown_decor().
func listed_decor() -> Array[World.Listing]:
	var listed := World.listings(ridges, World.DecorLayer.BACKDROP, World.DecorPart.RIDGE)
	listed.append_array(World.listings(structures, World.DecorLayer.BACKDROP, World.DecorPart.SILHOUETTE))
	listed.append_array(World.listings(hazes, World.DecorLayer.PARALLAX, World.DecorPart.HAZE))
	listed.append_array(World.listings(windows, World.DecorLayer.LIGHTS, World.DecorPart.SKYLINE_WINDOWS))
	listed.append_array(World.listings(beacons, World.DecorLayer.LIGHTS, World.DecorPart.SKYLINE_BEACON))
	return listed


# The colour the depth scrolling at scroll is filled with now, or the nearest depth sideways if no
# ridge scrolls at it; transparent without any ridge.
func color_of(scroll: Vector2) -> Color:
	var color := Color.TRANSPARENT
	var nearest := INF
	for ridge in ridges:
		var depth := (ridge.get_parent() as AnchoredParallax).scroll_scale
		if depth == scroll:
			return ridge.color
		var away := absf(depth.x - scroll.x)
		if away < nearest:
			nearest = away
			color = ridge.color
	return color


# Fills each ridge and its structures with its depth's colour, from the background gradient
# (background_color: a world y to its colour) behind the farthest ridge's highest peak, tints each
# haze band with the sky behind it, and brightens the lights like the city's: never dimmed.
func show_sky(sky: SkyLook, background_color: Callable) -> void:
	var colors := depth_colors(background_color.call(peak_y), darkenings)
	for i in ridges.size():
		ridges[i].color = colors[i]
	for i in structures.size():
		structures[i].color = colors[structure_ridges[i]]
	for haze in hazes:
		haze.color = background_color.call(haze.polygon[0].y)
	for lights in windows + beacons:
		lights.modulate = CityLights.brightness(sky)


# The colours of depths in front of a sky colour, farther first, each darker than that sky by its
# darkening, then kept at least MIN_STEP darker than the one behind it and lifted to its floor.
static func depth_colors(sky: Color, darkening: Array[float]) -> Array[Color]:
	var colors: Array[Color] = []
	var count := darkening.size()
	var sky_luminance := maxf(sky.get_luminance(), 0.001)
	var previous := INF
	for i in count:
		var luminance := minf(sky_luminance * (1.0 - darkening[i]), previous - MIN_STEP)
		previous = luminance
		luminance = maxf(luminance, NEAR_FLOOR + (count - 1 - i) * MIN_STEP)
		var color := sky
		color.s = minf(color.s + mini(i, MAX_SATURATION_STEPS) * SATURATION_STEP, 1.0)
		color = color * (luminance / maxf(color.get_luminance(), 0.001))
		color.a = 1.0
		colors.append(color)
	return colors
