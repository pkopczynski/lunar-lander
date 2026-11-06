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
# How much darker than the sky behind the roofs each depth is by day, and how fast it scrolls.
# Tuning, expected to change in playtests.
const SKYLINE_FAR_DARKENING := 0.12
const SKYLINE_NEAR_DARKENING := 0.3
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
# faintly moonlit, out of the night. Each nearer ridge is also SATURATION_STEP more saturated.
# Tuning, expected to change in playtests.
const MIN_STEP := 0.032
const NEAR_FLOOR := 0.056
const SATURATION_STEP := 0.12


# One ridge of a location's Backdrop: its top edge, left to right, how much darker than the sky
# behind the peaks it's filled by day (Backdrop.depth_colors() keeps the steps between ridges), and how fast it scrolls with the camera (by default
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
# The world y of the highest peak of any ridge: the sky there is the one they're all coloured from.
var peak_y := 0.0


# Builds the Backdrop afresh from a location's ridges, each carried on past both sides and closing
# down past bottom_y, in its own parallax layer anchored on anchor.
func build(from: Array[Ridge], bottom_y: float, anchor: Vector2) -> void:
	DecorKit.clear(self)
	ridges.clear()
	darkenings.clear()
	peak_y = INF
	for ridge in from:
		for point in ridge.top_edge:
			peak_y = minf(peak_y, point.y)
		var top := ridge.top_edge.duplicate()
		top.insert(0, top[0] - Vector2(SIDE_MARGIN, 0))
		top.append(top[-1] + Vector2(SIDE_MARGIN, 0))
		# A layer rising faster with the camera reaches further down, so its bottom never shows with
		# the camera up at the Border.
		var rise := maxf(anchor.y - World.BORDER_Y, 0.0) * (1.0 - ridge.scroll_scale.y)
		ridges.append(DecorKit.add_in_layer(self, DecorKit.closed_down(top, bottom_y + BOTTOM_MARGIN + rise),
			ridge.scroll_scale, anchor))
		darkenings.append(ridge.darkening)


# The ridges, for World.shown_decor().
func listed_decor() -> Array[World.Listing]:
	return World.listings(ridges, World.DecorLayer.BACKDROP, World.DecorPart.RIDGE)


# Fills each ridge with its depth's colour, from the background gradient (background_color: a
# world y to its colour) behind the highest peak.
func show_sky(background_color: Callable) -> void:
	var colors := depth_colors(background_color.call(peak_y), darkenings)
	for i in ridges.size():
		ridges[i].color = colors[i]


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
		color.s = minf(color.s + i * SATURATION_STEP, 1.0)
		color = color * (luminance / maxf(color.get_luminance(), 0.001))
		color.a = 1.0
		colors.append(color)
	return colors
