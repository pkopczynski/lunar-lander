extends "res://tests/scene_test.gd"
# A ship touching the ground is a rigid body: it tips about its centre of mass onto its legs or
# its side, rolls and slides down steep faces, holds on gentle slopes, turns with the controls,
# and keeps a spin in the air until the player counters it.

const OFF_PAD := 400.0


# Drops the ship in service off the pad, its lowest point `height` px above the Valley's ground,
# turned `tilt_deg`, at rest.
func drop(tilt_deg: float, height := 10.0) -> void:
	var rotation := deg_to_rad(tilt_deg)
	place(Vector2(pad_x() + OFF_PAD, World.GROUND_TOP_Y - hull_bottom(rotation) - height))
	lander().rotation = rotation


func tilt_deg() -> float:
	return rad_to_deg(lander().tilt())


func test_a_tilted_sparrow_rocks_back_onto_its_legs() -> void:
	await choose_ship()
	drop(30.0)
	await seconds(2.0)
	check(tilt_deg() < 3.0, "a Sparrow dropped at 30° should rock back onto its legs, tilt %s°" % tilt_deg())
	check(lander().state == Lander.State.FLYING, "it should rest off the pad Flying, says %s" % message())


func test_a_steeply_tilted_sparrow_tips_onto_its_side_and_cannot_rest_on_its_nose() -> void:
	await choose_ship()
	drop(60.0, 2.0)
	await seconds(3.0)
	# Its flank lies flat at about 112°, past the 90° that counts as tipped over.
	check(tilt_deg() > 100.0 and tilt_deg() < 125.0, "a Sparrow dropped at 60° should tip onto its side, tilt %s°" % tilt_deg())
	await start_over()
	await choose_ship()
	# Balanced 2° off its nose it topples slowly, as gravity here is low.
	drop(178.0, 2.0)
	await seconds(4.0)
	check(tilt_deg() > 100.0 and tilt_deg() < 125.0, "a Sparrow dropped on its nose should fall onto its side, tilt %s°" % tilt_deg())


func test_a_mule_resting_on_its_side_at_90_degrees_crashes_after_two_seconds() -> void:
	await choose_ship(ShipType.MULE)
	drop(90.0, 1.0)
	await seconds(1.5)
	check(lander().state == Lander.State.FLYING, "a Mule on its side shouldn't crash before 2 s, says %s" % message())
	check_near(tilt_deg(), 90.0, 0.5, "the Mule should lie flat on its side")
	await seconds(1.0)
	check(lander().state == Lander.State.CRASHED, "resting at 90° for 2 s should crash, says %s" % message())


# Moves to a location with a ramp rising to the right at slope_deg from x 700 on the Valley's
# ground, and stands the Sparrow on it, legs flat on the slope (0.5 px off it), the middle of its
# legs `along` px up the ramp.
func stand_on_ramp(slope_deg: float, along := 60.0) -> void:
	var slope := deg_to_rad(slope_deg)
	var run := 300.0
	var foot := Vector2(700.0, World.GROUND_TOP_Y)
	var location := Location.new()
	location.name = "RAMP"
	location.pad_center_x = 1800.0
	location.terrain = [PackedVector2Array([foot, foot + Vector2(run, -run * tan(slope)), foot + Vector2(run, 0.0)])]
	clock().move_to(location)
	await frames(1)
	var on_slope := foot + Vector2(cos(slope), -sin(slope)) * along
	var normal := Vector2(-sin(slope), -cos(slope))
	place(on_slope + normal * (hull_bottom() + 0.5))
	lander().rotation = -slope


func test_a_ship_holds_on_a_gentle_slope_and_slides_and_rolls_down_a_steep_face() -> void:
	await choose_ship()
	await stand_on_ramp(27.0)
	var start := lander().position
	await seconds(2.0)
	check(lander().position.distance_to(start) < 3.0,
		"a Sparrow should hold on a 27° slope, moved from %s to %s" % [start, lander().position])
	await start_over()
	await choose_ship()
	# Standing square on a 60° face it slides; with friction at 60 px/s² it doesn't tip as it slides.
	await stand_on_ramp(60.0, 120.0)
	start = lander().position
	await seconds(2.0)
	check(lander().position.x < start.x - 15.0 and lander().position.y > start.y + 30.0,
		"a Sparrow should slide down a 60° face, moved from %s to %s" % [start, lander().position])
	await start_over()
	await choose_ship()
	# Dropped upright with its uphill leg on the face, its centre of mass hangs past that leg, so
	# it rolls down.
	await stand_on_ramp(60.0, 120.0)
	# The Sparrow's right leg (its hull's second point) is the uphill one on a ramp rising right.
	var uphill_leg := lander().ship_type.hull[1]
	var leg_on_face := lander().to_global(uphill_leg)
	place(leg_on_face + Vector2(-sin(PI / 3.0), -cos(PI / 3.0)) - uphill_leg)
	start = lander().position
	await seconds(2.0)
	check(lander().position.y > start.y + 30.0, "an upright Sparrow should come down a 60° face, moved from %s to %s" % [start, lander().position])
	check(tilt_deg() > 45.0, "it should roll as it comes down, tilt %s°" % tilt_deg())


func test_the_controls_turn_a_ship_on_the_ground_so_a_tipping_ship_can_be_saved() -> void:
	await choose_ship()
	# Dropped at 60° it would tip onto its side (as above); turning left saves it.
	drop(60.0, 2.0)
	hold(&"ui_left")
	await seconds(1.0)
	release(&"ui_left")
	await seconds(2.5)
	check(tilt_deg() < 3.0, "turning left should bring the tipping Sparrow back onto its legs, tilt %s°" % tilt_deg())
	check(lander().state == Lander.State.FLYING, "a saved ship shouldn't crash, says %s" % message())


func test_a_spin_keeps_going_in_the_air_until_the_controls_counter_it() -> void:
	await choose_ship()
	place(Vector2(pad_x(), 0.0))
	lander().spin = 1.0
	var start := lander().rotation
	await seconds(1.0)
	check_near(lander().rotation - start, 1.0, 0.05, "a spin of 1 rad/s should turn the ship 1 rad in 1 s, undamped")
	# Turning left counters a clockwise spin, at the ground torque: 1 rad/s is gone in 1/6 s.
	hold(&"ui_left")
	await seconds(0.25)
	release(&"ui_left")
	await frames(1)
	var countered := lander().rotation
	await seconds(1.0)
	check_near(lander().rotation, countered, 0.01, "a countered spin should stay stopped")
