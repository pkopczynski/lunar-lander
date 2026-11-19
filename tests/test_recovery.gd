extends "res://tests/scene_test.gd"
# A crash makes the ship in service a Wreck, and R brings it back by Recovery, in place.


func test_r_after_a_crash_opens_the_office_with_the_wreck_docked_and_no_scene_reload() -> void:
	await choose_ship()
	var scene := main()
	await crash_in_deep_space()
	check(message() == "Crashed!\nPress R for recovery", "the crash message should offer recovery, got %s" % message())
	await recover()
	check(main() == scene, "Recovery should not reload the scene")
	check(office().showing and office().screen == Office.Screen.MAIN, "R should open the Office main screen")
	check(lander().state == Lander.State.DOCKED and lander().is_inside_spot(), "the Wreck should be Docked at the station")
	check(hangar().in_service.name == "SPARROW 1", "the Wreck should still be in service")
	check(office().main_lines() == PackedStringArray(["SPARROW 1", "WRECKED"]),
		"the main screen should tag the ship in service WRECKED, shows %s" % office().main_lines())


func test_recovery_charges_5_percent_of_the_ship_types_price_and_the_world_carries_on() -> void:
	var fees := {ShipType.SPARROW: 12500, ShipType.MULE: 20000, ShipType.HALO: 32500}
	for type: ShipType in fees:
		await start_over()
		await choose_ship(type)
		clock().move_to(Location.MINE)
		clock().minutes = 14 * 60 + 0.5
		var offer := known_offer(1, 0.0)
		economy().put_offer(offer)
		var name := hangar().in_service.name
		await crash_in_deep_space()
		await recover()
		check(economy().balance == Economy.START_BALANCE - fees[type], "a %s's Recovery should cost €%d, balance %s" % [type.name, fees[type], economy().balance])
		await open_bank_account()
		check(office().bank_account.rows()[0] == "RECOVERY — %s  SHIP  %s" % [name, Economy.eur(-fees[type])],
			"the recovery fee should be the newest Transaction, rows %s" % office().bank_account.rows())
		check(world().location == Location.MINE, "Recovery should keep the location")
		check(clock().minutes >= 14 * 60 and clock().minutes < 14 * 60 + 5, "Recovery should keep the local time, %s" % clock().minutes)
		check(offer in economy().offers, "Recovery should keep the offer pool")


# Two Contracts worth €42 000 each, loaded, then a crash on the Surface: R recovers rather than
# landing on the pad, and each Contract is a Failed contract settled for half its reward.
func test_contracts_aboard_fail_for_half_their_reward_and_r_on_the_surface_still_recovers() -> void:
	var first := known_offer(1, 0.0)
	var second := known_offer(1, 0.0)
	await start_loading([first, second])
	while economy().phase == Economy.Phase.LOADING:
		await frames(1)
	place(Vector2(pad_x() + 400.0, 560), Vector2(0, 200))
	await seconds(1.0)
	check(lander().state == Lander.State.CRASHED, "the ship should crash on the Surface")
	check(economy().balance == Economy.START_BALANCE - 2 * 21000 - 12500,
		"two failure fees and the recovery fee should be charged at the crash, balance %s" % economy().balance)
	await recover()
	check(lander().in_deep_space and lander().state == Lander.State.DOCKED, "R on the Surface after a crash should recover to the station")
	check(economy().contracts.is_empty() and economy().phase == Economy.Phase.NONE, "the Contracts should be gone, no delivery under way")
	check(lander().load_mass == 0.0, "the Load should be lost, %s kg left" % lander().load_mass)
	await open_bank_account()
	var rows := office().bank_account.rows()
	check(rows.size() == 3 and rows[0].begins_with("RECOVERY — SPARROW 1"), "the recovery fee should be newest, rows %s" % rows)
	for row in [1, 2]:
		check(rows[row].ends_with("PASSENGERS  -€21 000"), "each Failed contract should cost €21 000, rows %s" % rows)
	await press(&"ui_down")
	await press(&"ui_accept")
	await seconds(0.5)
	var details := office().bank_account.details(1)
	check(details.has("FAILURE FEE -€21 000") and details.has("FAILED"), "a Failed contract should show its fee and FAILED, shows %s" % details)


func test_a_free_flight_crash_costs_only_the_recovery_fee() -> void:
	await choose_ship()
	await crash_in_deep_space()
	await recover()
	check(economy().balance == Economy.START_BALANCE - 12500, "a free flight crash should cost only €12 500, balance %s" % economy().balance)
	check(economy().transactions.size() == 1, "only the recovery fee should be a Transaction, %d made" % economy().transactions.size())


func test_the_office_cant_be_left_with_a_wreck_in_service_until_another_ship_is() -> void:
	await choose_ship()
	await crash_in_deep_space()
	await recover()
	await press(&"ui_cancel")
	await wait_for_terminal()
	check(office().showing, "Escape should not leave the Office with a Wreck in service")
	check(office().notice() == Office.WRECK_IN_SERVICE, "Escape should say why, notice '%s'" % office().notice())
	await open_transport_offers()
	await press(&"ui_right")
	check(offers().start_text() == "START", "the free flight's START should show, got %s" % offers().start_text())
	await press(&"ui_accept")
	await wait_for_terminal()
	check(office().showing, "START should not leave the Office with a Wreck in service")
	check(office().notice() == Office.WRECK_IN_SERVICE, "START should say why, notice '%s'" % office().notice())
	await press(&"ui_cancel")
	await press(&"ui_cancel")
	economy().balance += ShipType.MULE.price
	var mule := await buy_ship(ShipType.MULE)
	await put_in_service()
	check(hangar().in_service == mule, "another ship should go in service in place of the Wreck")
	check(office().main_lines().is_empty(), "the main screen shouldn't tag a flyable ship, shows %s" % office().main_lines())
	await press(&"ui_cancel")
	await open_ship_page(owned_ship(ShipType.SPARROW))
	check(hangar_screen().rows()[0].begins_with("SPARROW 1  WRECKED  "), "the Hangar should list the Wreck as WRECKED, rows %s" % hangar_screen().rows())
	check(hangar_screen().reasons()[HangarScreen.Action.PUT_IN_SERVICE] == HangarScreen.WRECK_REASON,
		"a Wreck can't go in service, reasons %s" % hangar_screen().reasons())
	await select_action(HangarScreen.Action.PUT_IN_SERVICE)
	check(office().popup == Office.PopupKind.NONE and office().notice() == HangarScreen.WRECK_REASON,
		"PUT IN SERVICE on a Wreck should only show its reason, notice '%s'" % office().notice())
	await leave_office()
	check(lander().ship_type == ShipType.MULE and lander().state == Lander.State.DOCKED, "the Mule should be left Docked, ready to fly")
