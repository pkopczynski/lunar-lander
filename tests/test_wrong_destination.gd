extends "res://tests/scene_test.gd"
# Drift keeps running during a delivery: if it takes the destination away, landing on another
# location's pad still unloads the Load but every Contract pays €0.


func test_landing_on_another_locations_pad_unloads_as_usual() -> void:
	await deliver_to_the_mine([known_offer(4, 8000.0)])
	check(economy().phase == Economy.Phase.UNLOADING, "landing on the Mine's pad should start unloading")
	# 2 s + 0.5 s × 4 passengers + 0.5 s × 8 tonnes = 8 s.
	check(message() == "Landed!\nUnloading… 8s", "the message should count down from 8 s, got %s" % message())
	await seconds(8.5)
	check(economy().phase == Economy.Phase.NONE, "unloading should be over")
	check(economy().contracts.is_empty(), "the Contracts should be cleared")
	check(lander().total_mass() == ShipType.SPARROW.default_dry_mass + lander().fuel,
		"the Load should be off, total %s" % lander().total_mass())


func test_each_contract_settles_for_0_euros_with_its_own_transaction() -> void:
	var crew := known_offer(1, 0.0)
	var parts := known_offer(0, 2000.0)
	await deliver_to_the_mine([crew, parts])
	await unloaded()
	check(economy().balance == 0, "a wrong pad should pay nothing, balance is %s" % economy().balance)
	check(office().bank_account.rows() == PackedStringArray([
			"#%03d TEST RUN  CARGO  €0" % parts.number,
			"#%03d TEST RUN  PASSENGERS  €0" % crew.number]),
		"one €0 transaction per Contract, newest first, shows %s" % office().bank_account.rows())


func test_the_details_show_the_wrong_destination_in_place_of_the_penalty() -> void:
	var offer := known_offer(1, 0.0)
	# Overdue too: the whole base value goes, never more.
	offer.deadline = 10.0
	await deliver_to_the_mine([offer], 22.7)
	await unloaded()
	await enter_office()
	await open_bank_account()
	await press(&"ui_accept")
	# Loaded at 14:00, 10 s deadline (20 in-game minutes), landed after 22 s (45 in-game minutes).
	check(office().bank_account.details(0) == PackedStringArray(["BASE VALUE €420", "WRONG DESTINATION -€420",
			"PAYOUT €0", "DEADLINE 14:20", "LANDED 14:45", "DELIVERED TO MINE", "DESTINATION VALLEY", "SHIP SPARROW"]),
		"the breakdown should show the wrong destination, shows %s" % office().bank_account.details(0))


func test_landing_on_the_destinations_pad_after_drifting_away_and_back_pays_as_usual() -> void:
	await deliver_after_drift([known_offer(1, 0.0)], 5.0, 2)
	await unloaded()
	check(economy().balance == 420, "the Valley was the destination, balance is %s" % economy().balance)
	await enter_office()
	await open_bank_account()
	await press(&"ui_accept")
	check(office().bank_account.details(0) == PackedStringArray(["BASE VALUE €420", "PENALTY €0", "PAYOUT €420",
			"DEADLINE 17:00", "LANDED 14:10", "DELIVERED TO VALLEY", "SHIP SPARROW"]),
		"a right delivery should show the usual breakdown, shows %s" % office().bank_account.details(0))


# Loads the Contracts for the Valley, lets the location drift on to the Mine during the delivery,
# then lands on the Mine's pad `delivered_in` seconds after loading finished at 14:00.
func deliver_to_the_mine(contracts: Array, delivered_in := 5.0) -> void:
	await deliver_after_drift(contracts, delivered_in, 1)
	check(world().location == Location.MINE, "the location should have drifted to the Mine")


# Loads the Contracts for the Valley, lets the location drift on `drifts` times during the
# delivery, then lands on that location's pad `delivered_in` seconds after loading finished at 14:00.
func deliver_after_drift(contracts: Array, delivered_in: float, drifts: int) -> void:
	var typed: Array[TransportOffer] = []
	typed.assign(contracts)
	await start_loading(typed)
	while economy().phase == Economy.Phase.LOADING:
		await frames(1)
	economy().loaded_at = 14 * 60 + 0.5
	for i in drifts:
		var before := world().location
		clock().drift = PlanetClock.DRIFT_MINUTES
		await frames(2)
		check(world().location != before, "the location should drift during the delivery")
	await seconds(delivered_in - 2.0 * drifts / PHYSICS_FPS)
	place(Vector2(world().location.pad_center_x, World.GROUND_BOTTOM_Y - 400.0))
	await press(&"restart")
	check(lander().state == Lander.State.LANDED, "R on the surface should land the ship on the Mine's pad")


func unloaded() -> void:
	while economy().phase == Economy.Phase.UNLOADING:
		await frames(1)


func enter_office() -> void:
	await dock_in_spot()
	await press(&"ui_left")
	await press(&"ui_accept")
	await wait_for_terminal()
	check(office().showing, "Yes should enter the Office")
