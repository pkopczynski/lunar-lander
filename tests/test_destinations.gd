extends "res://tests/scene_test.gd"
# Every Transport offer goes to a destination, and the Contracts share one.


# A long-lived one-passenger offer to that location.
func offer_to(location: Location) -> TransportOffer:
	var offer := known_offer(1, 0.0)
	offer.destination = location
	return offer


func test_every_offer_goes_to_the_valley_or_the_mine_shown_in_its_row_and_details() -> void:
	await open_transport_offers()
	var seen := {}
	for seed_value in 20:
		economy().reseed(seed_value)
		for i in economy().offers.size():
			var offer := economy().offers[i]
			check(offer.destination in [Location.VALLEY, Location.MINE],
				"offer #%03d should go to the Valley or the Mine" % offer.number)
			check(" %s " % offer.destination.name in offers().rows()[i],
				"the row should name the destination %s, got %s" % [offer.destination.name, offers().rows()[i]])
			seen[offer.destination] = true
	check(seen.size() == 2, "both the Valley and the Mine should come up over 100 offers")
	var mine := offer_to(Location.MINE)
	economy().put_offer(mine)
	await open_details(mine)
	check("DESTINATION MINE" in offers().details(economy().offers.find(mine)),
		"the details should show DESTINATION MINE, got %s" % offers().details(economy().offers.find(mine)))


# From START LOADING, Up to the DESTINATION row.
func up_to_destination() -> void:
	while offers().selected_mission_line() != "DESTINATION":
		await press(&"ui_up")


func test_the_first_contract_sets_the_destination_and_locks_the_row() -> void:
	var mine := offer_to(Location.MINE)
	economy().put_offer(mine)
	await open_transport_offers()
	check(offers().mission_lines()[0] == "DESTINATION VALLEY", "a run starts at the Valley, got %s" % offers().mission_lines())
	await accept(mine)
	check(offers().mission_lines()[0] == "DESTINATION MINE",
		"accepting a Mine offer should set DESTINATION MINE, got %s" % offers().mission_lines())
	await press(&"ui_right")
	await up_to_destination()
	await press(&"ui_accept")
	check(offers().mission_lines()[0] == "DESTINATION MINE",
		"Return on DESTINATION should do nothing with Contracts, got %s" % offers().mission_lines())
	check(office().popup == Office.PopupKind.NONE and office().showing, "Return on DESTINATION should open nothing")


func test_with_contracts_offers_for_another_destination_are_dimmed_and_cant_be_accepted() -> void:
	var mine := offer_to(Location.MINE)
	var valley := offer_to(Location.VALLEY)
	var also_mine := offer_to(Location.MINE)
	for offer in [mine, valley, also_mine]:
		economy().put_offer(offer)
	await open_transport_offers()
	check(reason_for(valley) == "", "without Contracts every destination can be taken, got %s" % reason_for(valley))
	await accept(mine)
	check(reason_for(valley) == "OTHER DESTINATION", "a Valley offer should read OTHER DESTINATION, got %s" % reason_for(valley))
	check(reason_for(also_mine) == "", "another Mine offer should still fit, got %s" % reason_for(also_mine))
	await open_details(valley)
	await press(&"ui_down")
	check(not offers().on_accept(), "Down should skip the Valley offer's ACCEPT")
	await accept(also_mine)


func test_confirming_are_you_sure_checks_the_destination_again() -> void:
	var mine := offer_to(Location.MINE)
	var valley := offer_to(Location.VALLEY)
	economy().put_offer(mine)
	economy().put_offer(valley)
	await open_transport_offers()
	await open_details(valley)
	await press(&"ui_down")
	await press(&"ui_accept")
	check(office().popup == Office.PopupKind.ACCEPT_OFFER, "ACCEPT should ask ARE YOU SURE?")
	economy().accept(mine)
	await press(&"ui_accept")
	check(not valley in economy().contracts, "Yes shouldn't accept an offer for another destination than the Contracts'")
	check(valley in economy().offers, "the Valley offer should stay listed")


func test_removing_the_last_contract_unlocks_the_destination_keeping_its_value() -> void:
	var first := offer_to(Location.MINE)
	var second := offer_to(Location.MINE)
	economy().put_offer(first)
	economy().put_offer(second)
	await open_transport_offers()
	await accept(first)
	await accept(second)
	await press(&"ui_right")
	for contract in [first, second]:
		await up_to_destination()
		await press(&"ui_up")
		await press(&"ui_accept")
		check(office().popup == Office.PopupKind.REMOVE_CONTRACT, "Return on a Contract should ask REMOVE CONTRACT?")
		await press(&"ui_left")
		await press(&"ui_accept")
		if not economy().contracts.is_empty():
			await press(&"ui_down")
			await up_to_destination()
			await press(&"ui_accept")
			check(offers().mission_lines()[0] == "DESTINATION MINE", "one Contract left should keep the row locked")
	check(economy().contracts.is_empty(), "both Contracts should be removed")
	check(offers().mission_lines()[0] == "DESTINATION MINE",
		"removing the last Contract should keep DESTINATION MINE, got %s" % offers().mission_lines())
	await up_to_destination()
	await press(&"ui_accept")
	check(offers().mission_lines()[0] == "DESTINATION VALLEY",
		"Return should cycle DESTINATION again once unlocked, got %s" % offers().mission_lines())


func test_reopening_the_office_keeps_the_contracts_destination() -> void:
	var mine := offer_to(Location.MINE)
	economy().put_offer(mine)
	await open_transport_offers()
	await accept(mine)
	await press(&"ui_cancel")
	await press(&"ui_cancel")
	await wait_for_terminal()
	office().open()
	await wait_for_terminal()
	check(offers().mission_lines()[0] == "DESTINATION MINE",
		"with Contracts the row should open on their destination, got %s" % offers().mission_lines())


func test_start_loading_takes_the_surface_to_the_contracts_destination() -> void:
	await start_loading([offer_to(Location.MINE)])
	check(world().location == Location.MINE, "START LOADING should make the Mine the location")
	check(hud().clock_text().begins_with("MINE  "), "the HUD clock line should show the Mine, got %s" % hud().clock_text())


func test_the_hud_deadline_names_the_destination() -> void:
	await start_loading([offer_to(Location.MINE)])
	clock().minutes = 14 * 60 + 0.5
	# 3 s + 1 passenger: loading finishes at 14:08, and 90 s is 3 in-game hours.
	await seconds(4.5)
	check(economy().phase == Economy.Phase.DELIVERING, "loading should have finished")
	check(hud().delivery_text() == "MINE BY 17:08", "the HUD deadline should name the Mine, got %s" % hud().delivery_text())
	clock().move_to(Location.VALLEY)
	check(hud().clock_text().begins_with("VALLEY  "), "the clock line should still show the current location")
	check(hud().delivery_text() == "MINE BY 17:08", "the deadline should keep the destination, got %s" % hud().delivery_text())
	await seconds(91.0)
	check(hud().delivery_text() == "MINE OVERDUE SINCE 17:08", "the overdue line should name the Mine, got %s" % hud().delivery_text())
