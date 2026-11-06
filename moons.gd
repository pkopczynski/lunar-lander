class_name Moons
extends Node2D
# The Moons: the same four other bodies in the surface sky at every location, each location
# placing and sizing them (see Moon). A giant one low, partly behind the Backdrop and in view from
# the pad, a medium one higher and two small ones high up. They're very far away: each sits in its
# own static layer anchored on the pad (a backdrop fixed on screen: it doesn't move as the camera
# does), and fades out as it nears the Border (World.high_sky_opacity()), so deep space never shows them. Muted
# colours, a fixed lit side and no phases; faint by day, clear at night. No collider.

# Tuning, expected to change in playtests.
# The four bodies, giant first: their colour (dusty rose, blue-grey, ochre, bone). They don't scroll
# with the camera at all (SCROLL).
# Shaded, each colour must stay 0.1 from every solid terrain colour, however dimmed (see
# test_tonal_depth.gd).
const COLORS: Array[Color] = [
	Color(0.8, 0.58, 0.58), Color(0.6, 0.65, 0.72), Color(0.77, 0.67, 0.45), Color(0.86, 0.83, 0.75),
]
const SCROLL := Vector2.ZERO
# Where each location shows the four, giant first: each centre as seen from the pad's top (with the
# camera centred there) and radius.
# They stay where they're placed on screen, so they're placed within the sky the view shows above the pad
# at the surface zoom.
const VALLEY := [
	[Vector2(-170, -170), 150.0], [Vector2(330, -205), 38.0], [Vector2(-390, -225), 14.0], [Vector2(170, -235), 11.0],
]
const MINE := [
	[Vector2(-360, -150), 180.0], [Vector2(-40, -215), 44.0], [Vector2(250, -230), 16.0], [Vector2(390, -195), 12.0],
]
const METROPOLIS := [
	[Vector2(-350, -130), 145.0], [Vector2(220, -210), 36.0], [Vector2(-130, -235), 13.0], [Vector2(400, -225), 10.0],
]
# The side away from the sun, toward which each Moon shades, is this much darker than its lit side.
const SHADE := 0.45
const LIT_FROM := Vector2(-0.6, -0.8)
# How opaque the Moons are by day; they're fully opaque at full night.
const DAY_ALPHA := 0.3
const SIDES := 48


# Where a location shows one Moon: its centre as seen from the pad's top, and its radius.
class Moon:
	var center: Vector2
	var radius: float

	func _init(at: Vector2, size: float) -> void:
		center = at
		radius = size


static func placed(table: Array) -> Array[Moon]:
	var moons: Array[Moon] = []
	for moon in table:
		moons.append(Moon.new(moon[0], moon[1]))
	return moons


static func valley() -> Array[Moon]:
	return placed(VALLEY)


static func mine() -> Array[Moon]:
	return placed(MINE)


static func metropolis() -> Array[Moon]:
	return placed(METROPOLIS)


# The Moons as drawn, and each one's top, for fading it out near the Border.
var pieces: Array[Polygon2D] = []
var tops := PackedFloat32Array()


func _process(_delta: float) -> void:
	DecorKit.fade_toward_border(pieces, tops)


# Builds the Moons afresh where the location places them, each in its own layer anchored on anchor.
func build(from: Array[Moon], anchor: Vector2) -> void:
	DecorKit.clear(self)
	pieces.clear()
	tops.clear()
	for i in mini(from.size(), COLORS.size()):
		var moon := from[i]
		var visual := DecorKit.add_in_layer(self, DecorKit.disc(anchor + moon.center, moon.radius, SIDES), SCROLL, anchor)
		var shades := PackedColorArray()
		for point in visual.polygon:
			var lit := ((point - anchor - moon.center) / moon.radius).dot(LIT_FROM.normalized()) * 0.5 + 0.5
			shades.append(COLORS[i].darkened(SHADE * (1.0 - lit)))
		visual.vertex_colors = shades
		visual.add_to_group(World.HIGH_SKY_GROUP)
		pieces.append(visual)
		tops.append(DecorKit.top_of(visual.polygon))


# The Moons, for World.shown_decor().
func listed_decor() -> Array[World.Listing]:
	return World.listings(pieces, World.DecorLayer.PARALLAX, World.DecorPart.MOON)


# Faint by day, clear at night.
func show_sky(sky: SkyLook) -> void:
	for moon in pieces:
		moon.modulate.a = lerpf(DAY_ALPHA, 1.0, sky.night())
