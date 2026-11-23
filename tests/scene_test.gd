extends RefCounted
# Base for scene tests: loads the main scene, drives it with input actions and
# checks what a player could observe. Extend it with `extends "res://tests/scene_test.gd"`.

const MAIN_SCENE := "res://main.tscn"
const PHYSICS_FPS := 60.0
const POWER_TIMEOUT_FRAMES := 120

var tree: SceneTree
var failures: Array[String] = []
var checks := 0
# What this test leaves pending, reported by the runner without failing the test.
var pending_notes: Array[String] = []


func start(scene_tree: SceneTree) -> void:
	tree = scene_tree
	await start_over()


# Loads a fresh main scene, as a fresh start of the game does: R no longer restarts anything.
# Waits for the Terminal to power on unless wait_for_power is false.
func start_over(wait_for_power := true) -> void:
	tree.change_scene_to_file(MAIN_SCENE)
	# The new scene is added on the next frame and becomes ready on the one after.
	await tree.process_frame
	await tree.process_frame
	if wait_for_power:
		await wait_for_terminal()


func finish() -> void:
	for action: StringName in InputMap.get_actions():
		if Input.is_action_pressed(action):
			Input.action_release(action)
	tree.unload_current_scene()
	tree.paused = false
	await tree.process_frame


# Scene access

func main() -> Node:
	return tree.current_scene


func world() -> World:
	return main()


func lander() -> Lander:
	return main().get_node("Lander")


func office() -> Office:
	return main().get_node("Office")


func economy() -> Economy:
	return main().get_node("Economy")


func station() -> Station:
	return main().get_node("Station")


func clock() -> PlanetClock:
	return main().get_node("PlanetClock")


func pad_x() -> float:
	return world().location.pad_center_x


# The middle of the drawn pad, in world x.
func pad_visual_center_x() -> float:
	var pad: Polygon2D = main().get_node("Ground/Pad")
	var left := INF
	var right := -INF
	for point in pad.polygon:
		left = minf(left, pad.to_global(point).x)
		right = maxf(right, pad.to_global(point).x)
	return (left + right) / 2.0


func ground() -> Polygon2D:
	return main().get_node("Ground/Polygon2D")


func mountain() -> Polygon2D:
	for child in main().get_node("Mountains").get_children():
		if child is Polygon2D:
			return child
	return null


# A Polygon2D's colour as drawn: its colour tinted by its own and its ancestors' modulate.
func shown_color(item: Polygon2D) -> Color:
	var color := item.color * item.self_modulate
	var node: Node = item
	while node is CanvasItem:
		color *= (node as CanvasItem).modulate
		node = node.get_parent()
	return color


func message() -> String:
	var label: Label = main().get_node("UI/Message")
	return label.text if label.visible else ""


# Set-up

# Puts a ship of this type in service the way a player does, from the main screen, then presses
# Escape until the Office closes, leaving it Docked in the parking spot. A type already in service
# needs nothing; an owned ship of the type is put in service from the Hangar; otherwise one is
# bought in the Shipyard first, with its price added to the balance beforehand so the balance ends
# as it was (the purchase is still a Transaction).
func choose_ship(type: ShipType = ShipType.SPARROW) -> void:
	await swap_to(type)
	await leave_office()


# choose_ship() without leaving: ends on the Office's main screen.
func swap_to(type: ShipType) -> void:
	if lander().ship_type == type:
		return
	var owned := owned_ship(type)
	if owned == null:
		economy().balance += type.price
		owned = await buy_ship(type)
	else:
		await open_hangar()
		await open_ship_page(owned)
	await put_in_service()
	check(lander().ship_type == type, "choosing the %s should put it in the parking spot" % type.name)
	await press(&"ui_cancel")
	await press(&"ui_cancel")
	check(office().screen == Office.Screen.MAIN, "Escape twice from a Ship page should reach the main screen")


# Escape until the Office closes, from any of its screens.
func leave_office() -> void:
	for i in 4:
		if not office().showing:
			break
		await press(&"ui_cancel")
		await wait_for_terminal()
	check(not office().showing, "Escape should close the Office")


# The first owned ship of this type, or null.
func owned_ship(type: ShipType) -> OwnedShip:
	for ship in hangar().ships:
		if ship.ship_type == type:
			return ship
	return null


func hangar() -> Hangar:
	return main().get_node("Hangar")


# Goes to the main screen's tile at this index (0 is SHIPYARD) and opens it.
func open_tile(index: int) -> void:
	for i in Office.TILES.size():
		await press(&"ui_left")
	for i in index:
		await press(&"ui_right")
	await press(&"ui_accept")
	check(office().screen == Office.TILES[index], "Return should open %s" % office().SCREEN_TITLES[Office.TILES[index]])


func open_shipyard() -> void:
	await open_tile(0)


func open_hangar() -> void:
	await open_tile(1)


func shipyard() -> ShipyardScreen:
	return office().shipyard


func hangar_screen() -> HangarScreen:
	return office().hangar_screen


# Presses action (Right or Left) in the Shipyard until it offers that ship type.
func browse_to(type: ShipType, action := &"ui_right") -> void:
	for i in ShipType.ALL.size():
		if shipyard().selected() == type:
			break
		await press(action)
	check(shipyard().selected() == type, "the Shipyard should offer the %s" % type.name)


# Buys a ship of this type from the main screen: the Shipyard, BUY, Yes. Returns the new ship,
# whose Ship page is then open.
func buy_ship(type: ShipType) -> OwnedShip:
	var before := hangar().ships.duplicate()
	await open_shipyard()
	await browse_to(type)
	await press(&"ui_accept")
	check(office().popup == Office.PopupKind.CONFIRM, "BUY should ask first, popup %s" % office().popup)
	await press(&"ui_accept")
	var bought: OwnedShip = null
	for ship in hangar().ships:
		if not ship in before:
			bought = ship
	check(bought != null, "Yes should buy a %s" % type.name)
	return bought


# On the Hangar's berths table: moves to the ship's row and opens its Ship page.
func open_ship_page(ship: OwnedShip) -> void:
	var row := hangar().ships.find(ship)
	while hangar_screen().row > row:
		await press(&"ui_up")
	while hangar_screen().row < row:
		await press(&"ui_down")
	await press(&"ui_accept")
	check(office().screen == Office.Screen.SHIP_PAGE and hangar_screen().ship == ship,
		"Return should open %s's Ship page" % ship.name)


# On a Ship page: moves to the action and presses Return.
func select_action(action: HangarScreen.Action) -> void:
	while hangar_screen().action > action:
		await press(&"ui_up")
	while hangar_screen().action < action:
		await press(&"ui_down")
	await press(&"ui_accept")


# On a Ship page: PUT IN SERVICE, then Yes.
func put_in_service() -> void:
	await select_action(HangarScreen.Action.PUT_IN_SERVICE)
	check(office().popup == Office.PopupKind.CONFIRM, "PUT IN SERVICE should ask first")
	await press(&"ui_accept")


# From the main screen: the Hangar, the ship's Ship page, then FUEL.
func open_fuel_screen(ship: OwnedShip) -> void:
	await open_hangar()
	await open_ship_page(ship)
	await select_action(HangarScreen.Action.FUEL)
	check(office().screen == Office.Screen.FUEL, "FUEL should open the fuel screen, screen %s" % office().screen)


func fuel_screen() -> FuelScreen:
	return office().fuel_screen


# Puts the lander Flying at a set position, upright, out of whatever state it was in.
func place(position: Vector2, velocity := Vector2.ZERO) -> void:
	lander().fly_from(position, velocity)


# How far below its origin the ship in service's hull reaches, turned by rotation.
func hull_bottom(rotation := 0.0) -> float:
	var bottom := -INF
	for point in lander().ship_type.hull:
		bottom = maxf(bottom, point.rotated(rotation).y)
	return bottom


# Flies the ship up into the station's underside, away from the entry, which crashes it in deep space.
func crash_in_deep_space() -> void:
	place(Vector2(World.WORLD_WIDTH / 4.0, World.SPACE_TOP_Y + 60.0), Vector2(0, -300))
	await seconds(1.0)
	check(message().begins_with("Crashed"), "should have crashed into the station, got %s" % message())
	check(lander().in_deep_space, "the crash should be in deep space")


# After a crash: presses R and waits for the Office to power on with the Wreck at the station.
func recover() -> void:
	check(lander().state == Lander.State.CRASHED, "Recovery needs a crash first")
	await press(&"restart")
	await wait_for_terminal()
	check(office().showing, "R after a crash should open the Office")


# Flies the ship into the parking spot from free flight, which docks it, and waits
# past the leveling (so the Enter-the-Office popup is open).
func dock_in_spot() -> void:
	place(station().parking_spot.get_center())
	await seconds(0.5)
	check(lander().state == Lander.State.DOCKED, "the ship should dock in the parking spot")


# Flies the ship in service down onto the current location's pad from just above it and waits until
# it's Landed (and the "ENTER THE WORKSHOP?" popup is open).
func land_on_pad() -> void:
	place(Vector2(pad_x(), world().location.ground_y - hull_bottom() - 8.0), Vector2(0, 20))
	for i in roundi(4.0 * PHYSICS_FPS):
		if lander().state == Lander.State.LANDED:
			break
		await frames(1)
	check(lander().state == Lander.State.LANDED, "the ship should land on the pad")


# From the "ENTER THE WORKSHOP?" popup: No (selected), leaving the ship Landed, free to lift off.
func decline_workshop() -> void:
	check(office().popup == Office.PopupKind.ENTER_WORKSHOP, "landing should ask ENTER THE WORKSHOP?")
	await press(&"ui_accept")


# From the "ENTER THE WORKSHOP?" popup: Yes, then waits for the Terminal to power on.
func enter_workshop() -> void:
	check(office().popup == Office.PopupKind.ENTER_WORKSHOP, "landing should ask ENTER THE WORKSHOP?")
	await press(&"ui_left")
	await press(&"ui_accept")
	await wait_for_terminal()
	check(office().showing and office().in_workshop(), "Yes should open the Workshop")


func open_bank_account() -> void:
	await open_tile(3)


# Transport offers

func open_transport_offers() -> void:
	await open_tile(2)


# Puts the cursor on the row itself, not its ACCEPT.
func select_row(index: int) -> void:
	while offers().list.selected_index() < index:
		await press(&"ui_down")
	while offers().list.selected_index() > index or offers().on_accept():
		await press(&"ui_up")
	check(offers().list.selected_index() == index and not offers().on_accept(), "Up/Down should reach row %d" % index)


func listed(prefix: String) -> bool:
	for row in offers().rows():
		if row.begins_with(prefix):
			return true
	return false


func reason_for(offer: TransportOffer) -> String:
	var row := economy().offers.find(offer)
	check(row != -1, "offer #%03d should be listed" % offer.number)
	return offers().reasons()[row] if row != -1 else "(not listed)"


func offers() -> TransportOffersScreen:
	return office().transport_offers


# Selects the offer's row and opens its details.
func open_details(offer: TransportOffer) -> void:
	await select_row(economy().offers.find(offer))
	await press(&"ui_accept")
	check(economy().offers.find(offer) in offers().list.expanded_rows(), "Return should open offer #%03d's details" % offer.number)


# Accepts the offer the way a player does: its details, Down to its ACCEPT, Return, then Yes.
func accept(offer: TransportOffer) -> void:
	await open_details(offer)
	await press(&"ui_down")
	check(offers().on_accept(), "Down should reach offer #%03d's ACCEPT" % offer.number)
	await press(&"ui_accept")
	check(office().popup == Office.PopupKind.ACCEPT_OFFER, "ACCEPT on offer #%03d should ask ARE YOU SURE?" % offer.number)
	await press(&"ui_accept")
	check(offer in economy().contracts, "Yes should make offer #%03d a Contract" % offer.number)


# Accepts the offers, then presses START LOADING and waits for the Terminal to power off.
func start_loading(contracts: Array[TransportOffer]) -> void:
	for offer in contracts:
		economy().put_offer(offer)
	await open_transport_offers()
	for offer in contracts:
		await accept(offer)
	await press(&"ui_right")
	await press(&"ui_accept")
	await wait_for_terminal()


func tester() -> Tester:
	return main().get_node("Tester")


# Turns Tester mode on if it's off, opens the Tester panel if it's closed, moves to the option's row
# and presses Return. The panel stays open.
func choose_tester_option(name: String) -> void:
	if not tester().on:
		await type_keys("TESTER")
	if not tester().panel_open:
		await press_key(KEY_QUOTELEFT)
	var row := tester().options.find(tester().option_named(name))
	check(row != -1 and tester().panel_open, "the Tester panel should list %s" % name)
	while tester().selected > row:
		await press(&"ui_up")
	while tester().selected < row:
		await press(&"ui_down")
	await press(&"ui_accept")


# Lands the ship on the current location's pad from anywhere in flight: the Tester panel's BACK TO
# PAD (turning Tester mode on first if it's off), then Escape closes the panel.
func back_to_pad() -> void:
	await choose_tester_option("BACK TO PAD")
	await close_tester_panel()


# Closes the Tester panel with Escape.
func close_tester_panel() -> void:
	await press(&"ui_cancel")
	check(not tester().panel_open, "Escape should close the Tester panel")


func hud() -> Control:
	return main().get_node("UI/Hud")


# An offer with these passengers, cargo and seconds left, long-lived unless time_left is given.
func known_offer(passengers: int, cargo_mass: float, time_left := 1000.0) -> TransportOffer:
	var offer := TransportOffer.new()
	offer.title = "Test run"
	offer.trader = "Test Trader"
	offer.passengers = passengers
	offer.cargo_mass = cargo_mass
	offer.deadline = 90.0
	offer.time_left = time_left
	offer.passenger_reward = 30000
	offer.cargo_reward = 12000
	return offer


# Per-ship-type measurements, for whichever ship type is chosen. Each one puts
# the ship in free flight, so choose a ship first.

func dry_mass() -> float:
	return lander().dry_mass


# Adds a Load that brings the ship, with its full Tank, to its Maximum weight.
func raise_to_maximum_weight() -> void:
	var ship := lander()
	ship.load_mass = ship.ship_type.maximum_weight - ship.total_mass()


# Whether a second of full thrust above the pad leaves the ship climbing.
func climbs_under_full_thrust() -> bool:
	var ship := lander()
	place(Vector2(World.WORLD_WIDTH / 2.0, 0))
	hold(&"ui_up")
	await seconds(1.0)
	release(&"ui_up")
	return ship.velocity.y < 0.0 and ship.position.y < 0.0


# Holds full thrust from below the border band until the ship crosses into deep
# space or 15 s pass; returns the top climb speed reached.
func top_climb_speed_to_the_border() -> float:
	var ship := lander()
	place(Vector2(World.WORLD_WIDTH / 2.0, World.BORDER_Y + 600.0))
	var top_speed := 0.0
	hold(&"ui_up")
	for i in roundi(15.0 * PHYSICS_FPS):
		await frames(1)
		top_speed = maxf(top_speed, -ship.velocity.y)
		if ship.in_deep_space:
			break
	release(&"ui_up")
	return top_speed


# Height in px climbed in 1 s of full thrust from rest at pad altitude (full gravity).
func climb_off_the_pad() -> float:
	var ship := lander()
	var start := Vector2(pad_x(), 400.0)
	place(start)
	hold(&"ui_up")
	await seconds(1.0)
	release(&"ui_up")
	return start.y - ship.position.y


# Rad/s turned while holding Left for 1 s in open deep space.
func turn_rate() -> float:
	var ship := lander()
	place(Vector2(World.WORLD_WIDTH / 4.0, World.BORDER_Y - 600.0))
	hold(&"ui_left")
	await seconds(1.0)
	release(&"ui_left")
	return -ship.rotation


# Seconds of continuous thrust a full tank lasts, with the ship held still in
# deep space (no gravity, no braking burn).
func full_tank_thrust_time() -> float:
	var ship := lander()
	var spot := Vector2(World.WORLD_WIDTH / 4.0, World.BORDER_Y - 600.0)
	place(spot)
	var thrust_frames := 0
	hold(&"ui_up")
	while ship.fuel > 0.0 and thrust_frames < roundi(120.0 * PHYSICS_FPS):
		await frames(1)
		thrust_frames += 1
		ship.position = spot
		ship.velocity = Vector2.ZERO
	release(&"ui_up")
	return thrust_frames / PHYSICS_FPS


# Input

func hold(action: StringName) -> void:
	send(action, true)


func release(action: StringName) -> void:
	send(action, false)


func press(action: StringName) -> void:
	hold(action)
	await frames(1)
	release(action)
	await frames(1)


func send(action: StringName, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	Input.parse_input_event(event)


# Types a key by its keycode (both its layout and physical key), as a player does: pressed, then released.
func press_key(keycode: Key) -> void:
	send_key(keycode, true)
	await frames(1)
	send_key(keycode, false)
	await frames(1)


func send_key(keycode: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.unicode = keycode if keycode < 128 else 0
	event.pressed = pressed
	Input.parse_input_event(event)


# Types the letters one after another, as a player does.
func type_keys(letters: String) -> void:
	for letter in letters:
		await press_key(OS.find_keycode_from_string(letter))


# Waits out the Terminal's CRT power-on/off effect, if one is running.
func wait_for_terminal() -> void:
	for i in POWER_TIMEOUT_FRAMES:
		if not office().powering:
			return
		await frames(1)
	check(false, "the Terminal's power-on/off effect should finish")


# Time

func frames(count: int) -> void:
	for i in count:
		await tree.physics_frame


func seconds(duration: float) -> void:
	await frames(roundi(duration * PHYSICS_FPS))


# Checks

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)


func check_near(actual: float, expected: float, tolerance: float, description: String) -> void:
	check(absf(actual - expected) <= tolerance, "%s: expected %s ± %s, got %s" % [description, expected, tolerance, actual])


# Notes that part of what this test checks is pending (for example until the scenery meeting it
# lands); the runner reports it without failing the test.
func pending(what: String) -> void:
	pending_notes.append(what)
