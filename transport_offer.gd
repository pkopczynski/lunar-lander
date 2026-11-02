class_name TransportOffer
extends RefCounted
# A Transport offer: a job to carry passengers, cargo or both from the station to the pad.
# Once accepted it's a Contract, the same object. Holds its own settlement maths and the
# random generator.

const PASSENGER_MASS := 80.0

# Generation
const MIN_EXPIRY := 180
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
const OVERLOADED := "Overloaded"


# A delivered Contract's line in the Bank account, in euros, with the flight's deadline it was
# settled against and the delivery time (seconds from the end of loading to landing on the pad).
class Transaction:
	var contract: TransportOffer
	var reward: int
	var penalty: int
	var payout: int
	var deadline: float
	var delivery_time: float
	# The flight deadline and the landing as local times, in in-game minutes since the midnight
	# before loading finished: at or past PlanetClock.MINUTES_PER_DAY on the next day.
	var deadline_at: float
	var landed_at: float
	# The name of the location it was delivered to.
	var delivered_to: String
	# The name of the ship type that delivered it.
	var ship: String

	# Whole seconds overdue, rounded down like the red counter.
	func overdue_seconds() -> int:
		return maxi(floori(delivery_time - deadline), 0)

	# The whole seconds overdue as in-game minutes.
	func overdue_minutes() -> int:
		return roundi(overdue_seconds() * PlanetClock.MINUTES_PER_SECOND)


var number: int
var title: String
var trader: String
var passengers: int
var cargo_mass: float
# Seconds to deliver, counted from when loading finishes.
var deadline: float
# Seconds left to accept it.
var time_left: float
var passenger_reward: int
var cargo_reward: int


func kind() -> Kind:
	if passengers > 0 and cargo_mass > 0.0:
		return Kind.MIXED
	return Kind.PASSENGERS if passengers > 0 else Kind.CARGO


func load_mass() -> float:
	return passengers * PASSENGER_MASS + cargo_mass


func reward() -> int:
	return passenger_reward + cargo_reward


# Its number and title, as #004 MINING SUPPLIES.
func label() -> String:
	return "#%03d %s" % [number, title.to_upper()]


# Why it doesn't fit the seats and cargo left, or "" when it does.
func misfit_reason(seats_left: int, cargo_left: float) -> String:
	if passengers > seats_left:
		return NOT_ENOUGH_SEATS
	if cargo_mass > cargo_left:
		return OVERLOADED
	return ""


# What it pays when delivered after delivery_time against the flight's deadline, for each
# whole second overdue. The passenger and cargo parts are penalised separately, each never
# below €0. The local times and the location are only recorded, for the payout's breakdown.
func settlement(flight_deadline: float, delivery_time: float, deadline_at: float, landed_at: float,
		delivered_to: Location) -> Transaction:
	var transaction := Transaction.new()
	transaction.contract = self
	transaction.deadline = flight_deadline
	transaction.delivery_time = delivery_time
	transaction.deadline_at = deadline_at
	transaction.landed_at = landed_at
	transaction.delivered_to = delivered_to.name
	var overdue := transaction.overdue_seconds()
	transaction.reward = reward()
	transaction.penalty = mini(roundi(passenger_reward * PASSENGER_PENALTY_SHARE * overdue), passenger_reward) \
		+ mini(roundi(cargo_reward * CARGO_PENALTY_SHARE * overdue), cargo_reward)
	transaction.payout = transaction.reward - transaction.penalty
	return transaction


# A random offer of at most max_passengers (at least 1) and max_cargo (at least MIN_CARGO).
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
