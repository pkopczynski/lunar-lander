extends "res://tests/scene_test.gd"


# Accepts the offers, then moves focus to the Contracts column.
func accept_and_focus_contracts(contracts: Array[TransportOffer]) -> void:
	for offer in contracts:
		economy().put_offer(offer)
	await open_transport_offers()
	for offer in contracts:
		await accept(offer)
	await press(&"ui_right")


# From START LOADING, Up past START PERIOD and DESTINATION to the last Contract.
func up_to_last_contract() -> void:
	await press(&"ui_up")
	await press(&"ui_up")
	await press(&"ui_up")


func test_up_and_down_select_each_contract_then_the_mission_rows_and_start_loading() -> void:
	var first := known_offer(1, 0.0)
	var second := known_offer(0, 1000.0)
	await accept_and_focus_contracts([first, second])
	check(offers().on_start_loading(), "Right should land on START LOADING")
	await press(&"ui_up")
	check(offers().selected_mission_line() == "START PERIOD", "Up should select START PERIOD")
	await press(&"ui_up")
	check(offers().selected_mission_line() == "DESTINATION", "Up again should select DESTINATION")
	await press(&"ui_up")
	check(offers().selected_contract() == second, "Up again should select the last Contract")
	await press(&"ui_up")
	check(offers().selected_contract() == first, "Up again should select the first Contract")
	await press(&"ui_up")
	check(offers().selected_contract() == first, "Up should stop at the first Contract")
	await press(&"ui_down")
	await press(&"ui_down")
	check(offers().selected_mission_line() == "DESTINATION", "Down should reach DESTINATION after the Contracts")
	await press(&"ui_down")
	check(offers().selected_mission_line() == "START PERIOD", "Down should reach START PERIOD after DESTINATION")
	await press(&"ui_down")
	check(offers().on_start_loading(), "Down should reach START LOADING after START PERIOD")
	await press(&"ui_down")
	check(offers().on_start_loading(), "Down should stop at START LOADING")
	await press(&"ui_accept")
	await wait_for_terminal()
	check(economy().phase == Economy.Phase.LOADING, "Return on START LOADING should still start loading")


func test_return_on_a_contract_asks_remove_contract_and_no_or_escape_keep_it() -> void:
	var offer := known_offer(1, 0.0)
	await accept_and_focus_contracts([offer])
	await up_to_last_contract()
	await press(&"ui_accept")
	check(office().popup == Office.PopupKind.REMOVE_CONTRACT, "Return on a Contract should ask to remove it")
	check(office().popup_text() == "REMOVE CONTRACT?", "the popup should ask REMOVE CONTRACT?, got %s" % office().popup_text())
	check(office().selected_button == Office.Choice.NO, "REMOVE CONTRACT? should have No selected")
	await press(&"ui_accept")
	check(office().popup == Office.PopupKind.NONE, "No should close the popup")
	check(economy().contracts == [offer], "No should keep the Contract")
	await press(&"ui_accept")
	await press(&"ui_cancel")
	check(office().popup == Office.PopupKind.NONE, "Escape should close the popup")
	check(office().screen == Office.Screen.TRANSPORT_OFFERS, "Escape on the popup should stay on Transport offers")
	check(economy().contracts == [offer], "Escape should keep the Contract")
	check(offers().selected_contract() == offer, "the cursor should stay on the Contract")


func test_yes_removes_the_contract_with_no_payout() -> void:
	var kept := known_offer(1, 1000.0)
	var removed := known_offer(2, 2000.0)
	await accept_and_focus_contracts([kept, removed])
	await up_to_last_contract()
	check(offers().selected_contract() == removed, "Up should select the last Contract")
	await press(&"ui_accept")
	await press(&"ui_left")
	await press(&"ui_accept")
	check(office().popup == Office.PopupKind.NONE, "Yes should close the popup")
	check(economy().contracts == [kept], "Yes should remove only that Contract, has %d" % economy().contracts.size())
	check(not "#%03d TEST RUN" % removed.number in offers().contract_lines(),
		"the Contracts column should drop it, lists %s" % offers().contract_lines())
	check(offers().summary() == PackedStringArray(["PASSENGERS 1/4", "CARGO 1 000/6 920 KG",
		"DELIVER WITHIN 3H 00M", "TOTAL VALUE €420"]), "the summary should count only the kept Contract, got %s" % offers().summary())
	check(economy().balance == 0, "removing should pay nothing, balance %d" % economy().balance)
	check(economy().transactions.is_empty(), "removing should add no transaction")
	check(offers().selected_contract() == kept, "the cursor should stay in range, on the remaining Contract")


# Clears the pool, then puts the known offers in it, numbered on from the run's last offer.
func only_offers(known: Array[TransportOffer]) -> void:
	economy().offers.clear()
	for offer in known:
		economy().put_offer(offer)


# Removes the only Contract: Right to the Contracts column, Up to it, Return, then Yes, then
# Left back to the offers.
func remove_the_only_contract() -> void:
	await press(&"ui_right")
	await up_to_last_contract()
	await press(&"ui_accept")
	await press(&"ui_left")
	await press(&"ui_accept")
	check(economy().contracts.is_empty(), "Yes should remove the Contract")
	await press(&"ui_left")


func test_a_removed_contract_goes_back_to_the_offers_with_its_number_in_number_order() -> void:
	var first := known_offer(1, 0.0)
	var second := known_offer(1, 0.0)
	var third := known_offer(1, 0.0)
	only_offers([first, second, third])
	await open_transport_offers()
	await accept(second)
	await remove_the_only_contract()
	check(economy().offers == [first, second, third],
		"the removed Contract should go back between its neighbours, lists %s" % offers().rows())
	check(offers().rows()[1].begins_with("#%03d TEST RUN" % second.number),
		"its row should keep its number, lists %s" % offers().rows())


func test_a_removed_contract_comes_back_with_its_destination() -> void:
	var offer := known_offer(1, 0.0)
	offer.destination = Location.MINE
	only_offers([offer])
	await open_transport_offers()
	await accept(offer)
	await remove_the_only_contract()
	check(offer in economy().offers, "the removed Contract should be back in the offers")
	check(offer.destination == Location.MINE, "it should still go to the Mine")
	check(" MINE " in offers().rows()[0], "its row should still show MINE, lists %s" % offers().rows())


func test_a_removed_contract_comes_back_with_the_time_left_it_had_when_accepted() -> void:
	var offer := known_offer(1, 0.0, 500.0)
	only_offers([offer])
	await open_transport_offers()
	await accept(offer)
	var accepted_left := offer.time_left
	await seconds(20.0)
	await remove_the_only_contract()
	check(offer in economy().offers, "the removed Contract should be back in the offers")
	check_near(offer.time_left, accepted_left, 0.1, "it should have the time left it had when accepted")
	await seconds(10.0)
	check_near(offer.time_left, accepted_left - 10.0, 0.5, "its time should run again once it's an offer")


func test_a_removed_contract_goes_back_past_seven_and_no_offer_arrives_until_fewer_than_seven() -> void:
	var known: Array[TransportOffer] = []
	for i in Economy.MAX_OFFERS + 1:
		known.append(known_offer(1, 0.0, 10000.0))
	only_offers(known.slice(0, Economy.MAX_OFFERS))
	await open_transport_offers()
	await accept(known[0])
	economy().put_offer(known[Economy.MAX_OFFERS])
	check(offers().rows().size() == Economy.MAX_OFFERS, "the list should hold 7, lists %s" % offers().rows())
	await remove_the_only_contract()
	check(offers().rows().size() == Economy.MAX_OFFERS + 1,
		"the removed Contract should go back even with 7 listed, lists %s" % offers().rows())
	check(economy().offers[0] == known[0], "it should go back first, in number order, lists %s" % offers().rows())
	await seconds(Economy.MAX_OFFER_INTERVAL + 5.0)
	check(offers().rows().size() == Economy.MAX_OFFERS + 1,
		"no new offer should arrive while 7 or more are listed, lists %s" % offers().rows())
	await accept(known[1])
	await seconds(Economy.MAX_OFFER_INTERVAL + 5.0)
	check(offers().rows().size() == Economy.MAX_OFFERS,
		"no new offer should arrive with exactly 7 listed, lists %s" % offers().rows())
	await accept(known[2])
	await seconds(Economy.MAX_OFFER_INTERVAL + 5.0)
	check(offers().rows().size() == Economy.MAX_OFFERS,
		"one new offer should arrive once fewer than 7 are listed, lists %s" % offers().rows())


func test_removing_the_last_contract_dims_start_loading() -> void:
	var offer := known_offer(1, 0.0)
	await accept_and_focus_contracts([offer])
	await up_to_last_contract()
	await press(&"ui_accept")
	await press(&"ui_left")
	await press(&"ui_accept")
	check(economy().contracts.is_empty(), "Yes should remove the Contract")
	check(not offers().start_loading_enabled(), "START LOADING should dim with no Contracts")
	check(offers().on_start_loading(), "the cursor should be on START LOADING")
	await press(&"ui_accept")
	check(office().showing and economy().phase == Economy.Phase.NONE, "START LOADING should do nothing")
