extends "res://tests/scene_test.gd"
# In debug builds (which tests run in), R on the Surface teleports the ship to
# the pad instead of restarting the run.


func test_r_on_the_surface_teleports_to_the_pad_landed() -> void:
	await choose_ship()
	var ship := lander()
	var scene := main()
	place(Vector2(300, 100), Vector2(80, -40))
	ship.rotation = 1.0
	await seconds(0.5)
	ship.load_mass = 2000.0
	var fuel := ship.fuel
	var mass := ship.total_mass()
	await press(&"restart")
	await frames(2)
	check(main() == scene, "R on the Surface should not reload the scene")
	check(not office().showing, "R on the Surface should not open the Office")
	check(ship.state == Lander.State.LANDED, "the ship should be Landed after the teleport")
	check(not ship.in_deep_space, "the ship should still be on the Surface")
	check_near(ship.position.x, Lander.PAD_CENTER_X, 0.5, "x at the pad centre")
	check_near(ship.rotation, 0.0, 0.0001, "rotation (upright)")
	check(ship.velocity == Vector2.ZERO, "velocity should be zero, got %s" % ship.velocity)
	check(message().begins_with("Landed!"), "the message should say Landed!, got %s" % message())
	check(ship.ship_type == ShipType.SPARROW, "the ship type should be kept")
	check_near(ship.fuel, fuel, 1.0, "fuel should be kept")
	check_near(ship.total_mass(), mass, 1.0, "dry mass, fuel and Load should be kept")


func test_the_teleported_ship_rests_on_the_pad_and_can_lift_off() -> void:
	await choose_ship(ShipType.MULE)
	var ship := lander()
	place(Vector2(300, 100))
	await press(&"restart")
	await seconds(1.0)
	check(ship.state == Lander.State.LANDED, "the Mule should stay Landed on the pad, says %s" % message())
	check(not message().begins_with("Crashed"), "the Mule should not crash after the teleport")
	var rest_y := ship.position.y
	hold(&"ui_up")
	await seconds(0.5)
	release(&"ui_up")
	check(ship.state != Lander.State.LANDED, "Up should lift off the pad")
	check(ship.position.y < rest_y, "the ship should climb off the pad, y is %s from %s" % [ship.position.y, rest_y])


func test_r_after_a_crash_on_the_surface_teleports_to_the_pad() -> void:
	await choose_ship()
	var ship := lander()
	place(Vector2(Lander.PAD_CENTER_X + 400.0, 560), Vector2(0, 200))
	await seconds(1.0)
	check(message().begins_with("Crashed"), "should have crashed, got %s" % message())
	await press(&"restart")
	await frames(2)
	check(not office().showing, "R after a crash on the Surface should not open the Office")
	check(ship.state == Lander.State.LANDED, "the ship should be Landed on the pad after the teleport")
	check(message().begins_with("Landed!"), "the crash message should clear, got %s" % message())
	hold(&"ui_up")
	await seconds(0.5)
	release(&"ui_up")
	check(ship.state != Lander.State.LANDED, "the ship should fly again after the teleport")


func test_r_while_flying_in_deep_space_returns_to_the_office() -> void:
	await choose_ship()
	place(Vector2(World.WORLD_WIDTH / 4.0, World.BORDER_Y - 600.0), Vector2(50, -50))
	await seconds(0.2)
	await restart()
	check(office().showing, "R in deep space should return to the Office")
