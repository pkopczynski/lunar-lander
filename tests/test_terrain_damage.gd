extends "res://tests/scene_test.gd"
# Touching a solid damages the ship by its Impact speed and it bounces; only a hit above the
# Crash speed, a hit to 0% Condition or resting tipped over crashes it.

# The Sparrow's hull bottom is 14 px below its origin, and the Valley's ground top is at 608.
const RESTING_Y := World.GROUND_TOP_Y - 14.0
const OFF_PAD := 400.0


func condition() -> float:
	return hangar().in_service.condition


# Drops the Sparrow onto the ground off the pad, from just above it, at a falling speed (and a
# sideways one), and waits for the frame it leaves the ground again, settles or crashes.
func hit_ground(falling: float, sideways := 0.0) -> void:
	place(Vector2(pad_x() + OFF_PAD, RESTING_Y - 0.5), Vector2(sideways, falling))
	for i in 30:
		await frames(1)
		if lander().state != Lander.State.FLYING or lander().velocity.y < 0.0 or lander().is_on_floor():
			break


func test_a_touch_below_the_no_damage_speed_does_nothing_and_the_ship_settles() -> void:
	await choose_ship()
	await hit_ground(10.0)
	await seconds(0.5)
	check(lander().state == Lander.State.FLYING, "a gentle touch off the pad should stay Flying, says %s" % message())
	check(condition() == 1.0, "a touch under 15 px/s should do no damage, Condition %s" % condition())
	check_near(lander().position.y, RESTING_Y, 1.0, "the ship should rest on the ground")
	check(absf(lander().velocity.y) < 2.0, "the ship should not bounce, velocity %s" % lander().velocity)


func test_a_hit_damages_in_a_straight_line_and_the_ship_bounces() -> void:
	await choose_ship()
	await hit_ground(60.0, 40.0)
	check(lander().state == Lander.State.FLYING, "a 60 px/s hit should not crash, says %s" % message())
	# (60 − 15) / (120 − 15) × 50%.
	check_near(condition(), 1.0 - 0.2143, 0.015, "Condition after a 60 px/s hit")
	check_near(lander().velocity.y, -0.35 * 60.0, 2.0, "the bounce leaves at 35% of the impact speed")
	check_near(lander().velocity.x, 0.8 * 40.0, 1.0, "80% of the speed along the surface is kept")
	await start_over()
	await choose_ship()
	await hit_ground(110.0)
	check(lander().state == Lander.State.FLYING, "a 110 px/s hit should not crash, says %s" % message())
	check_near(condition(), 1.0 - 0.4524, 0.015, "Condition after a 110 px/s hit")


func test_a_hit_above_the_crash_speed_crashes() -> void:
	await choose_ship()
	await hit_ground(130.0)
	check(lander().state == Lander.State.CRASHED, "a 130 px/s hit should crash, says %s" % message())
	check(hangar().in_service.is_wreck(), "the crash should make a Wreck")


func test_a_hit_to_zero_condition_crashes_so_a_worn_ship_crashes_from_a_smaller_hit() -> void:
	await choose_ship()
	hangar().in_service.condition = 0.3
	await hit_ground(90.0)
	check(lander().state == Lander.State.CRASHED, "a 36%% hit on a 30%% ship should crash, says %s" % message())
	await start_over()
	await choose_ship()
	await hit_ground(90.0)
	check(lander().state == Lander.State.FLYING, "the same hit on a new ship should not crash, says %s" % message())


func test_a_ship_resting_off_the_pad_stays_flying_delivers_nothing_and_lifts_off() -> void:
	await start_loading([known_offer(1, 0.0)])
	while economy().phase == Economy.Phase.LOADING:
		await frames(1)
	await hit_ground(5.0, 30.0)
	await seconds(1.5)
	check(lander().state == Lander.State.FLYING, "resting off the pad should stay Flying, says %s" % message())
	check(absf(lander().velocity.x) < 1.0, "friction should stop the sliding ship, velocity %s" % lander().velocity)
	check(economy().phase == Economy.Phase.DELIVERING and economy().contracts.size() == 1,
		"nothing should be delivered off the pad")
	var rest_y := lander().position.y
	hold(&"ui_up")
	await seconds(0.5)
	release(&"ui_up")
	check(lander().position.y < rest_y - 5.0, "the ship should lift off again, y %s from %s" % [lander().position.y, rest_y])


func test_friction_slows_a_sliding_ship_by_60_px_per_second_squared() -> void:
	await choose_ship()
	await hit_ground(5.0, 50.0)
	var start_x := lander().velocity.x
	await seconds(0.5)
	check_near(lander().velocity.x, start_x - 30.0, 2.0, "sideways speed after 0.5 s of sliding")


func test_resting_tipped_over_for_two_seconds_crashes() -> void:
	await choose_ship()
	# Lying on its side: turned 100°, its lowest corner is about 11.4 px below its centre.
	place(Vector2(pad_x() + OFF_PAD, World.GROUND_TOP_Y - 12.0), Vector2(0, 5))
	lander().rotation = deg_to_rad(100.0)
	await seconds(1.5)
	check(lander().state == Lander.State.FLYING, "a tipped ship shouldn't crash before 2 s, says %s" % message())
	await seconds(1.0)
	check(lander().state == Lander.State.CRASHED, "resting tipped over for 2 s should crash, says %s" % message())


func test_stranded_off_the_pad_and_recovered_keeping_condition_and_failing_contracts() -> void:
	await start_loading([known_offer(1, 0.0)])
	while economy().phase == Economy.Phase.LOADING:
		await frames(1)
	var balance := economy().balance
	await hit_ground(40.0)
	lander().fuel = 0.0
	await seconds(1.5)
	check(lander().state == Lander.State.STRANDED, "resting off the pad with an empty tank should be Stranded")
	check(message() == "Stranded!\nPress R for recovery", "the Stranded message, got %s" % message())
	var worn := condition()
	check(worn < 1.0 and worn > 0.0, "the hit should have worn the ship, Condition %s" % worn)
	check(economy().contracts.is_empty() and economy().phase == Economy.Phase.NONE, "the Contract should fail")
	check(economy().balance == balance - 21000 - 12500,
		"the failure fee and the recovery fee should be charged, balance %s from %s" % [economy().balance, balance])
	await press(&"restart")
	await wait_for_terminal()
	check(office().showing, "R while Stranded should open the Office")
	check(lander().in_deep_space and lander().state == Lander.State.DOCKED, "the ship should be Docked at the station")
	check(condition() == worn and not hangar().in_service.is_wreck(), "Recovery should keep the Condition, %s" % condition())
	check(not "WRECKED" in office().main_lines(), "a Stranded ship isn't a Wreck, main lines %s" % office().main_lines())


func test_the_hud_shows_condition_and_flashes_each_loss() -> void:
	await choose_ship()
	check(hud().condition_text() == "CONDITION 100%", "the HUD's Condition, got %s" % hud().condition_text())
	check(hud().loss_text() == "", "no loss shown before a hit, got %s" % hud().loss_text())
	await hit_ground(60.0)
	await frames(1)
	# About 21% from a 60 px/s hit.
	var lost := roundi((1.0 - condition()) * 100.0)
	check(lost >= 20 and lost <= 23, "a 60 px/s hit should cost about 21%%, cost %d%%" % lost)
	check(hud().condition_text() == "CONDITION %d%%" % (100 - lost), "the HUD's Condition after a hit, got %s" % hud().condition_text())
	check(hud().loss_text() == "−%d%%" % lost, "the HUD should flash the loss, got %s" % hud().loss_text())
	await seconds(3.0)
	check(hud().loss_text() == "", "the loss flash should be brief, got %s" % hud().loss_text())


func test_crossing_the_border_does_no_damage() -> void:
	await choose_ship()
	lander().rng.seed = 1
	place(Vector2(World.WORLD_WIDTH / 2.0, World.BORDER_Y + 40.0), Vector2(0, -400))
	await seconds(0.5)
	check(lander().in_deep_space, "the ship should have crossed into deep space")
	check(condition() == 1.0, "crossing the Border should do no damage, Condition %s" % condition())
