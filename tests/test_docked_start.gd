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


func test_up_undocks_and_flies_out_of_the_spot() -> void:
	var ship := lander()
	await frames(2)
	var start := ship.position
	hold(&"ui_up")
	await seconds(0.4)
	release(&"ui_up")
	check(not ship.docked, "Up should undock the ship")
	check(ship.velocity.y < 0.0, "should be climbing after undocking, velocity.y is %s" % ship.velocity.y)
	check(ship.position.y < start.y, "should have moved up, y is %s from %s" % [ship.position.y, start.y])
	check(message() == "", "the Docked! message should be hidden, got %s" % message())
	await seconds(0.3)
	check(not ship.docked, "should not dock again before leaving the spot")
	check(not message().begins_with("Crashed"), "should not crash leaving the spot, got %s" % message())


func test_restart_starts_docked_with_a_newly_picked_spot() -> void:
	var first_spot := station().parking_spot
	var picked_another := false
	# Six arm endings: the odds of never picking another in ten restarts are below 1e-7.
	for i in 10:
		await restart()
		var ship := lander()
		check(ship.docked, "restart %d should start Docked" % i)
		check(ship.is_inside_spot(), "restart %d should start inside the parking spot" % i)
		check_near(ship.tank_level(), 1.0, 0.0001, "tank level after restart %d" % i)
		if station().parking_spot != first_spot:
			picked_another = true
	check(picked_another, "restarts should re-pick the parking spot")


func test_restart_after_a_crash_starts_docked() -> void:
	place(Vector2(Lander.PAD_CENTER_X + 400.0, 560), Vector2(0, 200))
	await seconds(1.0)
	check(message().begins_with("Crashed"), "should have crashed, got %s" % message())
	await restart()
	check(lander().docked, "should start Docked after restarting from a crash")
