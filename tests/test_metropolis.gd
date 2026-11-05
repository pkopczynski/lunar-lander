extends "res://tests/scene_test.gd"
# The Metropolis, a third location: a pad on a rooftop between buildings of several heights.


func test_drift_goes_valley_mine_metropolis_and_back_to_the_valley() -> void:
	await choose_ship()
	var seen := PackedStringArray([world().location.name])
	for i in 3:
		clock().drift = PlanetClock.DRIFT_MINUTES
		await frames(2)
		seen.append(world().location.name)
	check(seen == PackedStringArray(["VALLEY", "MINE", "METROPOLIS", "VALLEY"]),
		"drift should go Valley, Mine, Metropolis and wrap to the Valley, got %s" % seen)
	check(hud().clock_text().begins_with("VALLEY  "), "the HUD should read VALLEY, got '%s'" % hud().clock_text())


func test_touching_down_on_the_rooftop_pad_lands_and_on_the_roof_beside_it_crashes() -> void:
	await choose_ship()
	clock().move_to(Location.METROPOLIS)
	var roof := Location.METROPOLIS.ground_y
	check(roof < World.GROUND_TOP_Y - 60.0, "the pad's roof should be raised well above the Valley's ground, y %s" % roof)
	place(Vector2(pad_x(), roof - 28.0), Vector2(0, 20))
	await seconds(1.0)
	check(message().begins_with("Landed"), "touching down on the rooftop pad should land, got %s" % message())
	check_near(lander().position.x, pad_x(), 1.0, "x on the rooftop pad")
	# The same roof, past the pad's right edge.
	place(Vector2(pad_x() + 110.0, roof - 28.0), Vector2(0, 20))
	await seconds(1.0)
	check(message().begins_with("Crashed"), "touching down on the roof beside the pad should crash, got %s" % message())


# Drops the ship gently from a point and waits for it to touch something, or 6 s.
func drop_from(start: Vector2) -> void:
	place(start, Vector2(0, 20))
	for i in roundi(6.0 * PHYSICS_FPS):
		if lander().state != Lander.State.FLYING:
			break
		await frames(1)


func test_touching_a_tower_the_street_or_the_antenna_crashes() -> void:
	var spots := {
		# Onto the second tower's flat roof, high above the pad's.
		"a tower's roof": Vector2(710, 200),
		# Down the street between that tower and the pad's building.
		"the street": Vector2(960, 700),
		# Onto the antenna's tip, beside the pad.
		"the antenna": Vector2(Location.PAD_BUILDING_LEFT + 5.0, 300),
	}
	for what: String in spots:
		await choose_ship()
		clock().move_to(Location.METROPOLIS)
		await drop_from(spots[what])
		check(message().begins_with("Crashed"), "touching %s should crash, got %s" % [what, message()])
		check(lander().position.y < spots[what].y + 150.0,
			"the ship should crash on %s, not fall far past it, y %s" % [what, lander().position.y])
		await restart()


# Flies straight down from high above the pad, thrusting whenever the ship sinks faster than a
# gentle speed, until it touches down or the time runs out.
func descend_from(start: Vector2) -> void:
	place(start)
	for i in roundi(20.0 * PHYSICS_FPS):
		if lander().state != Lander.State.FLYING:
			break
		if lander().velocity.y > 30.0:
			hold(&"ui_up")
		else:
			release(&"ui_up")
		await frames(1)
	release(&"ui_up")
	await seconds(0.5)


func test_every_ship_type_can_fly_down_past_the_city_onto_the_rooftop_pad() -> void:
	for type: ShipType in ShipType.ALL:
		await choose_ship(type)
		clock().move_to(Location.METROPOLIS)
		raise_to_maximum_weight()
		await descend_from(Vector2(pad_x(), 100.0))
		check(lander().state == Lander.State.LANDED,
			"the %s should land on the rooftop pad at its Maximum weight, says %s" % [type.name, message()])
		check_near(lander().position.x, pad_x(), 1.0, "the %s's x after flying down" % type.name)
		await restart()


# The visible area of the world, as the camera shows it.
func view() -> Rect2:
	return main().get_viewport().get_canvas_transform().affine_inverse() * main().get_viewport_rect()


func test_the_camera_follows_down_to_the_street() -> void:
	await choose_ship()
	clock().move_to(Location.METROPOLIS)
	place(Vector2(960, 760))
	await frames(2)
	check(view().end.y > Location.STREET_Y, "the view should reach down to the street, ends at %s" % view().end.y)
	check_near(view().end.y, Location.METROPOLIS.lowest_y, 1.0, "the view should stop at the street's bottom")
