extends "res://tests/scene_test.gd"


func test_lands_on_the_pad() -> void:
	var ship := lander()
	ship.landed = false
	ship.position = Vector2(Lander.PAD_CENTER_X, 580)
	ship.velocity = Vector2(0, 20)
	await seconds(4.0)
	check(ship.landed, "Sparrow should be landed")
	check(message().begins_with("Landed!"), "message should say Landed!, got %s" % message())


func test_starts_as_a_sparrow_with_a_full_tank() -> void:
	var ship := lander()
	check(ship.ship_type.name == "Sparrow", "ship type should be the Sparrow, got %s" % ship.ship_type.name)
	check_near(ship.fuel, 5000.0, 0.01, "fuel")
	check_near(ship.total_mass(), 15000.0, 0.01, "total mass")
	check_near(ship.tank_level(), 1.0, 0.0001, "tank level")


func test_weight_keys_stay_within_the_sparrow_range() -> void:
	var ship := lander()
	for i in 20:
		await press(&"weight_up")
	check_near(ship.total_mass() - ship.fuel, 17000.0, 0.01, "dry mass after many weight_up")
	for i in 30:
		await press(&"weight_down")
	check_near(ship.total_mass() - ship.fuel, 5000.0, 0.01, "dry mass after many weight_down")
