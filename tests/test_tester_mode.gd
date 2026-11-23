extends "res://tests/scene_test.gd"
# Tester mode: typing TESTER within 3 s turns it on (and off again), and while it's on backquote
# opens the Tester panel, which pauses everything and lists the Tester options.


func test_typing_tester_turns_tester_mode_on_and_typing_it_again_turns_it_off() -> void:
	await choose_ship()
	check(not tester().on, "a fresh start has Tester mode off")
	await type_keys("TESTER")
	check(tester().on, "typing TESTER in flight should turn Tester mode on")
	await type_keys("TESTER")
	check(not tester().on, "typing TESTER again should turn it off")


func test_typing_tester_works_in_the_office() -> void:
	check(office().showing, "a fresh start opens on the Office")
	await type_keys("TESTER")
	check(tester().on, "typing TESTER in the Office should turn Tester mode on")
	check(office().showing and office().screen == Office.Screen.MAIN, "typing should leave the Office as it was")


func test_a_wrong_or_slow_sequence_does_nothing() -> void:
	await choose_ship()
	await type_keys("TESTXR")
	check(not tester().on, "a wrong letter should not turn Tester mode on")
	await type_keys("TEST")
	await seconds(3.5)
	await type_keys("ER")
	check(not tester().on, "letters spread over more than 3 s should not turn it on")
	await type_keys("TESTER")
	check(tester().on, "a quick TESTER after those should still work")


func turn_on_tester() -> void:
	await type_keys("TESTER")
	check(tester().on, "typing TESTER should turn Tester mode on")


func test_backquote_does_nothing_with_tester_mode_off() -> void:
	await choose_ship()
	await press_key(KEY_QUOTELEFT)
	check(not tester().panel_open, "backquote should do nothing with Tester mode off")


func test_the_panel_stops_everything_in_flight_and_escape_closes_it() -> void:
	await start_loading([known_offer(1, 0.0)])
	await seconds(economy().loading_left + 0.1)
	check(economy().phase == Economy.Phase.DELIVERING, "loading should finish into the delivery")
	place(Vector2(pad_x() + 300.0, 100.0), Vector2(30, 0))
	await turn_on_tester()
	await press_key(KEY_QUOTELEFT)
	check(tester().panel_open, "backquote should open the Tester panel in flight")
	var position := lander().position
	var minutes := clock().minutes
	var delivery := economy().delivery_time
	var offer := economy().offers[0]
	var time_left := offer.time_left
	await seconds(1.0)
	check(lander().position == position, "the ship should not move while the panel is open")
	check(clock().minutes == minutes, "the planet clock should stop while the panel is open")
	check(economy().delivery_time == delivery, "the delivery clock should stop while the panel is open")
	check(offer.time_left == time_left, "offers should not expire while the panel is open")
	await press(&"ui_cancel")
	check(not tester().panel_open, "Escape should close the panel")
	await seconds(0.5)
	check(lander().position != position, "the ship should fly on once the panel closes")
	check(clock().minutes > minutes and economy().delivery_time > delivery, "the clocks should run on")
	check(offer.time_left < time_left, "offers should count down again")


func test_the_panel_opens_over_the_terminal_and_escape_leaves_the_office_as_it_was() -> void:
	await turn_on_tester()
	await press_key(KEY_QUOTELEFT)
	check(tester().panel_open, "backquote should open the Tester panel over the Terminal")
	await press(&"ui_right")
	check(office().selected_tile() == "SHIPYARD", "keys should go to the panel, not the Office")
	await press(&"ui_cancel")
	check(not tester().panel_open, "Escape should close the panel")
	check(office().showing and office().screen == Office.Screen.MAIN, "Escape should leave the Office showing")
	check(tree.paused, "the Office should still pause the world")


func test_plus_and_minus_500_000_each_add_one_tester_adjustment() -> void:
	economy().balance = 20000
	var count := economy().transactions.size()
	await choose_tester_option("+€500 000")
	check(economy().balance == 520000, "+€500 000 should add €500 000, balance %s" % economy().balance)
	check(economy().transactions.size() == count + 1, "+€500 000 should add one Transaction")
	await choose_tester_option("-€500 000")
	await choose_tester_option("-€500 000")
	check(economy().balance == -480000, "-€500 000 may take the balance below €0, balance %s" % economy().balance)
	check(economy().transactions.size() == count + 3, "each press should add one Transaction")
	await close_tester_panel()
	await open_bank_account()
	var rows := office().bank_account.rows()
	check(rows[0] == "TESTER  -€500 000" and rows[2] == "TESTER  €500 000",
		"the rows should read TESTER and the amount, got %s" % rows)
	await press(&"ui_accept")
	var row := office().bank_account.list.selected_index()
	var details := office().bank_account.details(row)
	check("TESTER ADJUSTMENT" in details, "a Tester adjustment should open to say so, got %s" % details)


func test_auto_refuel_keeps_fuel_at_the_fuel_cap_with_a_load_aboard_for_free() -> void:
	await choose_ship()
	raise_to_maximum_weight()
	lander().load_mass += 1000.0
	lander().fuel = 100.0
	var count := economy().transactions.size()
	var balance := economy().balance
	place(Vector2(pad_x() + 300.0, 100.0))
	await choose_tester_option("AUTO-REFUEL")
	check(tester().is_on("AUTO-REFUEL"), "Return should turn AUTO-REFUEL on")
	await close_tester_panel()
	var cap := lander().fuel_cap()
	check(cap < lander().ship.tank(), "the Load should bring the fuel cap below the Tank")
	hold(&"ui_up")
	await seconds(1.0)
	check_near(lander().fuel, cap, 0.01, "fuel should be held at the fuel cap while thrusting")
	release(&"ui_up")
	check(economy().transactions.size() == count and economy().balance == balance, "Auto-refuel should be free")


# Drops the ship onto the Valley's ground off the pad, from just above it, at a falling speed, and
# waits for the frame it stops falling: it bounces, settles or crashes.
func hit_ground(falling: float) -> void:
	place(Vector2(pad_x() + 400.0, World.GROUND_TOP_Y - hull_bottom() - 0.5), Vector2(0, falling))
	for i in 30:
		await frames(1)
		if lander().state != Lander.State.FLYING or lander().velocity.y < 0.5:
			break


func test_auto_repair_shows_each_loss_then_restores_condition_but_a_hard_hit_still_crashes() -> void:
	await choose_ship()
	var count := economy().transactions.size()
	await choose_tester_option("AUTO-REPAIR")
	await close_tester_panel()
	await hit_ground(60.0)
	check(lander().state == Lander.State.FLYING, "a 60 px/s hit should not crash, says %s" % message())
	check(hud().loss_text() != "", "the loss should still flash in the HUD")
	check(hangar().in_service.condition == 1.0, "Condition should be back at 100%%, got %s" % hangar().in_service.condition)
	check(hud().condition_text() == "CONDITION 100%", "the HUD should read 100%%, got %s" % hud().condition_text())
	check(economy().transactions.size() == count, "Auto-repair should make no Transaction")
	await hit_ground(130.0)
	check(lander().state == Lander.State.CRASHED, "a hit above the crash speed should still crash, says %s" % message())


func test_immune_a_hit_above_the_crash_speed_bounces_with_no_loss() -> void:
	await choose_ship()
	await choose_tester_option("IMMUNE")
	await close_tester_panel()
	await hit_ground(130.0)
	check(lander().state == Lander.State.FLYING, "an Immune ship should not crash, says %s" % message())
	check(lander().velocity.y < -20.0, "the hit should bounce, velocity %s" % lander().velocity)
	check(hangar().in_service.condition == 1.0, "an Immune ship should lose no Condition")
	check(hud().loss_text() == "", "no loss should flash")


func test_immune_a_touchdown_past_a_landing_band_lands_and_delivers() -> void:
	await start_loading([known_offer(1, 0.0)])
	await seconds(economy().loading_left + 0.1)
	check(economy().phase == Economy.Phase.DELIVERING, "loading should finish into the delivery")
	await choose_tester_option("IMMUNE")
	await close_tester_panel()
	place(Vector2(pad_x(), world().location.ground_y - hull_bottom() - 0.5), Vector2(0, 100))
	for i in 240:
		await frames(1)
		if lander().state != Lander.State.FLYING:
			break
	check(lander().state == Lander.State.LANDED, "a 100 px/s touchdown should land, says %s" % message())
	check(message().begins_with("Landed!"), "it should be a plain landing, says %s" % message())
	check(hangar().in_service.condition == 1.0, "an Immune ship should lose no Condition")
	check(economy().phase == Economy.Phase.UNLOADING, "the landing should deliver")


func test_immune_a_ship_resting_tipped_over_does_not_crash() -> void:
	await choose_ship()
	await choose_tester_option("IMMUNE")
	await close_tester_panel()
	place(Vector2(pad_x() + 400.0, World.GROUND_TOP_Y - 30.0))
	lander().rotation = deg_to_rad(90.0)
	await seconds(5.0)
	check(roundf(rad_to_deg(lander().tilt())) >= 90.0, "the ship should rest on its side")
	check(lander().state != Lander.State.CRASHED, "an Immune ship resting tipped over should not crash")


func available(name: String) -> bool:
	return tester().available(name)


func test_back_to_station_docks_the_ship_keeping_everything_and_the_popup_follows() -> void:
	var offer := known_offer(1, 0.0)
	await start_loading([offer])
	await seconds(economy().loading_left + 0.1)
	check(economy().phase == Economy.Phase.DELIVERING, "loading should finish into the delivery")
	place(Vector2(pad_x() + 300.0, 100.0), Vector2(40, 20))
	lander().fuel = 1000.0
	hangar().in_service.condition = 0.7
	var load := lander().load_mass
	var delivery := economy().delivery_time
	await choose_tester_option("BACK TO STATION")
	check(lander().state == Lander.State.DOCKED, "the ship should be Docked")
	check(station().parking_spot.has_point(lander().position) and lander().in_deep_space, "in the parking spot")
	check(lander().velocity == Vector2.ZERO and lander().rotation == 0.0, "upright and at rest")
	check(lander().fuel == 1000.0 and hangar().in_service.condition == 0.7, "fuel and Condition should be kept")
	check(lander().load_mass == load and offer in economy().contracts, "the Load and Contracts should be kept")
	check(not available("BACK TO STATION") and not available("BACK TO PAD"), "both teleports are dimmed while Docked")
	await close_tester_panel()
	await seconds(0.5)
	check(office().popup == Office.PopupKind.ENTER_OFFICE, "ENTER THE OFFICE? should follow")
	check(economy().delivery_time > delivery, "the delivery clock should keep running")


func test_back_to_pad_lands_the_ship_from_deep_space_and_starts_unloading() -> void:
	await start_loading([known_offer(1, 0.0)])
	await seconds(economy().loading_left + 0.1)
	place(Vector2(World.WORLD_WIDTH / 4.0, World.BORDER_Y - 600.0), Vector2(50, -50))
	check(lander().in_deep_space, "the ship should start in deep space")
	var fuel := lander().fuel
	var load := lander().load_mass
	await choose_tester_option("BACK TO PAD")
	check(lander().state == Lander.State.LANDED, "the ship should be Landed")
	check_near(lander().position.x, pad_x(), 0.01, "on the current pad")
	check(not lander().in_deep_space and lander().rotation == 0.0, "on the Surface, upright")
	check(lander().fuel == fuel and lander().load_mass == load, "fuel and Load should be kept")
	check(economy().phase == Economy.Phase.UNLOADING, "unloading should start")
	await close_tester_panel()
	await seconds(0.5)
	check(lander().state == Lander.State.LANDED, "the ship should stay Landed")
	check(office().popup == Office.PopupKind.ENTER_WORKSHOP, "ENTER THE WORKSHOP? should follow")


func test_back_to_pad_from_the_surface() -> void:
	await choose_ship(ShipType.MULE)
	place(Vector2(300, 100))
	await choose_tester_option("BACK TO PAD")
	await close_tester_panel()
	await seconds(1.0)
	check(lander().state == Lander.State.LANDED, "the Mule should be Landed on the pad, says %s" % message())
	check_near(lander().position.x, pad_x(), 0.01, "on the current pad")


func test_the_teleports_are_dimmed_and_do_nothing_when_crashed_stranded_docked_or_in_the_office() -> void:
	await turn_on_tester()
	await press_key(KEY_QUOTELEFT)
	check(not available("BACK TO STATION") and not available("BACK TO PAD"), "dimmed in the Office")
	await choose_tester_option("BACK TO PAD")
	check(office().showing and lander().state == Lander.State.DOCKED, "a dimmed row should do nothing")
	await close_tester_panel()
	await leave_office()
	await press_key(KEY_QUOTELEFT)
	check(not available("BACK TO STATION") and not available("BACK TO PAD"), "dimmed while Docked")
	await close_tester_panel()
	place(Vector2(pad_x() + 300.0, 100.0))
	await press_key(KEY_QUOTELEFT)
	check(available("BACK TO STATION") and available("BACK TO PAD"), "available while Flying")
	await close_tester_panel()
	lander().fuel = 0.0
	place(Vector2(pad_x() + 300.0, World.GROUND_TOP_Y - hull_bottom() - 0.5))
	await seconds(1.5)
	check(lander().state == Lander.State.STRANDED, "an empty ship resting off the pad should be Stranded")
	await press_key(KEY_QUOTELEFT)
	check(not available("BACK TO STATION") and not available("BACK TO PAD"), "dimmed while Stranded")
	await choose_tester_option("BACK TO STATION")
	check(lander().state == Lander.State.STRANDED, "a dimmed row should do nothing")
	await close_tester_panel()
	await crash_in_deep_space()
	await press_key(KEY_QUOTELEFT)
	check(not available("BACK TO STATION") and not available("BACK TO PAD"), "dimmed while Crashed")


func test_r_on_the_surface_no_longer_moves_the_ship_to_the_pad() -> void:
	await choose_ship()
	place(Vector2(300, 100))
	await press(&"restart")
	await frames(2)
	check(lander().state == Lander.State.FLYING, "R on the Surface should do nothing, says %s" % message())


func test_back_to_station_from_the_workshop_question_keeps_everything_stopped_until_the_panel_closes() -> void:
	await choose_ship()
	await land_on_pad()
	check(office().popup == Office.PopupKind.ENTER_WORKSHOP, "landing should ask ENTER THE WORKSHOP?")
	await choose_tester_option("BACK TO STATION")
	var minutes := clock().minutes
	await seconds(0.5)
	check(office().popup == Office.PopupKind.NONE, "the Workshop's question should go")
	check(tree.paused and clock().minutes == minutes, "everything should stay stopped while the panel is open")
	await close_tester_panel()
	await seconds(0.5)
	check(lander().state == Lander.State.DOCKED and office().popup == Office.PopupKind.ENTER_OFFICE,
		"Docked, ENTER THE OFFICE? should follow")


func test_the_tester_tag_shows_in_the_hud_and_the_terminal_header_listing_the_switches_that_are_on() -> void:
	check(tester().tag_text() == "" and hud().tester_tag_text() == "", "no tag with Tester mode off")
	check(not office().header_tag_text().contains("TESTER"), "no tag in the Terminal header with Tester mode off")
	await turn_on_tester()
	check(hud().tester_tag_text() == "TESTER", "the HUD tag with no switch on, got %s" % hud().tester_tag_text())
	check(office().header_tag_text() == "TESTER", "the Terminal header's tag, got %s" % office().header_tag_text())
	await choose_tester_option("AUTO-REFUEL")
	await choose_tester_option("IMMUNE")
	check(hud().tester_tag_text() == "TESTER: FUEL · IMMUNE", "the HUD tag lists the ON switches, got %s" % hud().tester_tag_text())
	await choose_tester_option("AUTO-REPAIR")
	check(office().header_tag_text() == "TESTER: FUEL · REPAIR · IMMUNE",
		"the header's tag lists the ON switches, got %s" % office().header_tag_text())
	await close_tester_panel()
	await type_keys("TESTER")
	check(hud().tester_tag_text() == "" and office().header_tag_text() == "", "the tag goes with Tester mode")
	check(not lander().immune, "turning Tester mode off turns its switches off")


func test_nothing_about_tester_mode_survives_a_fresh_start() -> void:
	await choose_tester_option("IMMUNE")
	await close_tester_panel()
	await start_over()
	check(not tester().on and tester().tag_text() == "", "a fresh start has Tester mode off")
	check(not tester().is_on("IMMUNE") and not lander().immune, "and every switch off")


func test_back_to_station_is_dimmed_while_unloading_on_the_pad() -> void:
	await start_loading([known_offer(1, 0.0)])
	await seconds(economy().loading_left + 0.1)
	place(Vector2(pad_x() + 300.0, 100.0))
	await back_to_pad()
	check(economy().phase == Economy.Phase.UNLOADING, "Back to pad should start unloading")
	await press_key(KEY_QUOTELEFT)
	check(not available("BACK TO STATION"), "Back to station should be dimmed while unloading")
	check(available("BACK TO PAD"), "Back to pad stays available while Landed")
	await choose_tester_option("BACK TO STATION")
	check(lander().state == Lander.State.LANDED, "a dimmed Back to station should do nothing")
