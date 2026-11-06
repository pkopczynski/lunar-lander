class_name Activity
extends Node2D
# A location's signs of work on its Backdrop's structures: red warning lights blinking a little out
# of step, never dimmed and brighter at night (as CityLights' are), and a few slow movers (a crane's
# trolley, a hauler, ore lumps riding a conveyor), silhouettes filled like the depth they move in.
# Each piece sits in a parallax layer anchored on the pad (one per depth, DecorKit.Depths), at the
# scroll scale of the Backdrop depth it stands on, so it stays on its structure. No collider. The
# lights blink through their own modulate and the movers only change position, so nothing is
# redrawn as time passes.

# Tuning, expected to change in playtests.
# Sides of the polygon each warning light is drawn as.
const SIDES := 12

# The Mine's warning lights, each on the top of a structure of a Backdrop depth.
const MINE_UPPER_WALLS_LIGHTS: Array[Vector2] = [
	# The factory's chimney, the headframe and the ropeway's towers.
	Vector2(428, -414), Vector2(880, -154), Vector2(746, -344), Vector2(1856, -264),
	# The crane's mast and the processing plant's taller chimney.
	Vector2(1604, 101), Vector2(2207, -394),
]
const MINE_FAR_WALLS_LIGHTS: Array[Vector2] = [
	# The far chimney and the two cranes' masts.
	Vector2(426, 426), Vector2(1005, 586), Vector2(1785, 396),
]
# The trolley under the upper walls' crane jib: its carriage, cable and hook block, hanging from
# its top; it runs back and forth along the jib.
const TROLLEY := [
	Vector2(-5, 0), Vector2(5, 0), Vector2(5, 4), Vector2(0.75, 4), Vector2(0.75, 26), Vector2(3, 26),
	Vector2(3, 30), Vector2(-3, 30), Vector2(-3, 26), Vector2(-0.75, 26), Vector2(-0.75, 4), Vector2(-5, 4),
]
const TROLLEY_FROM := Vector2(1512, 126)
const TROLLEY_TO := Vector2(1590, 126)
const TROLLEY_SECONDS := 12.0
# The hauler on the far walls' deep floor, behind the pad: a dump truck, standing on its bottom
# middle, driving back and forth.
const HAULER := [
	Vector2(-12, -8), Vector2(2, -8), Vector2(2, -4), Vector2(5, -7), Vector2(10, -7), Vector2(11, -2),
	Vector2(11, 0), Vector2(-11, 0), Vector2(-11, -2),
]
const HAULER_FROM := Vector2(1040, 690)
const HAULER_TO := Vector2(1300, 690)
const HAULER_SECONDS := 30.0
# The ore riding up the upper walls' conveyor (Backdrop.CONVEYOR), from its foot on the lowest
# bench to its head, standing on its top edge; each lump appears at the foot and is tipped off at
# the head.
const ORE := [Vector2(-3, 0), Vector2(-2, -4), Vector2(2, -5), Vector2(3, 0)]
const ORE_FROM := Vector2(1103, 309)
const ORE_TO := Vector2(967, 115)
const ORE_SECONDS := 24.0
const ORE_LUMPS := 4


# One warning light: where it is as designed (with the camera on the pad), and the depth it
# stands in (its parallax layer's scroll scale).
class Light:
	var at: Vector2
	var scroll: Vector2

	func _init(position: Vector2, scroll_scale: Vector2) -> void:
		at = position
		scroll = scroll_scale


# One slow mover: its outline (around its own origin), the two points it moves between as designed,
# how long one way takes in seconds, the depth it moves in, how far into its first trip it starts
# (0 to 1), and whether it starts over from the first point at the second (or turns back).
class Mover:
	var outline: PackedVector2Array
	var from: Vector2
	var to: Vector2
	var seconds: float
	var scroll: Vector2
	var start: float
	var loops: bool

	func _init(shape: Array, start_point: Vector2, end_point: Vector2, one_way_seconds: float, scroll_scale: Vector2,
			start_share := 0.0, starts_over := false) -> void:
		outline = PackedVector2Array(shape)
		from = start_point
		to = end_point
		seconds = one_way_seconds
		scroll = scroll_scale
		start = start_share
		loops = starts_over

	# Where it is, time seconds after it started.
	func at(time: float) -> Vector2:
		var trips := start + time / seconds
		return from.lerp(to, fposmod(trips, 1.0) if loops else pingpong(trips, 1.0))


static func mine_lights() -> Array[Light]:
	var lights: Array[Light] = []
	for at in MINE_UPPER_WALLS_LIGHTS:
		lights.append(Light.new(at, Backdrop.UPPER_WALLS_SCROLL))
	for at in MINE_FAR_WALLS_LIGHTS:
		lights.append(Light.new(at, Backdrop.FAR_WALLS_SCROLL))
	return lights


static func mine_movers() -> Array[Mover]:
	var movers: Array[Mover] = [
		Mover.new(TROLLEY, TROLLEY_FROM, TROLLEY_TO, TROLLEY_SECONDS, Backdrop.UPPER_WALLS_SCROLL),
		Mover.new(HAULER, HAULER_FROM, HAULER_TO, HAULER_SECONDS, Backdrop.FAR_WALLS_SCROLL, 0.4),
	]
	for i in ORE_LUMPS:
		movers.append(Mover.new(ORE, ORE_FROM, ORE_TO, ORE_SECONDS, Backdrop.UPPER_WALLS_SCROLL,
			float(i) / ORE_LUMPS, true))
	return movers


# The warning lights and movers as drawn, and each mover's way.
var lights: Array[Polygon2D] = []
var movers: Array[Polygon2D] = []
var ways: Array[Mover] = []
var time := 0.0


# Builds the pieces afresh, each depth in its own layer anchored on anchor.
func build(from_lights: Array[Light], from_movers: Array[Mover], anchor: Vector2) -> void:
	DecorKit.clear(self)
	lights.clear()
	movers.clear()
	ways = from_movers
	time = 0.0
	var layers := DecorKit.Depths.new(self, anchor)
	for mover in from_movers:
		var visual := Polygon2D.new()
		visual.polygon = mover.outline
		layers.at(mover.scroll).add_child(visual)
		movers.append(visual)
	for light in from_lights:
		var visual := Polygon2D.new()
		visual.polygon = DecorKit.disc(light.at, CityLights.WARNING_RADIUS, SIDES)
		visual.color = CityLights.WARNING_COLOR
		layers.at(light.scroll).add_child(visual)
		lights.append(visual)
	animate()


func _process(delta: float) -> void:
	time += delta
	animate()


# Moves each mover along its way and blinks each light through its own modulate.
func animate() -> void:
	for i in movers.size():
		movers[i].position = ways[i].at(time)
	for i in lights.size():
		lights[i].modulate.a = CityLights.blink_alpha(time, i)


# The movers, on the Backdrop, then the warning lights, for World.shown_decor().
func listed_decor() -> Array[World.Listing]:
	return World.listings(movers, World.DecorLayer.BACKDROP, World.DecorPart.MOVER) \
		+ World.listings(lights, World.DecorLayer.LIGHTS, World.DecorPart.WARNING_LIGHT)


# Fills each mover like the Backdrop depth it moves in, and brightens the lights with the sky's
# darkness, as the city's; they're never dimmed.
func show_sky(sky: SkyLook, backdrop: Backdrop) -> void:
	for i in movers.size():
		movers[i].color = backdrop.color_of(ways[i].scroll)
	for light in lights:
		light.self_modulate = CityLights.brightness(sky)
