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
# How much darker than the sky behind the peaks each Tatra ridge is, by day.
const TATRA_FAR_DARKENING := 0.1
const TATRA_NEAR_DARKENING := 0.28
# How fast each Tatra ridge scrolls with the camera, the world's being 1: mostly horizontal, so the
# ridges barely rise into the sky as the ship climbs. Tuning, expected to change in playtests.
const TATRA_FAR_SCROLL := Vector2(0.6, 0.97)
const TATRA_NEAR_SCROLL := Vector2(0.75, 0.98)
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
# How far below the location's lowest point each ridge reaches, so its bottom never shows as its
# layer rises with a camera above the pad.
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


# The Tatra-like ridges, farther first.
static func tatras() -> Array[Ridge]:
	return [Ridge.new(TATRA_FAR, TATRA_FAR_DARKENING, TATRA_FAR_SCROLL),
		Ridge.new(TATRA_NEAR, TATRA_NEAR_DARKENING, TATRA_NEAR_SCROLL)]


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


# The colour the depth scrolling at scroll is filled with now; transparent if no ridge does.
func color_of(scroll: Vector2) -> Color:
	for ridge in ridges:
		if (ridge.get_parent() as AnchoredParallax).scroll_scale == scroll:
			return ridge.color
	return Color.TRANSPARENT


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
