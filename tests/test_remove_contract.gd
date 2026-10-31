extends "res://tests/scene_test.gd"


# Accepts the offers, then moves focus to the Contracts column.
func accept_and_focus_contracts(contracts: Array[TransportOffer]) -> void:
	for offer in contracts:
		economy().put_offer(offer)
	await open_transport_offers()
	for offer in contracts:
		await accept(offer)
	await press(&"ui_right")


func test_up_and_down_select_each_contract_then_start_loading() -> void:
	var first := known_offer(1, 0.0)
	var second := known_offer(0, 1000.0)
	await accept_and_focus_contracts([first, second])
	check(offers().selected_contract() == null, "Right should land on START LOADING")
	await press(&"ui_up")
	check(offers().selected_contract() == second, "Up should select the last Contract")
	await press(&"ui_up")
	check(offers().selected_contract() == first, "Up again should select the first Contract")
	await press(&"ui_up")
	check(offers().selected_contract() == first, "Up should stop at the first Contract")
	await press(&"ui_down")
	await press(&"ui_down")
	check(offers().selected_contract() == null, "Down should reach START LOADING after the Contracts")
	await press(&"ui_down")
	check(offers().selected_contract() == null, "Down should stop at START LOADING")
	await press(&"ui_accept")
	await wait_for_terminal()
	check(economy().phase == Economy.Phase.LOADING, "Return on START LOADING should still start loading")


func test_return_on_a_contract_asks_remove_contract_and_no_or_escape_keep_it() -> void:
	var offer := known_offer(1, 0.0)
	await accept_and_focus_contracts([offer])
	await press(&"ui_up")
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


func test_yes_removes_the_contract_for_good_with_no_payout() -> void:
	var kept := known_offer(1, 1000.0)
	var removed := known_offer(2, 2000.0)
	await accept_and_focus_contracts([kept, removed])
	await press(&"ui_up")
	check(offers().selected_contract() == removed, "Up should select the last Contract")
	await press(&"ui_accept")
	await press(&"ui_left")
	await press(&"ui_accept")
	check(office().popup == Office.PopupKind.NONE, "Yes should close the popup")
	check(economy().contracts == [kept], "Yes should remove only that Contract, has %d" % economy().contracts.size())
	check(not "#%03d TEST RUN" % removed.number in offers().contract_lines(),
		"the Contracts column should drop it, lists %s" % offers().contract_lines())
	check(offers().summary() == PackedStringArray(["PASSENGERS 1/4", "CARGO 1 000/6 920 KG",
		"DELIVER WITHIN 1:30", "TOTAL VALUE €420"]), "the summary should count only the kept Contract, got %s" % offers().summary())
	check(economy().balance == 0, "removing should pay nothing, balance %d" % economy().balance)
	check(economy().transactions.is_empty(), "removing should add no transaction")
	check(not listed("#%03d " % removed.number), "the removed Contract should not return to the offers, lists %s" % offers().rows())
	check(offers().selected_contract() == kept, "the cursor should stay in range, on the remaining Contract")
	await seconds(1.0)
	check(not removed in economy().offers, "the removed Contract should stay out of the offers")


func test_removing_the_last_contract_dims_start_loading() -> void:
	var offer := known_offer(1, 0.0)
	await accept_and_focus_contracts([offer])
	await press(&"ui_up")
	await press(&"ui_accept")
	await press(&"ui_left")
	await press(&"ui_accept")
	check(economy().contracts.is_empty(), "Yes should remove the Contract")
	check(not offers().start_loading_enabled(), "START LOADING should dim with no Contracts")
	check(offers().selected_contract() == null, "the cursor should be on START LOADING")
	await press(&"ui_accept")
	check(office().showing and economy().phase == Economy.Phase.NONE, "START LOADING should do nothing")
