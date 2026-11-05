extends "res://tests/scene_test.gd"
# A loaded mission can be cancelled at the station: docking during a delivery offers the Office,
# where CANCEL MISSION gives up every Contract for a fee of 25% of its reward.


func test_docking_while_delivering_asks_to_enter_the_office_after_leveling() -> void:
	await deliver([known_offer(1, 0.0)])
	place(station().parking_spot.get_center())
	await seconds(0.1)
	check(lander().state == Lander.State.DOCKED, "the ship should dock in the parking spot")
	check(office().popup == Office.PopupKind.NONE, "no popup should show before the ship is level")
	await seconds(0.4)
	check(office().popup == Office.PopupKind.ENTER_OFFICE,
		"docking while delivering should ask ENTER THE OFFICE?, got %s" % office().popup_text())
	check(lander().held, "the ship should be held while the popup shows")


func test_during_a_loaded_mission_the_button_reads_cancel_mission_and_asks_with_no_selected() -> void:
	await deliver_and_open_offers([known_offer(1, 0.0)])
	check(offers().start_text() == "CANCEL MISSION", "the button should read CANCEL MISSION, got %s" % offers().start_text())
	await press(&"ui_accept")
	check(office().popup == Office.PopupKind.CANCEL_MISSION, "Return should ask CANCEL MISSION?")
	check(office().popup_text() == "CANCEL MISSION?", "the popup should read CANCEL MISSION?, got %s" % office().popup_text())
	check(office().selected_button == Office.Choice.NO, "No should be selected")


func test_no_or_escape_keeps_the_mission() -> void:
	var offer := known_offer(1, 0.0)
	await deliver_and_open_offers([offer])
	await press(&"ui_accept")
	await press(&"ui_accept")
	check(office().popup == Office.PopupKind.NONE and office().showing, "No should close the popup, not the Office")
	await press(&"ui_accept")
	await press(&"ui_cancel")
	check(office().popup == Office.PopupKind.NONE and office().showing, "Escape should close the popup, not the Office")
	check(economy().phase == Economy.Phase.DELIVERING, "the mission should go on")
	check(economy().contracts == [offer], "the Contract should stay")
	check(economy().transactions.is_empty(), "no transaction should be recorded")


func test_yes_charges_each_contract_a_quarter_of_its_reward_and_the_balance_may_go_negative() -> void:
	var crew := known_offer(1, 0.0)
	var parts := known_offer(0, 2000.0)
	parts.passenger_reward = 0
	parts.cargo_reward = 500
	await deliver_and_open_offers([crew, parts])
	await cancel()
	check(economy().contracts.is_empty(), "Yes should give up every Contract")
	check(economy().phase == Economy.Phase.NONE, "the mission should end")
	# €420 (300 + 120) and €500 (0 + 500): fees €105 and €125.
	check(economy().balance == -230, "the fees should come off the balance, which may go negative, got %s"
		% economy().balance)
	check(office().bank_account.rows() == PackedStringArray([
			"#%03d TEST RUN  CARGO  -€125" % parts.number,
			"#%03d TEST RUN  PASSENGERS  -€105" % crew.number]),
		"each Contract should get a transaction with a negative payout, shows %s" % office().bank_account.rows())


func test_a_cancelled_contracts_details_show_the_fee_and_cancelled() -> void:
	await deliver_and_open_offers([known_offer(1, 0.0)])
	await cancel()
	await press(&"ui_cancel")
	await open_bank_account()
	await press(&"ui_accept")
	check(office().bank_account.details(0) == PackedStringArray(["BASE VALUE €420", "CANCELLATION FEE -€105",
			"PAYOUT -€105", "CANCELLED", "SHIP SPARROW"]),
		"the breakdown should show the fee and CANCELLED, shows %s" % office().bank_account.details(0))


func test_cancelling_takes_the_load_off_and_ends_the_deadline() -> void:
	# 8 000 kg leaves the Sparrow less room than a full Tank.
	await deliver_and_open_offers([known_offer(4, 8000.0)])
	check(lander().fuel_cap() < lander().ship_type.tank, "the Load should limit the fuel cap before cancelling")
	await cancel()
	check(lander().load_mass == 0.0, "the Load should come off at once, %s kg left" % lander().load_mass)
	check(lander().fuel_cap() == lander().ship_type.tank, "the fuel cap should be a full Tank again")
	check(hud().delivery_text() == "", "the HUD deadline should go, got '%s'" % hud().delivery_text())


func test_cancelled_contracts_dont_return_to_the_offers() -> void:
	var offer := known_offer(1, 0.0)
	await deliver_and_open_offers([offer])
	await cancel()
	check(not offer in economy().offers, "the cancelled Contract should not go back to the offers")
	check(not listed("#%03d" % offer.number), "the cancelled Contract should not be listed")
	check(offers().start_text() == "START", "with no Contracts the button should read START, got %s" % offers().start_text())


func test_offers_and_ship_swap_are_locked_during_the_mission_and_unlock_after_cancelling() -> void:
	var offer := known_offer(1, 0.0)
	var another := known_offer(1, 0.0)
	await deliver_and_open_offers([offer])
	economy().put_offer(another)
	check(reason_for(another) == "MISSION UNDER WAY",
		"an offer should show MISSION UNDER WAY during the mission, got %s" % reason_for(another))
	check(not economy().accept(another), "no offer should be accepted while the mission is under way")
	await press(&"ui_cancel")
	check(office().screen == Office.Screen.MAIN, "Escape should go back to the main screen")
	await open_ship_selection()
	await browse_to(ShipType.MULE)
	check(office().ship_locked_shown(), "ship swap should be locked during the mission")
	await press(&"ui_cancel")
	await open_transport_offers()
	await press(&"ui_right")
	await cancel()
	check(reason_for(another) == "", "offers should fit again after cancelling, got %s" % reason_for(another))
	await press(&"ui_cancel")
	await open_ship_selection()
	await browse_to(ShipType.MULE)
	check(not office().ship_locked_shown(), "ship swap should unlock after cancelling")
	await press(&"ui_accept")
	await press(&"ui_accept")
	check(lander().ship_type == ShipType.MULE, "the Mule should be chosen after cancelling")


func test_a_contract_cant_be_removed_during_the_mission() -> void:
	var offer := known_offer(1, 0.0)
	await deliver_and_open_offers([offer])
	while offers().selected_contract() != offer:
		await press(&"ui_up")
	await press(&"ui_accept")
	check(office().popup == Office.PopupKind.NONE, "Return on a Contract should not ask REMOVE CONTRACT? while loaded")
	check(economy().contracts == [offer], "the Contract should stay")


# Return on CANCEL MISSION, then Left to Yes and Return.
func cancel() -> void:
	check(offers().on_start_button() and offers().start_text() == "CANCEL MISSION",
		"the cursor should be on CANCEL MISSION")
	await press(&"ui_accept")
	await press(&"ui_left")
	await press(&"ui_accept")
	check(office().popup == Office.PopupKind.NONE and office().showing, "Yes should close the popup, not the Office")


# Delivers the Contracts, docks again, enters the Office and puts the cursor on CANCEL MISSION.
func deliver_and_open_offers(contracts: Array) -> void:
	await deliver(contracts)
	await dock_in_spot()
	await press(&"ui_left")
	await press(&"ui_accept")
	await wait_for_terminal()
	check(office().showing, "Yes should enter the Office")
	await open_transport_offers()
	await press(&"ui_right")
	check(offers().on_start_button(), "Right should put the cursor on the button under the mission rows")


# Loads the Contracts, then undocks and flies on, delivering.
func deliver(contracts: Array) -> void:
	var typed: Array[TransportOffer] = []
	typed.assign(contracts)
	await start_loading(typed)
	while economy().phase == Economy.Phase.LOADING:
		await frames(1)
	check(economy().phase == Economy.Phase.DELIVERING, "loading should finish into the delivery")
	place(Vector2(World.WORLD_WIDTH / 4.0, World.BORDER_Y - 600.0))
	await frames(2)
