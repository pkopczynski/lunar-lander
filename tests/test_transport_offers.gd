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


func test_return_opens_and_closes_an_offers_details_and_leaves_the_cursor_on_its_row() -> void:
	economy().put_offer(known_offer(3, 1200.0))
	await open_transport_offers()
	await select_row(5)
	check(offers().details(5).is_empty(), "no details should show before Return")
	await press(&"ui_accept")
	var details := offers().details(5)
	for expected: String in ["PASSENGERS 3", "CARGO 1 200 KG", "DEADLINE 3H 00M", "TRADER TEST TRADER", "VALUE €420", "ACCEPT"]:
		check(expected in details, "the details should show %s, show %s" % [expected, details])
	check(offers().list.expanded_rows() == [5], "the details should open under the selected row, open %s" % [offers().list.expanded_rows()])
	check(offers().list.selected_index() == 5 and not offers().on_accept(), "opening should leave the cursor on the row")
	await press(&"ui_accept")
	check(offers().list.expanded_rows().is_empty(), "Return on an open row should close it, open %s" % [offers().list.expanded_rows()])
	check(offers().list.selected_index() == 5, "closing should leave the cursor on the row, got %d" % offers().list.selected_index())


func test_closing_an_offer_shrinks_its_details_back_and_reopening_grows_them_from_there() -> void:
	var offer := known_offer(3, 1200.0)
	economy().put_offer(offer)
	await open_transport_offers()
	await select_row(5)
	await press(&"ui_accept")
	await seconds(ExpandableList.OPEN_TIME)
	check(offers().list.open_share(offer) == 1.0, "the details should be fully open")
	await press(&"ui_accept")
	check(offers().list.expanded_rows().is_empty() and offers().details(5).is_empty(), "Return should close the offer at once")
	await frames(3)
	var shrinking := offers().list.open_share(offer)
	check(shrinking > 0.0 and shrinking < 1.0, "the details should still be shrinking, %s open" % shrinking)
	await press(&"ui_accept")
	await frames(1)
	check(offers().list.open_share(offer) >= shrinking, "reopening should grow from where it was, %s after %s" % [offers().list.open_share(offer), shrinking])
	await press(&"ui_accept")
	await seconds(ExpandableList.OPEN_TIME + 0.05)
	check(offers().list.open_share(offer) == 0.0, "the details should be gone once shrunk")


func test_several_offers_can_be_open_at_once() -> void:
	await open_transport_offers()
	await select_row(1)
	await press(&"ui_accept")
	await select_row(3)
	await press(&"ui_accept")
	check(offers().list.expanded_rows() == [1, 3], "both offers should be open, open %s" % [offers().list.expanded_rows()])
	check(not offers().details(1).is_empty() and not offers().details(3).is_empty(), "each open offer should show its details")
	await press(&"ui_accept")
	check(offers().list.expanded_rows() == [1], "closing one should leave the other open, open %s" % [offers().list.expanded_rows()])


func test_escape_closes_only_the_offer_under_the_cursor_and_then_returns_to_the_main_screen() -> void:
	var first := known_offer(1, 0.0)
	var second := known_offer(1, 0.0)
	for offer in [first, second]:
		economy().put_offer(offer)
	await open_transport_offers()
	await open_details(first)
	await open_details(second)
	await select_row(5)
	await press(&"ui_down")
	check(offers().on_accept(), "Down from an open row should reach its ACCEPT")
	await press(&"ui_cancel")
	check(offers().list.expanded_rows() == [6], "Escape on an ACCEPT should close only its offer, open %s" % [offers().list.expanded_rows()])
	check(offers().list.selected_index() == 5 and not offers().on_accept(), "Escape should put the cursor on the closed offer's row")
	check(office().screen == Office.Screen.TRANSPORT_OFFERS, "closing an offer should stay on Transport offers")
	await select_row(6)
	await press(&"ui_cancel")
	check(offers().list.expanded_rows().is_empty(), "Escape on an open row should close it, open %s" % [offers().list.expanded_rows()])
	check(office().screen == Office.Screen.TRANSPORT_OFFERS, "closing an offer should stay on Transport offers")
	await press(&"ui_cancel")
	check(office().screen == Office.Screen.MAIN, "Escape with no open offer under the cursor should return to the main screen")


func test_up_and_down_visit_the_accept_of_each_open_offer_that_fits_and_skip_a_dimmed_one() -> void:
	var fits := known_offer(1, 0.0)
	var too_many := known_offer(5, 0.0)
	for offer in [fits, too_many]:
		economy().put_offer(offer)
	await open_transport_offers()
	for offer in [fits, too_many]:
		await open_details(offer)
	await select_row(5)
	var visited: Array = []
	for i in 3:
		await press(&"ui_down")
		visited.append([offers().list.selected_index(), offers().on_accept()])
	check(visited == [[5, true], [6, false], [6, false]],
		"Down should visit row 5's ACCEPT, then row 6, skipping its dimmed ACCEPT, visited %s" % [visited])
	await press(&"ui_up")
	check(offers().list.selected_index() == 5 and offers().on_accept(), "Up should come back to row 5's ACCEPT")


func test_accept_on_one_of_two_open_offers_accepts_only_that_offer() -> void:
	var first := known_offer(1, 0.0)
	var second := known_offer(2, 0.0)
	for offer in [first, second]:
		economy().put_offer(offer)
	await open_transport_offers()
	await open_details(first)
	await open_details(second)
	await press(&"ui_down")
	check(offers().on_accept() and offers().list.selected_index() == 6, "Down should reach the second offer's ACCEPT")
	await press(&"ui_accept")
	check(office().popup == Office.PopupKind.ACCEPT_OFFER, "ACCEPT should ask ARE YOU SURE?")
	await press(&"ui_accept")
	check(economy().contracts.size() == 1 and economy().contracts[0] == second, "only the second offer should be accepted, got %d Contracts" % economy().contracts.size())
	check(first in economy().offers, "the first offer should stay listed")
	check(offers().list.expanded_rows() == [economy().offers.find(first)], "the first offer should stay open, open %s" % [offers().list.expanded_rows()])


func test_switching_columns_keeps_offers_open() -> void:
	await open_transport_offers()
	await select_row(2)
	await press(&"ui_accept")
	await press(&"ui_right")
	check(offers().list.expanded_rows() == [2], "moving to the Contracts should keep the offer open, open %s" % [offers().list.expanded_rows()])
	await press(&"ui_left")
	check(offers().list.expanded_rows() == [2], "moving back should keep the offer open, open %s" % [offers().list.expanded_rows()])
	check(offers().list.selected_index() == 2, "the cursor should stay on its row, got %d" % offers().list.selected_index())


func test_up_and_down_move_between_the_rows_and_stop_at_both_ends() -> void:
	await open_transport_offers()
	check(offers().list.selected_index() == 0, "the first row should be selected, got %d" % offers().list.selected_index())
	await press(&"ui_up")
	check(offers().list.selected_index() == 0, "Up on the first row should keep it, got %d" % offers().list.selected_index())
	await select_row(4)
	await press(&"ui_down")
	check(offers().list.selected_index() == 4, "Down on the last row should keep it, got %d" % offers().list.selected_index())


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
	check(offers().list.expanded_rows().is_empty(), "Return on an empty list should open nothing")
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


func test_a_tall_list_scrolls_to_the_last_accept_and_marks_what_lies_beyond() -> void:
	var known: Array[TransportOffer] = []
	for i in Economy.MAX_OFFERS:
		known.append(known_offer(1, 0.0, 1000.0 + i))
		economy().put_offer(known[i])
	await open_transport_offers()
	for offer in known:
		await open_details(offer)
	await select_row(0)
	await seconds(0.5)
	check(offers().list.scroll == 0.0 and not offers().list.more_above(), "the cursor on the first row should keep the list at its top, scrolled %s" % offers().list.scroll)
	check(offers().list.more_below(), "7 open offers should overflow the list")
	await select_row(known.size() - 1)
	await press(&"ui_down")
	await seconds(0.5)
	check(offers().on_accept(), "Down should reach the last offer's ACCEPT")
	check(offers().list.scroll > 0.0, "reaching the last ACCEPT should scroll the list")
	check(offers().list.cursor_in_view(), "the last ACCEPT should be scrolled into view, scrolled %s" % offers().list.scroll)
	check(offers().list.more_above() and not offers().list.more_below(), "at the bottom the list should mark content above only")
	await press(&"ui_accept")
	await press(&"ui_accept")
	check(known[-1] in economy().contracts, "the last ACCEPT should accept its offer")


func test_opening_a_dimmed_last_offer_at_the_bottom_scrolls_its_details_into_view() -> void:
	var known: Array[TransportOffer] = []
	for i in Economy.MAX_OFFERS:
		known.append(known_offer(5 if i == Economy.MAX_OFFERS - 1 else 1, 0.0, 1000.0 + i))
		economy().put_offer(known[i])
	await open_transport_offers()
	check(reason_for(known[-1]) != "", "the last offer should be dimmed")
	for offer in known:
		await open_details(offer)
	await seconds(0.5)
	check(offers().list.selected_index() == known.size() - 1 and not offers().on_accept(), "the cursor should be on the last row")
	check(offers().list.more_above() and not offers().list.more_below(),
		"the dimmed last offer's details should be scrolled into view, scrolled %s" % offers().list.scroll)
