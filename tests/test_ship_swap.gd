extends "res://tests/scene_test.gd"


func test_run_start_shows_no_office_popup() -> void:
	await choose_ship()
	await seconds(0.5)
	check(lander().state == Lander.State.DOCKED, "the run should start Docked")
	check(office().popup == Office.PopupKind.NONE, "the run start should not open the Enter-the-Office popup")


func test_docking_asks_to_enter_the_office_with_no_selected() -> void:
	await choose_ship()
	await dock_in_spot()
	check(lander().state == Lander.State.DOCKED, "the ship should be Docked")
	check(office().popup == Office.PopupKind.ENTER_OFFICE, "docking should open the Enter-the-Office popup")
	check(office().popup_text() == "ENTER THE OFFICE?", "the popup should ask ENTER THE OFFICE?, got %s" % office().popup_text())
	check(office().selected_button == Office.Choice.NO, "the Enter-the-Office popup should have No selected")
	check(not office().showing, "the Terminal should not be showing behind the Enter-the-Office popup")


func test_the_office_popup_waits_for_the_ship_to_finish_leveling() -> void:
	await choose_ship()
	var ship := lander()
	place(station().parking_spot.get_center())
	ship.rotation = 0.3
	await frames(2)
	check(ship.state == Lander.State.DOCKED, "the tilted ship should dock in the parking spot")
	await seconds(Lander.LEVEL_TIME / 2.0)
	check(absf(ship.rotation) > 0.01, "the ship should still be easing upright, rotation %s" % ship.rotation)
	check(office().popup == Office.PopupKind.NONE, "the popup should not show while the ship is easing upright")
	check(not ship.held, "the ship should not be held while it eases upright")
	await seconds(Lander.LEVEL_TIME / 2.0 + 0.05)
	check_near(ship.rotation, 0.0, 0.0001, "rotation once leveled")
	check(office().popup == Office.PopupKind.ENTER_OFFICE, "the popup should show once the ship is upright")
	check(ship.held, "the ship should be held once the popup shows")


func test_choosing_another_ship_type_shows_no_office_popup() -> void:
	await choose_ship(ShipType.MULE)
	await seconds(Lander.LEVEL_TIME + 0.2)
	check(lander().state == Lander.State.DOCKED, "the Mule should be Docked")
	check(office().popup == Office.PopupKind.NONE, "choosing a ship type should not open the Enter-the-Office popup")


func test_undocking_while_leveling_shows_no_office_popup() -> void:
	await choose_ship()
	var ship := lander()
	place(station().parking_spot.get_center())
	ship.rotation = 0.3
	await frames(2)
	check(ship.state == Lander.State.DOCKED, "the tilted ship should dock in the parking spot")
	hold(&"ui_up")
	await seconds(Lander.LEVEL_TIME + 0.2)
	release(&"ui_up")
	check(ship.state == Lander.State.FLYING, "Up should undock while the ship eases upright")
	check(office().popup == Office.PopupKind.NONE, "undocking before the ship is upright should not open the popup")


func test_ship_is_frozen_while_the_office_popup_is_open() -> void:
	await choose_ship()
	await dock_in_spot()
	var ship := lander()
	var spot := ship.position
	hold(&"ui_up")
	await seconds(0.5)
	release(&"ui_up")
	check(ship.state == Lander.State.DOCKED, "Up should not undock while the Enter-the-Office popup is open")
	check(ship.position == spot, "the ship should not move, %s from %s" % [ship.position, spot])
	hold(&"ui_left")
	await seconds(0.5)
	release(&"ui_left")
	hold(&"ui_right")
	await seconds(0.2)
	release(&"ui_right")
	check_near(ship.rotation, 0.0, 0.0001, "rotation while the Enter-the-Office popup is open")
	ship.fuel = 1000.0
	await seconds(3.0)
	check_near(ship.fuel, 1000.0, 0.0001, "fuel while the Enter-the-Office popup is open")
	check(not message().contains("Refueling"), "should not refuel while the Enter-the-Office popup is open, got %s" % message())
	check(office().popup == Office.PopupKind.ENTER_OFFICE, "the Enter-the-Office popup should still be open")


func test_r_in_the_office_popup_does_nothing() -> void:
	await choose_ship()
	await dock_in_spot()
	var scene := main()
	await press(&"restart")
	await frames(2)
	check(main() == scene, "R should not reload the scene")
	check(office().popup == Office.PopupKind.ENTER_OFFICE and not office().showing,
		"R should leave the Enter-the-Office popup open")


func test_no_closes_the_office_popup_and_leaves_the_ship_free_to_undock() -> void:
	await declining_leaves_the_ship_free_to_undock(&"ui_accept")


func test_escape_closes_the_office_popup_and_leaves_the_ship_free_to_undock() -> void:
	await declining_leaves_the_ship_free_to_undock(&"ui_cancel")


func declining_leaves_the_ship_free_to_undock(action: StringName) -> void:
	await choose_ship()
	await dock_in_spot()
	var ship := lander()
	ship.fuel = 1000.0
	await press(action)
	check(office().popup == Office.PopupKind.NONE, "%s should close the Enter-the-Office popup" % action)
	check(not office().showing, "%s should not open the Office" % action)
	check(ship.state == Lander.State.DOCKED, "the ship should stay Docked")
	await seconds(3.0)
	check_near(ship.fuel, 1000.0, 0.0001, "docking at the station adds no fuel")
	check(message() == "Docked!", "no Refueling… at the station, got %s" % message())
	hold(&"ui_up")
	await seconds(0.4)
	release(&"ui_up")
	check(ship.state != Lander.State.DOCKED, "Up should undock once the Enter-the-Office popup is closed")


func test_landing_on_the_pad_asks_for_the_workshop_not_the_office() -> void:
	await choose_ship()
	place(Vector2(pad_x(), 580), Vector2(0, 20))
	await seconds(4.0)
	check(lander().state == Lander.State.LANDED, "the ship should be Landed on the pad")
	check(office().popup == Office.PopupKind.ENTER_WORKSHOP, "landing on the pad should ask for the Workshop, not the Office")
	check(not office().showing, "landing on the pad should not open the Office")


func test_yes_opens_the_office_main_screen_with_the_current_ship_in_service() -> void:
	await choose_ship(ShipType.HALO)
	await dock_in_spot()
	await answer_swap_yes()
	check(office().showing, "Yes should open the Office")
	check(office().popup == Office.PopupKind.NONE and office().screen == Office.Screen.MAIN,
		"the Office should open on the main screen")
	await open_hangar()
	var rows := hangar_screen().rows()
	check(rows[1].begins_with("HALO 1 IN SERVICE"), "the Halo should be tagged IN SERVICE, got %s" % rows[1])
	check(not rows[0].contains("IN SERVICE"), "SPARROW 1 should not be tagged IN SERVICE, got %s" % rows[0])


func answer_swap_yes() -> void:
	check(office().popup == Office.PopupKind.ENTER_OFFICE, "the Enter-the-Office popup should be open")
	await press(&"ui_left")
	check(office().selected_button == Office.Choice.YES, "Left should select Yes")
	await press(&"ui_accept")
	await wait_for_terminal()


func test_choosing_another_ship_type_puts_it_in_the_same_parking_spot() -> void:
	await choose_ship(ShipType.SPARROW)
	var ship := lander()
	ship.fuel = 1500.0
	var spot := station().parking_spot
	var station_node := station()
	await dock_in_spot()
	await answer_swap_yes()
	await choose_ship(ShipType.MULE)
	check(ship.ship_type == ShipType.MULE, "the ship should now be a Mule, got %s" % ship.ship_type.name)
	check(ship.state == Lander.State.DOCKED, "the Mule should be Docked")
	check(station() == station_node and station().parking_spot == spot, "the station should not be rebuilt")
	check_near(ship.position.x, spot.get_center().x, 0.5, "x at the same parking spot centre")
	check_near(ship.position.y, spot.get_center().y, 0.5, "y at the same parking spot centre")
	check(ship.is_inside_spot(), "the whole Mule should be inside the parking spot")
	check_near(ship.tank_level(), 1.0, 0.0001, "the Mule's tank level")
	check_near(dry_mass(), ShipType.MULE.default_dry_mass, 0.01, "the Mule's dry mass")
	await seconds(0.5)
	check(office().popup == Office.PopupKind.NONE, "the swap should not ask about a swap again")
	check(not tree.paused, "the world should run again after the swap")
	hold(&"ui_up")
	await seconds(0.5)
	release(&"ui_up")
	check(ship.state != Lander.State.DOCKED, "Up should undock the Mule")


func test_escape_on_the_main_screen_returns_to_the_dock_as_no() -> void:
	await leaving_the_office_returns_to_the_dock(false)


func test_choosing_the_in_service_ship_type_then_leaving_returns_to_the_dock_as_no() -> void:
	await leaving_the_office_returns_to_the_dock(true)


func leaving_the_office_returns_to_the_dock(choose_in_service: bool) -> void:
	await choose_ship(ShipType.HALO)
	var ship := lander()
	await dock_in_spot()
	var spot := ship.position
	ship.fuel = 1000.0
	await answer_swap_yes()
	if choose_in_service:
		await open_hangar()
		await open_ship_page(hangar().in_service)
		await select_action(HangarScreen.Action.PUT_IN_SERVICE)
		check(office().popup == Office.PopupKind.NONE, "PUT IN SERVICE on the Halo in service should not ask")
		await press(&"ui_cancel")
		await press(&"ui_cancel")
		check(office().screen == Office.Screen.MAIN, "Escape twice should return to the main screen")
	await press(&"ui_cancel")
	await wait_for_terminal()
	check(not office().showing, "Escape on the main screen should close the Office")
	check(office().popup == Office.PopupKind.NONE, "leaving the Office should not leave a popup open")
	check(not tree.paused, "the world should run again")
	check(ship.ship_type == ShipType.HALO, "the ship should still be the Halo, got %s" % ship.ship_type.name)
	check(ship.state == Lander.State.DOCKED and ship.position == spot, "the ship should stay Docked where it was")
	check_near(dry_mass(), ShipType.HALO.default_dry_mass, 0.01, "the Halo's dry mass should be kept")
	await seconds(3.0)
	check_near(ship.fuel, 1000.0, 0.0001, "docking at the station adds no fuel")
