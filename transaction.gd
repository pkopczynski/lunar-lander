class_name Transaction
extends RefCounted
# A Transaction: one line in the Bank account, for anything that changed the balance, in euros.
# A settled Contract (delivered, `cancelled` for its fee or `failed` in a crash for its failure fee;
# made by `TransportOffer.settlement()`, `cancellation()` and `failure()`), a ship purchase or sale
# (`ship_purchase()`, `ship_sale()`), a recovery fee (`recovery()`), a repair (`repair()`) or fuel
# bought or sold back (`fuel()`, `FUEL  STATION  2 000 L`), each of the last five naming the owned ship. `label()`, `kind_label()` and `detail_pairs()` are how its row and open details read.

enum Kind { CONTRACT, SHIP_PURCHASE, SHIP_SALE, RECOVERY, REPAIR, FUEL }

const KIND_SHIP := "SHIP"
const CANCELLED_LABEL := "CANCELLED"
const FAILED_LABEL := "FAILED"
const PURCHASE_LABEL := "SHIP PURCHASE — %s"
const SALE_LABEL := "SHIP SALE — %s"
const RECOVERY_LABEL := "RECOVERY — %s"
const REPAIR_LABEL := "REPAIR — %s"
const FUEL_LABEL := "FUEL  %s  %s"
# Where fuel is sold: only the station, for now.
const STATION := "STATION"

var kind := Kind.CONTRACT
# What it added to the balance; negative when it took money.
var payout: int
# Contracts only: the Contract, its reward and what was taken off it.
var contract: TransportOffer
var reward: int
var penalty: int
# Contracts only: the flight deadline it was settled against and the delivery time (seconds from
# the end of loading to landing on the pad).
var deadline: float
var delivery_time: float
# The flight deadline and the landing as local times, in in-game minutes since the midnight
# before loading finished: at or past PlanetClock.MINUTES_PER_DAY on the next day.
var deadline_at: float
var landed_at: float
# The names of the location it was delivered to and of its destination.
var delivered_to: String
var destination: String
# A Contract's: the name of the ship type that delivered it. A ship purchase's or sale's: the
# owned ship's name, as SPARROW 2.
var ship: String
# Given up with its mission: the penalty is the cancellation fee, and nothing was delivered.
var cancelled := false
# A Failed contract, lost in a crash: the penalty is the failure fee, and nothing was delivered.
var failed := false
# Ship sales: the ship's value and the repair cost taken off its share. Recovery: the Ship type's
# price. Repairs: the ship's value.
var value: int
var repair_cost: int
# Repairs only: the share of Condition restored and the Ship type's repair rate.
var repaired: float
var repair_rate: float
# Fuel only: how much was bought or sold back (in kg, always positive; the payout's sign tells
# which), its price per litre in cents and where.
var fuel_mass: float
var fuel_price: int
# The Ship type's fuel multiplier the price carries, shown when it isn't 1.
var fuel_multiplier: float
var place: String


static func ship_purchase(owned: OwnedShip) -> Transaction:
	var transaction := Transaction.new()
	transaction.kind = Kind.SHIP_PURCHASE
	transaction.ship = owned.name
	transaction.value = owned.value()
	transaction.payout = -owned.value()
	return transaction


static func ship_sale(owned: OwnedShip) -> Transaction:
	var transaction := Transaction.new()
	transaction.kind = Kind.SHIP_SALE
	transaction.ship = owned.name
	transaction.value = owned.value()
	transaction.repair_cost = owned.repair_cost()
	transaction.payout = owned.sale_price()
	return transaction


# Recovery after a crash: the owned ship's recovery fee.
static func recovery(owned: OwnedShip) -> Transaction:
	var transaction := Transaction.new()
	transaction.kind = Kind.RECOVERY
	transaction.ship = owned.name
	transaction.value = owned.ship_type.price
	transaction.payout = -owned.recovery_fee()
	return transaction


# A repair of the owned ship: its repair cost, restoring all its missing Condition.
static func repair(owned: OwnedShip) -> Transaction:
	var transaction := Transaction.new()
	transaction.kind = Kind.REPAIR
	transaction.ship = owned.name
	transaction.value = owned.value()
	transaction.repaired = 1.0 - owned.condition
	transaction.repair_rate = owned.ship_type.repair_rate
	transaction.payout = -owned.repair_cost()
	return transaction


# Fuel bought for the owned ship (kg above 0, a negative payout) or sold back from it (kg below 0,
# a positive payout), at the station's price.
static func fuel(owned: OwnedShip, kg: float) -> Transaction:
	var transaction := Transaction.new()
	transaction.kind = Kind.FUEL
	transaction.ship = owned.name
	transaction.fuel_mass = absf(kg)
	transaction.fuel_price = owned.fuel_price()
	transaction.fuel_multiplier = owned.ship_type.fuel_multiplier
	transaction.place = STATION
	transaction.payout = owned.fuel_cost(absf(kg)) * (-1 if kg > 0.0 else 1)
	return transaction


# Landed on another location's pad (drift took the destination away): it pays nothing.
func wrong_destination() -> bool:
	return kind == Kind.CONTRACT and not cancelled and not failed and delivered_to != destination


# Whole seconds overdue, rounded down like the red counter.
func overdue_seconds() -> int:
	return maxi(floori(delivery_time - deadline), 0)


# The whole seconds overdue as in-game minutes.
func overdue_minutes() -> int:
	return roundi(overdue_seconds() * PlanetClock.MINUTES_PER_SECOND)


# The row's left-hand part: #004 INDUSTRIAL SUPPLIES, or SHIP PURCHASE — MULE 1.
func label() -> String:
	match kind:
		Kind.SHIP_PURCHASE:
			return PURCHASE_LABEL % ship
		Kind.SHIP_SALE:
			return SALE_LABEL % ship
		Kind.RECOVERY:
			return RECOVERY_LABEL % ship
		Kind.REPAIR:
			return REPAIR_LABEL % ship
		Kind.FUEL:
			return FUEL_LABEL % [place, Office.litres(fuel_mass)]
	return contract.label()


# The row's kind, before the payout: CARGO, or SHIP.
func kind_label() -> String:
	if kind == Kind.CONTRACT:
		return TransportOffer.KIND_LABELS[contract.kind()]
	return KIND_SHIP


# How the payout was worked out, as [label, text] pairs, times local. The deadline is the
# flight's, which the penalty was counted against. A wrong destination replaces the penalty
# and names the destination after where it was delivered. A cancelled Contract shows its fee
# and CANCELLED (a label without a value) in place of the delivery. A ship purchase shows its
# price; a sale its value, the share paid for it and the repair cost taken off; a recovery fee the
# Ship type's price and the fee's share; a repair the share restored, the repair rate and the value;
# fuel its litres and kg, the price per litre, the Ship type's factor when it isn't 1, and the place.
func detail_pairs() -> Array[Array]:
	match kind:
		Kind.SHIP_PURCHASE:
			return [["SHIP", ship], ["PRICE", Economy.eur(value)], ["PAYOUT", Economy.eur(payout)]]
		Kind.SHIP_SALE:
			return [["SHIP", ship], ["VALUE", Economy.eur(value)],
				["SALE SHARE", "%d%%" % roundi(OwnedShip.SALE_SHARE * 100.0)],
				["REPAIR COST", Economy.eur(-repair_cost)], ["PAYOUT", Economy.eur(payout)]]
		Kind.RECOVERY:
			return [["SHIP", ship], ["SHIP TYPE PRICE", Economy.eur(value)],
				["RECOVERY FEE", "%d%%" % roundi(OwnedShip.RECOVERY_FEE_SHARE * 100.0)], ["PAYOUT", Economy.eur(payout)]]
		Kind.REPAIR:
			return [["SHIP", ship], ["REPAIRED", "%d%%" % roundi(repaired * 100.0)],
				["REPAIR RATE", "%d%%" % roundi(repair_rate * 100.0)], ["VALUE", Economy.eur(value)],
				["PAYOUT", Economy.eur(payout)]]
		Kind.FUEL:
			var pairs: Array[Array] = [["SHIP", ship], ["FUEL", Office.litres_and_kg(fuel_mass)],
				["PRICE", Office.per_litre(fuel_price)]]
			if fuel_multiplier != 1.0:
				pairs.append(["SHIP TYPE FACTOR", "×%s" % fuel_multiplier])
			pairs.append_array([["PLACE", place], ["PAYOUT", Economy.eur(payout)]])
			return pairs
	if cancelled:
		return [["BASE VALUE", Economy.eur(reward)], ["CANCELLATION FEE", Economy.eur(-penalty)],
			["PAYOUT", Economy.eur(payout)], [CANCELLED_LABEL, ""], ["SHIP", ship.to_upper()]]
	if failed:
		return [["BASE VALUE", Economy.eur(reward)], ["FAILURE FEE", Economy.eur(-penalty)],
			["PAYOUT", Economy.eur(payout)], [FAILED_LABEL, ""], ["SHIP", ship.to_upper()]]
	var deduction := ["PENALTY", Economy.eur(0)]
	if wrong_destination():
		deduction = ["WRONG DESTINATION", Economy.eur(-penalty)]
	elif overdue_seconds() > 0:
		deduction[1] = "%s (%d MIN OVERDUE)" % [Economy.eur(-penalty), overdue_minutes()]
	var pairs: Array[Array] = [["BASE VALUE", Economy.eur(reward)], deduction,
		["PAYOUT", Economy.eur(payout)], ["DEADLINE", PlanetClock.local_time(deadline_at)],
		["LANDED", PlanetClock.local_time(landed_at)], ["DELIVERED TO", delivered_to]]
	if wrong_destination():
		pairs.append(["DESTINATION", destination])
	pairs.append(["SHIP", ship.to_upper()])
	return pairs
