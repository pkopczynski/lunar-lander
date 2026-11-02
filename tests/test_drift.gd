extends "res://tests/scene_test.gd"
# Location drift: after 48 in-game hours above the Border the location moves on to the next one.


func terrain_count() -> int:
	return main().get_node("Terrain").get_children().filter(func(child: Node) -> bool: return child is Polygon2D).size()


func test_48_hours_docked_at_the_station_moves_the_location_on_with_the_terrain_and_hud_name() -> void:
	await choose_ship()
	# 10 in-game minutes short of 48 h: 5 real seconds.
	clock().drift = PlanetClock.DRIFT_MINUTES - 10.0
	await seconds(4.0)
	check(world().location == Location.VALLEY, "8 in-game minutes in, 2 short of 48 h, it should still be the Valley")
	await seconds(2.0)
	check(world().location == Location.MINE, "past 48 h above the Border it should be the Mine")
	check(hud().clock_text().begins_with("MINE  "), "the HUD should read MINE, got '%s'" % hud().clock_text())
	check_near(pad_visual_center_x(), Location.MINE.pad_center_x, 0.01, "the drawn pad should be at the Mine's pad")
	check(terrain_count() == Location.MINE.terrain.size(), "the Mine's benches should be built")


# High in deep space, far enough above the Border that the surface is out of view.
const HIGH_IN_DEEP_SPACE := Vector2(World.WORLD_WIDTH / 2.0, World.BORDER_Y - 1500.0)


func test_going_below_the_border_starts_the_count_over() -> void:
	await choose_ship()
	place(HIGH_IN_DEEP_SPACE)
	await seconds(1.0)
	# 4 in-game minutes short of 48 h: 2 real seconds.
	clock().drift = PlanetClock.DRIFT_MINUTES - 4.0
	place(Vector2(World.WORLD_WIDTH / 2.0, World.BORDER_Y + 300.0))
	await frames(2)
	place(HIGH_IN_DEEP_SPACE)
	await seconds(4.0)
	check(world().location == Location.VALLEY, "a dip below the Border should start the count over, so it should still be the Valley")


func test_time_on_the_surface_never_counts() -> void:
	await choose_ship()
	lander().reset_to_pad()
	await seconds(1.0)
	clock().drift = PlanetClock.DRIFT_MINUTES - 10.0
	await seconds(4.0)
	place(HIGH_IN_DEEP_SPACE)
	await seconds(2.5)
	check(world().location == Location.VALLEY, "8 in-game minutes on the pad shouldn't count, so 5 more above the Border shouldn't move the location")


func test_the_change_waits_while_the_surface_is_on_screen() -> void:
	await choose_ship()
	place(Vector2(World.WORLD_WIDTH / 2.0, World.BORDER_Y - 100.0))
	await seconds(1.0)
	clock().drift = PlanetClock.DRIFT_MINUTES
	await seconds(2.0)
	check(world().location == Location.VALLEY, "just above the Border the surface is on screen, so the change should wait")
	place(HIGH_IN_DEEP_SPACE)
	await seconds(2.0)
	check(world().location == Location.MINE, "once the surface is out of view the change should happen")
	check(hud().clock_text().begins_with("MINE  "), "the HUD should read MINE, got '%s'" % hud().clock_text())


func test_the_count_doesnt_run_while_the_office_shows() -> void:
	# 1 in-game minute short of 48 h: half a real second.
	clock().drift = PlanetClock.DRIFT_MINUTES - 1.0
	await seconds(2.0)
	check(world().location == Location.VALLEY, "the count shouldn't run behind the Office")
	await choose_ship()
	await seconds(1.0)
	check(world().location == Location.MINE, "once the Office closes the count should run on and move the location")


# The minutes since midnight the HUD clock shows.
func shown_minutes() -> int:
	var hhmm: String = hud().clock_text().get_slice("  ", 1)
	return hhmm.get_slice(":", 0).to_int() * 60 + hhmm.get_slice(":", 1).to_int()


func test_the_local_time_carries_on_at_a_location_change() -> void:
	await choose_ship()
	clock().minutes = 600.5
	clock().drift = PlanetClock.DRIFT_MINUTES - 1.0
	var readings := PackedInt32Array()
	for i in roundi(PHYSICS_FPS):
		readings.append(shown_minutes())
		await frames(1)
	check(world().location == Location.MINE, "the location should have moved on")
	check(hud().clock_text().begins_with("MINE  "), "the HUD should read MINE, got '%s'" % hud().clock_text())
	var steepest := 0
	for i in range(1, readings.size()):
		steepest = maxi(steepest, readings[i] - readings[i - 1])
	check(steepest <= 1, "the HUD's local time shouldn't jump at the change, largest step %d minutes" % steepest)
	check(hud().clock_text().ends_with("10:02"),
		"a real second from 10:00 should still read 10:02 across the change, got '%s'" % hud().clock_text())


func test_the_location_drifts_during_a_delivery_and_landing_on_the_new_pad_delivers() -> void:
	await start_loading([known_offer(1, 0.0)])
	await seconds(economy().loading_left + 0.1)
	check(economy().phase == Economy.Phase.DELIVERING, "loading should finish into the delivery")
	clock().drift = PlanetClock.DRIFT_MINUTES
	await frames(2)
	check(world().location == Location.MINE, "the location should drift during a delivery too")
	place(Vector2(Location.MINE.pad_center_x, World.GROUND_BOTTOM_Y - 400.0))
	await press(&"restart")
	check(lander().state == Lander.State.LANDED, "R on the surface should land the ship on the Mine's pad")
	check_near(lander().position.x, Location.MINE.pad_center_x, 0.01, "the ship should be on the Mine's pad")
	check(economy().phase == Economy.Phase.UNLOADING, "landing on the new location's pad should deliver")


func test_the_count_starts_over_after_each_change() -> void:
	await choose_ship()
	clock().drift = PlanetClock.DRIFT_MINUTES
	await frames(2)
	check(world().location == Location.MINE, "48 h should move the location to the Mine")
	# 48 in-game hours are 24 real minutes; stop 2 s short of them.
	await seconds(PlanetClock.DRIFT_MINUTES / PlanetClock.MINUTES_PER_SECOND - 2.0)
	check(world().location == Location.MINE, "the count should have started over at the change, so it should still be the Mine")
	await seconds(3.0)
	check(world().location == Location.VALLEY, "another 48 h above the Border should move it on, wrapping to the Valley")
