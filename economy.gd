class_name Economy
extends Node
# The run's economy: the pilot's Bank account balance, the Transport offer pool and the
# Contracts. It lives in the scene, so a restart (a scene reload) wipes it, and it keeps
# running while the Office pauses the world.

const PILOT := "PILOT"
const MAX_OFFERS := 5

# In whole euros. It may go negative.
var balance := 0
# The Transport offers on the Terminal, oldest first.
var offers: Array[TransportOffer] = []
# Accepted Transport offers.
var contracts: Array[TransportOffer] = []
var rng := RandomNumberGenerator.new()
var last_offer_number := 0

@onready var lander: Lander = $"../Lander"


func _ready() -> void:
	rng.randomize()
	refill()


# Ticked in physics so the --fixed-fps tests stay deterministic.
func _physics_process(delta: float) -> void:
	for offer in offers:
		offer.time_left -= delta
	offers = offers.filter(func(offer: TransportOffer) -> bool: return offer.time_left > 0.0)
	refill()


# Starts the offer pool over from this seed, numbered from #001. For tests.
func reseed(value: int) -> void:
	rng.seed = value
	offers.clear()
	last_offer_number = 0
	refill()


# Puts a known offer in the pool, in place of the one closest to expiring, with the next number.
func put_offer(offer: TransportOffer) -> void:
	if offers.size() >= MAX_OFFERS:
		offers.erase(closest_to_expiring())
	last_offer_number += 1
	offer.number = last_offer_number
	offers.append(offer)


# Tops the pool up to MAX_OFFERS. If none fits what the ship has left while something could,
# the offer closest to expiring is replaced right away by one that fits.
func refill() -> void:
	while offers.size() < MAX_OFFERS:
		offers.append(next_offer(largest_seats(), largest_cargo()))
	var seats := seats_left()
	var cargo := cargo_left()
	if not TransportOffer.could_fit(seats, cargo):
		return
	for offer in offers:
		if offer.misfit_reason(seats, cargo) == "":
			return
	offers.erase(closest_to_expiring())
	offers.append(next_offer(seats, cargo))


func next_offer(max_passengers: int, max_cargo: float) -> TransportOffer:
	last_offer_number += 1
	return TransportOffer.generate(rng, last_offer_number, max_passengers, max_cargo)


func closest_to_expiring() -> TransportOffer:
	var closest := offers[0]
	for offer in offers:
		if offer.time_left < closest.time_left:
			closest = offer
	return closest


# Why the ship can't take this offer on top of the Contracts, or "" when it can.
func misfit_reason(offer: TransportOffer) -> String:
	return offer.misfit_reason(seats_left(), cargo_left())


func seats_left() -> int:
	var taken := 0
	for contract in contracts:
		taken += contract.passengers
	return lander.ship_type.passenger_seats - taken


func cargo_left() -> float:
	var taken := 0.0
	for contract in contracts:
		taken += contract.cargo_mass
	return lander.ship_type.cargo_capacity - taken


# Generated offers may be too big for the smaller ship types on purpose.
static func largest_seats() -> int:
	var most := 0
	for type in ShipType.ALL:
		most = maxi(most, type.passenger_seats)
	return most


static func largest_cargo() -> float:
	var most := 0.0
	for type in ShipType.ALL:
		most = maxf(most, type.cargo_capacity)
	return most


# Euros with the sign first, as -€120; never €-0.
static func eur(amount: int) -> String:
	return ("-€%d" if amount < 0 else "€%d") % absi(amount)
