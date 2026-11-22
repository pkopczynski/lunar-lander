extends "res://tests/scene_test.gd"
# O opens the Office again while the ship is Docked and free, and a pad's Workshop while it's Landed
# and free; the HUD's hint shows the key exactly while it would work.

const Hud := preload("res://hud.gd")


# Docks in the spot and answers No on the "ENTER THE OFFICE?" popup.
func dock_and_decline() -> void:
	await dock_in_spot()
	check(office().popup == Office.PopupKind.ENTER_OFFICE, "docking should ask ENTER THE OFFICE?")
	await press(&"ui_accept")
	check(office().popup == Office.PopupKind.NONE, "No should close the popup")


# Presses O and waits for the Terminal to power on.
func open_office_by_key() -> void:
	await press(&"office")
	await wait_for_terminal()


func check_opens_on_the_main_screen(why: String) -> void:
	check(office().showing, "O should open the Office " + why)
	check(office().screen == Office.Screen.MAIN, "O should open the main screen " + why)
	check(not office().in_workshop(), "O should open the Office, not a Workshop " + why)
	check(lander().held, "the ship should be held in the Office " + why)
	check(hud().office_hint_text() == "", "no hint while the Office shows " + why)


func check_hint_shows(why: String) -> void:
	check(hud().office_hint_text() == Hud.OFFICE_HINT_TEXT, "the hint shows " + why + ", got %s" % hud().office_hint_text())


func check_o_does_nothing(why: String) -> void:
	check(hud().office_hint_text() == "", "no hint " + why + ", got %s" % hud().office_hint_text())
	await press(&"office")
	await wait_for_terminal()
	check(not office().showing, "O should not open the Office " + why)


func test_after_no_o_opens_the_office_with_the_ship_held() -> void:
	await choose_ship()
	await dock_and_decline()
	check_hint_shows("while Docked and free")
	await open_office_by_key()
	check_opens_on_the_main_screen("after No")


func test_after_leaving_the_office_o_opens_it_again_and_escape_releases_the_ship() -> void:
	await choose_ship()
	check_hint_shows("after a fresh start's Escape")
	await open_office_by_key()
	check_opens_on_the_main_screen("after a fresh start's Escape")
	await press(&"ui_cancel")
	await wait_for_terminal()
	check(not office().showing and not lander().held, "Escape on the main screen should release the ship")
	check_hint_shows("again")
	await open_office_by_key()
	check_opens_on_the_main_screen("after leaving it with Escape")
	await press(&"ui_cancel")
	await wait_for_terminal()
	hold(&"ui_up")
	await seconds(0.5)
	release(&"ui_up")
	check(lander().state == Lander.State.FLYING, "Up should undock after leaving the Office, state %s" % lander().state)


func test_after_start_o_opens_the_office() -> void:
	await open_transport_offers()
	await press(&"ui_right")
	check(offers().start_text() == "START", "no Contracts: the button reads START, got %s" % offers().start_text())
	await press(&"ui_accept")
	await wait_for_terminal()
	check(not office().showing, "START should close the Office")
	check_hint_shows("after START")
	await open_office_by_key()
	check_opens_on_the_main_screen("after START")


func test_once_loaded_o_opens_the_office_and_cancel_mission_is_reachable() -> void:
	await start_loading([known_offer(1, 0.0)])
	while economy().phase == Economy.Phase.LOADING:
		await frames(1)
	check(economy().phase == Economy.Phase.DELIVERING, "loading should finish into the delivery")
	check_hint_shows("once loaded")
	await open_office_by_key()
	check_opens_on_the_main_screen("once loaded")
	await open_transport_offers()
	await press(&"ui_right")
	check(offers().start_text() == "CANCEL MISSION", "the button should read CANCEL MISSION, got %s" % offers().start_text())
	await press(&"ui_accept")
	check(office().popup == Office.PopupKind.CANCEL_MISSION, "Return should ask CANCEL MISSION?")


func test_while_fuel_is_pumped_o_opens_the_office_and_the_pump_goes_on() -> void:
	var ship := lander()
	ship.fuel = 800.0
	await open_fuel_screen(hangar().in_service)
	await press(&"ui_down")
	await press(&"ui_accept")
	await press(&"ui_accept")
	await press(&"ui_accept")
	await leave_office()
	check(hangar().pumping, "fuel should be pumping")
	check_hint_shows("while pumping")
	await open_office_by_key()
	check_opens_on_the_main_screen("while pumping")
	var fuel := ship.fuel
	await seconds(1.0)
	check(ship.fuel > fuel + 300.0, "the pump keeps going behind the Office, %s then %s kg" % [fuel, ship.fuel])


func test_o_does_nothing_during_the_loading_countdown() -> void:
	await start_loading([known_offer(2, 7000.0)])
	check(economy().phase == Economy.Phase.LOADING, "loading should be under way")
	await check_o_does_nothing("during the loading countdown")
	check(economy().phase == Economy.Phase.LOADING, "loading should go on")


func test_o_does_nothing_while_easing_upright_after_docking() -> void:
	await choose_ship()
	place(station().parking_spot.get_center())
	lander().rotation = 0.3
	await frames(2)
	check(lander().state == Lander.State.DOCKED and absf(lander().rotation) > 0.01, "the ship should be easing upright")
	check(hud().office_hint_text() == "", "no hint while easing upright, got %s" % hud().office_hint_text())
	await press(&"office")
	await wait_for_terminal()
	check(not office().showing, "O should not open the Office while easing upright")
	await seconds(Lander.LEVEL_TIME)
	check(office().popup == Office.PopupKind.ENTER_OFFICE, "the popup still shows once upright")


func test_o_does_nothing_while_the_popup_shows() -> void:
	await choose_ship()
	await dock_in_spot()
	check(office().popup == Office.PopupKind.ENTER_OFFICE, "docking should ask ENTER THE OFFICE?")
	await check_o_does_nothing("while the popup shows")
	check(office().popup == Office.PopupKind.ENTER_OFFICE, "the popup should stay")


func test_o_does_nothing_when_flying_or_crashed() -> void:
	await choose_ship()
	place(Vector2(World.WORLD_WIDTH / 4.0, World.BORDER_Y - 600.0))
	await frames(2)
	await check_o_does_nothing("while Flying")
	await crash_in_deep_space()
	await check_o_does_nothing("while Crashed")


# The pad's Workshop

func check_opens_the_workshop(why: String) -> void:
	check(office().showing and office().in_workshop(), "O should open the Workshop " + why)
	check(office().place == clock().location, "the Workshop should be this pad's " + why)
	check(office().screen == Office.Screen.SHIP_PAGE and hangar_screen().ship == hangar().in_service,
		"O should open the Landed ship's page " + why)
	check(lander().held, "the ship should be held in the Workshop " + why)
	check(hud().office_hint_text() == "", "no hint while the Workshop shows " + why)


func check_workshop_hint_shows(why: String) -> void:
	check(hud().office_hint_text() == Hud.WORKSHOP_HINT_TEXT,
		"the Workshop hint shows " + why + ", got %s" % hud().office_hint_text())


func test_landed_after_no_o_opens_the_workshop_and_after_leaving_it_again() -> void:
	clock().move_to(Location.MINE)
	await choose_ship()
	await land_on_pad()
	await decline_workshop()
	check_workshop_hint_shows("after No")
	check(hud().office_hint_text() == "O  ENTER THE WORKSHOP", "the hint reads, got %s" % hud().office_hint_text())
	await open_office_by_key()
	check_opens_the_workshop("after No")
	await press(&"ui_cancel")
	await wait_for_terminal()
	check(not office().showing and not lander().held, "Escape should leave the Workshop, releasing the ship")
	check_workshop_hint_shows("after leaving the Workshop")
	await open_office_by_key()
	check_opens_the_workshop("after leaving it")
	await press(&"ui_cancel")
	await wait_for_terminal()
	hold(&"ui_up")
	await seconds(0.5)
	release(&"ui_up")
	check(lander().state == Lander.State.FLYING, "Up should lift off after leaving the Workshop, state %s" % lander().state)
	await check_o_does_nothing("once lifted off")


func test_o_does_nothing_while_the_workshop_popup_shows() -> void:
	await choose_ship()
	await land_on_pad()
	check(office().popup == Office.PopupKind.ENTER_WORKSHOP, "landing should ask ENTER THE WORKSHOP?")
	await check_o_does_nothing("while the Workshop popup shows")
	check(office().popup == Office.PopupKind.ENTER_WORKSHOP, "the popup should stay")
