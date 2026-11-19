class_name Transaction
extends RefCounted
# A Transaction: one line in the Bank account, for anything that changed the balance, in euros.
# A settled Contract (delivered, or `cancelled` for its fee; made by `TransportOffer.settlement()` and
# `cancellation()`), or a ship purchase or sale (`ship_purchase()`, `ship_sale()`, naming the owned
# ship). `label()`, `kind_label()` and `detail_pairs()` are how its row and open details read.

enum Kind { CONTRACT, SHIP_PURCHASE, SHIP_SALE }

const KIND_SHIP := "SHIP"
const CANCELLED_LABEL := "CANCELLED"
const PURCHASE_LABEL := "SHIP PURCHASE — %s"
const SALE_LABEL := "SHIP SALE — %s"

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
# Ship sales only: the ship's value and the repair cost taken off its share.
var value: int
var repair_cost: int


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


# Landed on another location's pad (drift took the destination away): it pays nothing.
func wrong_destination() -> bool:
	return kind == Kind.CONTRACT and not cancelled and delivered_to != destination


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
# price; a sale its value, the share paid for it and the repair cost taken off.
func detail_pairs() -> Array[Array]:
	match kind:
		Kind.SHIP_PURCHASE:
			return [["SHIP", ship], ["PRICE", Economy.eur(value)], ["PAYOUT", Economy.eur(payout)]]
		Kind.SHIP_SALE:
			return [["SHIP", ship], ["VALUE", Economy.eur(value)],
				["SALE SHARE", "%d%%" % roundi(OwnedShip.SALE_SHARE * 100.0)],
				["REPAIR COST", Economy.eur(-repair_cost)], ["PAYOUT", Economy.eur(payout)]]
	if cancelled:
		return [["BASE VALUE", Economy.eur(reward)], ["CANCELLATION FEE", Economy.eur(-penalty)],
			["PAYOUT", Economy.eur(payout)], [CANCELLED_LABEL, ""], ["SHIP", ship.to_upper()]]
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
