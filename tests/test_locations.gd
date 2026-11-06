extends "res://tests/scene_test.gd"
# The location table and the current location: the pad, landing judgement and the debug
# pad shortcut all follow the current location's pad.


func test_a_run_starts_at_the_valley_with_the_pad_in_the_middle_of_the_world() -> void:
	await choose_ship()
	check(Location.ALL[0] == Location.VALLEY, "the Valley should come first in the location table")
	check(world().location == Location.VALLEY, "a run should start at the Valley")
	check(Location.VALLEY.name == "VALLEY", "the Valley's name should be VALLEY, got %s" % Location.VALLEY.name)
	check(Location.VALLEY.terrain.is_empty(), "the Valley should have no extra terrain")
	check_near(pad_x(), 1000.0, 0.01, "the Valley's pad centre")
	check_near(pad_visual_center_x(), 1000.0, 0.01, "the drawn pad's centre")


# A location with its pad left of the Valley's.
func elsewhere() -> Location:
	var location := Location.new()
	location.name = "ELSEWHERE"
	location.pad_center_x = 600.0
	return location


func test_the_pad_and_the_debug_pad_shortcut_follow_the_current_location() -> void:
	await choose_ship()
	var location := elsewhere()
	clock().move_to(location)
	check_near(pad_visual_center_x(), 600.0, 0.01, "the drawn pad should move to the location's pad")
	place(Vector2(1400, 100))
	await press(&"restart")
	await frames(2)
	check(lander().state == Lander.State.LANDED, "R on the Surface should land the ship, says %s" % message())
	check_near(lander().position.x, 600.0, 0.5, "x at the current location's pad centre")


func test_landing_is_judged_against_the_current_locations_pad() -> void:
	await choose_ship()
	var location := elsewhere()
	clock().move_to(location)
	place(Vector2(600, 580), Vector2(0, 20))
	await seconds(1.0)
	check(message().begins_with("Landed"), "landing on the current location's pad should land, got %s" % message())
	place(Vector2(1000, 580), Vector2(0, 20))
	await seconds(1.0)
	check(message().begins_with("Crashed"), "touching down where the Valley's pad was should crash, got %s" % message())


# A rooftop pad: the landing surface is a narrow roof raised above a street that spans the
# world, and the location reaches down below the Valley's ground.
func rooftop() -> Location:
	var location := Location.new()
	location.name = "ROOFTOP"
	location.pad_center_x = 1400.0
	location.ground_y = 400.0
	location.ground_width = 160.0
	location.lowest_y = 900.0
	location.terrain = [PackedVector2Array([
		Vector2(-World.SIDE_OVERHANG, 860), Vector2(World.WORLD_WIDTH + World.SIDE_OVERHANG, 860),
		Vector2(World.WORLD_WIDTH + World.SIDE_OVERHANG, 900), Vector2(-World.SIDE_OVERHANG, 900),
	])]
	return location


func test_a_narrow_landing_surface_lands_on_its_roof_and_crashes_beside_it() -> void:
	await choose_ship()
	clock().move_to(rooftop())
	place(Vector2(1400, 372), Vector2(0, 20))
	await seconds(1.0)
	check(message().begins_with("Landed"), "touching down on the roof's pad should land, got %s" % message())
	var drawn_left := INF
	var drawn_right := -INF
	for point: Vector2 in ground().polygon:
		drawn_left = minf(drawn_left, ground().to_global(point).x)
		drawn_right = maxf(drawn_right, ground().to_global(point).x)
	check_near(drawn_left, 1320.0, 0.01, "the drawn roof's left edge")
	check_near(drawn_right, 1480.0, 0.01, "the drawn roof's right edge")
	# Beside the roof, nothing at its height: the ship falls past it onto the street below.
	place(Vector2(1100, 372), Vector2(0, 20))
	await seconds(0.5)
	check(lander().state == Lander.State.FLYING, "beside the roof the ship should fall past its height, says %s" % message())
	for i in roundi(6.0 * PHYSICS_FPS):
		if lander().state != Lander.State.FLYING:
			break
		await frames(1)
	check(message().begins_with("Crashed"), "touching down on the street beside the roof should crash, got %s" % message())


# The visible area of the world, as the camera shows it.
func view() -> Rect2:
	return main().get_viewport().get_canvas_transform().affine_inverse() * main().get_viewport_rect()


func test_the_cameras_bottom_limit_follows_the_locations_lowest_point() -> void:
	await choose_ship()
	place(Vector2(600, 560))
	await frames(2)
	check_near(view().end.y, World.GROUND_BOTTOM_Y, 1.0, "at the Valley the view should stop at the ground's bottom")
	clock().move_to(rooftop())
	place(Vector2(600, 830))
	await frames(2)
	check_near(view().end.y, 900.0, 1.0, "the view should reach down to the location's lowest point")
