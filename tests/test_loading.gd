extends "res://tests/scene_test.gd"


# Sets the local time half a minute past hh:mm, so whole-minute readings aren't on a boundary.
func set_time(hours: int, minutes: int) -> void:
	clock().minutes = hours * 60 + minutes + 0.5


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


func test_starting_loading_pumps_out_fuel_above_the_cap_for_the_contracts_load() -> void:
	# A Sparrow has 12 000 kg for fuel and Load; 7 160 kg of Load leaves 4 840 kg for fuel.
	await start_loading([known_offer(2, 7000.0)])
	check(economy().phase == Economy.Phase.LOADING, "loading should be under way")
	check(lander().fuel == 4840.0, "fuel above the cap should be pumped out as loading starts, has %s kg" % lander().fuel)
	check(lander().total_mass() == 14840.0, "the Load shouldn't count before loading ends, got %s" % lander().total_mass())


func test_up_doesnt_undock_and_left_right_dont_turn_while_loading() -> void:
	await start_loading([known_offer(1, 3000.0)])
	hold(&"ui_up")
	hold(&"ui_left")
	await seconds(4.0)
	release(&"ui_up")
	release(&"ui_left")
	check(lander().state == Lander.State.DOCKED, "Up should not undock while loading")
	check(lander().rotation == 0.0, "Left should not turn a loading ship, rotation is %s" % lander().rotation)
	check(economy().phase == Economy.Phase.LOADING, "loading should still run")


func test_a_ship_refuels_while_loading_up_to_the_cap_from_the_first_frame() -> void:
	# 3 s + 2 passengers + 7 000 kg = 12 s; the cap for that Load is 4 840 kg.
	await start_loading([known_offer(2, 7000.0)])
	lander().fuel = 4000.0
	await frames(1)
	check(lander().fuel > 4000.0, "refuelling should start without the usual delay, has %s kg" % lander().fuel)
	check(message() == "Docked!\nLoading… 12s\nRefueling…",
		"Refueling… should show under the loading countdown, got %s" % message())
	await seconds(4.0)
	check(economy().phase == Economy.Phase.LOADING, "loading should still run")
	check(lander().fuel == 4840.0, "refuelling should stop at the cap for the Contracts' Load, has %s kg" % lander().fuel)
	check(message() == "Docked!\nLoading… 8s", "no Refueling… once at the cap, got %s" % message())
	check(lander().total_mass() == 14840.0, "the Load shouldn't count before loading ends, got %s" % lander().total_mass())
	await seconds(8.5)
	check(economy().phase == Economy.Phase.DELIVERING, "loading should have finished")
	check(lander().total_mass() == 22000.0, "the Load should join the mass when loading ends, got %s" % lander().total_mass())


func test_loading_adds_the_load_and_pumps_out_fuel_above_the_cap() -> void:
	# A Sparrow has 12 000 kg for fuel and Load; 7 160 kg of Load leaves 4 840 kg for fuel.
	await start_loading([known_offer(2, 7000.0)])
	set_time(10, 0)
	# 3 s + 2 passengers + 7 tonnes: loading finishes at 10:24, and 90 s is 3 in-game hours.
	await seconds(12.5)
	check(lander().total_mass() == 22000.0, "the Load should bring the Sparrow to 22 000 kg, got %s" % lander().total_mass())
	check(lander().fuel == 4840.0, "fuel above the cap should be pumped out, has %s kg" % lander().fuel)
	check(message() == "Docked!\nLoaded! Deliver by 13:24\nFuel limited to 4 840 kg",
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
	lander().fuel = 0.0
	set_time(10, 0)
	# 3 s + 1 passenger: loading finishes at 10:08, and 90 s is 3 in-game hours.
	await seconds(4.5)
	check(economy().phase == Economy.Phase.DELIVERING, "loading should have finished")
	var after_loading := lander().fuel
	check(after_loading > 0.0 and after_loading < lander().ship_type.tank,
		"the ship should have refuelled part of the Tank while loading, has %s kg" % after_loading)
	check(message() == "Docked!\nLoaded! Deliver by 13:08\nRefueling…",
		"a light Load gives no fuel warning and refuelling goes on, got %s" % message())
	await seconds(Lander.REFUEL_DELAY + 0.5)
	check(lander().fuel > after_loading, "refuelling should carry on after loading, has %s kg" % lander().fuel)
	check(message().ends_with("Loaded! Deliver by 13:08\nRefueling…"),
		"the loaded message should stay while refuelling, got %s" % message())


func test_the_hud_shows_the_shortest_deadline_as_a_local_time_then_turns_red_once_overdue() -> void:
	var urgent := known_offer(1, 0.0)
	urgent.deadline = 60.0
	check(hud().delivery_text() == "", "no deadline before loading, got %s" % hud().delivery_text())
	await start_loading([known_offer(1, 0.0), urgent])
	set_time(14, 0)
	check(hud().delivery_text() == "", "no deadline while loading, got %s" % hud().delivery_text())
	# 3 s + 2 passengers: loading finishes at 14:10, and 60 s is 2 in-game hours.
	await seconds(5.0)
	await frames(1)
	check(economy().phase == Economy.Phase.DELIVERING, "loading should have finished")
	check(hud().delivery_text() == "VALLEY BY 16:10", "the shortest deadline as a local time, got %s" % hud().delivery_text())
	check(not hud().delivery_overdue(), "the deadline should not be red while on time")
	await seconds(1.5)
	check(hud().delivery_text() == "VALLEY BY 16:10", "the deadline time should stay put, got %s" % hud().delivery_text())
	check_near(economy().delivery_time, 1.5, 0.05, "the delivery clock")
	await seconds(58.0)
	check(not hud().delivery_overdue(), "not overdue just before the deadline")
	await seconds(1.0)
	check(lander().state == Lander.State.DOCKED, "the ship should still be Docked")
	check(hud().delivery_text() == "VALLEY OVERDUE SINCE 16:10", "the deadline once overdue, got %s" % hud().delivery_text())
	check(hud().delivery_overdue(), "the deadline should be red once overdue")


func test_a_deadline_past_midnight_reads_as_a_plain_time_in_the_message_and_the_hud() -> void:
	await start_loading([known_offer(1, 0.0)])
	set_time(22, 0)
	# 3 s + 1 passenger: loading finishes at 22:08, and 90 s is 3 in-game hours.
	await seconds(4.5)
	check(economy().phase == Economy.Phase.DELIVERING, "loading should have finished")
	check(message() == "Docked!\nLoaded! Deliver by 01:08",
		"the loaded message should give the next-day deadline with no day mark, got %s" % message())
	check(hud().delivery_text() == "VALLEY BY 01:08", "the HUD should give the next-day deadline with no day mark, got %s" % hud().delivery_text())
	await seconds(91.0)
	check(hud().delivery_text() == "VALLEY OVERDUE SINCE 01:08", "overdue shows the plain time too, got %s" % hud().delivery_text())
