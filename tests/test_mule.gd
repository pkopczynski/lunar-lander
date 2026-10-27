extends "res://tests/scene_test.gd"

const MULE_HULL := [Vector2(-21, -34), Vector2(21, -34), Vector2(21, 34), Vector2(-21, 34)]


func test_the_mule_offer_is_next_to_the_sparrow() -> void:
	await press(&"ui_right")
	check(office().selected_offer().name == "Mule", "Right from the Sparrow should show the Mule, got %s" % office().selected_offer().name)
	var lines := office().offer_lines()
	for expected: String in ["MULE", "LONG, HEAVY AND SLOW. HAULS THE BIG LOADS.",
			"TANK 12 000 KG", "DRY MASS 20 000 KG", "MAX WEIGHT 35 000 KG",
			"THRUST ■■□□□", "HANDLING ■■□□□", "< 2/%d >" % ShipType.ALL.size()]:
		check(expected in lines, "the Mule Offer should show %s, shows %s" % [expected, lines])
	check(office().offer_picture() == PackedVector2Array(MULE_HULL), "the Offer picture should be the Mule's 42×68 hull")
	await press(&"ui_left")
	check(office().selected_offer().name == "Sparrow", "Left from the Mule should go back to the Sparrow")


func test_choosing_the_mule_docks_it_in_the_parking_spot_with_a_full_tank() -> void:
	await choose_ship("Mule")
	var ship := lander()
	check(ship.ship_type.name == "Mule", "the ship should be a Mule, got %s" % ship.ship_type.name)
	check(ship.docked, "the Mule should start Docked")
	check(ship.is_inside_spot(), "the whole Mule hull should be inside the parking spot")
	check_near(ship.fuel, 12000.0, 0.01, "fuel")
	check_near(ship.total_mass(), 32000.0, 0.01, "total mass")
	check(ship.hull.polygon == PackedVector2Array(MULE_HULL), "the collision shape should match the Mule's hull")


func test_weight_keys_stay_within_the_mule_range() -> void:
	await choose_ship("Mule")
	var ship := lander()
	for i in 30:
		await press(&"weight_up")
	check_near(ship.total_mass() - ship.fuel, 35000.0, 0.01, "dry mass after many weight_up")
	for i in 40:
		await press(&"weight_down")
	check_near(ship.total_mass() - ship.fuel, 5000.0, 0.01, "dry mass after many weight_down")


func test_hovers_at_maximum_weight() -> void:
	await choose_ship("Mule")
	await check_hovers_at_maximum_weight()


func test_crosses_the_border_at_maximum_weight() -> void:
	await choose_ship("Mule")
	await check_crosses_the_border_at_maximum_weight()


func test_turn_rate() -> void:
	await choose_ship("Mule")
	check_near(await measured_turn_rate(), 1.5, 0.1, "turn rate")


func test_full_tank_thrust_time_is_28_to_the_sparrows_20() -> void:
	await choose_ship("Mule")
	var expected := SPARROW_FULL_TANK_THRUST_TIME * 28.0 / 20.0
	check_near(await full_tank_thrust_time(), expected, expected * 0.05, "full-tank thrust time")


# The spec asks for ~60% of the Sparrow's climb, but under the shared mass rules
# hovering at Maximum weight (35 000 kg dry + 12 000 kg fuel) needs thrust >= ~389,
# which already climbs at ~98% of the Sparrow at default dry mass. Hovering is a
# must, so the Mule is tuned just above that and its climb is held there.
func test_climbs_off_the_pad_no_faster_than_the_sparrow_needs_to_hover_at_maximum_weight() -> void:
	await choose_ship("Mule")
	var ratio := await climb_off_pad() / SPARROW_CLIMB_OFF_PAD
	check_near(ratio, 1.04, 0.05, "climb off the pad relative to the Sparrow")
