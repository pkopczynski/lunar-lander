extends "res://tests/scene_test.gd"
# The Shipyard: every Ship type on sale with its price; buying one adds a named owned ship with a
# full tank to a berth, without changing the ship in service.


func test_the_shipyard_opens_on_the_sparrow_with_its_price_tank_and_what_is_owned() -> void:
	await open_shipyard()
	var lines := shipyard().lines()
	for expected: String in ["SPARROW", "SMALL, LIGHT AND QUICK. BUILT FOR SHORT HOPS.", "PRICE €250 000",
			"TANK 6 000 L FULL", "SEATS 4", "CARGO 7 200 KG", "MAX CAPACITY 8 000 KG", "THRUST ■■■■■",
			"HANDLING ■■■■■", "< 1/3 >", "OWNED: 1", "HANGAR 1/4", "BUY €250 000"]:
		check(expected in lines, "the Sparrow's Ship offer should show %s, shows %s" % [expected, lines])
	check(shipyard().picture() == ShipType.SPARROW.hull, "the picture should be the Sparrow's hull")


func test_each_ship_type_has_its_price() -> void:
	economy().balance = 1000000
	await open_shipyard()
	for expected: Array in [[ShipType.MULE, "€400 000"], [ShipType.HALO, "€650 000"], [ShipType.SPARROW, "€250 000"]]:
		await browse_to(expected[0])
		check(shipyard().buy_text() == "BUY " + expected[1], "the %s should cost %s, shows %s"
			% [expected[0].name, expected[1], shipyard().buy_text()])
		check("OWNED: %d" % (1 if expected[0] == ShipType.SPARROW else 0) in shipyard().lines(),
			"the %s should show how many are owned, shows %s" % [expected[0].name, shipyard().lines()])


func test_buying_a_mule_takes_its_price_and_opens_its_ship_page_with_a_full_tank() -> void:
	economy().balance = 500000
	await open_shipyard()
	await browse_to(ShipType.MULE)
	await press(&"ui_accept")
	check(office().popup == Office.PopupKind.CONFIRM, "BUY should ask first")
	check(office().popup_text() == "BUY A MULE FOR €400 000?", "the confirm should name the Mule and its price, got %s"
		% office().popup_text())
	check(office().selected_button == Office.Choice.YES, "Yes should be selected")
	await press(&"ui_accept")
	check(economy().balance == 100000, "the Mule's price should come off the balance, balance %d" % economy().balance)
	check(office().bank_account.rows()[0] == "SHIP PURCHASE — MULE 1  SHIP  -€400 000",
		"the purchase should be a Transaction naming the ship, shows %s" % office().bank_account.rows())
	check(office().screen == Office.Screen.SHIP_PAGE and hangar_screen().ship.name == "MULE 1",
		"the Terminal should open MULE 1's Ship page")
	check(office().screen_title() == "HANGAR // MULE 1", "the header should read HANGAR // MULE 1, got %s" % office().screen_title())
	check(office().notice() == "MULE 1 IS IN THE HANGAR", "a notice should confirm the purchase, got %s" % office().notice())
	var mule := owned_ship(ShipType.MULE)
	check(mule != null and is_equal_approx(mule.fuel, ShipType.MULE.tank), "the Mule should come with a full tank")
	check(hangar().ships.size() == 2, "the Mule should take a berth")
	check(hangar().in_service.name == "SPARROW 1" and lander().ship_type == ShipType.SPARROW,
		"buying should not change the ship in service")


func test_a_purchase_opens_to_show_the_ship_and_its_price() -> void:
	economy().balance = 300000
	await buy_ship(ShipType.SPARROW)
	await press(&"ui_cancel")
	await press(&"ui_cancel")
	check(office().screen == Office.Screen.MAIN, "Escape from the Ship page should go through the Hangar to the main screen")
	await open_bank_account()
	await press(&"ui_accept")
	check(office().bank_account.details(0) == PackedStringArray(["SHIP SPARROW 2", "PRICE €250 000", "PAYOUT -€250 000"]),
		"the purchase's details should show the ship and its price, show %s" % office().bank_account.details(0))


func test_buying_needs_the_balance_to_stay_at_or_above_zero() -> void:
	await open_shipyard()
	check(shipyard().reason() == "NOT ENOUGH MONEY: €230 000 SHORT", "€20 000 should be €230 000 short of a Sparrow, got %s"
		% shipyard().reason())
	check("NOT ENOUGH MONEY: €230 000 SHORT" in shipyard().lines(), "the reason should show")
	await press(&"ui_accept")
	check(office().popup == Office.PopupKind.NONE, "Return on a blocked BUY should not ask")
	check(office().notice() == "NOT ENOUGH MONEY: €230 000 SHORT", "Return should show the reason, got %s" % office().notice())
	check(hangar().ships.size() == 1 and economy().balance == 20000, "nothing should be bought")
	economy().balance = 250000
	check(shipyard().reason() == "", "exactly the price should be enough, got %s" % shipyard().reason())
	await press(&"ui_accept")
	await press(&"ui_accept")
	check(economy().balance == 0 and hangar().ships.size() == 2, "buying with exactly the price should leave €0")


func test_buying_is_blocked_while_in_debt() -> void:
	economy().balance = -100
	await open_shipyard()
	check(shipyard().reason() == "NOT ENOUGH MONEY: €250 100 SHORT", "in debt the Sparrow should be €250 100 short, got %s"
		% shipyard().reason())


func test_a_full_hangar_blocks_buying() -> void:
	economy().balance = 10000000
	for i in 3:
		hangar().buy(ShipType.SPARROW)
	await open_shipyard()
	check(shipyard().lines().has("HANGAR 4/4"), "the Shipyard should show HANGAR 4/4, shows %s" % shipyard().lines())
	check(shipyard().reason() == "HANGAR FULL 4/4: SELL A SHIP FIRST", "a full Hangar should block buying, got %s"
		% shipyard().reason())
	await press(&"ui_accept")
	check(office().popup == Office.PopupKind.NONE and hangar().ships.size() == 4, "Return should buy nothing")


func test_buying_works_with_contracts() -> void:
	economy().balance = 300000
	economy().contracts.append(known_offer(1, 0.0))
	await open_shipyard()
	check(shipyard().reason() == "", "Contracts should not block buying, got %s" % shipyard().reason())
	await press(&"ui_accept")
	await press(&"ui_accept")
	check(hangar().ships.size() == 2, "the Sparrow should be bought with Contracts accepted")


func test_no_or_escape_in_the_confirm_buys_nothing() -> void:
	economy().balance = 1000000
	await open_shipyard()
	await browse_to(ShipType.HALO)
	await press(&"ui_accept")
	await press(&"ui_right")
	check(office().selected_button == Office.Choice.NO, "Right should select No")
	await press(&"ui_left")
	check(office().selected_button == Office.Choice.YES, "Left should select Yes")
	await press(&"ui_right")
	await press(&"ui_accept")
	check(office().popup == Office.PopupKind.NONE and office().screen == Office.Screen.SHIPYARD, "No should stay in the Shipyard")
	check(shipyard().selected() == ShipType.HALO, "No should return to the Halo Ship offer")
	await press(&"ui_accept")
	await press(&"ui_cancel")
	check(office().popup == Office.PopupKind.NONE, "Escape should close the confirm")
	check(hangar().ships.size() == 1 and economy().balance == 1000000, "nothing should be bought")


func test_names_count_per_type() -> void:
	economy().balance = 10000000
	var first := await buy_ship(ShipType.MULE)
	await leave_office()
	var names := [first.name]
	await dock_and_enter()
	names.append((await buy_ship(ShipType.MULE)).name)
	await leave_office()
	await dock_and_enter()
	names.append((await buy_ship(ShipType.SPARROW)).name)
	check(names == ["MULE 1", "MULE 2", "SPARROW 2"], "names should count per type, got %s" % [names])


func test_browsing_wraps_around_any_number_of_ship_offers() -> void:
	await open_shipyard()
	var extra := ShipType.sparrow()
	extra.name = "Test ship"
	ShipType.ALL.append(extra)
	var count := ShipType.ALL.size()
	for i in count - 1:
		await press(&"ui_right")
	var after_right := shipyard().selected().name
	var indicator := shipyard().indicator()
	await press(&"ui_right")
	var after_wrap := shipyard().selected().name
	await press(&"ui_left")
	var after_left_wrap := shipyard().selected().name
	ShipType.ALL.erase(extra)
	check(after_right == "Test ship", "Right should browse to the last Ship offer, got %s" % after_right)
	check(indicator == "< %d/%d >" % [count, count], "the indicator should read < %d/%d >, got %s" % [count, count, indicator])
	check(after_wrap == "Sparrow", "Right on the last Ship offer should wrap to the first, got %s" % after_wrap)
	check(after_left_wrap == "Test ship", "Left on the first Ship offer should wrap to the last, got %s" % after_left_wrap)


# Docks in the parking spot and answers Yes to ENTER THE OFFICE?.
func dock_and_enter() -> void:
	await dock_in_spot()
	await press(&"ui_left")
	await press(&"ui_accept")
	await wait_for_terminal()
	check(office().showing and office().screen == Office.Screen.MAIN, "Yes should open the Office")
