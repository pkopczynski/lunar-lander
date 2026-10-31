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


func test_an_offer_whose_time_runs_out_disappears_and_the_list_refills_to_five() -> void:
	await open_transport_offers()
	var offer := known_offer(2, 0.0, 1.5)
	economy().put_offer(offer)
	var row := TransportOffersScreen.row_text(offer)
	check(row in offers().rows(), "the known offer should be listed, lists %s" % offers().rows())
	await seconds(2.0)
	check(not listed("#%03d " % offer.number), "the expired offer should be gone, lists %s" % offers().rows())
	check(offers().rows().size() == 5, "the list should refill to 5, lists %s" % offers().rows())


func test_return_expands_one_offers_details_at_a_time_and_escape_collapses_them() -> void:
	economy().put_offer(known_offer(3, 1200.0))
	await open_transport_offers()
	await select_row(4)
	check(offers().details().is_empty(), "no details should show before Return")
	await press(&"ui_accept")
	var details := offers().details()
	for expected: String in ["PASSENGERS 3", "CARGO 1 200 KG", "DEADLINE 1:30", "TRADER TEST TRADER", "VALUE €420", "ACCEPT"]:
		check(expected in details, "the details should show %s, show %s" % [expected, details])
	check(offers().expanded_row() == 4, "the details should open under the selected row, got %d" % offers().expanded_row())
	await press(&"ui_up")
	await press(&"ui_accept")
	check(offers().expanded_row() == 3, "Return on another row should open its details instead, got %d" % offers().expanded_row())
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
	check(reason_for(too_heavy) == "CARGO CAPACITY EXCEEDED", "8 100 kg on a Sparrow should read CARGO CAPACITY EXCEEDED, got %s" % reason_for(too_heavy))
	check(reason_for(fits) == "", "a full Sparrow's Load should fit, even with less room for fuel, got %s" % reason_for(fits))
	await press(&"ui_cancel")
	await open_ship_selection()
	await browse_to(ShipType.HALO)
	await press(&"ui_accept")
	await press(&"ui_accept")
	await open_transport_offers()
	check(reason_for(too_many) == "", "5 passengers should fit a Halo, got %s" % reason_for(too_many))


func test_at_least_one_offer_fits_the_sparrow_over_several_seeds() -> void:
	await open_transport_offers()
	for seed_value in [1, 2, 3, 4, 5, 6, 7, 8]:
		economy().reseed(seed_value)
		await frames(1)
		check(offers().rows().size() == 5, "seed %d should give 5 offers, gives %s" % [seed_value, offers().rows()])
		check("" in offers().reasons(), "seed %d should give an offer the Sparrow can take, reasons %s" % [seed_value, offers().reasons()])


func test_when_nothing_fits_the_offer_closest_to_expiring_is_replaced_right_away() -> void:
	var too_big: Array[TransportOffer] = []
	for i in Economy.MAX_OFFERS:
		too_big.append(known_offer(10, 0.0, TransportOffer.MAX_EXPIRY + 100.0 + i))
		economy().put_offer(too_big[i])
	await open_transport_offers()
	check(not listed("#%03d " % too_big[0].number), "the offer closest to expiring should be gone, lists %s" % offers().rows())
	for i in range(1, Economy.MAX_OFFERS):
		check(listed("#%03d " % too_big[i].number), "the other offers should stay, lists %s" % offers().rows())
	check(offers().rows().size() == 5, "the list should hold 5 offers, lists %s" % offers().rows())
	check("" in offers().reasons(), "the replacement should fit the Sparrow, reasons %s" % offers().reasons())


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
	# Not "#006 is gone": a new pool with nothing the Sparrow fits replaces one at once, taking #006.
	check(not " TEST RUN " in " ".join(offers().rows()), "the last run's known offer should be gone, lists %s" % offers().rows())
