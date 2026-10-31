class_name ShipType
extends RefCounted
# The ship type table: every ship type's shapes and numbers. The source of truth
# for per-ship values; rules shared by all ship types stay in lander.gd.

var name: String
# One line on the Ship offer saying what the ship type is for.
var flavour: String
# Outline used for drawing, collision and the docking check. Nose points up (-y).
var hull: PackedVector2Array
var flame: PackedVector2Array
var default_dry_mass: float
var maximum_weight: float
var tank: float
var passenger_seats: int
# The maximum capacity: the most cargo it can carry at all, in kg.
var cargo_capacity: float
# Thrust acceleration in px/s² at the reference mass.
var thrust: float
# Fuel burn in kg/s at the reference mass.
var burn_rate: float
# Rad/s.
var turn_rate: float
# Ship offer ratings out of 5 blocks, for comparing ship types at a glance.
var thrust_rating: int
var handling_rating: int

# Named like constants: GDScript can't build objects in a const, so never reassign these.
static var SPARROW := sparrow()
static var MULE := mule()
static var HALO := halo()
static var ALL: Array[ShipType] = [SPARROW, MULE, HALO]


# The full-Tank cargo: the cargo that, with these passengers aboard, still leaves room for a
# full Tank under the Maximum weight, never above the maximum capacity.
func full_tank_cargo(passengers := 0) -> float:
	return clampf(maximum_weight - default_dry_mass - tank - passengers * TransportOffer.PASSENGER_MASS,
		0.0, cargo_capacity)


static func sparrow() -> ShipType:
	var type := ShipType.new()
	type.name = "Sparrow"
	type.flavour = "Small, light and quick. Built for short hops."
	type.hull = PackedVector2Array([Vector2(0, -20), Vector2(14, 14), Vector2(-14, 14)])
	type.flame = PackedVector2Array([Vector2(-7, 14), Vector2(7, 14), Vector2(0, 30)])
	type.default_dry_mass = 10000.0
	type.maximum_weight = 22000.0
	type.tank = 5000.0
	type.passenger_seats = 4
	type.cargo_capacity = 8000.0
	type.thrust = 150.0
	# Nominally 20 s of thrust on a full tank (Tank / burn); it measures ~24 s in play,
	# as burn falls with the ship's weight. Other ship types' thrust times are tuned as
	# ratios to the measured value.
	type.burn_rate = type.tank / 20.0
	type.turn_rate = 3.0
	type.thrust_rating = 5
	type.handling_rating = 5
	return type


static func mule() -> ShipType:
	var type := ShipType.new()
	type.name = "Mule"
	type.flavour = "Long, heavy and slow. Hauls the big loads."
	# 42×68 px, long axis along the thrust, engine on the short side at the back.
	type.hull = rounded_nose_box(42.0, 68.0, 4.0, 3)
	type.flame = PackedVector2Array([Vector2(-10, 34), Vector2(10, 34), Vector2(0, 54)])
	type.default_dry_mass = 20000.0
	type.maximum_weight = 41000.0
	type.tank = 12000.0
	type.passenger_seats = 4
	type.cargo_capacity = 16000.0
	type.thrust = 316.0
	type.burn_rate = 207.0
	type.turn_rate = 1.5
	type.thrust_rating = 2
	type.handling_rating = 2
	return type


# A C-shaped ring, open at the nose, with the flame at the back. Its hull is
# concave; CollisionPolygon2D's default solids build mode splits it into convex parts.
static func halo() -> ShipType:
	var type := ShipType.new()
	type.name = "Halo"
	type.flavour = "A balanced ring for mixed runs. Open at the nose."
	type.hull = ring(20.0, 8.0, deg_to_rad(30.0), 10)
	type.flame = PackedVector2Array([Vector2(-6, 18), Vector2(6, 18), Vector2(0, 33)])
	type.default_dry_mass = 14000.0
	type.maximum_weight = 32000.0
	type.tank = 8000.0
	type.passenger_seats = 10
	type.cargo_capacity = 11000.0
	# Tuned against the Sparrow in tests/test_halo.gd: climbs off the pad at ~80%,
	# lasts ~1.2x as long on a full tank of continuous thrust.
	type.thrust = 214.0
	type.burn_rate = 231.0
	type.turn_rate = 2.2
	type.thrust_rating = 4
	type.handling_rating = 4
	return type


# Outline of a width × height box centred on the origin, with its two nose (-y)
# corners rounded to radius in segments steps each; the back corners stay square.
static func rounded_nose_box(width: float, height: float, radius: float, segments: int) -> PackedVector2Array:
	var half := Vector2(width, height) / 2.0
	var outline := PackedVector2Array()
	for corner: Vector2 in [Vector2(-half.x + radius, -half.y + radius), Vector2(half.x - radius, -half.y + radius)]:
		var start_angle := PI if corner.x < 0.0 else PI * 1.5
		for i in segments + 1:
			var angle := start_angle + PI / 2.0 * float(i) / segments
			outline.append(corner + Vector2(cos(angle), sin(angle)) * radius)
	outline.append(Vector2(half.x, half.y))
	outline.append(Vector2(-half.x, half.y))
	return outline


# Outline of a ring with a gap of 2 * gap_half_angle centred on the nose (-y):
# the outer arc one way round, then the inner arc back.
static func ring(outer_radius: float, inner_radius: float, gap_half_angle: float, segments: int) -> PackedVector2Array:
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in segments + 1:
		var angle := lerpf(gap_half_angle, TAU - gap_half_angle, float(i) / segments)
		var direction := Vector2(sin(angle), -cos(angle))
		outer.append(direction * outer_radius)
		inner.append(direction * inner_radius)
	inner.reverse()
	return outer + inner
