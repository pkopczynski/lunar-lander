extends "res://tests/scene_test.gd"


func test_lands_on_the_pad() -> void:
	await choose_ship()
	var ship := lander()
	place(Vector2(Lander.PAD_CENTER_X, 580), Vector2(0, 20))
	await seconds(4.0)
	check(ship.landed, "Sparrow should be landed")
	check(message().begins_with("Landed!"), "message should say Landed!, got %s" % message())


func test_starts_as_a_sparrow_with_a_full_tank() -> void:
	await choose_ship()
	var ship := lander()
	check(ship.ship_type.name == "Sparrow", "ship type should be the Sparrow, got %s" % ship.ship_type.name)
	check_near(ship.fuel, 5000.0, 0.01, "fuel")
	check_near(ship.total_mass(), 15000.0, 0.01, "total mass")
	check_near(ship.tank_level(), 1.0, 0.0001, "tank level")


func test_weight_keys_stay_within_the_sparrow_range() -> void:
	await choose_ship()
	var ship := lander()
	for i in 20:
		await press(&"weight_up")
	check_near(ship.total_mass() - ship.fuel, 17000.0, 0.01, "dry mass after many weight_up")
	for i in 30:
		await press(&"weight_down")
	check_near(ship.total_mass() - ship.fuel, 5000.0, 0.01, "dry mass after many weight_down")


func test_docks_in_the_parking_spot_and_refuels() -> void:
	await choose_ship()
	var ship := lander()
	place(station().parking_spot.get_center())
	check(not ship.docked, "should start the test in free flight")
	await seconds(0.5)
	check(ship.docked, "Sparrow should be docked")
	check(message() == "Docked!", "message should say Docked!, got %s" % message())
	ship.fuel = 1000.0
	await seconds(3.0)
	check(ship.fuel > 1000.0, "should refuel after the delay, fuel is %s" % ship.fuel)
	check(message().contains("Refueling"), "message should mention refuelling, got %s" % message())


func test_hovers_at_maximum_weight() -> void:
	await choose_ship()
	var ship := lander()
	await raise_to_maximum_weight()
	place(Vector2(World.WORLD_WIDTH / 2.0, 0))
	hold(&"ui_up")
	await seconds(1.0)
	release(&"ui_up")
	check(ship.velocity.y < 0.0, "should be climbing under full thrust, velocity.y is %s" % ship.velocity.y)
	check(ship.position.y < 0.0, "should have climbed, y is %s" % ship.position.y)


func test_crosses_the_border_at_maximum_weight() -> void:
	await choose_ship()
	var ship := lander()
	await raise_to_maximum_weight()
	place(Vector2(World.WORLD_WIDTH / 2.0, World.BORDER_Y + 600.0))
	var top_climb_speed := 0.0
	hold(&"ui_up")
	for i in roundi(10.0 * PHYSICS_FPS):
		await frames(1)
		top_climb_speed = maxf(top_climb_speed, -ship.velocity.y)
		if ship.in_deep_space:
			break
	release(&"ui_up")
	check(ship.in_deep_space, "should have crossed into deep space")
	check(top_climb_speed >= Lander.CROSSING_SPEED, "should reach the crossing speed, top speed %s" % top_climb_speed)


func raise_to_maximum_weight() -> void:
	for i in 10:
		await press(&"weight_up")
	var ship := lander()
	check_near(ship.total_mass() - ship.fuel, 17000.0, 0.01, "dry mass at Maximum weight")
