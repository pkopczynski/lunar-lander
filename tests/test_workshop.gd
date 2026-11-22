extends "res://tests/scene_test.gd"
# The Workshop on every pad: landing asks "ENTER THE WORKSHOP?", Return asks again while Landed,
# and the Workshop is the Terminal in orange, selling fuel (buy only) and repair at the pad's
# place markup, without pausing the world. Pads never add fuel by themselves.


func test_landing_on_a_pad_asks_to_enter_the_workshop_with_no_selected() -> void:
	await choose_ship()
	await land_on_pad()
	check(office().popup == Office.PopupKind.ENTER_WORKSHOP, "landing should ask, popup %s" % office().popup)
	check(office().popup_text() == "ENTER THE WORKSHOP?", "the question, got %s" % office().popup_text())
	check(office().selected_button == Office.Choice.NO, "No should be selected")
	check(office().palette == TerminalPalette.WORKSHOP, "the popup should be the Workshop's orange")
	check(not office().showing, "the Terminal shouldn't open by itself")


func test_no_leaves_the_ship_landed_and_return_asks_again_while_landed() -> void:
	await choose_ship()
	await land_on_pad()
	await press(&"ui_accept")
	check(office().popup == Office.PopupKind.NONE, "No should close the popup")
	check(lander().state == Lander.State.LANDED and not lander().held, "the ship should stay Landed, free to lift off")
	await press(&"ui_accept")
	check(office().popup == Office.PopupKind.ENTER_WORKSHOP, "Return should ask again while Landed")
	await press(&"ui_cancel")
	hold(&"ui_up")
	await seconds(0.3)
	release(&"ui_up")
	check(lander().state == Lander.State.FLYING, "Up should lift off after No")
	await press(&"ui_accept")
	check(office().popup == Office.PopupKind.NONE, "Return in flight should ask nothing")


func test_yes_opens_the_orange_workshop_on_the_landed_ships_page_and_the_world_runs_on() -> void:
	await choose_ship()
	await land_on_pad()
	await enter_workshop()
	check(office().header_text() == "VALLEY PAD // WORKSHOP", "the header, got %s" % office().header_text())
	check(office().palette == TerminalPalette.WORKSHOP, "the Workshop should be orange")
	check(office().screen == Office.Screen.SHIP_PAGE and hangar_screen().ship == hangar().in_service,
		"the Workshop should open on the Landed ship's page")
	check(hangar_screen().actions() == PackedStringArray(["FUEL", "REPAIR €0"]),
		"the Workshop should sell only fuel and repair, shows %s" % hangar_screen().actions())
	check(not tree.paused, "the Workshop shouldn't pause the world")
	var minutes := clock().minutes
	await seconds(1.0)
	check(clock().minutes > minutes, "the planet clock should keep running")
	hold(&"ui_up")
	await seconds(0.5)
	release(&"ui_up")
	check(lander().state == Lander.State.LANDED, "Up in the Workshop should move the cursor, not lift off")
	await press(&"restart")
	check(office().showing and lander().held, "R shouldn't reach the ship behind the Workshop")


func test_escape_leaves_the_workshop_and_the_ship_lifts_off_then_the_office_is_green_again() -> void:
	await choose_ship()
	await land_on_pad()
	await enter_workshop()
	await press(&"ui_cancel")
	await wait_for_terminal()
	check(not office().showing and not lander().held, "Escape should leave the Workshop, the ship free")
	hold(&"ui_up")
	await seconds(0.3)
	release(&"ui_up")
	check(lander().state == Lander.State.FLYING, "Up should lift off after leaving the Workshop")
	await dock_in_spot()
	check(office().palette == TerminalPalette.OFFICE, "ENTER THE OFFICE? should be green")
	await press(&"ui_left")
	await press(&"ui_accept")
	await wait_for_terminal()
	check(office().header_text() == "ORBITAL FREIGHT CO. // OFFICE", "the Office's header, got %s" % office().header_text())
	check(office().palette == TerminalPalette.OFFICE, "the Office should be green")


func test_mine_pad_fuel_costs_double_for_a_sparrow_and_is_pumped_in_blocking_lift_off() -> void:
	await choose_ship()
	clock().move_to(Location.MINE)
	lander().fuel = 1600.0
	await land_on_pad()
	await enter_workshop()
	await press(&"ui_accept")
	check(office().header_text() == "MINE PAD // WORKSHOP // FUEL", "FUEL should open the fuel screen, header %s"
		% office().header_text())
	check(fuel_screen().lines().has("PRICE €1.20 / L"), "€0.60 × 2 at the Mine, shows %s" % fuel_screen().lines())
	await press(&"ui_down")
	await press(&"ui_down")
	await press(&"ui_accept")
	check(office().popup_text() == "BUY 1 000 L FOR €1 200?", "the confirm, got %s" % office().popup_text())
	check(office().popup_warning() == "", "no debt, no warning")
	await press(&"ui_accept")
	check(economy().balance == Economy.START_BALANCE - 1200, "the fuel should be paid, balance %s" % economy().balance)
	var fuel := economy().transactions[0]
	check(fuel.label() == "FUEL  MINE  1 000 L", "the Transaction should name the pad, got %s" % fuel.label())
	check(fuel.detail_pairs().has(["PLACE", "MINE"]) and fuel.detail_pairs().has(["PLACE MARKUP", "×2"]),
		"the details should show the place and its markup, got %s" % [fuel.detail_pairs()])
	check(hangar().pumping, "the fuel should be pumped in")
	await press(&"ui_cancel")
	await press(&"ui_cancel")
	await wait_for_terminal()
	hold(&"ui_up")
	await seconds(0.3)
	release(&"ui_up")
	check(lander().state == Lander.State.LANDED, "the ship shouldn't lift off while pumping")
	await seconds(2.0)
	check_near(lander().fuel, 2400.0, 0.5, "kg after pumping 1 000 L in")


func test_valley_pad_fuel_for_a_mule_is_one_and_a_half_times_its_station_price() -> void:
	await choose_ship(ShipType.MULE)
	lander().fuel = 4000.0
	await land_on_pad()
	await enter_workshop()
	await press(&"ui_accept")
	# €0.60 × 1.5 × 0.6.
	check(fuel_screen().lines().has("PRICE €0.54 / L"), "shows %s" % fuel_screen().lines())


func test_the_workshop_sells_no_fuel_back() -> void:
	await choose_ship()
	lander().fuel = 2000.0
	await land_on_pad()
	await enter_workshop()
	await press(&"ui_accept")
	check(fuel_screen().amount_text() == "< BUY +1 000 L >", "the control, got %s" % fuel_screen().amount_text())
	await press(&"ui_left")
	await press(&"ui_left")
	check(fuel_screen().amount_text() == "< BUY +0 L >", "Left should stop at nothing, got %s" % fuel_screen().amount_text())
	check(fuel_screen().reason() == FuelScreen.NOTHING_CHOSEN, "nothing chosen, got %s" % fuel_screen().reason())


func test_fuel_bought_on_credit_warns_in_red() -> void:
	await choose_ship()
	economy().balance = 500
	lander().fuel = 2000.0
	await land_on_pad()
	await enter_workshop()
	await press(&"ui_accept")
	await press(&"ui_down")
	await press(&"ui_down")
	await press(&"ui_accept")
	# 1 000 L at €0.90.
	check(office().popup_warning() == "THIS LEAVES YOU AT -€400", "the debt warning, got %s" % office().popup_warning())
	await press(&"ui_accept")
	check(economy().balance == -400, "fuel may go on credit, balance %s" % economy().balance)


func test_metropolis_pad_repair_costs_its_markup_on_credit_with_contracts_accepted() -> void:
	await choose_ship()
	clock().move_to(Location.METROPOLIS)
	economy().balance = 10000
	await land_on_pad()
	economy().contracts.append(known_offer(1, 0.0))
	hangar().in_service.condition = 0.8
	await enter_workshop()
	# 20% × 25% × €250 000 × 1.75.
	check(hangar_screen().actions()[1] == "REPAIR €21 875", "the pad's repair price, shows %s" % hangar_screen().actions())
	await press(&"ui_down")
	await press(&"ui_accept")
	check(office().popup_text() == "REPAIR SPARROW 1 FOR €21 875?", "the confirm, got %s" % office().popup_text())
	check(office().popup_warning() == "THIS LEAVES YOU AT -€11 875", "the debt warning, got %s" % office().popup_warning())
	await press(&"ui_accept")
	check(hangar().in_service.condition == 1.0, "the repair should be full")
	check(economy().balance == -11875, "the repair may go on credit, balance %s" % economy().balance)
	var repair := economy().transactions[0]
	check(repair.label() == "REPAIR  METROPOLIS", "the Transaction should name the pad, got %s" % repair.label())
	check(repair.detail_pairs().has(["PLACE MARKUP", "×1.75"]), "the details should show the markup, got %s"
		% [repair.detail_pairs()])


func test_a_pad_never_adds_fuel_by_itself() -> void:
	await choose_ship()
	lander().fuel = 1000.0
	await land_on_pad()
	await press(&"ui_accept")
	await seconds(5.0)
	check(lander().fuel == 1000.0, "resting on the pad shouldn't refuel, has %s kg" % lander().fuel)
	check(message() == "Landed!", "no Refueling… line, got %s" % message())


func test_a_ship_landed_on_a_pad_with_an_empty_tank_isnt_stranded_and_buys_fuel_there() -> void:
	await choose_ship()
	lander().fuel = 0.0
	await land_on_pad()
	await press(&"ui_accept")
	await seconds(3.0)
	check(lander().state == Lander.State.LANDED, "an empty tank on the pad isn't Stranded, state %s" % lander().state)
	await press(&"ui_accept")
	await enter_workshop()
	await press(&"ui_accept")
	await press(&"ui_down")
	# FULL, then BUY FUEL, then Yes.
	await press(&"ui_accept")
	await press(&"ui_accept")
	check(office().popup_text() == "BUY 6 000 L FOR €5 400?", "a full tank at €0.90, got %s" % office().popup_text())
	await press(&"ui_accept")
	await seconds(13.0)
	check_near(lander().fuel, ShipType.SPARROW.tank, 0.5, "FULL should fill the tank")


func test_the_workshop_works_while_unloading() -> void:
	var offer := known_offer(1, 0.0)
	await start_loading([offer])
	while economy().phase == Economy.Phase.LOADING:
		await frames(1)
	await land_on_pad()
	check(economy().phase == Economy.Phase.UNLOADING, "landing should start unloading")
	await enter_workshop()
	# 2 s + 0.5 s × 1 passenger.
	await seconds(3.0)
	check(economy().phase == Economy.Phase.NONE, "unloading should finish behind the Workshop")
	check(economy().transactions[0].contract == offer, "the Contract should be paid out")
	check(office().showing, "the Workshop should stay open")
