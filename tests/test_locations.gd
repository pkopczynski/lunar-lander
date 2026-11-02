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
