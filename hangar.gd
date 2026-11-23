class_name Hangar
extends Node
# Owns the player's Owned ships, the ship in service and the per-type name counters (Career
# state in a scene node, ADR 0003). Owned ships change only through its named operations; the
# Office calls them and never edits a ship. Attached to `Hangar`.
#
# `_ready()` starts the Career with SPARROW 1 in service. Hits wear its Condition down in flight
# (the Lander does that). A crash (the Lander's `crashed`) makes the ship in service a Wreck
# (Condition 0%); `recover()` brings it back Docked at the station, still in service (Recovery,
# after a crash or when Stranded); `repair(ship)` restores any owned ship to 100%. `buy(type)` adds a new owned ship of that
# type to a free berth, full tank, not in service; `sell(ship)` takes one that isn't in service out
# of the Hangar; `put_in_service(ship)` is the Ship swap: it hands the ship to the Lander (`fly()`)
# and docks it in the parking spot (`start_docked()`), keeping each ship's own fuel. The Lander
# never learns of the Hangar. The Hangar has `BERTHS` berths and the ship in service takes one.
# Money is the Economy's: the Office charges a purchase and pays a sale there.
#
# `refuel(ship, kg)` takes fuel already paid for: a ship in a berth gets it at once, the ship in
# service has it pumped at `PUMP_RATE` up to `pumped_to` (`fuel_after_pumping()`), which runs while the
# Office pauses the world (process mode Always) and tells the Lander how long it has left
# (`pump_time_left`), so the ship can't lift off or undock meanwhile. A Ship swap finishes any pumping
# at once. `fuel_cap(ship)` counts the Lander's Load for the ship in service. `top_up()` is the Tester
# panel's Auto-refuel: the ship in service's fuel straight to its fuel cap, free.
#
# Names count up per Ship type and are never reused, even after a ship is sold: selling MULE 1
# leaves MULE 2, and the next Mule is MULE 3.
#
# Must stay below `Lander` in `main.tscn` (its `_ready()` docks the first ship, so the Lander must
# be ready) and above `UI`, `Economy` and `Office` (they read the ship in service from theirs).

const BERTHS := 4
# Litres a second the station pumps into (or out of) the ship in service.
const PUMP_RATE := 500.0

var ships: Array[OwnedShip] = []
var in_service: OwnedShip
# Ship type → the last number given to a ship of that type.
var last_numbers: Dictionary[ShipType, int] = {}
# Whether the station is pumping fuel into or out of the ship in service, and the kg it will hold
# once done (all paid for already).
var pumping := false
var pumped_to := 0.0

@onready var lander: Lander = $"../Lander"


func _ready() -> void:
	put_in_service(add_ship(ShipType.SPARROW))
	lander.crashed.connect(wreck)


# A crash: the ship in service becomes a Wreck.
func wreck() -> void:
	in_service.condition = 0.0


# Recovery: the ship in service, a Wreck after a crash or as it was when Stranded, goes back
# Docked into the parking spot.
func recover() -> void:
	lander.start_docked()


# A repair is always full.
func repair(ship: OwnedShip) -> void:
	ship.condition = 1.0


# Pumping runs whether the Office shows or not (process mode Always).
func _physics_process(delta: float) -> void:
	if not pumping:
		return
	in_service.fuel = move_toward(in_service.fuel, pumped_to, pump_step(delta))
	pumping = in_service.fuel != pumped_to
	show_pump_time()


# Kg the pump moves in this many seconds.
static func pump_step(seconds: float) -> float:
	return PUMP_RATE * OwnedShip.KG_PER_LITRE * seconds


# Fuel bought (kg above 0) or sold back (kg below 0) for an owned ship, already paid for: pumped
# into or out of the ship in service, at once for a ship in a berth.
func refuel(ship: OwnedShip, kg: float) -> void:
	if ship != in_service:
		ship.fuel += kg
		return
	pumped_to = fuel_after_pumping(ship) + kg
	pumping = true
	show_pump_time()


# Tells the Lander how long pumping has left, which keeps it from lifting off meanwhile.
func show_pump_time() -> void:
	lander.pump_time_left = absf(pumped_to - in_service.fuel) / pump_step(1.0) if pumping else 0.0


# The fuel in an owned ship's tank once any pumping under way is done.
func fuel_after_pumping(ship: OwnedShip) -> float:
	return pumped_to if pumping and ship == in_service else ship.fuel


# Whatever is still to pump goes in (or out) at once, as for a ship in a berth.
func finish_pumping() -> void:
	in_service.fuel = fuel_after_pumping(in_service)
	pumping = false
	show_pump_time()


# Tester mode's Auto-refuel: the ship in service's fuel straight to its fuel cap, free, no
# Transaction. It waits while pumping is under way, so paid fuel (or a sell-back) still finishes.
func top_up() -> void:
	if not pumping:
		in_service.fuel = fuel_cap(in_service)


# The most fuel an owned ship may hold: the ship in service's counts the Load aboard or coming aboard.
func fuel_cap(ship: OwnedShip) -> float:
	return lander.fuel_cap() if ship == in_service else ship.fuel_cap()


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
	if in_service:
		finish_pumping()
	in_service = ship
	lander.fly(ship)
	lander.start_docked()


func full() -> bool:
	return ships.size() >= BERTHS


# How many owned ships are of this type.
func count_of(type: ShipType) -> int:
	return ships.filter(func(ship: OwnedShip) -> bool: return ship.ship_type == type).size()
