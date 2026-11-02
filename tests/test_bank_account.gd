extends "res://tests/scene_test.gd"


func test_an_open_late_transaction_shows_how_the_payout_was_worked_out() -> void:
	var offer := known_offer(1, 1000.0)
	offer.deadline = 10.0
	await deliver([offer], 22.7)
	await open_bank_account()
	check(bank().details(0).is_empty(), "no details should show before Return")
	await press(&"ui_accept")
	# 12 s overdue: €300 − €72 and €120 − €14.40, rounded.
	# Loaded at 14:00, 10 s deadline (20 in-game minutes), landed after 22 s (45 in-game minutes).
	check(bank().details(0) == PackedStringArray(["BASE VALUE €420", "PENALTY -€86 (24 MIN OVERDUE)", "PAYOUT €334",
			"DEADLINE 14:20", "LANDED 14:45", "DELIVERED TO VALLEY", "SHIP SPARROW"]),
		"Return should open the breakdown, shows %s" % bank().details(0))


func test_an_on_time_transaction_shows_no_penalty() -> void:
	var offer := known_offer(2, 0.0)
	await deliver([offer], 5.0)
	await open_bank_account()
	await press(&"ui_accept")
	check(bank().details(0) == PackedStringArray(["BASE VALUE €420", "PENALTY €0", "PAYOUT €420",
			"DEADLINE 17:00", "LANDED 14:10", "DELIVERED TO VALLEY", "SHIP SPARROW"]),
		"an on-time delivery should show PENALTY €0, shows %s" % bank().details(0))


func test_the_deadline_shown_is_the_flights_shortest() -> void:
	var quick := known_offer(1, 0.0)
	quick.deadline = 60.0
	var slow := known_offer(0, 1000.0)
	await deliver([quick, slow], 5.0)
	await open_bank_account()
	await press(&"ui_accept")
	check("DEADLINE 16:00" in bank().details(0), "the slow Contract was settled against 16:00, shows %s" % bank().details(0))


func test_up_down_select_transactions_and_several_open_at_once_until_return_closes_one() -> void:
	await deliver([known_offer(1, 0.0), known_offer(0, 1000.0), known_offer(2, 0.0)], 5.0)
	await open_bank_account()
	check(bank().list.selected_index() == 0, "the newest transaction should be selected first")
	await press(&"ui_accept")
	await press(&"ui_down")
	await press(&"ui_down")
	check(bank().list.selected_index() == 2, "Down should move to the third transaction, on %d" % bank().list.selected_index())
	await press(&"ui_down")
	check(bank().list.selected_index() == 2, "Down should stop at the last transaction")
	await press(&"ui_accept")
	check(bank().list.expanded_rows() == [0, 2], "two transactions should be open, open %s" % [bank().list.expanded_rows()])
	await press(&"ui_up")
	await press(&"ui_up")
	await press(&"ui_accept")
	check(bank().list.expanded_rows() == [2], "Return should close only the first, open %s" % [bank().list.expanded_rows()])
	check(bank().details(2).size() == 7, "the third should stay open, shows %s" % bank().details(2))


func test_escape_on_an_open_transaction_closes_it_then_returns_to_the_main_screen() -> void:
	await deliver([known_offer(1, 0.0)], 5.0)
	await open_bank_account()
	await press(&"ui_accept")
	await press(&"ui_cancel")
	check(bank().list.expanded_rows().is_empty(), "Escape should close the open transaction")
	check(office().screen == Office.Screen.BANK_ACCOUNT, "the first Escape should stay on the Bank account")
	await press(&"ui_cancel")
	check(office().screen == Office.Screen.MAIN, "Escape with nothing open should return to the main screen")


func test_a_long_history_scrolls_to_follow_the_cursor() -> void:
	var contracts: Array[TransportOffer] = []
	for i in 4:
		contracts.append(known_offer(1, 0.0))
	await deliver(contracts, 5.0)
	await deliver(contracts.map(func(_offer: TransportOffer) -> TransportOffer: return known_offer(1, 0.0)), 5.0)
	await open_bank_account()
	while bank().list.selected_index() > 0:
		await press(&"ui_up")
	for i in bank().rows().size():
		await press(&"ui_accept")
		await press(&"ui_down")
	await seconds(0.5)
	check(bank().list.more_above(), "with every transaction open the list should scroll, scrolled %s" % bank().list.scroll)
	check(bank().list.cursor_in_view(), "the selected transaction should stay in view")
	while bank().list.selected_index() > 0:
		await press(&"ui_up")
	check(not bank().list.more_above() and bank().list.more_below(), "back at the newest, the list should scroll back to the top")


func test_opening_the_last_transaction_at_the_bottom_scrolls_its_details_into_view() -> void:
	var contracts: Array[TransportOffer] = []
	for i in 4:
		contracts.append(known_offer(1, 0.0))
	await deliver(contracts, 5.0)
	await deliver(contracts.map(func(_offer: TransportOffer) -> TransportOffer: return known_offer(1, 0.0)), 5.0)
	await open_bank_account()
	while bank().list.selected_index() > 0:
		await press(&"ui_up")
	for i in bank().rows().size():
		await press(&"ui_accept")
		await press(&"ui_down")
	await seconds(0.5)
	check(bank().list.selected_index() == bank().rows().size() - 1, "the cursor should be on the last transaction")
	check(bank().list.more_above() and not bank().list.more_below(),
		"the last open transaction's details should be scrolled into view, scrolled %s" % bank().list.scroll)


func test_a_delivery_past_midnight_marks_the_times_on_the_next_day() -> void:
	var offer := known_offer(1, 0.0)
	offer.deadline = 10.0
	await deliver([offer], 22.7, 23 * 60 + 30.5)
	await open_bank_account()
	await press(&"ui_accept")
	var details := bank().details(0)
	check("DEADLINE 23:50" in details, "the deadline fell before midnight, shows %s" % details)
	check("LANDED 00:15 +1" in details, "the landing fell after midnight, shows %s" % details)


func test_a_deadline_past_midnight_is_marked_on_the_next_day() -> void:
	await deliver([known_offer(1, 0.0)], 5.0, 23 * 60 + 30.5)
	await open_bank_account()
	await press(&"ui_accept")
	var details := bank().details(0)
	check("DEADLINE 02:30 +1" in details and "LANDED 23:40" in details,
		"only the deadline fell after midnight, shows %s" % details)


func test_the_details_name_the_location_delivered_to() -> void:
	await choose_ship()
	var location := Location.new()
	location.name = "ELSEWHERE"
	location.pad_center_x = 600.0
	clock().move_to(location)
	await deliver([known_offer(1, 0.0)], 5.0)
	await open_bank_account()
	await press(&"ui_accept")
	check("DELIVERED TO ELSEWHERE" in bank().details(0), "the ship landed at ELSEWHERE, shows %s" % bank().details(0))


func test_the_details_name_the_ship_type_that_delivered() -> void:
	await choose_ship(ShipType.MULE)
	await deliver([known_offer(1, 0.0)], 5.0)
	await open_bank_account()
	await press(&"ui_accept")
	check("SHIP MULE" in bank().details(0), "the Mule delivered it, shows %s" % bank().details(0))


func test_closing_a_transaction_shrinks_its_details_back() -> void:
	await deliver([known_offer(1, 0.0)], 5.0)
	await open_bank_account()
	var transaction := economy().transactions[0]
	await press(&"ui_accept")
	await seconds(ExpandableList.OPEN_TIME)
	await press(&"ui_accept")
	check(bank().list.expanded_rows().is_empty(), "Return should close it at once")
	await frames(2)
	var share := bank().list.open_share(transaction)
	check(share > 0.0 and share < 1.0, "the details should still be shrinking, %s open" % share)
	await seconds(ExpandableList.OPEN_TIME)
	check(bank().list.open_share(transaction) == 0.0, "the details should be gone after %s s" % ExpandableList.OPEN_TIME)


func bank() -> BankAccountScreen:
	return office().bank_account


# Loads the Contracts, lands on the pad after `delivered_in` seconds of delivery, waits for
# unloading, then docks and enters the Office. Loading counts as finished at `loaded_at`
# (in-game minutes since midnight; 14:00 by default).
func deliver(contracts: Array, delivered_in: float, loaded_at := 14 * 60 + 0.5) -> void:
	var typed: Array[TransportOffer] = []
	typed.assign(contracts)
	if not office().showing:
		await enter_office()
	await start_loading(typed)
	while economy().phase == Economy.Phase.LOADING:
		await frames(1)
	economy().loaded_at = loaded_at
	await seconds(delivered_in)
	place(Vector2(300, 100))
	await press(&"restart")
	check(lander().state == Lander.State.LANDED, "R on the Surface should land the ship on the pad")
	while economy().phase == Economy.Phase.UNLOADING:
		await frames(1)
	await enter_office()


func enter_office() -> void:
	await dock_in_spot()
	await press(&"ui_left")
	await press(&"ui_accept")
	await wait_for_terminal()
	check(office().showing, "Yes should enter the Office")
