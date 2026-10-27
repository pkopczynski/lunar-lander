class_name ShipType
extends RefCounted
# The ship type table: every ship type's shapes and numbers. The source of truth
# for per-ship values; rules shared by all ship types stay in lander.gd.

var name: String
# One line on the Offer saying what the ship type is for.
var flavour: String
# Outline used for drawing, collision and the docking check. Nose points up (-y).
var hull: PackedVector2Array
var flame: PackedVector2Array
var default_dry_mass: float
var maximum_weight: float
var tank: float
# Thrust acceleration in px/s² at the reference mass.
var thrust: float
# Fuel burn in kg/s at the reference mass.
var burn_rate: float
# Rad/s.
var turn_rate: float
# Offer ratings out of 5 blocks, for comparing ship types at a glance.
var thrust_rating: int
var handling_rating: int

static var SPARROW := sparrow()
static var ALL: Array[ShipType] = [SPARROW]


static func sparrow() -> ShipType:
	var type := ShipType.new()
	type.name = "Sparrow"
	type.flavour = "Small, light and quick. Built for short hops."
	type.hull = PackedVector2Array([Vector2(0, -20), Vector2(14, 14), Vector2(-14, 14)])
	type.flame = PackedVector2Array([Vector2(-7, 14), Vector2(7, 14), Vector2(0, 30)])
	type.default_dry_mass = 10000.0
	type.maximum_weight = 17000.0
	type.tank = 5000.0
	type.thrust = 150.0
	# A default ship empties its tank in ~20 s of thrust.
	type.burn_rate = type.tank / 20.0
	type.turn_rate = 3.0
	type.thrust_rating = 5
	type.handling_rating = 5
	return type
