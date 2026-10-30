extends "res://tests/scene_test.gd"
# The two cargo limits on the Transport offers screen: the full-Tank cargo (the cargo that
# still leaves room for a full Tank) and the maximum capacity (the hard limit).


func test_the_cargo_line_compares_against_the_full_tank_cargo_of_each_ship_type() -> void:
	await open_transport_offers()
	check("CARGO 0/7 000 KG" in offers().summary(), "an empty Sparrow's full-Tank cargo, got %s" % offers().summary())
	for expected: Array in [[ShipType.HALO, "CARGO 0/10 000 KG"], [ShipType.MULE, "CARGO 0/9 000 KG"]]:
		await switch_ship(expected[0])
		check(expected[1] in offers().summary(), "%s's full-Tank cargo should read %s, got %s" % [expected[0].name, expected[1], offers().summary()])


func test_the_full_tank_cargo_drops_by_each_accepted_passengers_mass() -> void:
	var crew := known_offer(3, 0.0)
	economy().put_offer(crew)
	await open_transport_offers()
	await accept(crew)
	check("CARGO 0/6 760 KG" in offers().summary(), "3 passengers should take 240 kg off the full-Tank cargo, got %s" % offers().summary())


func test_cargo_past_the_full_tank_cargo_is_accepted_and_turns_red_with_fuel_limited() -> void:
	var at_the_line := known_offer(0, 7000.0)
	var past_it := known_offer(0, 500.0)
	for offer in [at_the_line, past_it]:
		economy().put_offer(offer)
	await open_transport_offers()
	await accept(at_the_line)
	check(offers().red_summary_lines().is_empty(), "the full-Tank cargo itself should show nothing red, got %s" % offers().red_summary_lines())
	check(not has_fuel_limited(offers().summary()), "no FUEL LIMITED at the full-Tank cargo, got %s" % offers().summary())
	await accept(past_it)
	var red := offers().red_summary_lines()
	check(red == PackedStringArray(["CARGO 7 500/7 000 KG", "FUEL LIMITED: 4 500/5 000 KG"]),
		"CARGO and FUEL LIMITED should both be red past the full-Tank cargo, red %s of %s" % [red, offers().summary()])


func test_an_offer_past_the_maximum_capacity_reads_overloaded_and_cant_be_accepted() -> void:
	var too_heavy := known_offer(0, 8100.0)
	economy().put_offer(too_heavy)
	await open_transport_offers()
	check(reason_for(too_heavy) == "OVERLOADED", "8 100 kg on a Sparrow should read OVERLOADED, got %s" % reason_for(too_heavy))
	check(red_note_for(too_heavy) == "", "an overloaded offer gets no FUEL LIMITED note, got %s" % red_note_for(too_heavy))
	await open_details(too_heavy)
	await press(&"ui_accept")
	check(office().popup == Office.PopupKind.NONE, "ACCEPT on an overloaded offer should do nothing")


func test_a_fitting_offer_that_would_limit_fuel_stays_lit_with_a_red_note_and_can_be_accepted() -> void:
	var light := known_offer(0, 7000.0)
	var heavy := known_offer(1, 7000.0)
	for offer in [light, heavy]:
		economy().put_offer(offer)
	await open_transport_offers()
	check(red_note_for(light) == "", "an offer that leaves a full Tank should have no note, got %s" % red_note_for(light))
	check(reason_for(heavy) == "", "a heavy offer within the maximum capacity should stay lit, got %s" % reason_for(heavy))
	check(red_note_for(heavy) == "FUEL LIMITED", "a heavy offer should note FUEL LIMITED in red, got %s" % red_note_for(heavy))
	await accept(heavy)
	check(has_fuel_limited(offers().summary()), "accepting it should limit the fuel, got %s" % offers().summary())


func switch_ship(type: ShipType) -> void:
	await press(&"ui_cancel")
	await open_ship_selection()
	await browse_to(type)
	await press(&"ui_accept")
	await press(&"ui_accept")
	await open_transport_offers()


func red_note_for(offer: TransportOffer) -> String:
	var row := economy().offers.find(offer)
	check(row != -1, "offer #%03d should be listed" % offer.number)
	return offers().red_notes()[row] if row != -1 else "(not listed)"


func has_fuel_limited(lines: PackedStringArray) -> bool:
	for line in lines:
		if line.begins_with("FUEL LIMITED"):
			return true
	return false
