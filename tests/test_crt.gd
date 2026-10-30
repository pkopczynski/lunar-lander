extends "res://tests/scene_test.gd"
# The Terminal's CRT power-on/off effect (~0.3 s).


# R reloads the scene, which starts a new run on the Office.
func test_the_office_powers_on_at_run_start() -> void:
	await choose_ship()
	await restart(false)
	check(office().showing, "the Office should show at run start")
	check(office().powering, "the Terminal should be powering on at run start")
	await seconds(0.15)
	check(office().powering, "power-on should still be running after 0.15 s")
	await seconds(0.25)
	check(not office().powering, "power-on should be over after 0.4 s")
	check(office().showing, "the Office should still show after power-on")


func test_return_during_power_on_does_nothing() -> void:
	await choose_ship()
	await restart(false)
	await press(&"ui_accept")
	check(office().screen == Office.Screen.MAIN, "Return during power-on should not open a tile")
	await wait_for_terminal()
	await press(&"ui_accept")
	check(office().screen == Office.Screen.SHIP_SELECTION, "Return after power-on should open Ship selection")


func test_escape_on_the_main_screen_powers_off_before_the_flight_view_shows() -> void:
	await press(&"ui_cancel")
	check(office().powering, "Escape should power the Terminal off")
	check(office().showing, "the Terminal should cover the flight view during power-off")
	check(tree.paused, "the world should stay paused during power-off")
	await seconds(0.4)
	check(not office().powering, "power-off should be over after 0.4 s")
	check(not office().showing, "the flight view should show after power-off")
	check(not tree.paused, "the world should run after power-off")
	check(lander().state == Lander.State.DOCKED, "the ship should be Docked")


func test_choosing_a_ship_stays_powered_on() -> void:
	await open_ship_selection()
	await browse_to(ShipType.MULE)
	await press(&"ui_accept")
	await press(&"ui_accept")
	check(not office().powering, "choosing a ship should not power the Terminal off")
	check(office().showing and office().screen == Office.Screen.MAIN, "choosing a ship should show the main screen")


func test_holding_escape_through_power_off_does_not_reopen_anything() -> void:
	hold(&"ui_cancel")
	await seconds(1.0)
	release(&"ui_cancel")
	await frames(1)
	check(not office().showing, "the Office should stay closed")
	check(office().popup == Office.PopupKind.NONE, "holding Escape should not open a popup")
	check(lander().state == Lander.State.DOCKED and lander().ship_type == ShipType.SPARROW, "the Sparrow should be Docked")


func test_input_during_power_off_does_nothing() -> void:
	await press(&"ui_cancel")
	await press(&"ui_accept")
	await press(&"ui_left")
	await seconds(0.4)
	check(not office().showing, "the Office should close after power-off")
	check(office().popup == Office.PopupKind.NONE, "input during power-off should not open a popup")
	check(lander().ship_type == ShipType.SPARROW, "input during power-off should not change the ship")


func test_yes_in_the_office_popup_powers_the_terminal_on() -> void:
	await choose_ship()
	await dock_in_spot()
	await press(&"ui_left")
	await press(&"ui_accept")
	check(office().showing, "Yes should open the Office")
	check(office().powering, "Yes should power the Terminal on")
	await press(&"ui_accept")
	check(office().showing and office().screen == Office.Screen.MAIN,
		"Return during power-on should not open a tile")
	await wait_for_terminal()
	check(office().screen == Office.Screen.MAIN, "the main screen should show after power-on")


func test_leaving_the_office_after_docking_powers_off_before_the_flight_view_shows() -> void:
	await choose_ship()
	await dock_in_spot()
	await press(&"ui_left")
	await press(&"ui_accept")
	await wait_for_terminal()
	await press(&"ui_cancel")
	check(office().powering, "Escape should power the Terminal off")
	check(office().showing and tree.paused, "the Terminal should cover the paused world during power-off")
	await seconds(0.4)
	check(not office().showing and not tree.paused, "the flight view should show after power-off")
	check(lander().state == Lander.State.DOCKED, "the ship should stay Docked")


func test_no_in_the_office_popup_closes_it_without_an_effect() -> void:
	await choose_ship()
	await dock_in_spot()
	await press(&"ui_accept")
	check(not office().powering, "the Enter-the-Office popup is not the Terminal, so No plays no effect")
	check(office().popup == Office.PopupKind.NONE and not office().showing, "No should close the Enter-the-Office popup")
