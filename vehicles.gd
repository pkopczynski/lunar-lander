class_name Vehicles
extends Node2D
# A location's distant flying vehicles: small hulls crossing its sky behind the buildings, each with
# a light, in parallax layers anchored on the pad that move more slowly than the world (one per
# depth: each vehicle has its own scroll scale, by default SCROLL). Each one
# wraps around from one side to the other well outside the view. No collider. Moving a vehicle only
# changes its position, so nothing is redrawn as they fly. The hulls dim with the sky like the
# scenery; their lights are never dimmed and grow brighter as it darkens (see CityLights).

# Tuning, expected to change in playtests.
const SCROLL := Vector2(0.5, 0.96)
const HULL_COLOR := Color(0.42, 0.45, 0.5)
const HULL := [Vector2(-12, 0), Vector2(-8, -4), Vector2(6, -4), Vector2(12, 0), Vector2(8, 3), Vector2(-9, 3)]
const LIGHT_COLOR := Color(0.6, 0.9, 1.0)
const LIGHT_RADIUS := 1.5
# Where each light sits on its hull, at its nose.
const LIGHT_OFFSET := Vector2(9, -1)
const SIDES := 8
# Each Vehicle's trail of light streams behind it, as long as it flies in TRAIL_SECONDS (so faster
# Vehicles leave longer trails), from TRAIL_HALF_WIDTH at its tail to a thin end, fading from
# TRAIL_ALPHA to nothing.
const TRAIL_SECONDS := 2.0
const TRAIL_TAIL_X := -7.0
const TRAIL_HALF_WIDTH := 1.5
const TRAIL_END_HALF_WIDTH := 0.4
const TRAIL_ALPHA := 0.7


# One vehicle: where it is as designed (with the camera on the pad, before it flies), its speed
# in px/s, rightwards (negative: leftwards), and its depth (its parallax layer's scroll scale).
class Vehicle:
	var start: Vector2
	var speed: float
	var scroll: Vector2

	func _init(at: Vector2, px_per_s: float, scroll_scale := SCROLL) -> void:
		start = at
		speed = px_per_s
		scroll = scroll_scale


# The Vehicles flying in lanes (each [height, depth, speed, xs], see Location.METROPOLIS_LANES),
# placed so each lane is at the middle of the screen when the camera has climbed its height above
# pad_top_y: a layer comes down the screen more slowly than the world, by its vertical scroll scale.
static func in_lanes(lanes: Array, pad_top_y: float) -> Array[Vehicle]:
	var vehicles: Array[Vehicle] = []
	for lane: Array in lanes:
		var height: float = lane[0]
		var scroll: Vector2 = lane[1]
		for x: float in lane[3]:
			vehicles.append(Vehicle.new(Vector2(x, pad_top_y - height * scroll.y), lane[2], scroll))
	return vehicles


# The hulls, their lights and their trails as drawn.
var hulls: Array[Polygon2D] = []
var lights: Array[Polygon2D] = []
var trails: Array[Polygon2D] = []
var speeds := PackedFloat32Array()
var designed_x := PackedFloat32Array()
var flown := 0.0


# Builds the vehicles afresh, each depth in its own layer anchored on anchor.
func build(from: Array[Vehicle], anchor: Vector2) -> void:
	DecorKit.clear(self)
	hulls.clear()
	lights.clear()
	trails.clear()
	speeds.clear()
	designed_x.clear()
	flown = 0.0
	var layers := DecorKit.Depths.new(self, anchor)
	for vehicle in from:
		var hull := Polygon2D.new()
		# Flying leftwards, the hull faces left.
		hull.polygon = PackedVector2Array(HULL)
		hull.scale.x = signf(vehicle.speed) if vehicle.speed != 0.0 else 1.0
		hull.color = HULL_COLOR
		hull.position = vehicle.start
		layers.at(vehicle.scroll).add_child(hull)
		var light := Polygon2D.new()
		light.polygon = DecorKit.disc(LIGHT_OFFSET, LIGHT_RADIUS, SIDES)
		light.color = LIGHT_COLOR
		hull.add_child(light)
		var trail := trail_for(vehicle.speed)
		hull.add_child(trail)
		trails.append(trail)
		hulls.append(hull)
		lights.append(light)
		speeds.append(vehicle.speed)
		designed_x.append(vehicle.start.x)


func _process(delta: float) -> void:
	flown += delta
	for i in hulls.size():
		hulls[i].position.x = DecorKit.wrapped_x(designed_x[i] + speeds[i] * flown)


# A trail of light for a Vehicle flying at speed, streaming back from its tail, drawn behind its
# hull. In the hull's frame, which faces the way it flies.
static func trail_for(speed: float) -> Polygon2D:
	var end_x := TRAIL_TAIL_X - absf(speed) * TRAIL_SECONDS
	var trail := Polygon2D.new()
	trail.polygon = PackedVector2Array([
		Vector2(TRAIL_TAIL_X, -TRAIL_HALF_WIDTH), Vector2(TRAIL_TAIL_X, TRAIL_HALF_WIDTH),
		Vector2(end_x, TRAIL_END_HALF_WIDTH), Vector2(end_x, -TRAIL_END_HALF_WIDTH),
	])
	var bright := Color(LIGHT_COLOR, TRAIL_ALPHA)
	var gone := Color(LIGHT_COLOR, 0.0)
	trail.vertex_colors = PackedColorArray([bright, bright, gone, gone])
	trail.show_behind_parent = true
	return trail


# The hulls, behind the surface, then their lights and trails, for World.shown_decor().
func listed_decor() -> Array[World.Listing]:
	var listed := World.listings(hulls, World.DecorLayer.PARALLAX, World.DecorPart.VEHICLE)
	listed.append_array(World.listings(lights, World.DecorLayer.LIGHTS, World.DecorPart.VEHICLE_LIGHT))
	listed.append_array(World.listings(trails, World.DecorLayer.LIGHTS, World.DecorPart.TRAIL))
	return listed


# Dims the hulls with the sky's darkness, as the scenery is, and brightens their lights and trails.
func show_sky(sky: SkyLook) -> void:
	for i in hulls.size():
		hulls[i].self_modulate = Color.WHITE.darkened(sky.darkness)
		lights[i].self_modulate = CityLights.brightness(sky)
		trails[i].self_modulate = CityLights.brightness(sky)
