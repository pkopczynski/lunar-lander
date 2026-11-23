extends "res://tests/scene_test.gd"
# The Tester panel's Back to pad puts the ship Landed on the pad from anywhere in flight; R is only
# Recovery, after a crash, and does nothing otherwise.


func test_back_to_pad_from_the_surface_puts_the_ship_landed_on_the_pad() -> void:
	await choose_ship()
	var ship := lander()
	var scene := main()
	place(Vector2(300, 100), Vector2(80, -40))
	ship.rotation = 1.0
	await seconds(0.5)
	ship.load_mass = 2000.0
	var fuel := ship.fuel
	var mass := ship.total_mass()
	await back_to_pad()
	await frames(2)
	check(main() == scene, "Back to pad should not reload the scene")
	check(not office().showing, "Back to pad should not open the Office")
	check(ship.state == Lander.State.LANDED, "the ship should be Landed after the teleport")
	check(not ship.in_deep_space, "the ship should still be on the Surface")
	check_near(ship.position.x, pad_x(), 0.5, "x at the pad centre")
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
	await back_to_pad()
	await seconds(1.0)
	check(ship.state == Lander.State.LANDED, "the Mule should stay Landed on the pad, says %s" % message())
	check(not message().begins_with("Crashed"), "the Mule should not crash after the teleport")
	await decline_workshop()
	var rest_y := ship.position.y
	hold(&"ui_up")
	await seconds(0.5)
	release(&"ui_up")
	check(ship.state != Lander.State.LANDED, "Up should lift off the pad")
	check(ship.position.y < rest_y, "the ship should climb off the pad, y is %s from %s" % [ship.position.y, rest_y])


func test_r_after_a_crash_on_the_surface_recovers() -> void:
	await choose_ship()
	var ship := lander()
	place(Vector2(pad_x() + 400.0, 560), Vector2(0, 200))
	await seconds(1.0)
	check(message().begins_with("Crashed"), "should have crashed, got %s" % message())
	await recover()
	check(ship.state == Lander.State.DOCKED and ship.in_deep_space, "the Wreck should be Docked at the station, not on the pad")


func test_r_while_flying_in_deep_space_does_nothing() -> void:
	await choose_ship()
	var scene := main()
	place(Vector2(World.WORLD_WIDTH / 4.0, World.BORDER_Y - 600.0), Vector2(50, -50))
	await seconds(0.2)
	await press(&"restart")
	await frames(2)
	check(main() == scene, "R in deep space should not reload the scene")
	check(not office().showing, "R in deep space should not open the Office")
	check(lander().state == Lander.State.FLYING, "the ship should keep flying")
