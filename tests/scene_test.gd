extends RefCounted
# Base for scene tests: loads the main scene, drives it with input actions and
# checks what a player could observe. Extend it with `extends "res://tests/scene_test.gd"`.

const MAIN_SCENE := "res://main.tscn"
const PHYSICS_FPS := 60.0
const RESTART_TIMEOUT_FRAMES := 600
const POWER_TIMEOUT_FRAMES := 120

var tree: SceneTree
var failures: Array[String] = []
var checks := 0


func start(scene_tree: SceneTree) -> void:
	tree = scene_tree
	tree.change_scene_to_file(MAIN_SCENE)
	# The new scene is added on the next frame and becomes ready on the one after.
	await tree.process_frame
	await tree.process_frame
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


func lander() -> Lander:
	return main().get_node("Lander")


func office() -> Office:
	return main().get_node("Office")


func economy() -> Economy:
	return main().get_node("Economy")


func station() -> Station:
	return main().get_node("Station")


func message() -> String:
	var label: Label = main().get_node("UI/Message")
	return label.text if label.visible else ""


# Set-up

# Picks a ship type in the Office the way a player does, from the main screen: open
# Ship selection, browse to its Ship offer, press Return and confirm Yes (the ship type
# in service needs no confirming), then Escape. Leaves the ship Docked in the parking spot.
func choose_ship(type: ShipType = ShipType.SPARROW) -> void:
	await open_ship_selection()
	await browse_to(type)
	await press(&"ui_accept")
	if office().popup == Office.PopupKind.ARE_YOU_SURE:
		await press(&"ui_accept")
	check(office().screen == Office.Screen.MAIN, "choosing the %s should return to the main screen" % type.name)
	check(lander().ship_type == type, "choosing the %s should put it in the parking spot" % type.name)
	await press(&"ui_cancel")
	await wait_for_terminal()
	check(not office().showing, "Escape on the main screen should close the Office")


# Opens the Ship selection tile from the Office main screen.
func open_ship_selection() -> void:
	for i in Office.TILES.size():
		await press(&"ui_left")
	await press(&"ui_accept")
	check(office().screen == Office.Screen.SHIP_SELECTION, "Return should open Ship selection")


# Presses action (Right or Left) in the Office until it offers that ship type.
func browse_to(type: ShipType, action := &"ui_right") -> void:
	for i in ShipType.ALL.size():
		if office().selected_ship_offer() == type:
			break
		await press(action)
	check(office().selected_ship_offer() == type, "the Office should offer the %s" % type.name)


# Puts the lander Flying at a set position, upright, out of whatever state it was in.
func place(position: Vector2, velocity := Vector2.ZERO) -> void:
	lander().fly_from(position, velocity)


# Flies the ship up into the station's underside, away from the entry, which crashes it in deep space.
func crash_in_deep_space() -> void:
	place(Vector2(World.WORLD_WIDTH / 4.0, World.SPACE_TOP_Y + 60.0), Vector2(0, -300))
	await seconds(1.0)
	check(message().begins_with("Crashed"), "should have crashed into the station, got %s" % message())
	check(lander().in_deep_space, "the crash should be in deep space")


# Flies the ship into the parking spot from free flight, which docks it (and
# opens the Enter-the-Office popup).
func dock_in_spot() -> void:
	place(station().parking_spot.get_center())
	await seconds(0.5)
	check(lander().state == Lander.State.DOCKED, "the ship should dock in the parking spot")


# Transport offers

func open_transport_offers() -> void:
	for i in Office.TILES.size():
		await press(&"ui_left")
	await press(&"ui_right")
	await press(&"ui_accept")
	check(office().screen == Office.Screen.TRANSPORT_OFFERS, "Return should open Transport offers")


func select_row(index: int) -> void:
	while offers().selected_index < index:
		await press(&"ui_down")
	while offers().selected_index > index:
		await press(&"ui_up")
	check(offers().selected_index == index, "Down should reach row %d" % index)


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
	check(offers().expanded_row() == economy().offers.find(offer), "Return should open offer #%03d's details" % offer.number)


# Accepts the offer the way a player does: its details, ACCEPT, then Yes.
func accept(offer: TransportOffer) -> void:
	await open_details(offer)
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
	offer.passenger_reward = 300
	offer.cargo_reward = 120
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
	var start := Vector2(Lander.PAD_CENTER_X, 400.0)
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


# Presses R and waits until the reloaded main scene is ready and, unless
# wait_for_power is false, until the Terminal has powered on. R on the Surface
# only teleports to the pad, so a ship below the border is moved to deep space first.
func restart(wait_for_power := true) -> void:
	if not lander().in_deep_space:
		place(Vector2(World.WORLD_WIDTH / 4.0, World.BORDER_Y - 600.0))
	var old_scene := main()
	await press(&"restart")
	for i in RESTART_TIMEOUT_FRAMES:
		if main() != old_scene and main() != null and main().is_node_ready():
			if wait_for_power:
				await wait_for_terminal()
			return
		await tree.process_frame
	check(false, "R should have reloaded the scene")


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
