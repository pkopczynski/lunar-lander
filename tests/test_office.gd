extends "res://tests/scene_test.gd"


func test_run_starts_on_the_office_main_screen_with_the_world_paused() -> void:
	await frames(2)
	check(office().showing, "a fresh run should show the Office")
	check(office().screen == Office.Screen.MAIN, "a fresh run should open on the main screen")
	check(office().tile_labels() == PackedStringArray(["SHIPYARD", "HANGAR", "TRANSPORT OFFERS", "BANK ACCOUNT"]),
		"the main screen should show exactly four tiles, shows %s" % office().tile_labels())
	check(office().selected_tile() == "SHIPYARD", "SHIPYARD should be selected, got %s" % office().selected_tile())
	check(office().popup == Office.PopupKind.NONE, "no popup should be open at run start")
	check(tree.paused, "the world should be paused while the Office is showing")


func test_left_right_up_and_down_move_between_the_tiles() -> void:
	await press(&"ui_right")
	check(office().selected_tile() == "HANGAR", "Right should select HANGAR, got %s" % office().selected_tile())
	await press(&"ui_down")
	check(office().selected_tile() == "TRANSPORT OFFERS", "Down should select TRANSPORT OFFERS, got %s" % office().selected_tile())
	await press(&"ui_right")
	await press(&"ui_right")
	check(office().selected_tile() == "BANK ACCOUNT", "Right on the last tile should keep it, got %s" % office().selected_tile())
	for i in 3:
		await press(&"ui_up")
	check(office().selected_tile() == "SHIPYARD", "Up should go back to SHIPYARD, got %s" % office().selected_tile())
	await press(&"ui_left")
	check(office().selected_tile() == "SHIPYARD", "Left on the first tile should keep it, got %s" % office().selected_tile())


func test_every_tile_opens_its_screen_and_escape_returns_to_the_main_screen() -> void:
	for expected: Office.Screen in [Office.Screen.SHIPYARD, Office.Screen.HANGAR, Office.Screen.TRANSPORT_OFFERS,
			Office.Screen.BANK_ACCOUNT]:
		var tile := office().selected_tile()
		await press(&"ui_accept")
		check(office().screen == expected, "Return on %s should open its screen, got %s" % [tile, office().screen])
		await press(&"ui_cancel")
		check(office().showing and office().screen == Office.Screen.MAIN, "Escape on %s should return to the main screen" % tile)
		check(office().selected_tile() == tile, "the main screen should keep %s selected" % tile)
		await press(&"ui_right")


func test_the_header_shows_the_balance_on_every_screen_red_below_zero() -> void:
	await frames(2)
	check(office().balance_text() == "€20 000", "the header should show €20 000, shows %s" % office().balance_text())
	check(not office().balance_red(), "a positive balance should not be red")
	await press(&"ui_accept")
	check(office().balance_text() == "€20 000", "the Shipyard's header should show the balance too")
	economy().balance = -700
	check(office().balance_text() == "-€700" and office().balance_red(), "a negative balance should read -€700 in red")


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


func test_the_terminal_shows_the_game_version() -> void:
	await frames(2)
	check(office().version_text() == "V" + GameVersion.VERSION, "the Terminal should show V%s, got %s" % [GameVersion.VERSION, office().version_text()])


func test_a_fresh_start_shows_the_pilot_and_a_balance_of_20_000_euros() -> void:
	await open_bank_account()
	check(office().bank_account.lines() == PackedStringArray(["PILOT", "BALANCE €20 000"]),
		"Bank account should show PILOT and €20 000, shows %s" % office().bank_account.lines())


func test_bank_account_shows_a_negative_balance_with_the_sign_first() -> void:
	economy().balance = -1234567
	await open_bank_account()
	check(office().bank_account.lines().has("BALANCE -€1 234 567"),
		"the balance should read -€1 234 567, shows %s" % office().bank_account.lines())


func test_a_restart_starts_the_balance_at_20_000_euros_again() -> void:
	economy().balance = 50000
	await choose_ship()
	await restart()
	await open_bank_account()
	check(office().bank_account.lines().has("BALANCE €20 000"), "a new run should show €20 000, shows %s" % office().bank_account.lines())


func test_the_economy_keeps_running_while_the_office_pauses_the_world() -> void:
	check(tree.paused, "the Office should pause the world")
	check(economy().can_process(), "the Economy should keep processing while the world is paused")

