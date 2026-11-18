class_name OwnedShip
extends RefCounted
# An Owned ship: one ship the player owns. Its Ship type, its automatic name (the type plus a
# per-type number, "SPARROW 1"), its fuel in tank (kg) and its Condition (1.0 is 100%).
#
# Its effective numbers (`dry_mass()`, `maximum_weight()`, `tank()`, `thrust()`, `burn_rate()`,
# `turn_rate()`, `full_tank_cargo()`) are what the Lander flies. For now they are its Ship type's;
# upgrades will add to them here, so read a ship's numbers through these, never from its type.
# Seats and the maximum capacity are the type's alone.
#
# Owned ships belong to the Hangar: only its named operations create or change them. The one
# exception is the fuel in tank of the ship in service, which the Lander burns and refuels in flight.

var ship_type: ShipType
var name: String
var fuel: float
var condition := 1.0


func _init(type: ShipType, number: int) -> void:
	ship_type = type
	name = "%s %d" % [type.name.to_upper(), number]
	fuel = tank()


func dry_mass() -> float:
	return ship_type.default_dry_mass


func maximum_weight() -> float:
	return ship_type.maximum_weight


func tank() -> float:
	return ship_type.tank


# Thrust acceleration in px/s² at the reference mass.
func thrust() -> float:
	return ship_type.thrust


# Fuel burn in kg/s at the reference mass.
func burn_rate() -> float:
	return ship_type.burn_rate


# Rad/s.
func turn_rate() -> float:
	return ship_type.turn_rate


# The full-Tank cargo: the cargo that, with these passengers aboard, still leaves room for a
# full Tank under the Maximum weight, never above the maximum capacity.
func full_tank_cargo(passengers := 0) -> float:
	return clampf(maximum_weight() - dry_mass() - tank() - passengers * TransportOffer.PASSENGER_MASS,
		0.0, ship_type.cargo_capacity)
