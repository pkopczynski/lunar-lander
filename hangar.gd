class_name Hangar
extends Node
# Owns the player's Owned ships, the ship in service and the per-type name counters (Career
# state in a scene node, ADR 0003). Owned ships change only through its named operations; the
# Office calls them and never edits a ship. Attached to `Hangar`.
#
# `_ready()` starts the Career with SPARROW 1 in service. `replace_in_service(type)` is today's
# Ship swap: the ship in service is replaced by a new owned ship of that type, with a full tank.
# Every operation that changes the ship in service hands it to the Lander (`fly()`) and docks it
# in the parking spot (`start_docked()`); the Lander never learns of the Hangar.
#
# Names count up per Ship type and are never reused, even after a ship is gone: swapping
# Sparrow → Mule → Sparrow ends with SPARROW 2 in service.
#
# Must stay below `Lander` in `main.tscn` (its `_ready()` docks the first ship, so the Lander must
# be ready) and above `UI`, `Economy` and `Office` (they read the ship in service from theirs).

var ships: Array[OwnedShip] = []
var in_service: OwnedShip
# Ship type name → the last number given to a ship of that type.
var last_numbers := {}

@onready var lander: Lander = $"../Lander"


func _ready() -> void:
	put_in_service(add_ship(ShipType.SPARROW))


# Replaces the ship in service with a new owned ship of this type, full tank, Docked.
func replace_in_service(type: ShipType) -> void:
	var old := in_service
	put_in_service(add_ship(type))
	ships.erase(old)


func add_ship(type: ShipType) -> OwnedShip:
	var number: int = last_numbers.get(type.name, 0) + 1
	last_numbers[type.name] = number
	var ship := OwnedShip.new(type, number)
	ships.append(ship)
	return ship


func put_in_service(ship: OwnedShip) -> void:
	in_service = ship
	lander.fly(ship)
	lander.start_docked()
