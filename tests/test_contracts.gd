extends "res://tests/scene_test.gd"


func test_accepting_asks_are_you_sure_and_moves_the_offer_to_the_contracts() -> void:
	economy().reseed(1)
	var offer := known_offer(2, 1500.0)
	economy().put_offer(offer)
	await open_transport_offers()
	await open_details(offer)
	await press(&"ui_accept")
	check(office().popup == Office.PopupKind.ACCEPT_OFFER, "ACCEPT should ask ARE YOU SURE?")
	check(office().popup_text() == "ARE YOU SURE?", "the popup should ask ARE YOU SURE?, got %s" % office().popup_text())
	check(office().selected_button == Office.Choice.YES, "ARE YOU SURE? should have Yes selected")
	await press(&"ui_accept")
	check(office().popup == Office.PopupKind.NONE, "Yes should close the popup")
	check(economy().contracts.size() == 1 and economy().contracts[0] == offer, "Yes should make the offer a Contract")
	check(not listed("#%03d " % offer.number), "the Contract should leave the offer list, lists %s" % offers().rows())
	check(offers().details().is_empty(), "the details should close")
	check("#%03d TEST RUN" % offer.number in offers().contract_lines(),
		"the Contracts column should list it, lists %s" % offers().contract_lines())
	check(offers().rows().size() == 5, "nothing should take the Contract's place, lists %s" % offers().rows())


func test_a_new_offer_arrives_within_90_seconds_of_accepting() -> void:
	economy().reseed(1)
	var offer := known_offer(1, 0.0)
	economy().put_offer(offer)
	await open_transport_offers()
	await accept(offer)
	await seconds(Economy.MIN_OFFER_INTERVAL - 1.0)
	check(offers().rows().size() == 5, "nothing should arrive straight after accepting, lists %s" % offers().rows())
	await seconds(Economy.MAX_OFFER_INTERVAL - Economy.MIN_OFFER_INTERVAL + 1.0)
	check(offers().rows().size() == 6, "a new offer should arrive within 90 s, lists %s" % offers().rows())


func test_an_offer_that_expires_during_are_you_sure_cant_be_accepted_and_shows_offer_expired() -> void:
	var offer := known_offer(1, 0.0, 1.0)
	economy().put_offer(offer)
	await open_transport_offers()
	await open_details(offer)
	await press(&"ui_accept")
	check(office().popup == Office.PopupKind.ACCEPT_OFFER, "ACCEPT should ask ARE YOU SURE?")
	await seconds(1.0)
	check(office().popup == Office.PopupKind.NONE, "the offer expiring should close ARE YOU SURE?")
	check(offers().details().is_empty(), "the offer expiring should close its details")
	check(offers().notice() == "OFFER EXPIRED", "OFFER EXPIRED should show, got %s" % offers().notice())
	await press(&"ui_accept")
	check(economy().contracts.is_empty(), "nothing should be accepted, got %d Contracts" % economy().contracts.size())
	await seconds(TransportOffersScreen.NOTICE_TIME)
	check(offers().notice() == "", "OFFER EXPIRED should only show briefly, got %s" % offers().notice())


func test_an_offer_that_expires_with_its_details_open_closes_them_and_shows_offer_expired() -> void:
	var offer := known_offer(1, 0.0, 1.0)
	economy().put_offer(offer)
	await open_transport_offers()
	await open_details(offer)
	await seconds(1.0)
	check(offers().details().is_empty(), "the offer expiring should close its details")
	check(offers().notice() == "OFFER EXPIRED", "OFFER EXPIRED should show, got %s" % offers().notice())


func test_confirming_an_offer_that_is_already_gone_accepts_nothing() -> void:
	var offer := known_offer(1, 0.0)
	economy().put_offer(offer)
	await open_transport_offers()
	await open_details(offer)
	await press(&"ui_accept")
	# Gone from the pool without the screen hearing of it yet.
	economy().offers.erase(offer)
	await press(&"ui_accept")
	check(economy().contracts.is_empty(), "an offer no longer in the pool should not become a Contract")
	check(offers().notice() == "OFFER EXPIRED", "OFFER EXPIRED should show, got %s" % offers().notice())


func test_offers_that_would_exceed_the_seats_or_cargo_left_are_disabled_with_their_reason() -> void:
	var first := known_offer(3, 5000.0)
	var too_many := known_offer(2, 0.0)
	var too_heavy := known_offer(0, 3500.0)
	var fits := known_offer(1, 3000.0)
	for offer in [first, too_many, too_heavy, fits]:
		economy().put_offer(offer)
	await open_transport_offers()
	check(reason_for(too_many) == "", "2 passengers should fit an empty Sparrow, got %s" % reason_for(too_many))
	await accept(first)
	check(reason_for(too_many) == "NOT ENOUGH PASSENGER SEATS", "2 more passengers than seats left should read NOT ENOUGH PASSENGER SEATS, got %s" % reason_for(too_many))
	check(reason_for(too_heavy) == "OVERLOADED", "3 500 kg on 3 000 kg left should read OVERLOADED, got %s" % reason_for(too_heavy))
	check(reason_for(fits) == "", "what's left should still take 1 passenger and 3 000 kg, got %s" % reason_for(fits))
	await open_details(too_many)
	await press(&"ui_accept")
	check(office().popup == Office.PopupKind.NONE, "ACCEPT on an offer that doesn't fit should do nothing")
	await press(&"ui_cancel")
	await accept(fits)
	check(economy().contracts.size() == 2, "the ship should take both offers, has %d Contracts" % economy().contracts.size())


func test_the_summary_shows_passengers_cargo_and_start_loading() -> void:
	var offer := known_offer(3, 2500.0)
	economy().put_offer(offer)
	await open_transport_offers()
	check(offers().summary() == PackedStringArray(["PASSENGERS 0/4", "CARGO 0/7 000 KG"]),
		"an empty Sparrow's summary, got %s" % offers().summary())
	check(not offers().start_loading_enabled(), "START LOADING should be disabled with no Contracts")
	await accept(offer)
	check(offers().summary() == PackedStringArray(["PASSENGERS 3/4", "CARGO 2 500/6 760 KG"]),
		"the summary should count the Contract, got %s" % offers().summary())
	check(offers().start_loading_enabled(), "START LOADING should be enabled with a Contract")


func test_the_summary_warns_fuel_limited_when_the_load_leaves_less_room_than_a_full_tank() -> void:
	# A Sparrow has 12 000 kg for fuel and Load together, and a 5 000 kg Tank.
	var heavy := known_offer(2, 7000.0)
	economy().put_offer(heavy)
	await open_transport_offers()
	await accept(heavy)
	check("FUEL LIMITED: 4 840/5 000 KG" in offers().summary(),
		"7 160 kg of Load should leave room for 4 840 kg of fuel, got %s" % offers().summary())


func test_no_fuel_warning_while_a_full_tank_still_fits() -> void:
	var light := known_offer(0, 7000.0)
	economy().put_offer(light)
	await open_transport_offers()
	await accept(light)
	check(offers().summary().size() == 2, "7 000 kg of Load leaves room for a full Tank, got %s" % offers().summary())


func test_right_and_left_move_focus_between_the_offers_and_start_loading() -> void:
	var offer := known_offer(1, 0.0)
	economy().put_offer(offer)
	await open_transport_offers()
	await select_row(2)
	await press(&"ui_right")
	check(offers().focus == TransportOffersScreen.Column.CONTRACTS, "Right should move focus to the Contracts column")
	await press(&"ui_accept")
	check(office().showing and office().screen == Office.Screen.TRANSPORT_OFFERS,
		"START LOADING with no Contracts should do nothing")
	await press(&"ui_down")
	await press(&"ui_left")
	check(offers().focus == TransportOffersScreen.Column.OFFERS, "Left should move focus back to the offers")
	check(offers().selected_index == 2, "the offer list should keep its row, got %d" % offers().selected_index)
	await press(&"ui_right")
	await press(&"ui_cancel")
	check(office().screen == Office.Screen.MAIN, "Escape from the Contracts column should return to the main screen")


func test_contracts_survive_leaving_the_office_and_offers_expiring() -> void:
	var offer := known_offer(1, 0.0)
	economy().put_offer(offer)
	await open_transport_offers()
	await accept(offer)
	await press(&"ui_cancel")
	await press(&"ui_cancel")
	await wait_for_terminal()
	check(not office().showing, "Escape on the main screen should close the Office")
	for other in economy().offers:
		other.time_left = 0.5
	await seconds(1.0)
	check(economy().contracts.size() == 1 and economy().contracts[0] == offer,
		"the Contract should survive leaving the Office and offers expiring")


func test_ship_swapping_is_locked_while_contracts_exist() -> void:
	var offer := known_offer(1, 0.0)
	economy().put_offer(offer)
	await open_ship_selection()
	await browse_to(ShipType.HALO)
	check(not "SHIP LOCKED: CONTRACTS ACCEPTED" in office().ship_offer_lines(), "with no Contracts the Halo should not be locked")
	await press(&"ui_cancel")
	await open_transport_offers()
	await accept(offer)
	await press(&"ui_cancel")
	await open_ship_selection()
	check("SHIP LOCKED: CONTRACTS ACCEPTED" not in office().ship_offer_lines(), "the ship in service should not show the lock, shows %s" % office().ship_offer_lines())
	await browse_to(ShipType.HALO)
	check("SHIP LOCKED: CONTRACTS ACCEPTED" in office().ship_offer_lines(), "another Ship offer should show the lock, shows %s" % office().ship_offer_lines())
	await press(&"ui_accept")
	check(office().popup == Office.PopupKind.NONE, "Return on a locked Ship offer should do nothing")
	check(office().screen == Office.Screen.SHIP_SELECTION, "Return on a locked Ship offer should stay on Ship selection")
	check(lander().ship_type == ShipType.SPARROW, "the Sparrow should stay in service")
