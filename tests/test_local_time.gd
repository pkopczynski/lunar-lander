extends "res://tests/scene_test.gd"
# Local time: the planet clock and its HUD readout, `VALLEY  14:07`.


func clock_text() -> String:
	return hud().clock_text()


func shows_valley_time(text: String) -> bool:
	var pattern := RegEx.create_from_string("^VALLEY  ([01][0-9]|2[0-3]):[0-5][0-9]$")
	return pattern.search(text) != null


func test_the_hud_shows_the_location_and_local_time_in_every_ship_state() -> void:
	await choose_ship()
	check(shows_valley_time(clock_text()), "Docked: the HUD clock should read VALLEY  HH:MM, got '%s'" % clock_text())
	place(Vector2(pad_x() + 300.0, 200.0))
	await frames(2)
	check(shows_valley_time(clock_text()), "Flying: the HUD clock should read VALLEY  HH:MM, got '%s'" % clock_text())
	await press(&"restart")
	await frames(2)
	check(lander().state == Lander.State.LANDED, "R on the Surface should land the ship")
	check(shows_valley_time(clock_text()), "Landed: the HUD clock should read VALLEY  HH:MM, got '%s'" % clock_text())
	await crash_in_deep_space()
	check(shows_valley_time(clock_text()), "Crashed: the HUD clock should read VALLEY  HH:MM, got '%s'" % clock_text())


# The hour and minute the HUD clock shows.
func shown_time() -> Vector2i:
	var hhmm := clock_text().get_slice("  ", 1)
	return Vector2i(hhmm.get_slice(":", 0).to_int(), hhmm.get_slice(":", 1).to_int())


func test_a_run_starts_at_the_valley_at_a_random_evening_minute() -> void:
	var hours := {}
	var minutes := {}
	for value in 30:
		clock().reseed(value)
		var time := shown_time()
		check(clock_text().begins_with("VALLEY  "), "a run should start at the Valley, got '%s'" % clock_text())
		check(time.x >= 18 and time.x <= 23, "seed %d: a run should start in the Evening (18:00-23:59), got '%s'" % [value, clock_text()])
		hours[time.x] = true
		minutes[time.y] = true
	check(hours.size() > 1, "the starting hour should vary across seeds, got %s" % [hours.keys()])
	check(minutes.size() > 5, "the starting minute should vary across seeds, got %s" % [minutes.keys()])


# Sets the local time half a minute past hh:mm, so whole-minute readings aren't on a boundary.
func set_time(hours: int, minutes: int) -> void:
	clock().minutes = hours * 60 + minutes + 0.5


func test_one_real_second_is_two_minutes_and_thirty_seconds_an_hour() -> void:
	await choose_ship()
	set_time(10, 0)
	await frames(1)
	check(clock_text() == "VALLEY  10:00", "set to 10:00, got '%s'" % clock_text())
	set_time(10, 0)
	await seconds(1.0)
	check(clock_text() == "VALLEY  10:02", "one real second should advance 2 minutes, got '%s'" % clock_text())
	set_time(10, 0)
	await seconds(30.0)
	check(clock_text() == "VALLEY  11:00", "30 real seconds should advance an hour, got '%s'" % clock_text())


func test_23_59_wraps_to_00_00() -> void:
	await choose_ship()
	set_time(23, 59)
	await seconds(0.5)
	check(clock_text() == "VALLEY  00:00", "one minute after 23:59 should be 00:00, got '%s'" % clock_text())
	await seconds(30.0)
	check(clock_text() == "VALLEY  01:00", "the day should run on after midnight, got '%s'" % clock_text())


func test_time_stands_still_while_the_office_shows() -> void:
	check(office().showing, "a run should open on the Office")
	var before := clock_text()
	await seconds(3.0)
	check(clock_text() == before, "time shouldn't pass while the Office shows: %s, then %s" % [before, clock_text()])
	await choose_ship()
	await dock_in_spot()
	await press(&"ui_left")
	await press(&"ui_accept")
	await wait_for_terminal()
	check(office().showing, "Yes on ENTER THE OFFICE? should open the Office")
	set_time(10, 0)
	await seconds(3.0)
	check(clock_text() == "VALLEY  10:00", "time shouldn't pass while the Office shows again, got '%s'" % clock_text())


# Waits one real second from 10:00 and checks the HUD clock moved on two minutes.
func check_runs(where: String) -> void:
	set_time(10, 0)
	await seconds(1.0)
	check(clock_text() == "VALLEY  10:02", "time should run %s, got '%s'" % [where, clock_text()])


func test_time_runs_docked_loading_flying_and_landed() -> void:
	await start_loading([known_offer(1, 3000.0)])
	check(economy().phase == Economy.Phase.LOADING, "START LOADING should start loading")
	await check_runs("while loading")
	await seconds(7.0)
	check(lander().state == Lander.State.DOCKED and economy().phase == Economy.Phase.DELIVERING,
		"the loaded ship should still be Docked at the station")
	await check_runs("Docked at the station")
	place(Vector2(pad_x() + 300.0, 0.0))
	await check_runs("flying on the surface")
	await press(&"restart")
	await frames(2)
	check(lander().state == Lander.State.LANDED, "R on the Surface should land the ship on the pad")
	await check_runs("Landed on the pad")


# A location with its pad left of the Valley's.
func elsewhere() -> Location:
	var location := Location.new()
	location.name = "ELSEWHERE"
	location.pad_center_x = 600.0
	return location


func test_the_hud_names_the_current_location() -> void:
	await choose_ship()
	set_time(14, 7)
	clock().move_to(elsewhere())
	await frames(1)
	check(clock_text() == "ELSEWHERE  14:07", "the HUD should name the new location, keeping the time, got '%s'" % clock_text())


func test_a_restart_starts_over_at_the_valley_in_the_evening() -> void:
	await choose_ship()
	clock().move_to(elsewhere())
	set_time(10, 0)
	await restart()
	var time := shown_time()
	check(clock_text().begins_with("VALLEY  "), "a restart should start at the Valley, got '%s'" % clock_text())
	check(time.x >= 18 and time.x <= 23, "a restart should start in the Evening, got '%s'" % clock_text())
	check_near(pad_visual_center_x(), 1000.0, 0.01, "the drawn pad should be back at the Valley's")
