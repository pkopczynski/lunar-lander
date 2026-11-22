class_name OwnedShip
extends RefCounted
# An Owned ship: one ship the player owns. Its Ship type, its automatic name (the type plus a
# per-type number, "SPARROW 1"), its fuel in tank (in kg) and its Condition (1.0 is 100%; no effect
# on flight).
#
# Its effective numbers (`dry_mass()`, `maximum_weight()`, `tank()`, `thrust()`, `burn_rate()`,
# `turn_rate()`, `full_tank_cargo()`) are what the Lander flies. For now they are its Ship type's;
# upgrades will add to them here, so read a ship's numbers through these, never from its type.
# Seats and the maximum capacity are the type's alone.
#
# Its value (`value()`: its Ship type's price, upgrades will add theirs), the repair cost of its
# missing Condition at a place (`repair_cost(place)`: missing share × its type's repair rate × value
# × the place markup; at the station when the place is null),
# whether it's a Wreck (`is_wreck()`, Condition 0%), the fee for its Recovery after a crash
# (`recovery_fee()`: `RECOVERY_FEE_SHARE` of its type's price) and what selling it pays (`sale_price()`:
# `SALE_SHARE` of its value less the repair cost, never below €0; the fuel in its tank earns nothing).
#
# Fuel is kept in kg (it's mass) and shown in litres, `KG_PER_LITRE` to the litre. Its price per
# litre at a place (`fuel_price(place)`, in cents) is `FUEL_PRICE_CENTS` × the place markup × its
# type's fuel multiplier, rounded to the cent (the station when the place is null, a pad's Workshop
# otherwise: `Location.markup`); `fuel_cost(kg, place)` is that many litres at that price, in whole
# euros, for buying and selling back (only at the station) alike. A place is a `Location` (its pad)
# or null (the station). `fuel_cap(load)` is the most fuel it may hold with that Load aboard.
#
# Owned ships belong to the Hangar: only its named operations create or change them. The
# exceptions are the ship in service's fuel in tank, which the Lander burns,
# and its Condition, which the Lander wears down on each hit (ADR 0009).

# Selling a ship pays this share of its value, less its repair cost.
const SALE_SHARE := 0.5
# Recovery after a crash costs this share of its Ship type's price (upgrades not counted).
const RECOVERY_FEE_SHARE := 0.05
# Fuel's density, everywhere.
const KG_PER_LITRE := 0.8
# A litre of fuel at the station for a ship type whose fuel multiplier is 1, in cents.
const FUEL_PRICE_CENTS := 60

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


# The fuel cap: a full Tank, or less if this Load would push it past its Maximum weight.
func fuel_cap(load_mass := 0.0) -> float:
	return clampf(maximum_weight() - dry_mass() - load_mass, 0.0, tank())


# Cents per litre of fuel at a place: a pad's Workshop, or the station (null).
func fuel_price(place: Location = null) -> int:
	return roundi(FUEL_PRICE_CENTS * Location.markup_at(place) * ship_type.fuel_multiplier)


# Euros this much fuel (kg) costs at a place, or pays when sold back (at the station).
func fuel_cost(kg: float, place: Location = null) -> int:
	return roundi(kg / KG_PER_LITRE * fuel_price(place) / 100.0)


# Euros: its Ship type's price.
func value() -> int:
	return ship_type.price


# A crashed ship: Condition 0%. It can't be put in service or fly until repaired.
func is_wreck() -> bool:
	return condition <= 0.0


# Euros Recovery costs after a crash: a share of its Ship type's price.
func recovery_fee() -> int:
	return roundi(ship_type.price * RECOVERY_FEE_SHARE)


# Euros to repair its missing Condition at a place: a pad's Workshop, or the station (null).
func repair_cost(place: Location = null) -> int:
	return roundi((1.0 - condition) * ship_type.repair_rate * value() * Location.markup_at(place))


# Euros selling it pays: a share of its value less its repair cost, never below €0.
func sale_price() -> int:
	return maxi(roundi(value() * SALE_SHARE) - repair_cost(), 0)
