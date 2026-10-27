extends "res://tests/scene_test.gd"


func test_run_starts_docked_in_the_parking_spot() -> void:
	var ship := lander()
	await frames(2)
	check(ship.docked, "a fresh run should start Docked")
	check(not ship.landed, "a fresh run should not start Landed")
	check(ship.is_inside_spot(), "the whole hull should be inside the parking spot")
	check_near(ship.position.x, station().parking_spot.get_center().x, 0.5, "x at the parking spot centre")
	check_near(ship.rotation, 0.0, 0.0001, "rotation (facing up)")
	check(ship.velocity == Vector2.ZERO, "velocity should be zero, got %s" % ship.velocity)
	check_near(ship.tank_level(), 1.0, 0.0001, "tank level")
	check(ship.in_deep_space, "the station is in deep space")
