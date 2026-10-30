extends "res://tests/scene_test.gd"


func test_the_screen_lists_five_offers_whose_countdowns_run_while_the_office_is_open() -> void:
	await open_transport_offers()
	var rows := offers().rows()
	check(rows.size() == 5, "the screen should list 5 Transport offers, lists %s" % rows)
	var countdown := RegEx.create_from_string("^#\\d{3} .+ (PASSENGERS|CARGO|PASSENGERS \\+ CARGO) \\d+:\\d{2}$")
	for row in rows:
		check(countdown.search(row) != null, "a row should show number, title, kind and m:ss, got %s" % row)
	var before := rows[0]
	await seconds(2.0)
	check(tree.paused, "the Office should keep the world paused")
	check(offers().rows()[0] != before, "the countdown should advance while the Office is open: %s, then %s" % [before, offers().rows()[0]])


func test_an_offer_whose_time_runs_out_disappears_and_nothing_takes_its_place() -> void:
	economy().reseed(1)
	await open_transport_offers()
	var offer := known_offer(2, 0.0, 1.5)
	economy().put_offer(offer)
	var row := TransportOffersScreen.row_text(offer)
	check(row in offers().rows(), "the known offer should be listed, lists %s" % offers().rows())
	check(offers().rows().size() == 6, "the known offer should join the 5, lists %s" % offers().rows())
	await seconds(2.0)
	check(not listed("#%03d " % offer.number), "the expired offer should be gone, lists %s" % offers().rows())
	check(offers().rows().size() == 5, "nothing should take the expired offer's place, lists %s" % offers().rows())


func test_new_offers_arrive_every_30_to_90_seconds() -> void:
	await open_transport_offers()
	for seed_value in [1, 2, 3]:
		economy().reseed(seed_value)
		await seconds(Economy.MIN_OFFER_INTERVAL - 0.5)
		check(offers().rows().size() == 5, "seed %d should add nothing within 30 s, lists %s" % [seed_value, offers().rows()])
		await seconds(Economy.MAX_OFFER_INTERVAL - Economy.MIN_OFFER_INTERVAL + 1.0)
		check(offers().rows().size() == 6, "seed %d should add one offer within 90 s, lists %s" % [seed_value, offers().rows()])


func test_the_list_never_grows_past_seven_and_refills_once_one_goes() -> void:
	economy().reseed(1)
	await open_transport_offers()
	var short := known_offer(1, 0.0, 100.0)
	economy().put_offer(short)
	economy().put_offer(known_offer(1, 0.0))
	check(offers().rows().size() == 7, "the list should hold 7, lists %s" % offers().rows())
	await seconds(Economy.MAX_OFFER_INTERVAL + 5.0)
	check(offers().rows().size() == 7, "a full list should get no new offer, lists %s" % offers().rows())
	await seconds(10.0)
	check(offers().rows().size() == 6, "the short offer should have expired, lists %s" % offers().rows())
	await seconds(Economy.MAX_OFFER_INTERVAL)
	check(offers().rows().size() == 7, "a new offer should arrive within 90 s once one goes, lists %s" % offers().rows())


func test_return_expands_one_offers_details_at_a_time_and_escape_collapses_them() -> void:
	economy().put_offer(known_offer(3, 1200.0))
	await open_transport_offers()
	await select_row(5)
	check(offers().details().is_empty(), "no details should show before Return")
	await press(&"ui_accept")
	var details := offers().details()
	for expected: String in ["PASSENGERS 3", "CARGO 1 200 KG", "DEADLINE 1:30", "TRADER TEST TRADER", "VALUE €420", "ACCEPT"]:
		check(expected in details, "the details should show %s, show %s" % [expected, details])
	check(offers().expanded_row() == 5, "the details should open under the selected row, got %d" % offers().expanded_row())
	await press(&"ui_up")
	await press(&"ui_accept")
	check(offers().expanded_row() == 4, "Return on another row should open its details instead, got %d" % offers().expanded_row())
	await press(&"ui_cancel")
	check(offers().details().is_empty(), "Escape should close the details")
	check(office().screen == Office.Screen.TRANSPORT_OFFERS, "closing the details should stay on Transport offers")
	await press(&"ui_cancel")
	check(office().screen == Office.Screen.MAIN, "Escape with no details open should return to the main screen")


func test_up_and_down_move_between_the_rows_and_stop_at_both_ends() -> void:
	await open_transport_offers()
	check(offers().selected_index == 0, "the first row should be selected, got %d" % offers().selected_index)
	await press(&"ui_up")
	check(offers().selected_index == 0, "Up on the first row should keep it, got %d" % offers().selected_index)
	await select_row(4)
	await press(&"ui_down")
	check(offers().selected_index == 4, "Down on the last row should keep it, got %d" % offers().selected_index)


func test_offers_too_big_for_the_ship_show_why_and_fuel_never_disables_one() -> void:
	var too_many := known_offer(5, 0.0)
	var too_heavy := known_offer(0, 8100.0)
	var fits := known_offer(4, 8000.0)
	for offer in [too_many, too_heavy, fits]:
		economy().put_offer(offer)
	await open_transport_offers()
	check(reason_for(too_many) == "NOT ENOUGH PASSENGER SEATS", "5 passengers on a Sparrow should read NOT ENOUGH PASSENGER SEATS, got %s" % reason_for(too_many))
	check(reason_for(too_heavy) == "OVERLOADED", "8 100 kg on a Sparrow should read OVERLOADED, got %s" % reason_for(too_heavy))
	check(reason_for(fits) == "", "a full Sparrow's Load should fit, even with less room for fuel, got %s" % reason_for(fits))
	await press(&"ui_cancel")
	await open_ship_selection()
	await browse_to(ShipType.HALO)
	await press(&"ui_accept")
	await press(&"ui_accept")
	await open_transport_offers()
	check(reason_for(too_many) == "", "5 passengers should fit a Halo, got %s" % reason_for(too_many))


func test_every_new_pool_starts_with_five_offers_open_for_180_to_600_seconds() -> void:
	await open_transport_offers()
	for seed_value in [1, 2, 3, 4, 5, 6, 7, 8]:
		economy().reseed(seed_value)
		await frames(1)
		check(offers().rows().size() == 5, "seed %d should give 5 offers, gives %s" % [seed_value, offers().rows()])
		for offer in economy().offers:
			check(offer.time_left > 179.0 and offer.time_left <= 600.0,
				"seed %d: offer #%03d should be open for 180-600 s, has %.1f s" % [seed_value, offer.number, offer.time_left])


func test_offers_that_dont_fit_are_never_replaced() -> void:
	var too_big: Array[TransportOffer] = []
	for i in Economy.MAX_OFFERS:
		too_big.append(known_offer(10, 0.0, 1000.0 + i))
		economy().put_offer(too_big[i])
	await open_transport_offers()
	await seconds(1.0)
	for offer in too_big:
		check(listed("#%03d " % offer.number), "offer #%03d should stay though nothing fits, lists %s" % [offer.number, offers().rows()])
	check(offers().rows().size() == 7, "the list should hold 7 offers, lists %s" % offers().rows())


func test_return_does_nothing_once_every_offer_is_gone() -> void:
	await open_transport_offers()
	economy().reseed(1)
	for offer in economy().offers:
		offer.time_left = 0.5
	await seconds(1.0)
	check(offers().rows().is_empty(), "every offer should have expired, lists %s" % offers().rows())
	await press(&"ui_down")
	await press(&"ui_accept")
	check(offers().details().is_empty(), "Return on an empty list should open nothing")
	check(office().screen == Office.Screen.TRANSPORT_OFFERS, "the screen should stay on Transport offers")


func test_offer_timers_keep_running_in_flight() -> void:
	await choose_ship()
	place(Vector2(World.WORLD_WIDTH / 4.0, World.BORDER_Y - 600.0))
	var offer := known_offer(1, 0.0, 100.0)
	economy().put_offer(offer)
	await seconds(1.0)
	check_near(offer.time_left, 99.0, 0.05, "seconds left after 1 s of flight")


func test_offer_numbers_start_again_from_001_on_a_new_run() -> void:
	economy().put_offer(known_offer(1, 0.0))
	await choose_ship()
	await restart()
	await open_transport_offers()
	check(offers().rows()[0].begins_with("#001 "), "a new run should number offers from #001, lists %s" % offers().rows())
	check(not " TEST RUN " in " ".join(offers().rows()), "the last run's known offer should be gone, lists %s" % offers().rows())
