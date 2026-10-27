extends "res://tests/scene_test.gd"


func test_run_start_shows_no_swap_popup() -> void:
	await choose_ship()
	await seconds(0.5)
	check(lander().docked, "the run should start Docked")
	check(office().popup == Office.PopupKind.NONE, "the run start should not open the swap popup")


func test_docking_opens_the_swap_popup_with_no_selected() -> void:
	await choose_ship()
	await dock_in_spot()
	check(lander().docked, "the ship should be Docked")
	check(office().popup == Office.PopupKind.SWAP, "docking should open the swap popup")
	check(office().selected_button == Office.Choice.NO, "the swap popup should have No selected")
	check(not office().showing, "the Terminal should not be showing behind the swap popup")


func test_ship_is_frozen_while_the_swap_popup_is_open() -> void:
	await choose_ship()
	await dock_in_spot()
	var ship := lander()
	var spot := ship.position
	hold(&"ui_up")
	await seconds(0.5)
	release(&"ui_up")
	check(ship.docked, "Up should not undock while the swap popup is open")
	check(ship.position == spot, "the ship should not move, %s from %s" % [ship.position, spot])
	hold(&"ui_left")
	await seconds(0.5)
	release(&"ui_left")
	hold(&"ui_right")
	await seconds(0.2)
	release(&"ui_right")
	check_near(ship.rotation, 0.0, 0.0001, "rotation while the swap popup is open")
	ship.fuel = 1000.0
	await seconds(Lander.REFUEL_DELAY + 1.0)
	check_near(ship.fuel, 1000.0, 0.0001, "fuel while the swap popup is open")
	check(not message().contains("Refueling"), "should not refuel while the swap popup is open, got %s" % message())
	check(office().popup == Office.PopupKind.SWAP, "the swap popup should still be open")


func test_no_closes_the_swap_popup_and_refuels_after_the_delay() -> void:
	await declining_refuels_after_the_delay(&"ui_accept")


func test_escape_closes_the_swap_popup_and_refuels_after_the_delay() -> void:
	await declining_refuels_after_the_delay(&"ui_cancel")


func declining_refuels_after_the_delay(action: StringName) -> void:
	await choose_ship()
	await dock_in_spot()
	var ship := lander()
	ship.fuel = 1000.0
	await press(action)
	check(office().popup == Office.PopupKind.NONE, "%s should close the swap popup" % action)
	check(not office().showing, "%s should not open the Office" % action)
	check(ship.docked, "the ship should stay Docked")
	await seconds(Lander.REFUEL_DELAY - 0.3)
	check_near(ship.fuel, 1000.0, 0.0001, "fuel before the refuel delay is over")
	await seconds(1.0)
	check(ship.fuel > 1000.0, "should refuel after the delay, fuel is %s" % ship.fuel)
	check(message().contains("Refueling"), "message should mention refuelling, got %s" % message())
	hold(&"ui_up")
	await seconds(0.4)
	release(&"ui_up")
	check(not ship.docked, "Up should undock once the swap popup is closed")
