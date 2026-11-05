class_name Vehicles
extends Node2D
# A location's distant flying vehicles: small hulls crossing its sky behind the buildings, each with
# a light, in one parallax layer anchored on the pad that moves more slowly than the world. Each one
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


# One vehicle: where it is as designed (with the camera on the pad, before it flies) and its speed
# in px/s, rightwards (negative: leftwards).
class Vehicle:
	var start: Vector2
	var speed: float

	func _init(at: Vector2, px_per_s: float) -> void:
		start = at
		speed = px_per_s


# The hulls and their lights as drawn, the pieces World.shown_decor() lists.
var hulls: Array[Polygon2D] = []
var lights: Array[Polygon2D] = []
var speeds := PackedFloat32Array()
var designed_x := PackedFloat32Array()
var flown := 0.0


# Builds the vehicles afresh, in a layer anchored on anchor.
func build(from: Array[Vehicle], anchor: Vector2) -> void:
	DecorKit.clear(self)
	hulls.clear()
	lights.clear()
	speeds.clear()
	designed_x.clear()
	flown = 0.0
	var layer := AnchoredParallax.new(SCROLL, anchor)
	add_child(layer)
	for vehicle in from:
		var hull := Polygon2D.new()
		# Flying leftwards, the hull faces left.
		hull.polygon = PackedVector2Array(HULL)
		hull.scale.x = signf(vehicle.speed) if vehicle.speed != 0.0 else 1.0
		hull.color = HULL_COLOR
		hull.position = vehicle.start
		layer.add_child(hull)
		var light := Polygon2D.new()
		light.polygon = DecorKit.disc(LIGHT_OFFSET, LIGHT_RADIUS, SIDES)
		light.color = LIGHT_COLOR
		hull.add_child(light)
		hulls.append(hull)
		lights.append(light)
		speeds.append(vehicle.speed)
		designed_x.append(vehicle.start.x)


func _process(delta: float) -> void:
	flown += delta
	for i in hulls.size():
		hulls[i].position.x = DecorKit.wrapped_x(designed_x[i] + speeds[i] * flown)


# Dims the hulls with the sky's darkness, as the scenery is, and brightens their lights.
func show_sky(sky: SkyLook) -> void:
	for i in hulls.size():
		hulls[i].self_modulate = Color.WHITE.darkened(sky.darkness)
		lights[i].self_modulate = CityLights.brightness(sky)
