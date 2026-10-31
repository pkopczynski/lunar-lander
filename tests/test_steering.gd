extends "res://tests/scene_test.gd"
# Steering at soft walls damps speed and pushes the ship back, leaving the nose where the
# player aimed it. Crossing the border disturbs the ship: a short, random, lasting turn of
# its nose and path while the controls are ignored.

const AIMED := 1.0
# Radians the Sparrow (3.0 rad/s) turns in 0.25 s.
const SPARROW_TURN := 0.75


# Drifts the ship into the left soft wall in deep space, nose turned to AIMED.
func drift_into_soft_wall() -> void:
	place(Vector2(100.0, World.BORDER_Y - 600.0), Vector2(-200, 0))
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


# The largest lasting turn, in radians, for a crossing at this speed.
func max_turn(speed: float) -> float:
	var fast := clampf(inverse_lerp(Lander.CROSSING_SPEED, Lander.DISTURB_FAST_SPEED, speed), 0.0, 1.0)
	return deg_to_rad(lerpf(Lander.DISTURB_SLOW_TURN_DEG, Lander.DISTURB_FAST_TURN_DEG, fast))


# Crosses the border at speed with the given seed, and returns the nose's lasting turn once the
# disturbance is over and the ship has flown on a while.
func crossing_turn(upward: bool, speed: float, seed_value: int) -> float:
	var ship := lander()
	ship.rng.seed = seed_value
	var side := 1.0 if upward else -1.0
	place(Vector2(World.WORLD_WIDTH / 2.0, World.BORDER_Y + side * 10.0), Vector2(0, -side * speed))
	ship.rotation = AIMED
	await seconds(1.2)
	check(ship.in_deep_space == upward, "the ship should have crossed the border")
	return ship.rotation - AIMED


func test_crossing_turns_the_nose_and_the_path_by_a_lasting_random_angle() -> void:
	await choose_ship()
	var ship := lander()
	var directions := {}
	# Deep space has no gravity to bend the path afterwards, so the path's turn shows clean.
	for seed_value in 6:
		var turn := await crossing_turn(true, 300.0, seed_value)
		var largest := max_turn(300.0)
		check(absf(turn) >= largest * Lander.DISTURB_MIN_TURN_SHARE - 0.0001 and absf(turn) <= largest + 0.0001,
			"the turn should be within %s..%s rad, got %s" % [largest * Lander.DISTURB_MIN_TURN_SHARE, largest, turn])
		directions[signf(turn)] = true
		var path_turn := angle_difference(Vector2.UP.angle(), ship.velocity.angle())
		check_near(path_turn, turn, 0.001, "the path should turn with the nose")
		check_near(ship.velocity.length(), Lander.STEER_SPEED, 1.0, "speed after crossing")
		var lasting := ship.rotation
		await seconds(0.5)
		check_near(ship.rotation, lasting, 0.0001, "the turn should last, not ease back")
	check(directions.size() == 2, "turns should go both ways across seeds, went %s" % [directions.keys()])


func test_crossing_down_turns_the_nose_too() -> void:
	await choose_ship()
	var turn := await crossing_turn(false, 300.0, 1)
	var largest := max_turn(300.0)
	check(absf(turn) >= largest * Lander.DISTURB_MIN_TURN_SHARE - 0.0001 and absf(turn) <= largest + 0.0001,
		"the turn should be within %s..%s rad, got %s" % [largest * Lander.DISTURB_MIN_TURN_SHARE, largest, turn])


func test_a_slow_crossing_turns_the_ship_more_than_a_fast_one() -> void:
	await choose_ship()
	var slow := await crossing_turn(true, 160.0, 7)
	var fast := await crossing_turn(true, 450.0, 7)
	check(absf(slow) > absf(fast), "slow turned %s, fast %s" % [slow, fast])
	check(absf(fast) <= max_turn(450.0) + 0.0001, "a fast turn should stay within %s, got %s" % [max_turn(450.0), fast])


func test_the_nose_wobbles_while_the_controls_are_ignored_then_they_return() -> void:
	await choose_ship()
	var ship := lander()
	ship.rng.seed = 3
	place(Vector2(World.WORLD_WIDTH / 2.0, World.BORDER_Y + 10.0), Vector2(0, -160.0))
	ship.rotation = AIMED
	while not ship.in_deep_space:
		await frames(1)
	var fuel := ship.fuel
	hold(&"ui_up")
	hold(&"ui_left")
	var angles := {}
	for i in roundi(Lander.DISTURB_FAST_TIME * PHYSICS_FPS):
		await frames(1)
		angles[snappedf(ship.rotation, 0.001)] = true
	check(ship.fuel == fuel, "Up should do nothing during the disturbance")
	check(angles.size() >= 4, "the nose should move through several angles, saw %d" % angles.size())
	check(absf(ship.rotation - AIMED) <= max_turn(160.0), "Left should be ignored, rotation %s" % ship.rotation)
	await seconds(Lander.DISTURB_SLOW_TIME)
	var turned := ship.rotation
	await seconds(0.25)
	release(&"ui_left")
	release(&"ui_up")
	check_near(ship.rotation, turned - SPARROW_TURN, 0.1, "Left should turn the ship again afterwards")
	check(ship.fuel < fuel, "Up should thrust again afterwards")


func test_slow_ship_bounces_off_the_border() -> void:
	await choose_ship()
	var ship := lander()
	place(Vector2(World.WORLD_WIDTH / 2.0, World.BORDER_Y + 20.0), Vector2(0, -60))
	await seconds(2.0)
	check(not ship.in_deep_space and ship.position.y > World.BORDER_Y,
		"a slow ship should bounce back below the border, y is %s" % ship.position.y)
	check(ship.rotation == 0.0, "a bounce shouldn't disturb the nose, rotation %s" % ship.rotation)


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
