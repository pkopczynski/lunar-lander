extends "res://tests/scene_test.gd"


func test_start_loading_closes_the_office_and_counts_down_3_s_plus_1_s_per_passenger_and_tonne() -> void:
	# 3 s + 2 passengers + 7 000 kg = 12 s.
	await start_loading([known_offer(2, 7000.0)])
	check(not office().showing, "START LOADING should close the Office")
	check(economy().phase == Economy.Phase.LOADING, "START LOADING should start loading")
	check(message() == "Docked!\nLoading… 12s", "the message should count down from 12 s, got %s" % message())
	await seconds(1.0)
	check(message() == "Docked!\nLoading… 11s", "the countdown should tick each second, got %s" % message())
	await seconds(10.5)
	check(economy().phase == Economy.Phase.LOADING, "loading should still run before 12 s")
	await seconds(1.0)
	check(economy().phase == Economy.Phase.DELIVERING, "loading should finish after 12 s")


func test_up_doesnt_undock_and_nothing_refuels_while_loading() -> void:
	await start_loading([known_offer(1, 3000.0)])
	lander().fuel = 1000.0
	hold(&"ui_up")
	await seconds(4.0)
	release(&"ui_up")
	check(lander().state == Lander.State.DOCKED, "Up should not undock while loading")
	check(lander().fuel == 1000.0, "a loading ship should neither burn nor refuel, has %s kg" % lander().fuel)


func test_loading_adds_the_load_and_pumps_out_fuel_above_the_cap() -> void:
	# A Sparrow has 12 000 kg for fuel and Load; 7 160 kg of Load leaves 4 840 kg for fuel.
	await start_loading([known_offer(2, 7000.0)])
	await seconds(12.5)
	check(lander().total_mass() == 22000.0, "the Load should bring the Sparrow to 22 000 kg, got %s" % lander().total_mass())
	check(lander().fuel == 4840.0, "fuel above the cap should be pumped out, has %s kg" % lander().fuel)
	check(message() == "Docked!\nLoaded! Deliver within 1:30\nFuel limited to 4 840 kg",
		"the loaded message should give the deadline and the fuel cap, got %s" % message())
	await seconds(Lander.REFUEL_DELAY + 1.0)
	check(lander().fuel == 4840.0, "refuelling should stop at the cap, has %s kg" % lander().fuel)
	hold(&"ui_up")
	await seconds(0.3)
	release(&"ui_up")
	check(lander().state == Lander.State.FLYING, "Up should undock once loaded")
	check(message() == "", "the loaded message should go when the ship undocks, got %s" % message())


func test_after_loading_refuelling_resumes_up_to_the_cap() -> void:
	await start_loading([known_offer(1, 0.0)])
	lander().fuel = 1000.0
	# As if the ship had already rested long enough: the delay must still start over.
	lander().rest_time = Lander.REFUEL_DELAY
	# 3 s + 1 passenger.
	await seconds(4.5)
	check(message() == "Docked!\nLoaded! Deliver within 1:30",
		"a light Load gives no fuel warning, got %s" % message())
	await seconds(Lander.REFUEL_DELAY - 0.8)
	check(lander().fuel == 1000.0, "refuelling should wait the usual delay after loading, has %s kg" % lander().fuel)
	await seconds(0.6)
	check(lander().fuel > 1000.0, "refuelling should resume after the usual delay, has %s kg" % lander().fuel)
	check(message().ends_with("Loaded! Deliver within 1:30\nRefueling…"),
		"the loaded message should stay while refuelling, got %s" % message())


func test_the_delivery_timer_counts_down_from_the_shortest_deadline_then_turns_red_and_counts_up() -> void:
	var urgent := known_offer(1, 0.0)
	urgent.deadline = 60.0
	check(hud().delivery_text() == "", "no delivery timer before loading, got %s" % hud().delivery_text())
	await start_loading([known_offer(1, 0.0), urgent])
	check(hud().delivery_text() == "", "no delivery timer while loading, got %s" % hud().delivery_text())
	# 3 s + 2 passengers.
	await seconds(5.0)
	await frames(1)
	check(economy().phase == Economy.Phase.DELIVERING, "loading should have finished")
	check(hud().delivery_text() == "DELIVERY 1:00", "the clock should start from the shortest deadline, got %s" % hud().delivery_text())
	check(not hud().delivery_overdue(), "the timer should not be red while on time")
	await seconds(1.5)
	check(hud().delivery_text() == "DELIVERY 0:59", "the timer should count down, got %s" % hud().delivery_text())
	check_near(economy().delivery_time, 1.5, 0.05, "the delivery clock")
	await seconds(71.0)
	check(lander().state == Lander.State.DOCKED, "the ship should still be Docked")
	check(hud().delivery_text() == "OVERDUE +0:12", "the timer should count up once overdue, got %s" % hud().delivery_text())
	check(hud().delivery_overdue(), "the timer should be red once overdue")


func test_docking_while_loaded_shows_no_popup_and_leaves_the_ship_free() -> void:
	await start_loading([known_offer(1, 0.0)])
	await seconds(4.5)
	await dock_in_spot()
	check(office().popup == Office.PopupKind.NONE, "docking while loaded should not ask to enter the Office")
	check(not lander().held, "docking while loaded should not hold the ship")
	hold(&"ui_up")
	await seconds(0.3)
	release(&"ui_up")
	check(lander().state == Lander.State.FLYING, "Up should undock right away")

