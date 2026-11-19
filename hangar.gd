class_name Hangar
extends Node
# Owns the player's Owned ships, the ship in service and the per-type name counters (Career
# state in a scene node, ADR 0003). Owned ships change only through its named operations; the
# Office calls them and never edits a ship. Attached to `Hangar`.
#
# `_ready()` starts the Career with SPARROW 1 in service. A crash (the Lander's `crashed`) makes the
# ship in service a Wreck (Condition 0%); `recover()` brings it back Docked at the station, still in
# service (Recovery); `repair(ship)` restores any owned ship to 100%. `buy(type)` adds a new owned ship of that
# type to a free berth, full tank, not in service; `sell(ship)` takes one that isn't in service out
# of the Hangar; `put_in_service(ship)` is the Ship swap: it hands the ship to the Lander (`fly()`)
# and docks it in the parking spot (`start_docked()`), keeping each ship's own fuel. The Lander
# never learns of the Hangar. The Hangar has `BERTHS` berths and the ship in service takes one.
# Money is the Economy's: the Office charges a purchase and pays a sale there.
#
# Names count up per Ship type and are never reused, even after a ship is sold: selling MULE 1
# leaves MULE 2, and the next Mule is MULE 3.
#
# Must stay below `Lander` in `main.tscn` (its `_ready()` docks the first ship, so the Lander must
# be ready) and above `UI`, `Economy` and `Office` (they read the ship in service from theirs).

const BERTHS := 4

var ships: Array[OwnedShip] = []
var in_service: OwnedShip
# Ship type → the last number given to a ship of that type.
var last_numbers: Dictionary[ShipType, int] = {}

@onready var lander: Lander = $"../Lander"


func _ready() -> void:
	put_in_service(add_ship(ShipType.SPARROW))
	lander.crashed.connect(wreck)


# A crash: the ship in service becomes a Wreck.
func wreck() -> void:
	in_service.condition = 0.0


# Recovery: the ship in service, a Wreck after a crash, goes back Docked into the parking spot.
func recover() -> void:
	lander.start_docked()


# A repair is always full.
func repair(ship: OwnedShip) -> void:
	ship.condition = 1.0


# A new owned ship of this type in a free berth, with a full tank; it doesn't go into service.
func buy(type: ShipType) -> OwnedShip:
	assert(not full(), "buying needs a free berth")
	return add_ship(type)


# Takes a ship out of the Hangar for good; never the ship in service.
func sell(ship: OwnedShip) -> void:
	assert(ship != in_service, "the ship in service can't be sold")
	ships.erase(ship)


func add_ship(type: ShipType) -> OwnedShip:
	var number: int = last_numbers.get(type, 0) + 1
	last_numbers[type] = number
	var ship := OwnedShip.new(type, number)
	ships.append(ship)
	return ship


# The Ship swap: this owned ship goes Docked into the parking spot with its own fuel.
func put_in_service(ship: OwnedShip) -> void:
	in_service = ship
	lander.fly(ship)
	lander.start_docked()


func full() -> bool:
	return ships.size() >= BERTHS


# How many owned ships are of this type.
func count_of(type: ShipType) -> int:
	return ships.filter(func(ship: OwnedShip) -> bool: return ship.ship_type == type).size()
