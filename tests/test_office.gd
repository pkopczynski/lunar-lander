extends "res://tests/scene_test.gd"


func test_run_starts_on_the_office_main_screen_with_the_world_paused() -> void:
	await frames(2)
	check(office().showing, "a fresh run should show the Office")
	check(office().screen == Office.Screen.MAIN, "a fresh run should open on the main screen")
	check(office().tile_labels() == PackedStringArray(["SHIP SELECTION", "TRANSPORT OFFERS", "BANK ACCOUNT"]),
		"the main screen should show three tiles, shows %s" % office().tile_labels())
	check(office().selected_tile() == "SHIP SELECTION", "SHIP SELECTION should be selected, got %s" % office().selected_tile())
	check(office().popup == Office.PopupKind.NONE, "no popup should be open at run start")
	check(tree.paused, "the world should be paused while the Office is showing")


func test_left_right_up_and_down_move_between_the_tiles() -> void:
	await press(&"ui_right")
	check(office().selected_tile() == "TRANSPORT OFFERS", "Right should select TRANSPORT OFFERS, got %s" % office().selected_tile())
	await press(&"ui_down")
	check(office().selected_tile() == "BANK ACCOUNT", "Down should select BANK ACCOUNT, got %s" % office().selected_tile())
	await press(&"ui_right")
	check(office().selected_tile() == "BANK ACCOUNT", "Right on the last tile should keep it, got %s" % office().selected_tile())
	await press(&"ui_up")
	await press(&"ui_left")
	check(office().selected_tile() == "SHIP SELECTION", "Up and Left should go back to SHIP SELECTION, got %s" % office().selected_tile())
	await press(&"ui_left")
	check(office().selected_tile() == "SHIP SELECTION", "Left on the first tile should keep it, got %s" % office().selected_tile())


func test_every_tile_opens_its_screen_and_escape_returns_to_the_main_screen() -> void:
	for expected: Office.Screen in [Office.Screen.SHIP_SELECTION, Office.Screen.TRANSPORT_OFFERS, Office.Screen.BANK_ACCOUNT]:
		var tile := office().selected_tile()
		await press(&"ui_accept")
		check(office().screen == expected, "Return on %s should open its screen, got %s" % [tile, office().screen])
		await press(&"ui_cancel")
		check(office().showing and office().screen == Office.Screen.MAIN, "Escape on %s should return to the main screen" % tile)
		check(office().selected_tile() == tile, "the main screen should keep %s selected" % tile)
		await press(&"ui_right")


func test_escape_on_the_main_screen_closes_the_office_with_the_sparrow_docked() -> void:
	await press(&"ui_cancel")
	await wait_for_terminal()
	var ship := lander()
	check(not office().showing, "Escape on the main screen should close the Office")
	check(not tree.paused, "the world should run once the Office is closed")
	check(ship.ship_type == ShipType.SPARROW, "the ship should be the default Sparrow, got %s" % ship.ship_type.name)
	check(ship.state == Lander.State.DOCKED and ship.is_inside_spot(), "the Sparrow should be Docked in the parking spot")
	check(message() == "Docked!", "message should say Docked!, got %s" % message())
	hold(&"ui_up")
	await seconds(0.4)
	release(&"ui_up")
	check(ship.state != Lander.State.DOCKED, "Up should undock once the Office is closed")


func test_ship_selection_opens_on_the_sparrow_in_service() -> void:
	await open_ship_selection()
	check(office().selected_offer() == ShipType.SPARROW, "the Sparrow Offer should be selected, got %s" % office().selected_offer().name)
	check(office().in_service_shown(), "the Sparrow should be tagged IN SERVICE at run start")
	check(Array(office().offer_lines()).has("IN SERVICE"), "the Offer should read IN SERVICE")
	await press(&"ui_right")
	check(not office().in_service_shown(), "other Offers should not be tagged IN SERVICE")


func test_return_on_another_offer_asks_are_you_sure_with_yes_selected() -> void:
	await open_ship_selection()
	await press(&"ui_right")
	await press(&"ui_accept")
	check(office().popup == Office.PopupKind.ARE_YOU_SURE, "Return should open ARE YOU SURE?")
	check(office().selected_button == Office.Choice.YES, "Yes should be selected by default")
	check(office().showing, "the Office should still be showing behind the popup")


func test_yes_puts_the_chosen_ship_docked_and_returns_to_the_main_screen() -> void:
	await open_ship_selection()
	await browse_to(ShipType.MULE)
	await press(&"ui_accept")
	await press(&"ui_accept")
	var ship := lander()
	check(office().showing and office().screen == Office.Screen.MAIN, "Yes should return to the main screen")
	check(office().popup == Office.PopupKind.NONE, "no popup should stay open")
	check(not office().powering, "returning to the main screen should not power the Terminal off")
	check(tree.paused, "the world should stay paused on the main screen")
	check(ship.ship_type == ShipType.MULE, "the ship should be a Mule, got %s" % ship.ship_type.name)
	check(ship.state == Lander.State.DOCKED, "the Mule should be Docked")
	check(ship.is_inside_spot(), "the whole hull should be inside the parking spot")
	check_near(ship.tank_level(), 1.0, 0.0001, "tank level")
	await press(&"ui_cancel")
	await wait_for_terminal()
	check(not office().showing and ship.ship_type == ShipType.MULE, "Escape should close the Office with the Mule")
	check(message() == "Docked!", "message should say Docked!, got %s" % message())


func test_return_on_the_offer_in_service_returns_to_the_main_screen() -> void:
	await open_ship_selection()
	await press(&"ui_accept")
	check(office().screen == Office.Screen.MAIN, "Return on the IN SERVICE Offer should return to the main screen")
	check(office().popup == Office.PopupKind.NONE, "Return on the IN SERVICE Offer should not ask ARE YOU SURE?")
	check(lander().ship_type == ShipType.SPARROW, "the ship should still be the Sparrow")


func test_left_and_right_move_between_the_popup_buttons() -> void:
	await open_ship_selection()
	await press(&"ui_right")
	await press(&"ui_accept")
	await press(&"ui_right")
	check(office().selected_button == Office.Choice.NO, "Right should select No")
	await press(&"ui_right")
	check(office().selected_button == Office.Choice.NO, "Right on No should keep No selected")
	await press(&"ui_left")
	check(office().selected_button == Office.Choice.YES, "Left should select Yes")


func test_no_returns_to_the_same_offer() -> void:
	await open_ship_selection()
	await browse_to(ShipType.MULE)
	await press(&"ui_accept")
	await press(&"ui_right")
	await press(&"ui_accept")
	check(office().screen == Office.Screen.SHIP_SELECTION, "No should stay on Ship selection")
	check(office().popup == Office.PopupKind.NONE, "No should close the popup")
	check(office().selected_offer() == ShipType.MULE, "No should return to the Mule Offer")
	check(lander().ship_type == ShipType.SPARROW, "No should keep the Sparrow")
	check(tree.paused, "the world should stay paused")


func test_escape_in_the_popup_counts_as_no() -> void:
	await open_ship_selection()
	await browse_to(ShipType.MULE)
	await press(&"ui_accept")
	await press(&"ui_cancel")
	check(office().screen == Office.Screen.SHIP_SELECTION, "Escape should stay on Ship selection")
	check(office().popup == Office.PopupKind.NONE, "Escape should close the popup")
	check(office().selected_offer() == ShipType.MULE, "Escape should return to the Mule Offer")


func test_the_ship_does_not_move_while_the_office_is_showing() -> void:
	var start := lander().position
	hold(&"ui_up")
	await seconds(0.5)
	release(&"ui_up")
	check(lander().position == start, "the ship should not move behind the Office, moved to %s" % lander().position)
	check(lander().state == Lander.State.DOCKED, "the ship should stay Docked behind the Office")


func test_r_returns_to_the_office_main_screen() -> void:
	await choose_ship()
	await restart()
	check(office().showing and office().screen == Office.Screen.MAIN, "R should return to the Office main screen")
	check(lander().ship_type == ShipType.SPARROW, "a new run should start with the Sparrow")
	check(tree.paused, "the world should be paused again")


func test_r_after_a_crash_returns_to_the_office() -> void:
	await choose_ship()
	await crash_in_deep_space()
	await restart()
	check(office().showing and office().screen == Office.Screen.MAIN, "R after a crash in deep space should return to the Office main screen")


func test_offer_shows_the_ship_types_numbers_and_ratings() -> void:
	await open_ship_selection()
	var lines := office().offer_lines()
	for expected: String in ["SPARROW", "SMALL, LIGHT AND QUICK. BUILT FOR SHORT HOPS.",
			"TANK 5 000 KG", "DRY MASS 10 000 KG", "MAX WEIGHT 17 000 KG",
			"THRUST ■■■■■", "HANDLING ■■■■■", "< 1/%d >" % ShipType.ALL.size()]:
		check(expected in lines, "the Offer should show %s, shows %s" % [expected, lines])
	check(office().offer_picture() == ShipType.SPARROW.hull, "the Offer picture should be the Sparrow's hull")


func test_browsing_wraps_around_any_number_of_offers() -> void:
	await open_ship_selection()
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


func test_the_terminal_shows_the_game_version() -> void:
	await frames(2)
	check(office().version_text() == "V" + GameVersion.VERSION, "the Terminal should show V%s, got %s" % [GameVersion.VERSION, office().version_text()])


func test_bank_account_shows_the_pilot_and_a_zero_balance_in_eur() -> void:
	await open_bank_account()
	check(office().bank_lines() == PackedStringArray(["PILOT", "BALANCE €0"]),
		"Bank account should show PILOT and €0, shows %s" % office().bank_lines())


func test_bank_account_shows_a_negative_balance_with_the_sign_first() -> void:
	economy().balance = -120
	await open_bank_account()
	check(office().bank_lines().has("BALANCE -€120"), "the balance should read -€120, shows %s" % office().bank_lines())


func test_a_restart_starts_the_balance_at_zero_again() -> void:
	economy().balance = 500
	await choose_ship()
	await restart()
	await open_bank_account()
	check(office().bank_lines().has("BALANCE €0"), "a new run should show €0, shows %s" % office().bank_lines())


func test_the_economy_keeps_running_while_the_office_pauses_the_world() -> void:
	check(tree.paused, "the Office should pause the world")
	check(economy().can_process(), "the Economy should keep processing while the world is paused")


func open_bank_account() -> void:
	for i in Office.TILES.size():
		await press(&"ui_right")
	await press(&"ui_accept")
	check(office().screen == Office.Screen.BANK_ACCOUNT, "Return should open the Bank account")
