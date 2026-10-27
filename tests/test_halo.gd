extends "res://tests/scene_test.gd"

# Tuning targets from the ship type table in issue #1, relative to the Sparrow.
const CLIMB_RATIO := 0.8
const TURN_RATE := 2.2
# ~24 s against the Sparrow's ~20 s.
const THRUST_TIME_RATIO := 24.0 / 20.0


func test_halo_offer_is_reachable_with_left_and_right() -> void:
	await browse_to(ShipType.HALO, &"ui_right")
	check(office().selected_offer() == ShipType.HALO, "Right should reach the Halo Offer")
	await restart_office()
	await browse_to(ShipType.HALO, &"ui_left")
	check(office().selected_offer() == ShipType.HALO, "Left should reach the Halo Offer")


func test_halo_offer_shows_its_numbers_ratings_and_wireframe() -> void:
	await browse_to(ShipType.HALO, &"ui_right")
	var lines := office().offer_lines()
	for expected: String in ["HALO", "TANK 8 000 KG", "DRY MASS 14 000 KG", "MAX WEIGHT 24 000 KG",
			"THRUST ■■■■□", "HANDLING ■■■■□"]:
		check(expected in lines, "the Halo Offer should show %s, shows %s" % [expected, lines])
	check(office().offer_picture() == office().selected_offer().hull, "the Offer picture should be the Halo's hull")


func test_choosing_the_halo_docks_it_with_a_full_tank_inside_the_spot() -> void:
	await choose_ship(ShipType.HALO)
	var ship := lander()
	check(ship.ship_type == ShipType.HALO, "the ship should be a Halo, got %s" % ship.ship_type.name)
	check(ship.docked, "the Halo should be Docked")
	check(ship.is_inside_spot(), "the whole Halo hull should be inside the parking spot")
	check_near(ship.fuel, 8000.0, 0.01, "fuel")
	check_near(ship.total_mass(), 22000.0, 0.01, "total mass")


func test_halo_is_a_ring_about_40_px_across_open_at_the_nose() -> void:
	await choose_ship(ShipType.HALO)
	var ship := lander()
	place(Vector2(World.WORLD_WIDTH / 4.0, World.BORDER_Y - 600.0))
	await frames(2)
	var size := Office.outline_bounds(ship.ship_type.hull).size
	check_near(size.x, 40.0, 2.0, "hull width")
	check(size.y >= 36.0 and size.y <= 42.0, "the hull should be about 40 px tall, is %s" % size.y)
	for point in [Vector2(14, 0), Vector2(-14, 0), Vector2(0, 14), Vector2(10, -10), Vector2(-10, -10)]:
		check(hits_ship(point), "the ring should be solid at %s" % point)
	# The ~16 px hole, and the gap from the nose into it.
	for point in [Vector2.ZERO, Vector2(5, 0), Vector2(-5, 0), Vector2(0, 5), Vector2(0, -5),
			Vector2(0, -10), Vector2(0, -14), Vector2(0, -18)]:
		check(not hits_ship(point), "the hole and gap should be open at %s" % point)
	var flame_size := Office.outline_bounds(ship.ship_type.flame).size
	var flame_top := INF
	for point in ship.ship_type.flame:
		flame_top = minf(flame_top, point.y)
	check(flame_top >= 15.0 and flame_size.y > 0.0, "the flame should come from the back of the ring, top at %s" % flame_top)


func test_halo_lands_on_the_pad_with_the_sparrows_limits() -> void:
	await choose_ship(ShipType.HALO)
	var ship := lander()
	# Hull bottom ~8 px above the pad.
	place(Vector2(Lander.PAD_CENTER_X, 580), Vector2(0, 20))
	await seconds(4.0)
	check(ship.landed, "a gentle Halo should land on the pad")
	await restart()
	await choose_ship(ShipType.HALO)
	place(Vector2(Lander.PAD_CENTER_X, 520), Vector2(0, Lander.MAX_LANDING_VERTICAL_SPEED + 30.0))
	await seconds(2.0)
	check(message().begins_with("Crashed"), "a hard Halo landing should crash, got %s" % message())


func test_halo_docks_in_the_parking_spot() -> void:
	await choose_ship(ShipType.HALO)
	var ship := lander()
	place(station().parking_spot.get_center())
	await seconds(0.5)
	check(ship.docked, "the Halo should dock in the parking spot")


func test_halo_hovers_at_maximum_weight() -> void:
	await choose_ship(ShipType.HALO)
	await raise_to_maximum_weight()
	check_near(dry_mass(), 24000.0, 0.01, "dry mass at Maximum weight")
	check(await climbs_under_full_thrust(), "the Halo should climb at Maximum weight")


func test_halo_crosses_the_border_at_maximum_weight() -> void:
	await choose_ship(ShipType.HALO)
	await raise_to_maximum_weight()
	var top_speed: float = await top_climb_speed_to_the_border()
	check(lander().in_deep_space, "the Halo should cross into deep space at Maximum weight")
	check(top_speed >= Lander.CROSSING_SPEED, "the Halo should reach the crossing speed, top speed %s" % top_speed)


func test_halo_climbs_off_the_pad_at_about_80_percent_of_the_sparrow() -> void:
	await choose_ship(ShipType.SPARROW)
	var sparrow: float = await climb_off_the_pad()
	await restart()
	await choose_ship(ShipType.HALO)
	var halo: float = await climb_off_the_pad()
	check_near(halo / sparrow, CLIMB_RATIO, 0.04, "Halo climb / Sparrow climb")


func test_halo_turns_at_about_2_2_rad_per_s() -> void:
	await choose_ship(ShipType.HALO)
	var rate: float = await turn_rate()
	check_near(rate, TURN_RATE, 0.05, "Halo turn rate")


func test_halo_thrusts_about_24_s_on_a_full_tank() -> void:
	await choose_ship(ShipType.SPARROW)
	var sparrow: float = await full_tank_thrust_time()
	await restart()
	await choose_ship(ShipType.HALO)
	var halo: float = await full_tank_thrust_time()
	check_near(halo / sparrow, THRUST_TIME_RATIO, 0.05, "Halo / Sparrow full-tank thrust time (%.1f s / %.1f s)" % [halo, sparrow])


func restart_office() -> void:
	await choose_ship()
	await restart()


func hits_ship(local_point: Vector2) -> bool:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = lander().to_global(local_point)
	for hit in lander().get_world_2d().direct_space_state.intersect_point(query):
		if hit.collider == lander():
			return true
	return false
