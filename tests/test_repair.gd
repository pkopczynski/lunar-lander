extends "res://tests/scene_test.gd"
# REPAIR on a Ship page: instant, always full, priced at missing Condition × the Ship type's repair
# rate × the ship's value, on credit.


# A crashed SPARROW 1 leaves €7 500 after its €12 500 Recovery; its repair is 100% × 25% × €250 000.
func test_repairing_a_wreck_on_credit_warns_of_the_debt_and_lets_the_ship_fly_again() -> void:
	await choose_ship()
	await crash_in_deep_space()
	await recover()
	await open_hangar()
	await open_ship_page(hangar().in_service)
	check(hangar_screen().actions()[HangarScreen.Action.REPAIR] == "REPAIR €62 500",
		"a wrecked Sparrow's repair should cost €62 500, actions %s" % hangar_screen().actions())
	await select_action(HangarScreen.Action.REPAIR)
	check(office().popup_text() == "REPAIR SPARROW 1 FOR €62 500?", "REPAIR should ask first, asks %s" % office().popup_text())
	check(office().popup_warning() == "THIS LEAVES YOU AT -€55 000",
		"a repair into debt should warn in red, warns '%s'" % office().popup_warning())
	await press(&"ui_accept")
	check(hangar().in_service.condition == 1.0, "Yes should restore 100%%, Condition %s" % hangar().in_service.condition)
	check(economy().balance == -55000 and office().balance_red(), "the repair should go on credit, balance %s" % economy().balance)
	check(hangar_screen().reasons()[HangarScreen.Action.REPAIR] == HangarScreen.NO_DAMAGE,
		"a repaired ship should have NO DAMAGE, reasons %s" % hangar_screen().reasons())
	await select_action(HangarScreen.Action.REPAIR)
	check(office().popup == Office.PopupKind.NONE and office().notice() == HangarScreen.NO_DAMAGE,
		"REPAIR at 100%% should only show NO DAMAGE, notice '%s'" % office().notice())
	await press(&"ui_cancel")
	await press(&"ui_cancel")
	await open_bank_account()
	check(office().bank_account.rows()[0] == "REPAIR — SPARROW 1  SHIP  -€62 500",
		"the repair should be the newest Transaction, rows %s" % office().bank_account.rows())
	while office().bank_account.list.selected_index() > 0:
		await press(&"ui_up")
	await press(&"ui_accept")
	await seconds(0.5)
	var details := office().bank_account.details(0)
	check(details.has("REPAIRED 100%") and details.has("REPAIR RATE 25%"), "the repair should show what it restored and the rate, shows %s" % details)
	await press(&"ui_cancel")
	await press(&"ui_cancel")
	await open_shipyard()
	check(shipyard().reason() == "NOT ENOUGH MONEY: €305 000 SHORT", "buying should be blocked in debt, reason '%s'" % shipyard().reason())
	await press(&"ui_cancel")
	await leave_office()
	check(lander().state == Lander.State.DOCKED, "the repaired ship should be left Docked, ready to fly")


# A Mule at 60% Condition: 40% × 15% × €400 000 = €24 000, with Contracts accepted.
func test_a_partial_repair_costs_the_missing_share_and_is_allowed_with_contracts() -> void:
	await swap_to(ShipType.MULE)
	var mule := hangar().in_service
	mule.condition = 0.6
	economy().put_offer(known_offer(1, 0.0))
	await open_transport_offers()
	await accept(economy().offers.back())
	while office().screen != Office.Screen.MAIN:
		await press(&"ui_cancel")
	economy().balance = 100000
	var balance := economy().balance
	await open_hangar()
	await open_ship_page(mule)
	check(hangar_screen().reasons()[HangarScreen.Action.REPAIR] == "", "Contracts shouldn't block a repair, reasons %s" % hangar_screen().reasons())
	await select_action(HangarScreen.Action.REPAIR)
	check(office().popup_text() == "REPAIR MULE 1 FOR €24 000?", "the Mule's repair should cost €24 000, asks %s" % office().popup_text())
	check(office().popup_warning() == "", "a repair the balance covers shouldn't warn, warns '%s'" % office().popup_warning())
	await press(&"ui_accept")
	check(mule.condition == 1.0, "the repair should always be full, Condition %s" % mule.condition)
	check(economy().balance == balance - 24000, "the repair should cost €24 000, balance %s from %s" % [economy().balance, balance])
	check(hangar_screen().rows()[0].contains("  100%  "), "the Hangar should show 100%%, rows %s" % hangar_screen().rows())
