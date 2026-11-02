class_name Economy
extends Node
# The run's economy: the pilot's Bank account balance, the Transport offer pool and the
# Contracts. It lives in the scene, so a restart (a scene reload) wipes it, and it keeps
# running while the Office pauses the world. It also runs the delivery: loading, the
# delivery clock and unloading, which settles the Contracts.

# An offer ran out of time and left the pool without being accepted.
signal offer_expired(offer: TransportOffer)
# Unloading finished and the Contracts paid this much in total.
signal paid_out(total: int)

const Hud := preload("res://hud.gd")

const PILOT := "PILOT"
# Each run starts with START_OFFERS. While fewer than MAX_OFFERS are listed, one more arrives
# every MIN_OFFER_INTERVAL to MAX_OFFER_INTERVAL seconds.
const START_OFFERS := 5
const MAX_OFFERS := 7
const MIN_OFFER_INTERVAL := 30.0
const MAX_OFFER_INTERVAL := 90.0

# Loading takes LOADING_TIME + LOADING_TIME_PER_PASSENGER per passenger + LOADING_TIME_PER_TONNE
# per 1 000 kg of cargo, in seconds.
const LOADING_TIME := 3.0
const LOADING_TIME_PER_PASSENGER := 1.0
const LOADING_TIME_PER_TONNE := 1.0

# Unloading takes UNLOADING_TIME + UNLOADING_TIME_PER_PASSENGER per passenger
# + UNLOADING_TIME_PER_TONNE per 1 000 kg of cargo, in seconds.
const UNLOADING_TIME := 2.0
const UNLOADING_TIME_PER_PASSENGER := 0.5
const UNLOADING_TIME_PER_TONNE := 0.5

const LOADING_TEXT := "Loading… %ds"
const LOADED_TEXT := "Loaded! Deliver by %s"
const FUEL_LIMITED_TEXT := "Fuel limited to %s"
const UNLOADING_TEXT := "Unloading… %ds"

# Each change of phase happens in one place, which checks the phase it leaves.
enum Phase { NONE, LOADING, DELIVERING, UNLOADING }

# May go negative.
var balance := 0
# One per delivered Contract, newest first.
var transactions: Array[TransportOffer.Transaction] = []
# The Transport offers on the Terminal, oldest first.
var offers: Array[TransportOffer] = []
var contracts: Array[TransportOffer] = []
var rng := RandomNumberGenerator.new()
var last_offer_number := 0
# Seconds until the next offer arrives; drawn afresh when it next runs after the pool was full.
var next_offer_left := 0.0
var phase := Phase.NONE
var loading_left := 0.0
# Seconds since loading finished; stops when the ship lands on the pad.
var delivery_time := 0.0
# The local time when loading finished, in in-game minutes since that day's midnight.
var loaded_at := 0.0
var unloading_left := 0.0

@onready var lander: Lander = $"../Lander"
@onready var clock: PlanetClock = $"../PlanetClock"


func _ready() -> void:
	rng.randomize()
	start_pool()
	lander.landed_on_pad.connect(start_unloading)


# Ticked in physics so the --fixed-fps tests stay deterministic.
func _physics_process(delta: float) -> void:
	for offer in offers.duplicate():
		offer.time_left -= delta
		if offer.time_left <= 0.0:
			offers.erase(offer)
			offer_expired.emit(offer)
	if offers.size() >= MAX_OFFERS:
		next_offer_left = 0.0
	else:
		if next_offer_left <= 0.0:
			next_offer_left = rng.randf_range(MIN_OFFER_INTERVAL, MAX_OFFER_INTERVAL)
		next_offer_left -= delta
		if next_offer_left <= 0.0:
			offers.append(next_offer())
	match phase:
		Phase.LOADING:
			loading_left -= delta
			if loading_left <= 0.0:
				finish_loading()
			else:
				lander.show_status(LOADING_TEXT % ceili(loading_left))
		Phase.DELIVERING:
			delivery_time += delta
		Phase.UNLOADING:
			unloading_left -= delta
			if unloading_left <= 0.0:
				finish_unloading()
			else:
				lander.show_status(UNLOADING_TEXT % ceili(unloading_left))


# NONE → LOADING: keeps the ship Docked, refuelling up to the cap for the Contracts' Load,
# while that Load goes aboard.
func start_loading() -> void:
	if phase != Phase.NONE or contracts.is_empty():
		return
	phase = Phase.LOADING
	loading_left = LOADING_TIME + contract_passengers() * LOADING_TIME_PER_PASSENGER \
		+ contract_cargo() / 1000.0 * LOADING_TIME_PER_TONNE
	lander.start_loading(contract_load_mass())
	lander.show_status(LOADING_TEXT % ceili(loading_left))


# LOADING → DELIVERING: the Load joins the ship's mass and the delivery clock starts.
func finish_loading() -> void:
	if phase != Phase.LOADING:
		return
	phase = Phase.DELIVERING
	delivery_time = 0.0
	loaded_at = clock.minutes
	lander.finish_loading()
	var status := LOADED_TEXT % PlanetClock.local_time(deadline_at())
	if lander.fuel_cap() < lander.ship_type.tank:
		status += "\n" + FUEL_LIMITED_TEXT % Hud.format_kg(lander.fuel_cap())
	lander.show_status(status)


# DELIVERING → UNLOADING: the ship is Landed on the pad. Lift-off is blocked until the Load
# is off, but refuelling goes on. Any later landing (a ship settling back) is ignored.
func start_unloading() -> void:
	if phase != Phase.DELIVERING:
		return
	phase = Phase.UNLOADING
	unloading_left = UNLOADING_TIME + contract_passengers() * UNLOADING_TIME_PER_PASSENGER \
		+ contract_cargo() / 1000.0 * UNLOADING_TIME_PER_TONNE
	lander.lift_off_blocked = true
	lander.show_status(UNLOADING_TEXT % ceili(unloading_left))


# UNLOADING → NONE: each Contract is settled for how late the ship landed and paid into the
# Bank account, then the Load comes off and the ship may lift off.
func finish_unloading() -> void:
	if phase != Phase.UNLOADING:
		return
	phase = Phase.NONE
	var total := 0
	for contract in contracts:
		var transaction := contract.settlement(deadline(), delivery_time)
		transaction.ship = lander.ship_type.name
		transactions.push_front(transaction)
		total += transaction.payout
	balance += total
	contracts.clear()
	lander.load_mass = 0.0
	lander.lift_off_blocked = false
	lander.show_status("")
	paid_out.emit(total)


# The shortest deadline among the Contracts: they're all delivered in one flight.
func deadline() -> float:
	var shortest := INF
	for contract in contracts:
		shortest = minf(shortest, contract.deadline)
	return shortest


# The flight deadline as a local time, in in-game minutes since the midnight before loading
# finished: at or past PlanetClock.MINUTES_PER_DAY when it falls on the next day.
func deadline_at() -> float:
	return loaded_at + deadline() * PlanetClock.MINUTES_PER_SECOND


# Seconds left to deliver; negative once overdue.
func delivery_left() -> float:
	return deadline() - delivery_time


# Starts the offer pool over from this seed, numbered from #001. For tests.
func reseed(value: int) -> void:
	rng.seed = value
	start_pool()


# A new pool of START_OFFERS, numbered from #001, with a fresh wait for the next one.
func start_pool() -> void:
	offers.clear()
	last_offer_number = 0
	next_offer_left = 0.0
	for i in START_OFFERS:
		offers.append(next_offer())


# Puts a known offer in the pool with the next number, in place of the one closest to
# expiring when the pool is full. For tests.
func put_offer(offer: TransportOffer) -> void:
	if offers.size() >= MAX_OFFERS:
		offers.erase(closest_to_expiring())
	last_offer_number += 1
	offer.number = last_offer_number
	offers.append(offer)


# Makes the offer a Contract, if it's still in the pool and still fits; returns whether it did.
func accept(offer: TransportOffer) -> bool:
	if not offer in offers or misfit_reason(offer) != "":
		return false
	offers.erase(offer)
	contracts.append(offer)
	return true


# Discards a Contract before loading, for good: no payout, no transaction, and it doesn't
# return to the pool.
func remove_contract(contract: TransportOffer) -> void:
	if phase == Phase.NONE:
		contracts.erase(contract)


# Generated up to the largest ship type, so some won't fit a smaller one.
func next_offer() -> TransportOffer:
	last_offer_number += 1
	return TransportOffer.generate(rng, last_offer_number, largest_seats(), largest_cargo())


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
	return lander.ship_type.passenger_seats - contract_passengers()


func cargo_left() -> float:
	return lander.ship_type.cargo_capacity - contract_cargo()


func contract_passengers() -> int:
	var total := 0
	for contract in contracts:
		total += contract.passengers
	return total


func contract_cargo() -> float:
	var total := 0.0
	for contract in contracts:
		total += contract.cargo_mass
	return total


# The Contracts' Load: passengers and cargo, in kg.
func contract_load_mass() -> float:
	var total := 0.0
	for contract in contracts:
		total += contract.load_mass()
	return total


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
