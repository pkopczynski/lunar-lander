class_name Clouds
extends Node2D
# A location's clouds, in three depths (see sky()): far, thin streaks high up and mid banks across
# the middle sky, behind the scenery, and near translucent wisps in front of everything, the ship
# included. Each depth sits in parallax layers anchored on the pad (each cloud has its own scroll
# scale and wind speed) and drifts slowly on its own wind, tinted by the sky colour behind it. Each
# cloud wraps around from one side to the other well outside the view, so none ever pops in sight.
# No collider. Moving a cloud only changes its position (and a wisp's modulate), so nothing is
# redrawn as they drift.
#
# A cloud in front of the world (scroll scale above 1 sideways) is a wisp: translucent, drawn in
# front of the ship, and kept beside the Approach corridor. A wisp left of the pad drifts in a lane
# from far out of sight on the left up to the corridor, one right of it from the corridor out of
# sight on the right; it fades out toward the corridor's end of its lane, so it wraps there unseen.

# The kind of a location's clouds: soft cumulus (the Valley), flat smog and haze (the Metropolis)
# or dust haze (the Mine).
enum Kind { CUMULUS, SMOG, DUST }

# Tuning, expected to change in playtests.
# A cloud's depth and wind by default.
const SCROLL := Vector2(0.35, 0.95)
# The wind, in px/s; rightwards (negative: leftwards).
const WIND_SPEED := 6.0
# How much of the sky's own colour (at ground level) lights a cloud over the gradient behind it, so
# even a cloud high in the dark upper sky takes the hour's colour; then how much lighter than that
# it is. At night it darkens with the sky.
const SKY_LIGHT := 0.6
const LIGHTENING := 0.45
# How much of that lightening is left at full night, so the clouds don't glow against the night sky.
const NIGHT_LIGHTENING := 0.4
const NIGHT_DARKENING := 0.8
# Points around each cloud's outline.
const SIDES := 24
# A wisp's opacity, before it fades toward the corridor.
const WISP_OPACITY := 0.32
# How far from the Approach corridor a wisp's lane ends, and over how much of its lane's end it
# fades out, in px of its layer.
const WISP_CLEARANCE := 40.0
const WISP_FADE := 260.0

# The three depths of sky(), farthest first: [scroll scale, wind (px/s), how many, the heights
# above the pad's top they're scattered between (px), the smallest and largest half size].
const DEPTHS := [
	# Far, thin streaks high up.
	[Vector2(0.2, 0.7), 4.0, 12, Vector2(650, 1100), Vector2(170, 5), Vector2(300, 9)],
	# Mid banks across the middle sky.
	[Vector2(0.4, 0.85), 8.0, 16, Vector2(250, 1450), Vector2(90, 20), Vector2(190, 36)],
	# Near wisps in front of the ship, high above the pad.
	[Vector2(1.15, 1.12), 16.0, 10, Vector2(850, 1900), Vector2(110, 16), Vector2(200, 30)],
]
# Each kind's shape and colour: [half size scale, lumps, lump height (share of the half height),
# bottom squash, the colour it's drawn toward, by how much].
const KINDS := {
	Kind.CUMULUS: [Vector2(1.0, 1.0), 3.0, 0.35, 0.5, Color.WHITE, 0.0],
	Kind.SMOG: [Vector2(1.7, 0.55), 2.0, 0.12, 0.85, Color(0.55, 0.53, 0.5), 0.3],
	Kind.DUST: [Vector2(1.4, 0.7), 4.0, 0.18, 0.7, Color(0.78, 0.62, 0.42), 0.3],
}


# One cloud: its centre and half size, as designed (with the camera on the pad, before it drifts),
# its depth (its parallax layer's scroll scale), the wind carrying it, in px/s, and its kind.
class Cloud:
	var center: Vector2
	var half_size: Vector2
	var scroll: Vector2
	var wind: float
	var kind: Kind

	func _init(at: Vector2, half: Vector2, scroll_scale := SCROLL, wind_speed := WIND_SPEED, of_kind := Kind.CUMULUS) -> void:
		center = at
		half_size = half
		scroll = scroll_scale
		wind = wind_speed
		kind = of_kind

	# A wisp: in front of the world.
	func is_wisp() -> bool:
		return scroll.x > 1.0


# A location's clouds of kind in the three DEPTHS, scattered evenly across the span they wrap
# around and between each depth's heights above pad_top, the same each time for a variety.
static func sky(kind: Kind, pad_top: Vector2, variety: int) -> Array[Cloud]:
	var rng := RandomNumberGenerator.new()
	rng.seed = variety
	var shape: Vector2 = KINDS[kind][0]
	var clouds: Array[Cloud] = []
	for depth: Array in DEPTHS:
		var count: int = depth[2]
		var heights: Vector2 = depth[3]
		var smallest: Vector2 = depth[4]
		var largest: Vector2 = depth[5]
		var slot := DecorKit.WRAP_WIDTH / count
		for i in count:
			var half := Vector2(rng.randf_range(smallest.x, largest.x), rng.randf_range(smallest.y, largest.y)) * shape
			var at := Vector2(DecorKit.WRAP_LEFT + slot * (i + rng.randf_range(0.15, 0.85)),
				pad_top.y - rng.randf_range(heights.x, heights.y))
			clouds.append(Cloud.new(at, half, depth[0], depth[1], kind))
	return clouds


# The clouds behind the scenery, and the wisps, as drawn.
var pieces: Array[Polygon2D] = []
var wisps: Array[Polygon2D] = []
# The wisps' node, drawn in front of the ship: the World adds it over everything.
var near := Node2D.new()
# How long the wind has carried the clouds since they were built, in s.
var drifted := 0.0
# Every cloud and wisp as drawn, in the order given, each with its designed x, wind, the span its x
# wraps around (x: left end, y: width), kind and whether it's a wisp.
var drawn: Array[Polygon2D] = []
var designed_x := PackedFloat32Array()
var winds := PackedFloat32Array()
var lanes := PackedVector2Array()
var kinds: Array[Kind] = []
var translucent: Array[bool] = []


# Builds the clouds afresh, each depth in its own layer anchored on anchor (the pad's top).
func build(from: Array[Cloud], anchor: Vector2) -> void:
	DecorKit.clear(self)
	DecorKit.clear(near)
	pieces.clear()
	wisps.clear()
	designed_x.clear()
	winds.clear()
	lanes.clear()
	kinds.clear()
	translucent.clear()
	drawn.clear()
	drifted = 0.0
	var layers := DecorKit.Depths.new(self, anchor)
	var near_layers := DecorKit.Depths.new(near, anchor)
	for cloud in from:
		var visual := Polygon2D.new()
		visual.polygon = outline(cloud.half_size, cloud.kind)
		visual.position = cloud.center
		if cloud.is_wisp():
			near_layers.at(cloud.scroll).add_child(visual)
			wisps.append(visual)
			lanes.append(wisp_lane(cloud, anchor))
		else:
			layers.at(cloud.scroll).add_child(visual)
			pieces.append(visual)
			lanes.append(Vector2(DecorKit.WRAP_LEFT, DecorKit.WRAP_WIDTH))
		drawn.append(visual)
		designed_x.append(cloud.center.x)
		winds.append(cloud.wind)
		kinds.append(cloud.kind)
		translucent.append(cloud.is_wisp())
	drift()


# The span a wisp's centre wraps around: from far out of sight up to the Approach corridor on its
# side of the pad, keeping it WISP_CLEARANCE clear of it.
static func wisp_lane(cloud: Cloud, anchor: Vector2) -> Vector2:
	var corridor_half := Lander.PAD_WIDTH / 2.0 + Foreground.CORRIDOR_MARGIN + WISP_CLEARANCE + cloud.half_size.x
	if cloud.center.x < anchor.x:
		var end := anchor.x - corridor_half
		return Vector2(DecorKit.WRAP_LEFT, end - DecorKit.WRAP_LEFT)
	var start := anchor.x + corridor_half
	return Vector2(start, DecorKit.WRAP_LEFT + DecorKit.WRAP_WIDTH - start)


func _process(delta: float) -> void:
	drifted += delta
	drift()


# Places each cloud where the wind has carried it, and fades each wisp near its lane's ends.
func drift() -> void:
	for i in drawn.size():
		var lane := lanes[i]
		var x := fposmod(designed_x[i] + winds[i] * drifted - lane.x, lane.y) + lane.x
		drawn[i].position.x = x
		if translucent[i]:
			drawn[i].modulate.a = clampf(minf(x - lane.x, lane.x + lane.y - x) / WISP_FADE, 0.0, 1.0)


# The clouds behind the scenery, then the wisps in front, for World.shown_decor().
func listed_decor() -> Array[World.Listing]:
	var listed := World.listings(pieces, World.DecorLayer.PARALLAX, World.DecorPart.CLOUD)
	listed.append_array(World.listings(wisps, World.DecorLayer.FOREGROUND, World.DecorPart.WISP))
	return listed


# Tints each cloud from the background gradient behind it (background_color: a world y to its
# colour) and the sky's colour, lighter, drawn a little toward its kind's colour and darker as the
# sky darkens.
func show_sky(sky: SkyLook, background_color: Callable) -> void:
	for i in drawn.size():
		var cloud := drawn[i]
		var shape: Array = KINDS[kinds[i]]
		var behind: Color = background_color.call(cloud.position.y)
		var lightening := LIGHTENING * lerpf(1.0, NIGHT_LIGHTENING, sky.night())
		var color := behind.lerp(sky.ground_color, SKY_LIGHT).lerp(Color.WHITE, lightening).lerp(shape[4], shape[5]).darkened(sky.darkness * NIGHT_DARKENING)
		color.a = WISP_OPACITY if translucent[i] else 1.0
		cloud.color = color


# A lumpy-topped, flat-bottomed ellipse, shaped by its kind.
static func outline(half: Vector2, kind := Kind.CUMULUS) -> PackedVector2Array:
	var shape: Array = KINDS[kind]
	var lumps: float = shape[1]
	var lump_height: float = shape[2]
	var bottom_squash: float = shape[3]
	var points := PackedVector2Array()
	for side in SIDES:
		var angle := TAU * side / SIDES
		var point := Vector2(cos(angle) * half.x, sin(angle) * half.y)
		if point.y < 0.0:
			point.y *= 1.0 + lump_height * absf(sin(angle * lumps))
		else:
			point.y *= bottom_squash
		points.append(point)
	return points
