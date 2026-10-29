extends "res://tests/scene_test.gd"


func test_run_starts_on_the_office_with_the_sparrow_offer_and_the_world_paused() -> void:
	await frames(2)
	check(office().showing, "a fresh run should show the Office")
	check(office().selected_offer() == ShipType.SPARROW, "the Sparrow Offer should be selected, got %s" % office().selected_offer().name)
	check(office().popup == Office.PopupKind.NONE, "no popup should be open at run start")
	check(not office().in_service_shown(), "no Offer is IN SERVICE at run start")
	check(tree.paused, "the world should be paused while the Office is showing")


func test_return_asks_are_you_sure_with_yes_selected() -> void:
	await press(&"ui_accept")
	check(office().popup == Office.PopupKind.ARE_YOU_SURE, "Return should open ARE YOU SURE?")
	check(office().selected_button == Office.Choice.YES, "Yes should be selected by default")
	check(office().showing, "the Office should still be showing behind the popup")


func test_yes_puts_the_chosen_ship_docked_in_the_parking_spot_with_a_full_tank() -> void:
	await press(&"ui_accept")
	await press(&"ui_accept")
	await wait_for_terminal()
	var ship := lander()
	check(not office().showing, "Yes should hide the Office")
	check(office().popup == Office.PopupKind.NONE, "no popup should stay open, and no swap popup at run start")
	check(not tree.paused, "the world should run once a ship is chosen")
	check(ship.ship_type == ShipType.SPARROW, "the ship should be a Sparrow, got %s" % ship.ship_type.name)
	check(ship.state == Lander.State.DOCKED, "the ship should be Docked")
	check(ship.is_inside_spot(), "the whole hull should be inside the parking spot")
	check_near(ship.tank_level(), 1.0, 0.0001, "tank level")
	check(message() == "Docked!", "message should say Docked!, got %s" % message())


func test_left_and_right_move_between_the_popup_buttons() -> void:
	await press(&"ui_accept")
	await press(&"ui_right")
	check(office().selected_button == Office.Choice.NO, "Right should select No")
	await press(&"ui_right")
	check(office().selected_button == Office.Choice.NO, "Right on No should keep No selected")
	await press(&"ui_left")
	check(office().selected_button == Office.Choice.YES, "Left should select Yes")


func test_no_returns_to_the_same_offer() -> void:
	await press(&"ui_accept")
	await press(&"ui_right")
	await press(&"ui_accept")
	check(office().showing, "No should keep the Office showing")
	check(office().popup == Office.PopupKind.NONE, "No should close the popup")
	check(office().selected_offer() == ShipType.SPARROW, "No should return to the Sparrow Offer")
	check(tree.paused, "the world should stay paused")


func test_escape_in_the_popup_counts_as_no() -> void:
	await press(&"ui_accept")
	await press(&"ui_cancel")
	check(office().showing, "Escape should keep the Office showing")
	check(office().popup == Office.PopupKind.NONE, "Escape should close the popup")
	check(office().selected_offer() == ShipType.SPARROW, "Escape should return to the Sparrow Offer")


func test_escape_on_the_offer_screen_at_run_start_does_nothing() -> void:
	await press(&"ui_cancel")
	check(office().showing, "Escape at run start should not leave the Office")
	check(office().popup == Office.PopupKind.NONE, "Escape at run start should not open a popup")
	check(office().selected_offer() == ShipType.SPARROW, "the Sparrow Offer should stay selected")


func test_the_ship_does_not_move_while_the_office_is_showing() -> void:
	var start := lander().position
	hold(&"ui_up")
	await seconds(0.5)
	release(&"ui_up")
	check(lander().position == start, "the ship should not move behind the Office, moved to %s" % lander().position)
	check(lander().state == Lander.State.DOCKED, "the ship should stay Docked behind the Office")


func test_r_returns_to_the_office() -> void:
	await choose_ship()
	await restart()
	check(office().showing, "R should return to the Office")
	check(office().selected_offer() == ShipType.SPARROW, "the Sparrow Offer should be selected after R")
	check(tree.paused, "the world should be paused again")


func test_r_after_a_crash_returns_to_the_office() -> void:
	await choose_ship()
	await crash_in_deep_space()
	await restart()
	check(office().showing, "R after a crash in deep space should return to the Office")


func test_offer_shows_the_ship_types_numbers_and_ratings() -> void:
	var lines := office().offer_lines()
	for expected: String in ["SPARROW", "SMALL, LIGHT AND QUICK. BUILT FOR SHORT HOPS.",
			"TANK 5 000 KG", "DRY MASS 10 000 KG", "MAX WEIGHT 17 000 KG",
			"THRUST ■■■■■", "HANDLING ■■■■■", "< 1/%d >" % ShipType.ALL.size()]:
		check(expected in lines, "the Offer should show %s, shows %s" % [expected, lines])
	check(office().offer_picture() == ShipType.SPARROW.hull, "the Offer picture should be the Sparrow's hull")


func test_browsing_wraps_around_any_number_of_offers() -> void:
	var extra := ShipType.sparrow()
	extra.name = "Test ship"
	ShipType.ALL.append(extra)
	var count := ShipType.ALL.size()
	for i in count - 1:
		await press(&"ui_right")
	var after_right := office().selected_offer().name
	var lines_after_right := office().offer_lines()
	await press(&"ui_right")
	var after_wrap := office().selected_offer().name
	await press(&"ui_left")
	var after_left_wrap := office().selected_offer().name
	ShipType.ALL.erase(extra)
	var indicator := "< %d/%d >" % [count, count]
	check(after_right == "Test ship", "Right should browse to the last Offer, got %s" % after_right)
	check(indicator in lines_after_right, "the indicator should read %s, shows %s" % [indicator, lines_after_right])
	check(after_wrap == "Sparrow", "Right on the last Offer should wrap to the first, got %s" % after_wrap)
	check(after_left_wrap == "Test ship", "Left on the first Offer should wrap to the last, got %s" % after_left_wrap)
