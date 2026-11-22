extends "res://tests/scene_test.gd"
# A touchdown on the pad is judged by three landing bands (falling 50 → 80 px/s, sideways
# 25 → 40 px/s, tilt 15° → 25°): safe, a Hard landing that still lands and delivers but loses
# 0% → 25% of Condition (the worst band counts), or a crash past any band. The ship then settles
# onto its legs without bouncing and is Landed once at rest.

const OVER_PAD := 0.5


func condition() -> float:
	return hangar().in_service.condition


# Touches the Sparrow down on the Valley's pad from just above it, at a falling and sideways
# speed and a tilt, and waits until it has settled and landed, or crashed.
func touch_down(falling: float, sideways := 0.0, tilt_deg := 0.0) -> void:
	place_over_pad(falling, sideways, tilt_deg)
	for i in 240:
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
	check(office().popup == Office.PopupKind.ENTER_WORKSHOP, "a Hard landing still asks to enter the Workshop")


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


func test_the_ship_settles_on_the_pad_without_bouncing_and_lands_once_at_rest() -> void:
	await choose_ship()
	await touch_down_and_watch(45.0, 0.0, 12.0)


func place_over_pad(falling: float, sideways: float, tilt_deg: float) -> void:
	var rotation := deg_to_rad(tilt_deg)
	place(Vector2(pad_x(), World.GROUND_TOP_Y - hull_bottom(rotation) - OVER_PAD), Vector2(sideways, falling))
	lander().rotation = rotation


# Touches down and watches every frame until Landed: never moving up off the pad, and Flying
# until it has been still (slower than 4 px/s, turning slower than 0.15 rad/s) for 0.3 s.
func touch_down_and_watch(falling: float, sideways: float, tilt_deg: float) -> void:
	place_over_pad(falling, sideways, tilt_deg)
	var still_frames := 0
	var fastest_rise := 0.0
	var last_rotation := lander().rotation
	for i in 240:
		await frames(1)
		if lander().state != Lander.State.FLYING:
			break
		fastest_rise = maxf(fastest_rise, -lander().velocity.y)
		var turning := absf(lander().rotation - last_rotation) * PHYSICS_FPS
		last_rotation = lander().rotation
		var still := lander().velocity.length() < 4.0 and turning < 0.15
		still_frames = still_frames + 1 if still else 0
	check(lander().state == Lander.State.LANDED, "the ship should land once it settles, says %s" % message())
	check(fastest_rise < 2.0, "the ship shouldn't bounce off the pad, rose at %s px/s" % fastest_rise)
	check(still_frames >= roundi(0.3 * PHYSICS_FPS) - 1,
		"it should be Landed only after resting 0.3 s, rested %d frames" % still_frames)
	check(lander().tilt() < deg_to_rad(2.0), "it should settle onto its legs, tilt %s°" % rad_to_deg(lander().tilt()))


func test_sliding_onto_the_pad_along_the_ground_is_judged_as_a_touchdown() -> void:
	await choose_ship()
	# Resting on the ground 2 px short of the pad, sliding onto it at 34 px/s.
	place(Vector2(pad_x() - Lander.PAD_WIDTH / 2.0 - 2.0, World.GROUND_TOP_Y - 14.0), Vector2(34.0, 0.0))
	for i in 240:
		await frames(1)
		if lander().state != Lander.State.FLYING:
			break
	check(lander().state == Lander.State.LANDED, "sliding onto the pad should land once settled, says %s" % message())
	# Friction takes ~1 px/s a frame, so it reaches the pad at about 30 px/s sideways:
	# (30 − 25) / (40 − 25) × 25% ≈ 8%. Without the touchdown it would land undamaged.
	check_near(condition(), 0.92, 0.02, "sliding onto the pad at ~30 px/s should be a Hard landing")
