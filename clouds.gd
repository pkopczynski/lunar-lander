class_name Clouds
extends Node2D
# A location's clouds: soft, lumpy shapes high in the surface sky, drifting slowly on the wind in
# parallax layers anchored on the pad (one per depth: each cloud has its own scroll scale and wind
# speed, by default the Valley's), tinted by the sky colour behind them. Each one wraps
# around from one side to the other well outside the view, so none ever pops in sight. No collider.
# Moving a cloud only changes its position, so nothing is redrawn as they drift.

# Tuning, expected to change in playtests.
# The Valley's clouds: the centre and half size of each.
const VALLEY := [
	[Vector2(150, -900), Vector2(150, 34)],
	[Vector2(800, -620), Vector2(110, 26)],
	[Vector2(1500, -1050), Vector2(180, 38)],
	[Vector2(1250, -320), Vector2(130, 30)],
	[Vector2(350, -150), Vector2(90, 22)],
	[Vector2(1850, -500), Vector2(120, 28)],
	[Vector2(2700, -780), Vector2(160, 34)],
	[Vector2(-700, -400), Vector2(140, 30)],
]
# A cloud's depth and wind by default.
const SCROLL := Vector2(0.35, 0.95)
# The wind, in px/s; rightwards (negative: leftwards).
const WIND_SPEED := 6.0
# How much lighter than the sky behind it a cloud is by day; at night it darkens with the sky.
const LIGHTENING := 0.45
const NIGHT_DARKENING := 0.8
# Points around each cloud's outline.
const SIDES := 24
# Each cloud's outline: its top raised by up to LUMP_HEIGHT of its half height in LUMPS bumps, its
# bottom squashed to BOTTOM_SQUASH of it, nearly flat.
const LUMPS := 3.0
const LUMP_HEIGHT := 0.35
const BOTTOM_SQUASH := 0.5


# One cloud: its centre and half size, as designed (with the camera on the pad, before it drifts),
# its depth (its parallax layer's scroll scale) and the wind carrying it, in px/s.
class Cloud:
	var center: Vector2
	var half_size: Vector2
	var scroll: Vector2
	var wind: float

	func _init(at: Vector2, half: Vector2, scroll_scale := SCROLL, wind_speed := WIND_SPEED) -> void:
		center = at
		half_size = half
		scroll = scroll_scale
		wind = wind_speed


static func valley() -> Array[Cloud]:
	var clouds: Array[Cloud] = []
	for cloud in VALLEY:
		clouds.append(Cloud.new(cloud[0], cloud[1]))
	return clouds


# The clouds as drawn.
var pieces: Array[Polygon2D] = []
# How long the wind has carried the clouds since they were built, in s.
var drifted := 0.0
var designed_x := PackedFloat32Array()
var winds := PackedFloat32Array()


# Builds the clouds afresh, each depth in its own layer anchored on anchor.
func build(from: Array[Cloud], anchor: Vector2) -> void:
	DecorKit.clear(self)
	pieces.clear()
	designed_x.clear()
	winds.clear()
	drifted = 0.0
	var layers := DecorKit.Depths.new(self, anchor)
	for cloud in from:
		var visual := Polygon2D.new()
		visual.polygon = outline(cloud.half_size)
		visual.position = cloud.center
		layers.at(cloud.scroll).add_child(visual)
		pieces.append(visual)
		designed_x.append(cloud.center.x)
		winds.append(cloud.wind)


func _process(delta: float) -> void:
	drifted += delta
	for i in pieces.size():
		pieces[i].position.x = DecorKit.wrapped_x(designed_x[i] + winds[i] * drifted)


# The clouds, for World.shown_decor().
func listed_decor() -> Array[World.Listing]:
	return World.listings(pieces, World.DecorLayer.PARALLAX, World.DecorPart.CLOUD)


# Tints each cloud from the background gradient behind it (background_color: a world y to its
# colour), lighter by day and darker as the sky darkens.
func show_sky(sky: SkyLook, background_color: Callable) -> void:
	for cloud in pieces:
		var behind: Color = background_color.call(cloud.position.y)
		cloud.color = behind.lerp(Color.WHITE, LIGHTENING).darkened(sky.darkness * NIGHT_DARKENING)


# A flat-bottomed, lumpy-topped ellipse.
static func outline(half: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	for side in SIDES:
		var angle := TAU * side / SIDES
		var point := Vector2(cos(angle) * half.x, sin(angle) * half.y)
		if point.y < 0.0:
			point.y *= 1.0 + LUMP_HEIGHT * absf(sin(angle * LUMPS))
		else:
			point.y *= BOTTOM_SQUASH
		points.append(point)
	return points
