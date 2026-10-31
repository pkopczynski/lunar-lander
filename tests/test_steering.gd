extends "res://tests/scene_test.gd"
# Steering at soft walls and after border crossings: it damps speed and pushes
# the ship back, but leaves the nose where the player aimed it.

const AIMED := 1.0
# Radians the Sparrow (3.0 rad/s) turns in 0.25 s.
const SPARROW_TURN := 0.75


# Drifts the ship into the left soft wall in deep space, nose turned to AIMED.
func drift_into_soft_wall() -> void:
	place(Vector2(100.0, World.BORDER_Y - 600.0), Vector2(-200, 0))
	lander().rotation = AIMED


# Sends the ship across the border, up or down, nose turned to AIMED.
func cross_border(upward: bool) -> void:
	var side := 1.0 if upward else -1.0
	place(Vector2(World.WORLD_WIDTH / 2.0, World.BORDER_Y + side * 30.0), Vector2(0, -side * 300.0))
	lander().rotation = AIMED


func test_soft_wall_pushes_the_ship_back_without_turning_it() -> void:
	await choose_ship()
	var ship := lander()
	drift_into_soft_wall()
	var lowest_x := ship.position.x
	for i in roundi(2.0 * PHYSICS_FPS):
		await frames(1)
		lowest_x = minf(lowest_x, ship.position.x)
	check(lowest_x >= 0.0, "the ship should never pass the edge, reached x %s" % lowest_x)
	check(ship.velocity.x > 0.0, "the soft wall should push the ship back inward, velocity %s" % ship.velocity)
	check_near(ship.rotation, AIMED, 0.0001, "rotation after the soft-wall push")


func test_crossing_up_keeps_the_nose_and_damps_speed() -> void:
	await choose_ship()
	var ship := lander()
	cross_border(true)
	await seconds(0.5)
	check(ship.in_deep_space, "the ship should have crossed into deep space")
	check_near(ship.velocity.length(), Lander.STEER_SPEED, 1.0, "speed after crossing up")
	check_near(ship.rotation, AIMED, 0.0001, "rotation after crossing up")


func test_crossing_down_keeps_the_nose_and_damps_speed() -> void:
	await choose_ship()
	var ship := lander()
	cross_border(false)
	await seconds(0.5)
	check(not ship.in_deep_space, "the ship should have crossed down to the Surface")
	check_near(ship.velocity.length(), Lander.STEER_SPEED, 1.0, "speed after crossing down")
	check_near(ship.rotation, AIMED, 0.0001, "rotation after crossing down")


func test_slow_ship_bounces_off_the_border() -> void:
	await choose_ship()
	var ship := lander()
	place(Vector2(World.WORLD_WIDTH / 2.0, World.BORDER_Y + 20.0), Vector2(0, -60))
	await seconds(2.0)
	check(not ship.in_deep_space and ship.position.y > World.BORDER_Y,
		"a slow ship should bounce back below the border, y is %s" % ship.position.y)


func test_left_and_right_rotate_inside_a_soft_wall() -> void:
	await choose_ship()
	var ship := lander()
	drift_into_soft_wall()
	await frames(1)
	var before := ship.rotation
	hold(&"ui_left")
	await seconds(0.25)
	release(&"ui_left")
	check_near(ship.rotation, before - SPARROW_TURN, 0.1, "rotation after Left in a soft wall")
	before = ship.rotation
	hold(&"ui_right")
	await seconds(0.25)
	release(&"ui_right")
	check_near(ship.rotation, before + SPARROW_TURN, 0.1, "rotation after Right in a soft wall")


func test_left_and_right_rotate_right_after_a_crossing() -> void:
	await choose_ship()
	var ship := lander()
	cross_border(true)
	await seconds(0.2)
	check(ship.in_deep_space and ship.position.y > World.BORDER_Y - Lander.STEER_DISTANCE,
		"the ship should be just past the border, y is %s" % ship.position.y)
	var before := ship.rotation
	hold(&"ui_left")
	await seconds(0.25)
	release(&"ui_left")
	check_near(ship.rotation, before - SPARROW_TURN, 0.1, "rotation after Left past the border")
