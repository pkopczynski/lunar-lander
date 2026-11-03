extends "res://tests/scene_test.gd"


func test_lands_on_the_pad() -> void:
	await choose_ship()
	var ship := lander()
	place(Vector2(pad_x(), 580), Vector2(0, 20))
	await seconds(4.0)
	check(ship.state == Lander.State.LANDED, "Sparrow should be landed")
	check(message().begins_with("Landed!"), "message should say Landed!, got %s" % message())


func test_starts_as_a_sparrow_with_a_full_tank() -> void:
	await choose_ship()
	var ship := lander()
	check(ship.ship_type == ShipType.SPARROW, "ship type should be the Sparrow, got %s" % ship.ship_type.name)
	check_near(ship.fuel, 5000.0, 0.01, "fuel")
	check_near(ship.total_mass(), 15000.0, 0.01, "total mass")
	check_near(ship.tank_level(), 1.0, 0.0001, "tank level")


func test_plus_and_minus_keys_no_longer_change_the_ship() -> void:
	await choose_ship()
	var ship := lander()
	for key: Key in [KEY_EQUAL, KEY_MINUS, KEY_KP_ADD, KEY_KP_SUBTRACT]:
		await press_key(key)
	check_near(ship.dry_mass, ShipType.SPARROW.default_dry_mass, 0.01, "dry mass after + and -")
	check_near(ship.total_mass(), 15000.0, 0.01, "total mass after + and -")
	for action: StringName in [&"weight_up", &"weight_down"]:
		check(not InputMap.has_action(action), "the %s action should be gone" % action)


func press_key(key: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = key
		event.pressed = pressed
		Input.parse_input_event(event)
		await frames(1)


func test_docks_in_the_parking_spot_and_refuels() -> void:
	await choose_ship()
	var ship := lander()
	place(station().parking_spot.get_center())
	check(ship.state != Lander.State.DOCKED, "should start the test in free flight")
	await seconds(0.5)
	check(ship.state == Lander.State.DOCKED, "Sparrow should be docked")
	check(message() == "Docked!", "message should say Docked!, got %s" % message())
	ship.fuel = 1000.0
	# Decline the Ship swap.
	await press(&"ui_accept")
	await seconds(3.0)
	check(ship.fuel > 1000.0, "should refuel after the delay, fuel is %s" % ship.fuel)
	check(message().contains("Refueling"), "message should mention refuelling, got %s" % message())


# Sparrow: 22 000 kg Maximum weight − 10 000 kg dry mass − 9 000 kg Load leaves room for 3 000 kg of fuel.
const LOAD_FOR_TESTS := 9000.0
const FUEL_CAP_WITH_LOAD := 3000.0


func test_a_load_stops_refuelling_at_the_station_short_of_a_full_tank() -> void:
	await choose_ship()
	var ship := lander()
	await dock_in_spot()
	ship.load_mass = LOAD_FOR_TESTS
	ship.fuel = 1000.0
	# Decline the Ship swap.
	await press(&"ui_accept")
	await seconds(10.0)
	check_near(ship.fuel_cap(), FUEL_CAP_WITH_LOAD, 0.01, "fuel cap with a Load")
	check_near(ship.fuel, FUEL_CAP_WITH_LOAD, 0.01, "fuel after refuelling with a Load")
	check(message() == "Docked!", "refuelling should be over, got %s" % message())


func test_a_load_stops_refuelling_on_the_pad_short_of_a_full_tank() -> void:
	await choose_ship()
	var ship := lander()
	ship.load_mass = LOAD_FOR_TESTS
	ship.fuel = 1000.0
	ship.reset_to_pad()
	await seconds(10.0)
	check_near(ship.fuel, FUEL_CAP_WITH_LOAD, 0.01, "fuel after refuelling on the pad with a Load")
	check(message() == "Landed!", "refuelling should be over, got %s" % message())


func test_without_a_load_the_fuel_cap_is_the_tank() -> void:
	await choose_ship()
	check_near(lander().fuel_cap(), ShipType.SPARROW.tank, 0.01, "fuel cap without a Load")


func test_hovers_at_maximum_weight() -> void:
	await choose_ship()
	await raise_to_maximum_weight()
	check_near(lander().total_mass(), 22000.0, 0.01, "total mass at Maximum weight")
	check(await climbs_under_full_thrust(), "the Sparrow should climb at Maximum weight")


func test_crosses_the_border_at_maximum_weight() -> void:
	await choose_ship()
	await raise_to_maximum_weight()
	var top_speed: float = await top_climb_speed_to_the_border()
	check(lander().in_deep_space, "should have crossed into deep space")
	check(top_speed >= Lander.CROSSING_SPEED, "should reach the crossing speed, top speed %s" % top_speed)


# Sparrow with a full Tank: 10 000 kg dry mass + 5 000 kg fuel = the 15 000 kg reference
# mass. A 6 000 kg Load still leaves room for a full Tank, and burn counts it at half:
# (15 000 + 3 000) / 15 000 × 250 kg/s = 300 kg/s, against 350 kg/s at full weight.
const BURN_TEST_LOAD := 6000.0


func test_a_load_burns_fuel_at_half_its_weight() -> void:
	await choose_ship()
	var ship := lander()
	var unloaded := await fuel_burned_in_a_second_of_thrust()
	ship.fuel = ship.ship_type.tank
	ship.load_mass = BURN_TEST_LOAD
	var loaded := await fuel_burned_in_a_second_of_thrust()
	check_near(unloaded, 250.0, 10.0, "fuel burned in 1 s of thrust without a Load")
	check_near(loaded, 300.0, 10.0, "fuel burned in 1 s of thrust with a 6 000 kg Load")
	check(loaded < 350.0, "a Load should burn less than full-weight scaling would, burned %s" % loaded)
	check(loaded > unloaded, "a Load should burn more than no Load, burned %s against %s" % [loaded, unloaded])


func test_a_load_still_weighs_fully_on_thrust_and_gravity() -> void:
	await choose_ship()
	var ship := lander()
	ship.load_mass = BURN_TEST_LOAD
	# Total 21 000 kg, factor 1.4: thrust 150 / 1.4 ≈ 107 px/s², gravity 60 × 1.2 = 72 px/s².
	var spot := Vector2(World.WORLD_WIDTH / 4.0, World.BORDER_Y - 600.0)
	place(spot)
	hold(&"ui_up")
	await seconds(1.0)
	release(&"ui_up")
	check_near(-ship.velocity.y, 107.1, 2.0, "speed after 1 s of thrust in deep space with a Load")
	ship.fuel = ship.ship_type.tank
	place(Vector2(pad_x(), 400.0))
	await seconds(1.0)
	check_near(ship.velocity.y, 72.0, 2.5, "falling speed after 1 s at pad altitude with a Load")


# Fuel burned in 1 s of thrust, with the ship held still in deep space (no gravity, no braking
# burn). A little under the nominal rate: the burn eases as fuel drops.
func fuel_burned_in_a_second_of_thrust() -> float:
	var ship := lander()
	var spot := Vector2(World.WORLD_WIDTH / 4.0, World.BORDER_Y - 600.0)
	place(spot)
	var before := ship.fuel
	hold(&"ui_up")
	for i in roundi(PHYSICS_FPS):
		await frames(1)
		ship.position = spot
		ship.velocity = Vector2.ZERO
	release(&"ui_up")
	return before - ship.fuel
