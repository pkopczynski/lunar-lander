extends "res://tests/scene_test.gd"
# The Hangar's berths and each owned ship's Ship page: PUT IN SERVICE (the Ship swap) and SELL.


func test_the_hangar_lists_four_berths_with_sparrow_1_in_service() -> void:
	await open_hangar()
	check(hangar_screen().berths_text() == "BERTHS 1/4", "the table should be headed BERTHS 1/4, got %s"
		% hangar_screen().berths_text())
	var rows := hangar_screen().rows()
	check(rows.size() == 4, "there should be a row per berth, shows %s" % rows)
	check(rows[0] == "SPARROW 1 IN SERVICE  100%  6 250 L  –  0",
		"SPARROW 1's row should show its name, IN SERVICE, condition, fuel, parachute and upgrades, got %s" % rows[0])
	for i in range(1, 4):
		check(rows[i] == HangarScreen.EMPTY_BERTH_TEXT, "berth %d should be empty, got %s" % [i + 1, rows[i]])


func test_return_on_an_empty_berth_opens_the_shipyard() -> void:
	await open_hangar()
	await press(&"ui_down")
	await press(&"ui_accept")
	check(office().screen == Office.Screen.SHIPYARD, "Return on an empty berth should open the Shipyard")


func test_return_on_a_ship_opens_its_ship_page() -> void:
	lander().ship.fuel = 2560.0
	await open_hangar()
	await press(&"ui_accept")
	check(office().screen == Office.Screen.SHIP_PAGE, "Return on SPARROW 1 should open its Ship page")
	check(office().screen_title() == "HANGAR // SPARROW 1", "the header should read HANGAR // SPARROW 1, got %s"
		% office().screen_title())
	var lines := hangar_screen().page_lines()
	for expected: String in ["SPARROW 1", "IN SERVICE", "NO UPGRADES", "CONDITION 100%", "FUEL 3 200 / 6 250 L",
			"DRY MASS 10 000 KG", "CARGO 7 000 KG", "VALUE €250 000"]:
		check(expected in lines, "the Ship page should show %s, shows %s" % [expected, lines])
	check(hangar_screen().actions() == PackedStringArray(["PUT IN SERVICE", "REPAIR €0", "SELL €125 000"]),
		"the actions should be PUT IN SERVICE, REPAIR €0 and SELL €125 000, are %s" % hangar_screen().actions())
	await press(&"ui_cancel")
	check(office().screen == Office.Screen.HANGAR, "Escape should go back to the berths table")


func test_the_ship_in_service_cant_be_sold() -> void:
	await open_hangar()
	await press(&"ui_accept")
	check(hangar_screen().reasons() == PackedStringArray(["ALREADY IN SERVICE", "NO DAMAGE", "THE SHIP IN SERVICE CAN'T BE SOLD"]),
		"every action should be blocked for an undamaged ship in service, reasons %s" % hangar_screen().reasons())
	await select_action(HangarScreen.Action.SELL)
	check(office().popup == Office.PopupKind.NONE, "Return on a blocked SELL should not ask")
	check(office().notice() == "THE SHIP IN SERVICE CAN'T BE SOLD", "Return should show the reason, got %s" % office().notice())
	check(hangar().ships.size() == 1 and economy().balance == 20000, "nothing should be sold")


func test_put_in_service_swaps_instantly_and_each_ship_keeps_its_own_fuel() -> void:
	economy().balance = 400000
	lander().ship.fuel = 1200.0
	var mule := await buy_ship(ShipType.MULE)
	mule.fuel = 3000.0
	check(hangar_screen().reasons()[0] == "", "a berth ship should be free to put in service")
	await select_action(HangarScreen.Action.PUT_IN_SERVICE)
	check(office().popup_text() == "PUT MULE 1 IN SERVICE?", "the swap should ask first, got %s" % office().popup_text())
	await press(&"ui_accept")
	check(hangar().in_service == mule and lander().ship_type == ShipType.MULE, "MULE 1 should be in service")
	check(lander().state == Lander.State.DOCKED and lander().is_inside_spot(), "MULE 1 should be Docked in the parking spot")
	check_near(lander().fuel, 3000.0, 0.001, "MULE 1 should fly with the fuel it was left with")
	check(economy().balance == 0, "the swap should be free, balance %d" % economy().balance)
	check(office().showing and office().screen == Office.Screen.SHIP_PAGE, "the Ship page should stay open")
	check("IN SERVICE" in hangar_screen().page_lines(), "MULE 1's page should now read IN SERVICE")
	await press(&"ui_cancel")
	var rows := hangar_screen().rows()
	check(rows[0].begins_with("SPARROW 1  ") and rows[0].contains("1 500 L"),
		"SPARROW 1 should be out of service with its own fuel, got %s" % rows[0])
	check(rows[1].begins_with("MULE 1 IN SERVICE"), "MULE 1 should be tagged IN SERVICE, got %s" % rows[1])


func test_put_in_service_is_blocked_with_contracts() -> void:
	economy().balance = 400000
	var mule := await buy_ship(ShipType.MULE)
	economy().contracts.append(known_offer(1, 0.0))
	check(hangar_screen().reasons()[0] == "LOCKED: CONTRACTS ACCEPTED", "Contracts should block the swap, reasons %s"
		% hangar_screen().reasons())
	await select_action(HangarScreen.Action.PUT_IN_SERVICE)
	check(office().popup == Office.PopupKind.NONE, "Return on a locked PUT IN SERVICE should not ask")
	check(office().notice() == "LOCKED: CONTRACTS ACCEPTED", "Return should show the reason, got %s" % office().notice())
	check(hangar().in_service != mule and lander().ship_type == ShipType.SPARROW, "the Sparrow should stay in service")


func test_selling_pays_half_the_value_records_a_transaction_and_frees_the_berth() -> void:
	economy().balance = 400000
	var mule := await buy_ship(ShipType.MULE)
	mule.fuel = 1000.0
	check(hangar_screen().actions()[HangarScreen.Action.SELL] == "SELL €200 000", "SELL should offer half of €400 000, shows %s"
		% hangar_screen().actions()[HangarScreen.Action.SELL])
	await select_action(HangarScreen.Action.SELL)
	check(office().popup_text() == "SELL MULE 1 FOR €200 000?", "the sale should ask first, got %s" % office().popup_text())
	await press(&"ui_accept")
	check(economy().balance == 200000, "the sale should pay €200 000 (fuel earns nothing), balance %d" % economy().balance)
	check(office().bank_account.rows()[0] == "SHIP SALE — MULE 1  SHIP  €200 000",
		"the sale should be a Transaction naming the ship, shows %s" % office().bank_account.rows())
	check(not mule in hangar().ships and hangar_screen().berths_text() == "BERTHS 1/4", "the sale should free the berth")
	check(office().screen == Office.Screen.HANGAR, "the Hangar's table should show after a sale")


func test_a_sale_takes_off_the_repair_cost() -> void:
	economy().balance = 650000
	var halo := await buy_ship(ShipType.HALO)
	halo.condition = 0.9
	# 50% of €650 000, less 10% × the Halo's 30% repair rate × €650 000.
	check(hangar_screen().actions()[HangarScreen.Action.SELL] == "SELL €305 500", "a 90%% Halo should sell for €305 500, shows %s"
		% hangar_screen().actions()[HangarScreen.Action.SELL])
	halo.condition = 0.0
	check(hangar_screen().actions()[HangarScreen.Action.SELL] == "SELL €130 000", "a wrecked Halo should sell for €130 000, shows %s"
		% hangar_screen().actions()[HangarScreen.Action.SELL])


func test_selling_is_allowed_in_debt() -> void:
	economy().balance = 250000
	var sparrow := await buy_ship(ShipType.SPARROW)
	economy().balance = -50000
	check(hangar_screen().reasons()[HangarScreen.Action.SELL] == "", "debt should not block selling, reasons %s" % hangar_screen().reasons())
	await select_action(HangarScreen.Action.SELL)
	await press(&"ui_accept")
	check(economy().balance == 75000 and not sparrow in hangar().ships, "selling in debt should pay €125 000, balance %d"
		% economy().balance)


func test_names_are_never_reused_after_a_sale() -> void:
	economy().balance = 10000000
	var mule_1 := hangar().buy(ShipType.MULE)
	hangar().buy(ShipType.MULE)
	await open_hangar()
	await open_ship_page(mule_1)
	await select_action(HangarScreen.Action.SELL)
	await press(&"ui_accept")
	await press(&"ui_cancel")
	var next := await buy_ship(ShipType.MULE)
	check(next.name == "MULE 3", "the next Mule after selling MULE 1 should be MULE 3, got %s" % next.name)


func test_the_parking_spot_shows_only_the_ship_in_service() -> void:
	economy().balance = 400000
	await buy_ship(ShipType.MULE)
	await leave_office()
	var shown := 0
	for node in main().find_children("*", "CharacterBody2D", true, false):
		shown += 1
	check(shown == 1, "only one ship should be in the world, found %d" % shown)
	check(lander().ship_type == ShipType.SPARROW, "the parking spot should show the Sparrow in service")
