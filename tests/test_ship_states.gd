extends "res://tests/scene_test.gd"
# Entering a Ship state starts it fresh, whatever the ship was doing before.


func test_docking_mid_lift_off_burn_undocks_at_the_default_burn() -> void:
	await choose_ship()
	var ship := lander()
	var default_burn := await fuel_burned_undocking(0.5)

	ship.reset_to_pad()
	hold(&"ui_up")
	await seconds(0.2)
	release(&"ui_up")
	check(ship.state != Lander.State.LANDED, "Up should lift off the pad")
	ship.start_docked(ship.ship_type)
	# A frame of input timing is ~3% of the burn; a leftover lift-off burn adds 30% or more.
	check_near(await fuel_burned_undocking(0.5), default_burn, default_burn * 0.1,
		"fuel burned undocking after a lift-off")


func test_docking_mid_bounce_undocks_without_a_kick() -> void:
	await choose_ship()
	var ship := lander()
	# Too slow to cross, so the ship drifts just past the border and starts bouncing back.
	place(Vector2(World.WORLD_WIDTH / 2.0, World.BORDER_Y + 20.0), Vector2(0, -60))
	await seconds(0.6)
	check(ship.position.y < World.BORDER_Y and not ship.in_deep_space,
		"the ship should be bouncing just past the border, y is %s" % ship.position.y)
	ship.start_docked(ship.ship_type)
	hold(&"ui_up")
	await seconds(0.1)
	release(&"ui_up")
	check(ship.velocity.y < 0.0, "undocking should climb, velocity is %s" % ship.velocity)


func test_docking_after_a_crash_lets_the_ship_undock() -> void:
	await choose_ship()
	await crash_in_deep_space()
	var ship := lander()
	ship.start_docked(ship.ship_type)
	var spot := ship.position
	hold(&"ui_up")
	await seconds(0.5)
	release(&"ui_up")
	check(ship.state != Lander.State.DOCKED, "Up should undock after a crash")
	check(ship.position.y < spot.y, "the ship should climb out of the spot, y is %s from %s" % [ship.position.y, spot.y])


# Fuel burned holding Up for duration from Docked, at rest in the parking spot.
func fuel_burned_undocking(duration: float) -> float:
	var before := lander().fuel
	hold(&"ui_up")
	await seconds(duration)
	release(&"ui_up")
	check(lander().state != Lander.State.DOCKED, "Up should undock")
	return before - lander().fuel
