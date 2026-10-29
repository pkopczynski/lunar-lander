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
	check(office().popup == Office.PopupKind.NONE, "Return during power-on should not open ARE YOU SURE?")
	await wait_for_terminal()
	await press(&"ui_accept")
	check(office().popup == Office.PopupKind.ARE_YOU_SURE, "Return after power-on should open ARE YOU SURE?")


func test_confirming_a_ship_powers_off_before_the_flight_view_shows() -> void:
	await press(&"ui_right")
	check(office().selected_offer() == ShipType.MULE, "Right should browse to the Mule")
	await press(&"ui_accept")
	await press(&"ui_accept")
	check(office().popup == Office.PopupKind.NONE, "Yes should close ARE YOU SURE?")
	check(office().powering, "Yes should power the Terminal off")
	check(office().showing, "the Terminal should cover the flight view during power-off")
	check(tree.paused, "the world should stay paused during power-off")
	await seconds(0.4)
	check(not office().powering, "power-off should be over after 0.4 s")
	check(not office().showing, "the flight view should show after power-off")
	check(not tree.paused, "the world should run after power-off")
	check(lander().ship_type == ShipType.MULE, "the ship should be the Mule, got %s" % lander().ship_type.name)
	check(lander().state == Lander.State.DOCKED, "the Mule should be Docked")


func test_holding_return_through_power_off_does_not_select_again() -> void:
	await press(&"ui_accept")
	hold(&"ui_accept")
	await seconds(1.0)
	release(&"ui_accept")
	await frames(1)
	check(not office().showing, "the Office should stay closed")
	check(office().popup == Office.PopupKind.NONE, "holding Return should not open a popup")
	check(lander().state == Lander.State.DOCKED and lander().ship_type == ShipType.SPARROW, "the Sparrow should be Docked")


func test_return_during_power_off_does_nothing() -> void:
	await press(&"ui_accept")
	await press(&"ui_accept")
	await press(&"ui_accept")
	await press(&"ui_left")
	await seconds(0.4)
	check(not office().showing, "the Office should close after power-off")
	check(office().popup == Office.PopupKind.NONE, "input during power-off should not open a popup")
	check(lander().ship_type == ShipType.SPARROW, "input during power-off should not change the ship")


func test_yes_in_the_swap_popup_powers_the_terminal_on() -> void:
	await choose_ship()
	await dock_in_spot()
	await press(&"ui_left")
	await press(&"ui_accept")
	check(office().showing, "Yes should open the Office")
	check(office().powering, "Yes should power the Terminal on")
	await press(&"ui_accept")
	check(office().showing and office().popup == Office.PopupKind.NONE,
		"Return during power-on should not pick the IN SERVICE Offer")
	await wait_for_terminal()
	check(office().in_service_shown(), "the IN SERVICE Offer should show after power-on")


func test_cancelling_a_swap_powers_off_before_the_flight_view_shows() -> void:
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


func test_no_in_the_swap_popup_closes_it_without_an_effect() -> void:
	await choose_ship()
	await dock_in_spot()
	await press(&"ui_accept")
	check(not office().powering, "the swap popup is not the Terminal, so No plays no effect")
	check(office().popup == Office.PopupKind.NONE and not office().showing, "No should close the swap popup")
