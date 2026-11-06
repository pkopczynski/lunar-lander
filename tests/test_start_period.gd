extends "res://tests/scene_test.gd"
# The Transport offers screen's START PERIOD row: the mission starts when the player chooses.


func shown_hour() -> int:
	return hud().clock_text().get_slice("  ", 1).get_slice(":", 0).to_int()


func test_the_start_period_row_sits_above_start_loading_and_is_reachable_without_contracts() -> void:
	await open_transport_offers()
	check(offers().mission_lines()[1] == "START PERIOD EVENING",
		"a run starts in the Evening, so the row should read START PERIOD EVENING, got %s" % offers().mission_lines())
	await press(&"ui_right")
	check(offers().on_start_button(), "Right should land on START LOADING")
	await press(&"ui_up")
	check(offers().selected_mission_line() == "START PERIOD", "Up from START LOADING should reach START PERIOD")
	await press(&"ui_up")
	check(offers().selected_mission_line() == "DESTINATION", "Up from START PERIOD should reach DESTINATION")
	await press(&"ui_down")
	await press(&"ui_down")
	check(offers().on_start_button(), "Down should go back to START LOADING")
	await press(&"ui_down")
	check(offers().on_start_button(), "Down should stop at START LOADING")


func test_return_cycles_morning_day_evening_night_and_wraps() -> void:
	await open_transport_offers()
	await press(&"ui_right")
	await press(&"ui_up")
	var seen := PackedStringArray([offers().mission_lines()[1]])
	for i in 4:
		await press(&"ui_accept")
		seen.append(offers().mission_lines()[1])
	check(seen == PackedStringArray(["START PERIOD EVENING", "START PERIOD NIGHT", "START PERIOD MORNING",
		"START PERIOD DAY", "START PERIOD EVENING"]), "Return should cycle the period and wrap, got %s" % seen)
	check(office().showing and economy().phase == Economy.Phase.NONE, "Return on the row shouldn't start loading")


func test_the_row_is_reachable_with_contracts_between_them_and_start_loading() -> void:
	var offer := known_offer(1, 0.0)
	economy().put_offer(offer)
	await open_transport_offers()
	await accept(offer)
	await press(&"ui_right")
	await press(&"ui_up")
	check(offers().selected_mission_line() == "START PERIOD", "Up from START LOADING should reach START PERIOD first")
	await press(&"ui_up")
	check(offers().selected_mission_line() == "DESTINATION", "Up from START PERIOD should reach DESTINATION")
	await press(&"ui_up")
	check(offers().selected_contract() == offer, "Up from DESTINATION should reach the Contract")
	await press(&"ui_down")
	await press(&"ui_down")
	check(offers().selected_mission_line() == "START PERIOD", "Down from the Contract should reach START PERIOD")
	await press(&"ui_down")
	check(offers().on_start_button(), "Down from START PERIOD should reach START LOADING")


# Sets the local time half a minute past hh:mm, so whole-minute readings aren't on a boundary.
func set_time(hours: int, minutes: int) -> void:
	clock().minutes = hours * 60 + minutes + 0.5


# Docks, says Yes to ENTER THE OFFICE? and waits for the Terminal.
func enter_the_office() -> void:
	await dock_in_spot()
	await press(&"ui_left")
	await press(&"ui_accept")
	await wait_for_terminal()
	check(office().showing, "Yes on ENTER THE OFFICE? should open the Office")


# Leaves Transport offers and the Office with Escape.
func leave_the_office() -> void:
	await press(&"ui_cancel")
	await press(&"ui_cancel")
	await wait_for_terminal()
	check(not office().showing, "Escape twice should leave the Office")


func test_opening_the_office_sets_the_row_to_the_period_holding_the_local_time() -> void:
	await choose_ship()
	for time: Array in [[8, 0, "MORNING"], [14, 0, "DAY"], [3, 0, "NIGHT"], [23, 0, "EVENING"], [6, 0, "MORNING"]]:
		set_time(time[0], time[1])
		await enter_the_office()
		await open_transport_offers()
		check(offers().mission_lines()[1] == "START PERIOD " + time[2],
			"opened at %02d:%02d, the row should read START PERIOD %s, got %s" % [time[0], time[1], time[2], offers().mission_lines()])
		# A changed row starts over on the next opening.
		await press(&"ui_right")
		await press(&"ui_up")
		await press(&"ui_accept")
		await leave_the_office()


func test_changing_the_row_without_starting_loading_leaves_the_local_time_alone() -> void:
	await choose_ship()
	await enter_the_office()
	set_time(14, 0)
	await open_transport_offers()
	await press(&"ui_right")
	await press(&"ui_up")
	await press(&"ui_accept")
	await press(&"ui_accept")
	check(offers().mission_lines()[1] != "START PERIOD EVENING", "Return should change the row")
	await leave_the_office()
	check(hud().clock_text() == "VALLEY  14:00", "leaving the Office without loading should keep the time, got '%s'" % hud().clock_text())


# Accepts the offer, picks the period on the START PERIOD row, presses START LOADING and waits
# for the Terminal to power off. Opens Transport offers from the main screen.
func start_loading_in(period: String, offer: TransportOffer) -> void:
	economy().put_offer(offer)
	await open_transport_offers()
	await accept(offer)
	await press(&"ui_right")
	await press(&"ui_up")
	for i in 4:
		if offers().mission_lines()[1] == "START PERIOD " + period:
			break
		await press(&"ui_accept")
	check(offers().mission_lines()[1] == "START PERIOD " + period, "Return should reach %s" % period)
	await press(&"ui_down")
	await press(&"ui_accept")
	await wait_for_terminal()
	check(economy().phase == Economy.Phase.LOADING, "START LOADING should start loading")


func test_start_loading_sets_the_local_time_within_the_chosen_period() -> void:
	var ranges := {"MORNING": [6, 11], "DAY": [12, 17], "EVENING": [18, 23], "NIGHT": [0, 5]}
	var seed_value := 0
	for period: String in ranges:
		# R restarts once a loading ship is back in the flight view.
		if seed_value > 0:
			await restart()
		clock().reseed(seed_value)
		seed_value += 1
		await start_loading_in(period, known_offer(1, 0.0))
		var hour := shown_hour()
		check(hour >= ranges[period][0] and hour <= ranges[period][1],
			"START LOADING in the %s should set the time within it, got '%s'" % [period, hud().clock_text()])


func test_every_mission_rerolls_the_time_even_in_the_current_period() -> void:
	clock().reseed(1)
	set_time(20, 0)
	await start_loading_in("EVENING", known_offer(1, 0.0))
	var first: String = hud().clock_text()
	check(shown_hour() >= 18 and first != "VALLEY  20:00",
		"START LOADING in the current period should roll a new Evening time, got '%s'" % first)
	await check_the_clock_moves_on(first, "through loading")
	await seconds(4.0)
	check(economy().phase == Economy.Phase.DELIVERING, "loading should have finished")
	# Deliver: the debug shortcut lands on the pad, which unloads.
	place(Vector2(pad_x() + 300.0, 0.0))
	await check_the_clock_moves_on(hud().clock_text(), "on the delivery flight")
	await press(&"restart")
	await frames(2)
	check(economy().phase == Economy.Phase.UNLOADING, "landing on the pad should start unloading")
	await check_the_clock_moves_on(hud().clock_text(), "while unloading")
	await seconds(3.0)
	check(economy().phase == Economy.Phase.NONE, "unloading should have finished")
	set_time(14, 0)
	await enter_the_office()
	await start_loading_in("DAY", known_offer(1, 0.0))
	var second: String = hud().clock_text()
	check(shown_hour() >= 12 and shown_hour() <= 17 and second != "VALLEY  14:00",
		"the second mission should roll a new Day time, got '%s'" % second)


# The HUD clock moves on 2 minutes in one real second.
func check_the_clock_moves_on(from: String, where: String) -> void:
	var hhmm := from.get_slice("  ", 1)
	var minutes := hhmm.get_slice(":", 0).to_int() * 60 + hhmm.get_slice(":", 1).to_int()
	clock().minutes = minutes + 0.5
	await seconds(1.0)
	var expected := (minutes + 2) % PlanetClock.MINUTES_PER_DAY
	check(hud().clock_text() == "VALLEY  %02d:%02d" % [expected / 60, expected % 60],
		"the clock should keep running %s, %s then '%s'" % [where, from, hud().clock_text()])
