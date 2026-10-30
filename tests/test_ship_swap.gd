extends "res://tests/scene_test.gd"


func test_run_start_shows_no_swap_popup() -> void:
	await choose_ship()
	await seconds(0.5)
	check(lander().state == Lander.State.DOCKED, "the run should start Docked")
	check(office().popup == Office.PopupKind.NONE, "the run start should not open the swap popup")


func test_docking_opens_the_swap_popup_with_no_selected() -> void:
	await choose_ship()
	await dock_in_spot()
	check(lander().state == Lander.State.DOCKED, "the ship should be Docked")
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
	check(ship.state == Lander.State.DOCKED, "Up should not undock while the swap popup is open")
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


func test_r_in_the_swap_popup_returns_to_the_office() -> void:
	await choose_ship()
	await dock_in_spot()
	await restart()
	check(office().showing, "R should return to the Office")
	check(office().popup == Office.PopupKind.NONE, "the Office should open on the Ship offer screen after R")
	check(not office().in_service_shown(), "a new run should not tag a Ship offer IN SERVICE")


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
	check(ship.state == Lander.State.DOCKED, "the ship should stay Docked")
	await seconds(Lander.REFUEL_DELAY - 0.3)
	check_near(ship.fuel, 1000.0, 0.0001, "fuel before the refuel delay is over")
	await seconds(1.0)
	check(ship.fuel > 1000.0, "should refuel after the delay, fuel is %s" % ship.fuel)
	check(message().contains("Refueling"), "message should mention refuelling, got %s" % message())
	hold(&"ui_up")
	await seconds(0.4)
	release(&"ui_up")
	check(ship.state != Lander.State.DOCKED, "Up should undock once the swap popup is closed")


func test_landing_on_the_pad_shows_no_swap_popup() -> void:
	await choose_ship()
	place(Vector2(Lander.PAD_CENTER_X, 580), Vector2(0, 20))
	await seconds(4.0)
	check(lander().state == Lander.State.LANDED, "the ship should be Landed on the pad")
	check(office().popup == Office.PopupKind.NONE, "landing on the pad should not open the swap popup")
	check(not office().showing, "landing on the pad should not open the Office")


func test_yes_opens_the_office_with_the_current_ship_in_service() -> void:
	await choose_ship(ShipType.HALO)
	await dock_in_spot()
	await answer_swap_yes()
	check(office().showing, "Yes should open the Office")
	check(office().popup == Office.PopupKind.NONE, "the Office should open on the Ship offer screen")
	check(office().selected_ship_offer() == ShipType.HALO, "the current ship type should be selected, got %s"
		% office().selected_ship_offer().name)
	check(office().in_service_shown(), "the current ship type should be tagged IN SERVICE")
	check(Array(office().ship_offer_lines()).has("IN SERVICE"), "the Ship offer should read IN SERVICE")
	await press(&"ui_right")
	check(not office().in_service_shown(), "other Ship offers should not be tagged IN SERVICE")


func answer_swap_yes() -> void:
	check(office().popup == Office.PopupKind.SWAP, "the swap popup should be open")
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


func test_choosing_the_in_service_ship_type_returns_to_the_dock_as_no() -> void:
	await cancelling_the_swap_returns_to_the_dock(&"ui_accept")


func test_escape_on_the_ship_offer_screen_returns_to_the_dock_as_no() -> void:
	await cancelling_the_swap_returns_to_the_dock(&"ui_cancel")


func cancelling_the_swap_returns_to_the_dock(action: StringName) -> void:
	await choose_ship(ShipType.HALO)
	var ship := lander()
	await dock_in_spot()
	var spot := ship.position
	ship.fuel = 1000.0
	await answer_swap_yes()
	check(office().in_service_shown(), "the Office should show the IN SERVICE Halo")
	await press(action)
	await wait_for_terminal()
	check(not office().showing, "%s on the IN SERVICE Ship offer should close the Office" % action)
	check(office().popup == Office.PopupKind.NONE, "%s should not leave a popup open" % action)
	check(not tree.paused, "the world should run again")
	check(ship.ship_type == ShipType.HALO, "the ship should still be the Halo, got %s" % ship.ship_type.name)
	check(ship.state == Lander.State.DOCKED and ship.position == spot, "the ship should stay Docked where it was")
	check_near(dry_mass(), ShipType.HALO.default_dry_mass, 0.01, "the Halo's dry mass should be kept")
	await seconds(Lander.REFUEL_DELAY - 0.3)
	check_near(ship.fuel, 1000.0, 0.0001, "fuel before the refuel delay is over")
	await seconds(1.0)
	check(ship.fuel > 1000.0, "should refuel after the delay, fuel is %s" % ship.fuel)
