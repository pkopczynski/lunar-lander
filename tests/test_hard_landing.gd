extends "res://tests/scene_test.gd"
# A touchdown on the pad is judged by three landing bands (falling 50 → 80 px/s, sideways
# 25 → 40 px/s, tilt 15° → 25°): safe, a Hard landing that still lands and delivers but loses
# 0% → 25% of Condition (the worst band counts), or a crash past any band.

const OVER_PAD := 0.5


func condition() -> float:
	return hangar().in_service.condition


# Touches the Sparrow down on the Valley's pad from just above it, at a falling and sideways
# speed and a tilt, and waits for the frame it touches down.
func touch_down(falling: float, sideways := 0.0, tilt_deg := 0.0) -> void:
	var rotation := deg_to_rad(tilt_deg)
	var hull_bottom := -INF
	for point in lander().ship_type.hull:
		hull_bottom = maxf(hull_bottom, point.rotated(rotation).y)
	place(Vector2(pad_x(), World.GROUND_TOP_Y - hull_bottom - OVER_PAD), Vector2(sideways, falling))
	lander().rotation = rotation
	for i in 30:
		await frames(1)
		if lander().state != Lander.State.FLYING:
			break


func test_a_touchdown_inside_the_safe_limits_lands_undamaged() -> void:
	await choose_ship()
	await touch_down(45.0, 20.0, 12.0)
	check(message().begins_with("Landed!"), "a safe touchdown should land, says %s" % message())
	check(condition() == 1.0, "a safe touchdown should do no damage, Condition %s" % condition())


func test_a_touchdown_inside_each_band_lands_and_loses_condition_in_a_straight_line() -> void:
	await choose_ship()
	# Sideways: (32.2 − 25) / (40 − 25) × 25% = 12%.
	await touch_down(10.0, 32.2)
	check(lander().state == Lander.State.LANDED, "a 32 px/s sideways touchdown should land, says %s" % message())
	check_near(condition(), 0.88, 0.005, "Condition after a 32.2 px/s sideways touchdown")
	await start_over()
	await choose_ship()
	# Falling: (65 − 50) / (80 − 50) × 25% = 12.5%, plus a frame of gravity.
	await touch_down(65.0)
	check(lander().state == Lander.State.LANDED, "a 65 px/s touchdown should land, says %s" % message())
	check_near(condition(), 0.875, 0.01, "Condition after a 65 px/s touchdown")
	await start_over()
	await choose_ship()
	# Tilt: (20 − 15) / (25 − 15) × 25% = 12.5%.
	await touch_down(10.0, 0.0, 20.0)
	check(lander().state == Lander.State.LANDED, "a 20° touchdown should land, says %s" % message())
	check_near(condition(), 0.875, 0.005, "Condition after a 20° touchdown")


func test_the_worst_band_counts() -> void:
	await choose_ship()
	# Falling 65 px/s is ~13%, sideways 30 px/s ~8%, but a 24° tilt is 22.5%.
	await touch_down(65.0, 30.0, 24.0)
	check(lander().state == Lander.State.LANDED, "a touchdown inside every band should land, says %s" % message())
	check_near(condition(), 0.775, 0.005, "the worst band's loss, not a sum")


func test_a_hard_landing_shows_its_loss_in_the_landing_message_and_flashes_it() -> void:
	await choose_ship()
	lander().fuel = lander().fuel_cap() / 2.0
	await touch_down(10.0, 32.2)
	check(message().begins_with("HARD LANDING −12%"), "the landing message should read HARD LANDING −12%%, says %s" % message())
	check(hud().loss_text() == "−12%", "the HUD should flash the loss, shows %s" % hud().loss_text())
	check(hud().condition_text() == "CONDITION 88%", "the HUD Condition line, shows %s" % hud().condition_text())
	await seconds(2.5)
	check(message().begins_with("HARD LANDING −12%"), "the message should stay while Landed, says %s" % message())
	check(message().contains("Refueling…"), "a Hard landing still refuels, says %s" % message())


func test_a_hard_landing_delivers() -> void:
	await start_loading([known_offer(1, 0.0)])
	while economy().phase == Economy.Phase.LOADING:
		await frames(1)
	await touch_down(70.0)
	check(lander().state == Lander.State.LANDED, "a hard landing should land, says %s" % message())
	check(condition() < 1.0, "a hard landing should cost Condition")
	check(economy().phase == Economy.Phase.UNLOADING, "a hard landing should start unloading")


func test_a_touchdown_past_any_band_crashes() -> void:
	for touchdown: Array in [[90.0, 0.0, 0.0], [10.0, 45.0, 0.0], [10.0, 0.0, 27.0]]:
		await choose_ship()
		await touch_down(touchdown[0], touchdown[1], touchdown[2])
		check(lander().state == Lander.State.CRASHED, "a touchdown at %s should crash, says %s" % [touchdown, message()])
		check(hangar().in_service.is_wreck(), "the crash should make a Wreck")
		await start_over()


func test_a_hard_landing_to_zero_condition_crashes() -> void:
	await choose_ship()
	hangar().in_service.condition = 0.1
	await touch_down(10.0, 32.2)
	check(lander().state == Lander.State.CRASHED, "a 12%% Hard landing on a 10%% ship should crash, says %s" % message())
	check(economy().phase == Economy.Phase.NONE, "a crash delivers nothing")
