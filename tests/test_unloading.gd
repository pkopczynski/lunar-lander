extends "res://tests/scene_test.gd"


func test_landing_on_the_pad_while_delivering_starts_unloading_which_blocks_lift_off_but_not_refuelling() -> void:
	# A full Sparrow's Load: 4 × 80 kg + 8 000 kg leaves room for 3 680 kg of fuel.
	await start_loading([known_offer(4, 8000.0)])
	# 3 s + 4 passengers + 8 tonnes.
	await seconds(15.5)
	await land_on_the_pad()
	check(economy().phase == Economy.Phase.UNLOADING, "landing on the pad while delivering should start unloading")
	# 2 s + 0.5 s × 4 passengers + 0.5 s × 8 tonnes = 8 s.
	check(message() == "Landed!\nUnloading… 8s", "the message should count down from 8 s, got %s" % message())
	lander().fuel = 3000.0
	var landed_at := lander().position
	hold(&"ui_up")
	await seconds(1.0)
	check(lander().state == Lander.State.LANDED, "Up should not lift off while unloading")
	check_near(lander().position.distance_to(landed_at), 0.0, 0.5, "how far the ship moved while unloading")
	check(lander().fuel == 3000.0, "the engine should not burn fuel while unloading, has %s kg" % lander().fuel)
	release(&"ui_up")
	await seconds(1.5)
	check(message() == "Landed!\nUnloading… 6s\nRefueling…", "refuelling should start after the usual delay, got %s" % message())
	await seconds(3.0)
	check(lander().fuel == 3680.0, "refuelling should stop at the cap while the Load is aboard, has %s kg" % lander().fuel)
	check(message() == "Landed!\nUnloading… 3s", "the countdown should go on, got %s" % message())
	await seconds(3.0)
	check(economy().phase == Economy.Phase.NONE, "unloading should be over")
	check(lander().fuel > 3680.0, "with the Load off, refuelling should go past the old cap, has %s kg" % lander().fuel)


func test_a_mixed_contract_delivered_late_loses_2_percent_of_passengers_and_1_percent_of_cargo_per_whole_second() -> void:
	# €300 for the passengers and €120 for the cargo, due 10 s after loading.
	var offer := late_offer(1, 1000.0, 10.0)
	await start_loading([offer])
	# 3 s + 1 passenger + 1 tonne of loading, then 12.7 s overdue.
	await seconds(5.0 + 10.0 + 12.7)
	check(hud().delivery_overdue(), "the ship should be overdue, got %s" % hud().delivery_text())
	await deliver_by_shortcut()
	check(hud().delivery_text() == "", "the delivery timer should go once the ship has landed, got %s" % hud().delivery_text())
	# 2 s + 0.5 s + 0.5 s.
	await seconds(3.5)
	check(economy().phase == Economy.Phase.NONE, "unloading should be over")
	# 12 s: €300 − €72 and €120 − €14.40, rounded.
	check(economy().balance == 334, "the payout should be €334, balance is %s" % economy().balance)
	check(office().bank_account.rows() == PackedStringArray(["#%03d TEST RUN  PASSENGERS + CARGO  €334" % offer.number]),
		"the Bank account should show the transaction, shows %s" % office().bank_account.rows())


func test_each_part_of_a_late_payout_stops_at_0_euros() -> void:
	var offer := late_offer(1, 1000.0, 0.0)
	await start_loading([offer])
	await seconds(5.0 + 60.5)
	await deliver_by_shortcut()
	await seconds(3.5)
	# 60 s: the passengers' €300 would lose €360 but lose only €300; the cargo's €120 loses €72.
	check(economy().balance == 48, "only the cargo part should still pay, balance is %s" % economy().balance)


func test_a_contract_that_pays_nothing_still_gets_a_transaction() -> void:
	var offer := late_offer(1, 0.0, 0.0)
	offer.cargo_reward = 0
	await start_loading([offer])
	await seconds(4.0 + 50.5)
	await deliver_by_shortcut()
	await seconds(3.0)
	check(economy().balance == 0, "50 s late, €300 for passengers should pay €0, balance is %s" % economy().balance)
	check(office().bank_account.rows() == PackedStringArray(["#%03d TEST RUN  PASSENGERS  €0" % offer.number]),
		"the Bank account should still show the transaction, shows %s" % office().bank_account.rows())


func test_several_contracts_each_get_a_transaction_newest_first_then_the_ship_is_empty_and_free() -> void:
	var crew := known_offer(1, 0.0)
	crew.cargo_reward = 0
	var parts := known_offer(0, 2000.0)
	parts.passenger_reward = 0
	await start_loading([crew, parts])
	# 3 s + 1 passenger + 2 tonnes.
	await seconds(6.5)
	await land_on_the_pad()
	# 2 s + 0.5 s + 1 s.
	await seconds(3.5)
	check(economy().phase == Economy.Phase.NONE, "unloading should be over")
	check(economy().balance == 420, "the balance should be €300 + €120, is %s" % economy().balance)
	check(office().bank_account.rows() == PackedStringArray([
			"#%03d TEST RUN  CARGO  €120" % parts.number,
			"#%03d TEST RUN  PASSENGERS  €300" % crew.number]),
		"one transaction per Contract, newest first, shows %s" % office().bank_account.rows())
	check(hud().payout == "+€420", "the total payout should float above the ship, shows %s" % hud().payout)
	check(economy().contracts.is_empty(), "the Contracts should be cleared")
	check(lander().total_mass() == ShipType.SPARROW.default_dry_mass + lander().fuel,
		"the Load should be off, total %s" % lander().total_mass())
	check(message() == "Landed!", "the unloading line should go, got %s" % message())
	await seconds(3.0)
	check(hud().payout == "", "the payout should fade away, shows %s" % hud().payout)
	hold(&"ui_up")
	await seconds(0.3)
	release(&"ui_up")
	check(lander().state == Lander.State.FLYING, "Up should lift off once unloaded")


func test_landing_again_neither_restarts_unloading_nor_pays_twice() -> void:
	var offer := known_offer(2, 0.0)
	await start_loading([offer])
	await seconds(5.5)
	await deliver_by_shortcut()
	# 2 s + 0.5 s × 2 passengers = 3 s.
	await seconds(1.5)
	await deliver_by_shortcut()
	check(message() == "Landed!\nUnloading… 2s", "a second landing should not restart unloading, got %s" % message())
	await seconds(2.0)
	check(economy().phase == Economy.Phase.NONE, "unloading should finish on time")
	await deliver_by_shortcut()
	await seconds(4.0)
	check(economy().balance == 420, "the Contract should be paid once, balance is %s" % economy().balance)
	check(office().bank_account.rows().size() == 1, "one transaction only, shows %s" % office().bank_account.rows())
	check(message() == "Landed!", "landing empty shows no unloading, got %s" % message())


func test_landing_on_the_pad_without_a_load_works_as_before() -> void:
	await choose_ship()
	await land_on_the_pad()
	check(economy().phase == Economy.Phase.NONE, "an empty landing should not unload")
	check(message() == "Landed!", "the message should just say Landed!, got %s" % message())
	hold(&"ui_up")
	await seconds(0.3)
	release(&"ui_up")
	check(lander().state == Lander.State.FLYING, "Up should lift off right away")
	check(economy().balance == 0 and office().bank_account.rows().is_empty(), "nothing should be paid")


func test_the_debug_pad_shortcut_delivers_even_after_a_crash_on_the_surface() -> void:
	await start_loading([known_offer(1, 0.0)])
	await seconds(4.5)
	place(Vector2(pad_x() + 400.0, 560), Vector2(0, 200))
	await seconds(1.0)
	check(lander().state == Lander.State.CRASHED, "the ship should crash on the Surface")
	await deliver_by_shortcut()
	check(economy().phase == Economy.Phase.UNLOADING, "the shortcut should start unloading")
	await seconds(3.0)
	check(economy().balance == 420, "the Contract should pay out, balance is %s" % economy().balance)


func test_a_crash_then_r_starts_a_new_run_with_the_economy_wiped() -> void:
	await open_ship_selection()
	await browse_to(ShipType.HALO)
	await press(&"ui_accept")
	await press(&"ui_accept")
	await start_loading([known_offer(1, 0.0)])
	await seconds(4.5)
	await deliver_by_shortcut()
	await seconds(3.0)
	check(economy().balance == 420, "the first run should earn €420, balance is %s" % economy().balance)
	await open_terminal_for_contract()
	await crash_in_deep_space()
	await restart()
	check(office().showing and office().screen == Office.Screen.MAIN, "a new run should open the Office main screen")
	check(lander().ship_type == ShipType.SPARROW, "a new run should start in the Sparrow")
	check(economy().balance == 0, "the balance should be €0 again, is %s" % economy().balance)
	check(office().bank_account.lines() == PackedStringArray(["PILOT", "BALANCE €0"]), "the Bank account should read €0, shows %s" % office().bank_account.lines())
	check(office().bank_account.rows().is_empty(), "no transactions should remain, shows %s" % office().bank_account.rows())
	check(economy().contracts.is_empty(), "no Contracts should remain")
	check(economy().phase == Economy.Phase.NONE, "no delivery should be under way")
	check(lander().total_mass() == ShipType.SPARROW.default_dry_mass + lander().fuel,
		"no Load should remain, total %s" % lander().total_mass())


# Docks and accepts one more Contract, so the run being wiped has one too.
func open_terminal_for_contract() -> void:
	await dock_in_spot()
	await press(&"ui_left")
	await press(&"ui_accept")
	await wait_for_terminal()
	var offer := known_offer(1, 0.0)
	economy().put_offer(offer)
	await open_transport_offers()
	await accept(offer)
	while office().screen != Office.Screen.MAIN:
		await press(&"ui_cancel")
	await press(&"ui_cancel")
	await wait_for_terminal()
	check(not office().showing, "Escape should close the Office")


func late_offer(passengers: int, cargo_mass: float, deadline: float) -> TransportOffer:
	var offer := known_offer(passengers, cargo_mass)
	offer.deadline = deadline
	return offer


# The debug pad shortcut: R on the Surface puts the ship Landed on the pad.
func deliver_by_shortcut() -> void:
	place(Vector2(300, 100))
	await press(&"restart")
	check(lander().state == Lander.State.LANDED, "R on the Surface should land the ship on the pad")


# Flies the ship down onto the pad from just above it.
func land_on_the_pad() -> void:
	place(Vector2(pad_x(), 580.0), Vector2(0, 20))
	for i in roundi(4.0 * PHYSICS_FPS):
		if lander().state == Lander.State.LANDED:
			break
		await frames(1)
	check(lander().state == Lander.State.LANDED, "the ship should land on the pad")
