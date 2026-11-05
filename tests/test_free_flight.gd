extends "res://tests/scene_test.gd"
# A free flight: START with no Contracts goes to the chosen destination and start period, with
# nothing to load or deliver.


func test_the_button_reads_start_without_contracts_and_start_loading_with_them() -> void:
	var offer := known_offer(1, 0.0)
	economy().put_offer(offer)
	await open_transport_offers()
	check(offers().start_text() == "START", "with no Contracts the button should read START, got %s" % offers().start_text())
	await accept(offer)
	check(offers().start_text() == "START LOADING",
		"with a Contract the button should read START LOADING, got %s" % offers().start_text())


func shown_hour() -> int:
	return hud().clock_text().get_slice("  ", 1).get_slice(":", 0).to_int()


# With no Contracts, sets DESTINATION and START PERIOD on the Transport offers screen, presses
# START and waits for the Terminal to power off. Opens Transport offers from the main screen.
func start_free_flight(destination: Location, period: String) -> void:
	await open_transport_offers()
	await press(&"ui_right")
	check(offers().start_text() == "START", "with no Contracts the button should read START")
	await press(&"ui_up")
	for i in PlanetClock.StartPeriod.size():
		if offers().mission_lines()[1] == "START PERIOD " + period:
			break
		await press(&"ui_accept")
	await press(&"ui_up")
	for i in Location.ALL.size():
		if offers().mission_lines()[0] == "DESTINATION " + destination.name:
			break
		await press(&"ui_accept")
	check(offers().mission_lines() == PackedStringArray(["DESTINATION " + destination.name, "START PERIOD " + period]),
		"the mission rows should read %s %s, got %s" % [destination.name, period, offers().mission_lines()])
	await press(&"ui_down")
	await press(&"ui_down")
	await press(&"ui_accept")
	await wait_for_terminal()
	check(not office().showing, "START should power the Terminal off")


func test_start_moves_the_surface_to_the_destination_and_sets_the_time_within_the_period() -> void:
	clock().reseed(3)
	clock().minutes = 20 * 60.5
	await start_free_flight(Location.MINE, "MORNING")
	check(clock().location == Location.MINE and world().location == Location.MINE,
		"START should move the surface to the Mine, at %s" % clock().location.name)
	check(hud().clock_text().begins_with("MINE  "), "the HUD should name the Mine, got '%s'" % hud().clock_text())
	check(shown_hour() >= 6 and shown_hour() <= 11,
		"START in the Morning should set the time within it, got '%s'" % hud().clock_text())


func test_after_start_the_ship_is_docked_and_up_undocks_it_at_once() -> void:
	# Entering the Office after docking holds the ship; START releases it.
	await choose_ship()
	await dock_in_spot()
	await press(&"ui_left")
	await press(&"ui_accept")
	await wait_for_terminal()
	check(office().showing and lander().held, "Yes on ENTER THE OFFICE? should open the Office, the ship held")
	await start_free_flight(Location.VALLEY, "DAY")
	check(lander().state == Lander.State.DOCKED, "after START the ship should still be Docked")
	check(not lander().held, "after START the ship should be released")
	check(economy().phase == Economy.Phase.NONE, "a free flight shouldn't load anything")
	check(message() == "Docked!" or message() == "Docked!\nRefueling…", "nothing should be loading, got %s" % message())
	await hold(&"ui_up")
	await seconds(0.3)
	await release(&"ui_up")
	check(lander().state == Lander.State.FLYING, "Up should undock the ship at once after START")


func test_a_free_flight_has_no_deadline_and_lands_plainly_then_docks_as_usual() -> void:
	await start_free_flight(Location.MINE, "EVENING")
	check(hud().delivery_text() == "", "a free flight should show no deadline, got '%s'" % hud().delivery_text())
	check(lander().fuel_cap() == lander().ship_type.tank, "a free flight should have no fuel cap")
	place(Vector2(pad_x(), world().location.ground_y - 28.0), Vector2(0, 20))
	await seconds(4.0)
	check(lander().state == Lander.State.LANDED, "the ship should land on the Mine's pad")
	check(economy().phase == Economy.Phase.NONE, "landing on a free flight shouldn't unload")
	check(message() == "Landed!" or message() == "Landed!\nRefueling…",
		"landing should be a plain Landed, got %s" % message())
	check(hud().delivery_text() == "", "no deadline should show after landing, got '%s'" % hud().delivery_text())
	await dock_in_spot()
	check(office().popup == Office.PopupKind.ENTER_OFFICE, "docking again should ask ENTER THE OFFICE?")
