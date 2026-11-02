extends "res://tests/scene_test.gd"
# The Mine, a second location, and the Transport offers screen's DESTINATION row that takes a
# mission there.


func test_the_destination_row_sits_above_start_period_and_starts_on_the_current_location() -> void:
	await open_transport_offers()
	check(offers().mission_lines() == PackedStringArray(["DESTINATION VALLEY", "START PERIOD EVENING"]),
		"a run starts at the Valley, so the rows should read DESTINATION VALLEY, START PERIOD EVENING, got %s" % offers().mission_lines())
	await press(&"ui_right")
	await press(&"ui_up")
	await press(&"ui_up")
	check(offers().selected_mission_line() == "DESTINATION", "Up twice from START LOADING should reach DESTINATION")
	await press(&"ui_up")
	check(offers().selected_mission_line() == "DESTINATION", "Up should stop at DESTINATION without Contracts")


# From START LOADING, Up to the DESTINATION row.
func up_to_destination() -> void:
	await press(&"ui_up")
	await press(&"ui_up")


func test_return_cycles_valley_mine_and_wraps_without_moving_the_location() -> void:
	await open_transport_offers()
	await press(&"ui_right")
	await up_to_destination()
	var seen := PackedStringArray([offers().mission_lines()[0]])
	for i in 2:
		await press(&"ui_accept")
		seen.append(offers().mission_lines()[0])
	check(seen == PackedStringArray(["DESTINATION VALLEY", "DESTINATION MINE", "DESTINATION VALLEY"]),
		"Return should cycle the destination and wrap, got %s" % seen)
	await press(&"ui_accept")
	check(office().showing and economy().phase == Economy.Phase.NONE, "Return on the row shouldn't start loading")
	check(world().location == Location.VALLEY, "only START LOADING should apply the destination")


# Accepts a passenger offer, picks the Mine on the DESTINATION row and presses START LOADING.
func start_loading_at_the_mine() -> void:
	var offer := known_offer(1, 0.0)
	economy().put_offer(offer)
	await open_transport_offers()
	await accept(offer)
	await press(&"ui_right")
	await up_to_destination()
	await press(&"ui_accept")
	check(offers().mission_lines()[0] == "DESTINATION MINE", "Return should pick the Mine")
	await press(&"ui_down")
	await press(&"ui_down")
	await press(&"ui_accept")
	await wait_for_terminal()
	check(economy().phase == Economy.Phase.LOADING, "START LOADING should start loading")


func test_start_loading_with_the_mine_takes_the_surface_there() -> void:
	await start_loading_at_the_mine()
	check(world().location == Location.MINE, "START LOADING with MINE should make the Mine the location")
	check(hud().clock_text().begins_with("MINE  "), "the HUD should show MINE  HH:MM, got '%s'" % hud().clock_text())
	check_near(pad_visual_center_x(), Location.MINE.pad_center_x, 0.01, "the drawn pad should be at the Mine's pad")
	check(absf(Location.MINE.pad_center_x - Location.VALLEY.pad_center_x) > Lander.PAD_WIDTH,
		"the Mine's pad should be away from where the Valley's is")


# Flies straight down from above the benches, thrusting whenever the ship sinks faster than a
# gentle speed, until it touches down or the time runs out.
func descend_from(start: Vector2) -> void:
	place(start)
	for i in roundi(20.0 * PHYSICS_FPS):
		if lander().state != Lander.State.FLYING:
			break
		if lander().velocity.y > 30.0:
			hold(&"ui_up")
		else:
			release(&"ui_up")
		await frames(1)
	release(&"ui_up")
	await seconds(0.5)


func test_every_ship_type_can_fly_down_into_the_pit_and_land_on_the_mines_pad() -> void:
	for type: ShipType in ShipType.ALL:
		await choose_ship(type)
		clock().move_to(Location.MINE)
		raise_to_maximum_weight()
		await descend_from(Vector2(pad_x(), 300.0))
		check(lander().state == Lander.State.LANDED,
			"the %s should land on the Mine's pad at its Maximum weight, says %s" % [type.name, message()])
		check_near(lander().position.x, pad_x(), 1.0, "the %s's x after flying down" % type.name)
		await restart()


func test_touching_down_on_the_pit_floor_where_the_valleys_pad_would_be_crashes() -> void:
	await choose_ship()
	clock().move_to(Location.MINE)
	place(Vector2(Location.VALLEY.pad_center_x, 580), Vector2(0, 20))
	await seconds(1.0)
	check(message().begins_with("Crashed"),
		"the Valley's pad spot isn't the Mine's pad, so touching down there should crash, got %s" % message())


func test_touching_a_bench_crashes_and_the_valley_has_no_benches() -> void:
	await choose_ship()
	clock().move_to(Location.MINE)
	# Gently onto the middle left bench, whose top is at y 488.
	place(Vector2(550, 440), Vector2(0, 20))
	await seconds(1.5)
	check(message().begins_with("Crashed"), "touching a bench should crash, got %s" % message())
	clock().move_to(Location.VALLEY)
	# Where the bench was, at the Mine.
	place(Vector2(550, 520))
	await frames(10)
	check(lander().state == Lander.State.FLYING, "back at the Valley the benches should be gone, says %s" % message())


func test_the_debug_pad_shortcut_puts_the_ship_on_the_mines_pad() -> void:
	await choose_ship(ShipType.MULE)
	clock().move_to(Location.MINE)
	place(Vector2(1000, 100))
	await press(&"restart")
	await seconds(1.0)
	check(lander().state == Lander.State.LANDED, "R at the Mine should land the ship and keep it landed, says %s" % message())
	check_near(lander().position.x, Location.MINE.pad_center_x, 0.5, "x at the Mine's pad centre")


func test_landing_on_the_mines_pad_while_delivering_unloads_and_is_delivered_to_the_mine() -> void:
	await start_loading_at_the_mine()
	await seconds(4.5)
	check(economy().phase == Economy.Phase.DELIVERING, "loading should have finished")
	place(Vector2(pad_x(), 580), Vector2(0, 20))
	await seconds(0.5)
	check(lander().state == Lander.State.LANDED, "touching down on the Mine's pad should land, says %s" % message())
	check(economy().phase == Economy.Phase.UNLOADING, "landing on the Mine's pad should start unloading")
	await seconds(3.0)
	check(economy().phase == Economy.Phase.NONE, "unloading should have finished")
	await dock_in_spot()
	await press(&"ui_left")
	await press(&"ui_accept")
	await wait_for_terminal()
	await open_bank_account()
	await press(&"ui_accept")
	var details := office().bank_account.details(0)
	check("DELIVERED TO MINE" in details, "a Mine delivery should show DELIVERED TO MINE, shows %s" % details)


func test_the_benches_dim_at_night_and_the_pad_doesnt() -> void:
	await choose_ship()
	clock().move_to(Location.MINE)
	var bench: Polygon2D = null
	for child in main().get_node("Terrain").get_children():
		if child is Polygon2D:
			bench = child
	check(bench != null, "the Mine's benches should be drawn")
	clock().minutes = 2 * 60 + 0.5
	await frames(2)
	var pad: Polygon2D = main().get_node("Ground/Pad")
	check(shown_color(bench).v < bench.color.v * 0.8, "the benches should dim at night, shown %s" % shown_color(bench))
	check(shown_color(pad) == pad.color, "the pad shouldn't dim, shown %s" % shown_color(pad))
