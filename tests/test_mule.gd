extends "res://tests/scene_test.gd"

# Tuning targets from the ship type table in issue #1, relative to the Sparrow.
# ~60% of the Sparrow's climb at default dry mass with a full tank. The table's
# 35 000 kg Maximum weight can't hover at that thrust, so Maximum weight is the
# highest round value at which the Mule still hovers and reaches the crossing speed.
const CLIMB_RATIO := 0.6
const MAXIMUM_WEIGHT := 29000.0
const TURN_RATE := 1.5
# ~28 s against the Sparrow's ~20 s.
const THRUST_TIME_RATIO := 28.0 / 20.0
const MULE_HULL := [Vector2(-21, -34), Vector2(21, -34), Vector2(21, 34), Vector2(-21, 34)]


func test_mule_offer_is_reachable_with_left_and_right() -> void:
	await browse_to(&"ui_right")
	check(office().selected_offer().name == "Mule", "Right should reach the Mule Offer")
	await choose_ship()
	await restart()
	await browse_to(&"ui_left")
	check(office().selected_offer().name == "Mule", "Left should reach the Mule Offer")


func test_mule_offer_shows_its_numbers_ratings_and_wireframe() -> void:
	await browse_to(&"ui_right")
	var lines := office().offer_lines()
	for expected: String in ["MULE", "LONG, HEAVY AND SLOW. HAULS THE BIG LOADS.",
			"TANK 12 000 KG", "DRY MASS 20 000 KG", "MAX WEIGHT 29 000 KG",
			"THRUST ■■□□□", "HANDLING ■■□□□"]:
		check(expected in lines, "the Mule Offer should show %s, shows %s" % [expected, lines])
	check(office().offer_picture() == PackedVector2Array(MULE_HULL), "the Offer picture should be the Mule's 42×68 hull")


func test_choosing_the_mule_docks_it_with_a_full_tank_inside_the_spot() -> void:
	await choose_ship("Mule")
	var ship := lander()
	check(ship.ship_type.name == "Mule", "the ship should be a Mule, got %s" % ship.ship_type.name)
	check(ship.docked, "the Mule should be Docked")
	check(ship.is_inside_spot(), "the whole Mule hull should be inside the parking spot")
	check_near(ship.fuel, 12000.0, 0.01, "fuel")
	check_near(ship.total_mass(), 32000.0, 0.01, "total mass")
	check(ship.hull.polygon == PackedVector2Array(MULE_HULL), "the collision shape should match the Mule's hull")


func test_weight_keys_stay_within_the_mule_range() -> void:
	await choose_ship("Mule")
	for i in 30:
		await press(&"weight_up")
	check_near(dry_mass(), MAXIMUM_WEIGHT, 0.01, "dry mass after many weight_up")
	check(dry_mass() > ShipType.HALO.maximum_weight, "the Mule should carry more than the Halo")
	for i in 40:
		await press(&"weight_down")
	check_near(dry_mass(), 5000.0, 0.01, "dry mass after many weight_down")


func test_mule_lands_on_the_pad_with_the_sparrows_limits() -> void:
	await choose_ship("Mule")
	var ship := lander()
	# Hull bottom ~6 px above the pad.
	place(Vector2(Lander.PAD_CENTER_X, 568), Vector2(0, 20))
	await seconds(4.0)
	check(ship.landed, "a gentle Mule should land on the pad, says %s" % message())
	await restart()
	await choose_ship("Mule")
	place(Vector2(Lander.PAD_CENTER_X, 500), Vector2(0, Lander.MAX_LANDING_VERTICAL_SPEED + 30.0))
	await seconds(2.0)
	check(message().begins_with("Crashed"), "a hard Mule landing should crash, got %s" % message())


func test_mule_docks_in_the_parking_spot() -> void:
	await choose_ship("Mule")
	var ship := lander()
	place(station().parking_spot.get_center())
	await seconds(0.5)
	check(ship.docked, "the Mule should dock in the parking spot")


func test_mule_hovers_at_maximum_weight() -> void:
	await choose_ship("Mule")
	await raise_to_maximum_weight()
	check_near(dry_mass(), MAXIMUM_WEIGHT, 0.01, "dry mass at Maximum weight")
	check(await climbs_under_full_thrust(), "the Mule should climb at Maximum weight")


func test_mule_crosses_the_border_at_maximum_weight() -> void:
	await choose_ship("Mule")
	await raise_to_maximum_weight()
	var top_speed: float = await top_climb_speed_to_the_border()
	check(lander().in_deep_space, "the Mule should cross into deep space at Maximum weight")
	check(top_speed >= Lander.CROSSING_SPEED, "the Mule should reach the crossing speed, top speed %s" % top_speed)


func test_mule_climbs_off_the_pad_at_about_60_percent_of_the_sparrow() -> void:
	await choose_ship("Sparrow")
	var sparrow: float = await climb_off_the_pad()
	await restart()
	await choose_ship("Mule")
	var mule: float = await climb_off_the_pad()
	check_near(mule / sparrow, CLIMB_RATIO, 0.05, "Mule climb / Sparrow climb")


func test_mule_turns_at_about_1_5_rad_per_s() -> void:
	await choose_ship("Mule")
	var rate: float = await turn_rate()
	check_near(rate, TURN_RATE, 0.05, "Mule turn rate")


func test_mule_thrusts_about_28_s_on_a_full_tank() -> void:
	await choose_ship("Sparrow")
	var sparrow: float = await full_tank_thrust_time()
	await restart()
	await choose_ship("Mule")
	var mule: float = await full_tank_thrust_time()
	check_near(mule / sparrow, THRUST_TIME_RATIO, 0.05, "Mule / Sparrow full-tank thrust time (%.1f s / %.1f s)" % [mule, sparrow])


func browse_to(action: StringName) -> void:
	for i in ShipType.ALL.size():
		if office().selected_offer().name == "Mule":
			return
		await press(action)
