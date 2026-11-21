extends "res://tests/scene_test.gd"
# Paid fuel at the station, in litres: no automatic refuelling, the Ship page's FUEL screen,
# pumping, and fuel sold back when a Load needs the room.


func test_docking_never_adds_fuel() -> void:
	await choose_ship()
	var ship := lander()
	await dock_in_spot()
	ship.fuel = 1000.0
	# Decline the Office.
	await press(&"ui_accept")
	await seconds(4.0)
	check_near(ship.fuel, 1000.0, 0.0001, "docking should add no fuel")
	check(message() == "Docked!", "no Refueling… at the station, got %s" % message())


func test_a_sparrow_tank_holds_6000_litres() -> void:
	await open_hangar()
	check(hangar_screen().rows()[0].contains("6 000 L"), "a full Sparrow should hold 6 000 L, got %s" % hangar_screen().rows()[0])
	check_near(lander().fuel, 4800.0, 0.01, "6 000 L weigh 4 800 kg")


func test_the_fuel_screen_shows_the_tank_the_cap_and_the_station_price_per_litre() -> void:
	var mule := hangar().buy(ShipType.MULE)
	mule.fuel = 4000.0
	await open_fuel_screen(mule)
	check(office().screen_title() == "HANGAR // MULE 1 // FUEL", "title, got %s" % office().screen_title())
	var expected := PackedStringArray(["IN TANK 5 000 L (4 000 KG)", "FUEL CAP 15 000 L (12 000 KG)",
		"PRICE €0.36 / L", "TOTAL €360"])
	check(fuel_screen().lines() == expected, "the Mule's fuel at the station, got %s" % fuel_screen().lines())
	check(fuel_screen().amount_text() == "< BUY +1 000 L >", "the control starts at +1 000 L, got %s" % fuel_screen().amount_text())
	check(fuel_screen().button_text() == "BUY FUEL", "got %s" % fuel_screen().button_text())


func test_buying_fuel_for_a_ship_in_a_berth_fills_it_at_once_and_is_a_transaction() -> void:
	var mule := hangar().buy(ShipType.MULE)
	mule.fuel = 4000.0
	await open_fuel_screen(mule)
	await press(&"ui_down")
	await press(&"ui_down")
	await press(&"ui_accept")
	check(office().popup_text() == "BUY 1 000 L FOR €360?", "confirm, got %s" % office().popup_text())
	check(office().popup_warning() == "", "no debt warning, got %s" % office().popup_warning())
	await press(&"ui_accept")
	check_near(mule.fuel, 4800.0, 0.01, "1 000 L (800 kg) more in the Mule's tank at once")
	check(economy().balance == Economy.START_BALANCE - 360, "balance, got %d" % economy().balance)
	check(fuel_screen().lines()[0] == "IN TANK 6 000 L (4 800 KG)", "IN TANK after buying, got %s" % fuel_screen().lines()[0])
	await press(&"ui_cancel")
	await press(&"ui_cancel")
	await press(&"ui_cancel")
	await open_bank_account()
	check(office().bank_account.rows()[0] == "FUEL  STATION  1 000 L  SHIP  -€360",
		"the newest Transaction, got %s" % office().bank_account.rows()[0])
	await press(&"ui_accept")
	var expected := PackedStringArray(["SHIP MULE 1", "FUEL 1 000 L (800 KG)", "PRICE €0.36 / L",
		"SHIP TYPE FACTOR ×0.6", "PLACE STATION", "PAYOUT -€360"])
	check(office().bank_account.details(0) == expected, "details, got %s" % office().bank_account.details(0))


func test_fuel_for_the_ship_in_service_is_pumped_at_500_litres_a_second_and_holds_it_docked() -> void:
	var ship := lander()
	ship.fuel = 800.0
	await open_fuel_screen(hangar().in_service)
	await press(&"ui_down")
	await press(&"ui_accept")
	check(fuel_screen().amount_text() == "< BUY +5 000 L >", "FULL fills up to the cap, got %s" % fuel_screen().amount_text())
	await press(&"ui_accept")
	check(office().popup_text() == "BUY 5 000 L FOR €3 000?", "confirm, got %s" % office().popup_text())
	await press(&"ui_accept")
	check(economy().balance == Economy.START_BALANCE - 3000, "paid at once, balance %d" % economy().balance)
	await seconds(1.0)
	check_near(ship.fuel, 800.0 + 400.0, 8.0, "500 L (400 kg) pumped in 1 s with the Terminal open")
	var early := fuel_screen().lines()[0]
	check(early.begins_with("IN TANK 1 4") or early.begins_with("IN TANK 1 5"), "IN TANK grows as it pumps, got %s" % early)
	check(fuel_screen().amount_text() == "< BUY +0 L >", "fuel still to pump counts toward the cap, got %s" % fuel_screen().amount_text())
	await press(&"ui_cancel")
	var page_fuel := fuel_line()
	await seconds(1.0)
	check(fuel_line() != page_fuel, "the Ship page's FUEL grows while pumping, %s then %s" % [page_fuel, fuel_line()])
	await press(&"ui_cancel")
	var row := hangar_screen().rows()[0]
	await seconds(1.0)
	check(hangar_screen().rows()[0] != row, "the berths table's fuel grows while pumping, %s then %s" % [row, hangar_screen().rows()[0]])
	await leave_office()
	await frames(2)
	check(message().begins_with("Docked!\nPumping fuel… "), "the HUD says it's pumping, got %s" % message())
	hold(&"ui_up")
	await seconds(0.5)
	release(&"ui_up")
	check(ship.state == Lander.State.DOCKED, "no undocking while pumping, state %s" % ship.state)
	await seconds(9.0)
	check_near(ship.fuel, 4800.0, 0.01, "a full tank once pumping is done")
	check(message() == "Docked!", "pumping is over, got %s" % message())
	hold(&"ui_up")
	await seconds(0.5)
	release(&"ui_up")
	check(ship.state == Lander.State.FLYING, "undocks once pumping is done, state %s" % ship.state)


func test_selling_fuel_back_from_a_halo_pays_its_station_price() -> void:
	var halo := hangar().buy(ShipType.HALO)
	await open_fuel_screen(halo)
	check(fuel_screen().amount_text() == "< BUY +0 L >", "a full tank has nothing to buy, got %s" % fuel_screen().amount_text())
	await press(&"ui_left")
	check(fuel_screen().amount_text() == "< SELL BACK -1 000 L >", "got %s" % fuel_screen().amount_text())
	check(fuel_screen().button_text() == "SELL FUEL", "got %s" % fuel_screen().button_text())
	check(fuel_screen().lines().slice(2) == PackedStringArray(["PRICE €0.78 / L", "YOU GET €780"]),
		"the Halo's price and what selling pays, got %s" % fuel_screen().lines())
	await press(&"ui_down")
	await press(&"ui_down")
	await press(&"ui_accept")
	check(office().popup_text() == "SELL 1 000 L FOR €780?", "confirm, got %s" % office().popup_text())
	await press(&"ui_accept")
	check_near(halo.fuel, 7200.0, 0.01, "1 000 L (800 kg) out of the Halo's tank at once")
	check(economy().balance == Economy.START_BALANCE + 780, "balance, got %d" % economy().balance)
	check(economy().transactions[0].label() == "FUEL  STATION  1 000 L" and economy().transactions[0].payout == 780,
		"a positive FUEL Transaction, got %s %d" % [economy().transactions[0].label(), economy().transactions[0].payout])
	for i in 12:
		await press(&"ui_left")
	check(fuel_screen().amount_text() == "< SELL BACK -9 000 L >", "never more than the tank holds, got %s" % fuel_screen().amount_text())


func test_buying_fuel_may_go_into_debt_with_a_red_warning() -> void:
	economy().balance = 100
	lander().fuel = 0.0
	await open_fuel_screen(hangar().in_service)
	await press(&"ui_down")
	await press(&"ui_accept")
	await press(&"ui_accept")
	check(office().popup_text() == "BUY 6 000 L FOR €3 600?", "confirm, got %s" % office().popup_text())
	check(office().popup_warning() == "THIS LEAVES YOU AT -€3 500", "debt warning, got %s" % office().popup_warning())
	await press(&"ui_accept")
	check(economy().balance == -3500, "fuel is sold on credit, balance %d" % economy().balance)


func test_fuel_is_never_bought_past_the_fuel_cap() -> void:
	# Sparrow: 22 000 kg Maximum weight − 10 000 kg dry mass − 9 000 kg Load leaves 3 000 kg (3 750 L).
	lander().load_mass = 9000.0
	lander().fuel = 800.0
	await open_fuel_screen(hangar().in_service)
	check(fuel_screen().lines()[1] == "FUEL CAP 3 750 L (3 000 KG)", "the cap counts the Load, got %s" % fuel_screen().lines()[1])
	for i in 5:
		await press(&"ui_right")
	check(fuel_screen().amount_text() == "< BUY +2 750 L >", "up to the cap, got %s" % fuel_screen().amount_text())
	await press(&"ui_left")
	check(fuel_screen().amount_text() == "< BUY +2 000 L >", "Left from the cap steps to a round amount, got %s" % fuel_screen().amount_text())


# Sparrow, full: 22 000 kg Maximum weight − 10 000 kg dry mass − 8 000 kg cargo leaves 4 000 kg of
# fuel, so 800 kg (1 000 L) of its 4 800 kg must go.
func test_an_offer_whose_load_pushes_the_fuel_over_the_cap_says_how_much_fuel_it_sells() -> void:
	var heavy := known_offer(0, 8000.0)
	var light := known_offer(0, 1000.0)
	economy().put_offer(heavy)
	economy().put_offer(light)
	await open_transport_offers()
	var notes := offers().red_notes()
	check(notes[economy().offers.find(heavy)] == "SELLS 1 000 L FUEL", "the heavy offer's note, got %s" % notes)
	check(notes[economy().offers.find(light)] == "", "a light offer sells nothing, got %s" % notes)


func test_start_loading_sells_the_fuel_above_the_new_cap_and_drains_it_while_loading() -> void:
	var ship := lander()
	await start_loading([known_offer(0, 8000.0)])
	check(economy().transactions[0].label() == "FUEL  STATION  1 000 L" and economy().transactions[0].payout == 600,
		"one positive FUEL Transaction, got %s %d" % [economy().transactions[0].label(), economy().transactions[0].payout])
	check(economy().balance == Economy.START_BALANCE + 600, "balance, got %d" % economy().balance)
	await seconds(1.0)
	check_near(ship.fuel, 4800.0 - 400.0, 15.0, "drains at the pump rate")
	check(message().contains("Pumping fuel… "), "the HUD says it's pumping, got %s" % message())
	await seconds(2.0)
	check_near(ship.fuel, 4000.0, 0.01, "down to the new cap")
	check(ship.state == Lander.State.DOCKED, "still loading, state %s" % ship.state)


func test_a_ship_swap_while_pumping_leaves_the_paid_fuel_in_the_ship_it_was_bought_for() -> void:
	var sparrow := hangar().in_service
	sparrow.fuel = 800.0
	var mule := hangar().buy(ShipType.MULE)
	await open_fuel_screen(sparrow)
	await press(&"ui_down")
	await press(&"ui_accept")
	await press(&"ui_accept")
	await press(&"ui_accept")
	await press(&"ui_cancel")
	await press(&"ui_cancel")
	await open_ship_page(mule)
	await put_in_service()
	check_near(sparrow.fuel, 4800.0, 0.01, "the Sparrow keeps all 5 000 L it paid for")
	check_near(mule.fuel, ShipType.MULE.tank, 0.01, "the Mule keeps its own fuel")
	await leave_office()
	await frames(2)
	check(message() == "Docked!", "nothing is pumping into the Mule, got %s" % message())



func fuel_line() -> String:
	for line in hangar_screen().page_lines():
		if line.begins_with("FUEL "):
			return line
	return ""


func test_the_fuel_bar_shows_the_tank_and_the_chosen_amount_on_top_of_it() -> void:
	lander().fuel = 800.0
	await open_fuel_screen(hangar().in_service)
	var bar := fuel_screen().bar()
	# 1 000 L in a 6 000 L Tank, +1 000 L chosen on top of it.
	check_near(bar.x, 1.0 / 6.0, 0.001, "the green fill is the fuel in the tank")
	check_near(bar.y, 2.0 / 6.0, 0.001, "the pulsing part reaches the tank after buying")
	check_near(bar.z, 1.0, 0.001, "the fuel cap is the whole Tank without a Load")
	await press(&"ui_left")
	await press(&"ui_left")
	bar = fuel_screen().bar()
	check_near(bar.x, 0.0, 0.001, "selling everything back leaves no green fill")
	check_near(bar.y, 1.0 / 6.0, 0.001, "the pulsing part is what is sold back")
