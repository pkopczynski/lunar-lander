class_name TransportOffer
extends RefCounted
# A Transport offer: a job to carry passengers, cargo or both from the station to the pad.
# Once accepted it's a Contract, the same object. Holds its own settlement maths and the
# random generator.

const PASSENGER_MASS := 80.0

# Generation
const MIN_EXPIRY := 120
const MAX_EXPIRY := 600
const MIN_DEADLINE := 60
const MAX_DEADLINE := 180
const MIN_CARGO := 500
const CARGO_STEP := 100
# Rewards at the reference deadline, scaled by (REFERENCE_DEADLINE / deadline)^URGENCY_EXPONENT,
# then by a random factor between MIN_LUCK and MAX_LUCK.
const PASSENGER_REWARD := 150.0
const CARGO_REWARD_PER_TONNE := 60.0
const REFERENCE_DEADLINE := 120.0
const URGENCY_EXPONENT := 0.5
const MIN_LUCK := 0.7
const MAX_LUCK := 1.3

# Settlement: share of each reward lost per whole overdue second.
const PASSENGER_PENALTY_SHARE := 0.02
const CARGO_PENALTY_SHARE := 0.01

enum Kind { PASSENGERS, CARGO, MIXED }

const KIND_LABELS := {
	Kind.PASSENGERS: "PASSENGERS",
	Kind.CARGO: "CARGO",
	Kind.MIXED: "PASSENGERS + CARGO",
}
const TITLES := {
	Kind.PASSENGERS: ["Crew rotation", "Mining shift", "Survey team", "Medical staff", "Tourist party"],
	Kind.CARGO: ["Mining supplies", "Water ice", "Spare parts", "Hydroponics kit", "Ore samples"],
	Kind.MIXED: ["Field camp", "Relief mission", "Drill crew and rig", "Science outpost", "Repair team"],
}
const TRADERS: Array[String] = ["Tycho Haulage", "Selene Mining", "Mare Logistics", "Copernicus Labs",
	"Kepler Supply", "Apollo Freight", "Regolith & Sons", "Crater Works"]

const NOT_ENOUGH_SEATS := "Not enough passenger seats"
const CARGO_EXCEEDED := "Cargo capacity exceeded"

var number: int
var title: String
var trader: String
var passengers: int
# In kg.
var cargo_mass: float
# Seconds to deliver, counted from when loading finishes.
var deadline: float
# Seconds left to accept it.
var time_left: float
# In whole euros.
var passenger_reward: int
var cargo_reward: int


func kind() -> Kind:
	if passengers > 0 and cargo_mass > 0.0:
		return Kind.MIXED
	return Kind.PASSENGERS if passengers > 0 else Kind.CARGO


func load_mass() -> float:
	return passengers * PASSENGER_MASS + cargo_mass


func value() -> int:
	return passenger_reward + cargo_reward


# Why it doesn't fit the seats and cargo left, or "" when it does.
func misfit_reason(seats_left: int, cargo_left: float) -> String:
	if passengers > seats_left:
		return NOT_ENOUGH_SEATS
	if cargo_mass > cargo_left:
		return CARGO_EXCEEDED
	return ""


# What it pays when delivered overdue_seconds late: base reward, penalty and payout, each in
# euros. The passenger and cargo parts are penalised separately, each never below €0.
func settlement(overdue_seconds: float) -> Dictionary:
	var late := maxi(floori(overdue_seconds), 0)
	var penalty := mini(roundi(passenger_reward * PASSENGER_PENALTY_SHARE * late), passenger_reward) \
		+ mini(roundi(cargo_reward * CARGO_PENALTY_SHARE * late), cargo_reward)
	return {"base": value(), "penalty": penalty, "payout": value() - penalty}


# Whether anything at all could be generated within these limits.
static func could_fit(seats_left: int, cargo_left: float) -> bool:
	return seats_left >= 1 or cargo_left >= MIN_CARGO


# A random offer of at most max_passengers and max_cargo; could_fit() must hold for them.
static func generate(rng: RandomNumberGenerator, offer_number: int, max_passengers: int,
		max_cargo: float) -> TransportOffer:
	var kinds: Array[Kind] = []
	if max_passengers >= 1:
		kinds.append(Kind.PASSENGERS)
	if max_cargo >= MIN_CARGO:
		kinds.append(Kind.CARGO)
	if kinds.size() == 2:
		kinds.append(Kind.MIXED)
	var offer_kind: Kind = kinds[rng.randi_range(0, kinds.size() - 1)]
	var offer := TransportOffer.new()
	offer.number = offer_number
	var titles: Array = TITLES[offer_kind]
	offer.title = titles[rng.randi_range(0, titles.size() - 1)]
	offer.trader = TRADERS[rng.randi_range(0, TRADERS.size() - 1)]
	if offer_kind != Kind.CARGO:
		offer.passengers = rng.randi_range(1, max_passengers)
	if offer_kind != Kind.PASSENGERS:
		offer.cargo_mass = rng.randi_range(MIN_CARGO / CARGO_STEP, floori(max_cargo / CARGO_STEP)) * CARGO_STEP
	offer.deadline = rng.randi_range(MIN_DEADLINE, MAX_DEADLINE)
	offer.time_left = rng.randi_range(MIN_EXPIRY, MAX_EXPIRY)
	var scale := pow(REFERENCE_DEADLINE / offer.deadline, URGENCY_EXPONENT) * rng.randf_range(MIN_LUCK, MAX_LUCK)
	offer.passenger_reward = roundi(PASSENGER_REWARD * offer.passengers * scale)
	offer.cargo_reward = roundi(CARGO_REWARD_PER_TONNE * offer.cargo_mass / 1000.0 * scale)
	return offer
