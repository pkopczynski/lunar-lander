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
	await check_hovers_at_maximum_weight()


func test_crosses_the_border_at_maximum_weight() -> void:
	await choose_ship()
	await check_crosses_the_border_at_maximum_weight()


func test_measurements_match_the_sparrows_table() -> void:
	await choose_ship()
	check_near(await measured_turn_rate(), 3.0, 0.1, "turn rate")
	check_near(await full_tank_thrust_time(), SPARROW_FULL_TANK_THRUST_TIME, 0.2, "full-tank thrust time")


func test_climb_off_the_pad() -> void:
	await choose_ship()
	check_near(await climb_off_pad(), SPARROW_CLIMB_OFF_PAD, 1.0, "climb off the pad in 1 s")
