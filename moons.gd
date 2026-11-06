class_name Moons
extends Node2D
# The Moons: the same four other bodies in the surface sky at every location, each location
# placing and sizing them (see Moon). A giant one low, partly behind the Backdrop and in view from
# the pad (above the Mine's walls and the Metropolis's towers, higher up), a medium one higher and
# two small ones high up. Each sits in its own layer anchored on
# the pad (SCROLL): very far away sideways, so flying across barely moves it, and fixed in the
# world up and down, so it stays in its spot in the sky and sinks out of view as the ship climbs,
# long before the Border, so deep space never shows them. Muted colours, a fixed lit side and no phases; faint by day, clear at night. No collider.

# Tuning, expected to change in playtests.
# The four bodies, giant first: their colour (dusty rose, blue-grey, ochre, bone).
# Shaded, each colour must stay 0.1 from every solid terrain colour, however dimmed (see
# test_tonal_depth.gd).
const COLORS: Array[Color] = [
	Color(0.8, 0.58, 0.58), Color(0.6, 0.65, 0.72), Color(0.77, 0.67, 0.45), Color(0.86, 0.83, 0.75),
]
# How fast they scroll with the camera, the world's being 1: barely at all sideways, like the world
# up and down.
const SCROLL := Vector2(0.03, 1.0)
# Where each location shows the four, giant first: each centre, from the pad's top, and radius.
# Each location places them where they first show above its own scenery, at the surface zoom: the
# Valley's within the sky the view shows with the ship resting on its pad (the camera there sits
# 203 px above the pad's top, its bottom held at the location's lowest point), the Mine's and the
# Metropolis's, whose walls and towers hide that sky, within the sky the view shows with the ship
# 700 px above its pad (the camera 720 px above the pad's top).
const VALLEY := [
	[Vector2(-170, -373), 150.0], [Vector2(330, -408), 38.0], [Vector2(-390, -428), 14.0], [Vector2(170, -438), 11.0],
]
const MINE := [
	[Vector2(-360, -870), 180.0], [Vector2(-40, -935), 44.0], [Vector2(250, -950), 16.0], [Vector2(390, -915), 12.0],
]
const METROPOLIS := [
	[Vector2(-350, -850), 145.0], [Vector2(220, -930), 36.0], [Vector2(-130, -955), 13.0], [Vector2(400, -945), 10.0],
]
# The side away from the sun, toward which each Moon shades, is this much darker than its lit side.
const SHADE := 0.45
const LIT_FROM := Vector2(-0.6, -0.8)
# How opaque the Moons are by day; they're fully opaque at full night.
const DAY_ALPHA := 0.3
const SIDES := 48


# Where a location shows one Moon: its centre from the pad's top, and its radius.
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


# The Moons as drawn.
var pieces: Array[Polygon2D] = []


# Builds the Moons afresh where the location places them, each in its own layer anchored on anchor.
func build(from: Array[Moon], anchor: Vector2) -> void:
	DecorKit.clear(self)
	pieces.clear()
	for i in mini(from.size(), COLORS.size()):
		var moon := from[i]
		var visual := DecorKit.add_in_layer(self, DecorKit.disc(anchor + moon.center, moon.radius, SIDES), SCROLL, anchor)
		var shades := PackedColorArray()
		for point in visual.polygon:
			var lit := ((point - anchor - moon.center) / moon.radius).dot(LIT_FROM.normalized()) * 0.5 + 0.5
			shades.append(COLORS[i].darkened(SHADE * (1.0 - lit)))
		visual.vertex_colors = shades
		pieces.append(visual)


# The Moons, for World.shown_decor().
func listed_decor() -> Array[World.Listing]:
	return World.listings(pieces, World.DecorLayer.PARALLAX, World.DecorPart.MOON)


# Faint by day, clear at night.
func show_sky(sky: SkyLook) -> void:
	for moon in pieces:
		moon.modulate.a = lerpf(DAY_ALPHA, 1.0, sky.night())
