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


func station() -> Station:
	return main().get_node("Station")


func message() -> String:
	var label: Label = main().get_node("UI/Message")
	return label.text if label.visible else ""


# Set-up

# Picks a ship type in the Office the way a player does: browse to its Offer,
# press Return, then Return again on Yes. Leaves the ship Docked in the parking spot.
func choose_ship(type: ShipType = ShipType.SPARROW) -> void:
	await browse_to(type)
	await press(&"ui_accept")
	await press(&"ui_accept")
	await wait_for_terminal()
	check(not office().showing, "choosing the %s should close the Office" % type.name)


# Presses action (Right or Left) in the Office until it offers that ship type.
func browse_to(type: ShipType, action := &"ui_right") -> void:
	for i in ShipType.ALL.size():
		if office().selected_offer() == type:
			break
		await press(action)
	check(office().selected_offer() == type, "the Office should offer the %s" % type.name)


# Puts the lander in free flight at a set position, out of its docked start.
func place(position: Vector2, velocity := Vector2.ZERO) -> void:
	var ship := lander()
	ship.landed = false
	ship.docked = false
	ship.can_dock = true
	ship.in_deep_space = position.y < World.BORDER_Y
	ship.position = position
	ship.velocity = velocity
	ship.rotation = 0.0
	ship.modulate = Color.WHITE
	main().get_node("UI/Message").visible = false


# Flies the ship into the parking spot from free flight, which docks it (and
# opens the swap popup).
func dock_in_spot() -> void:
	place(station().parking_spot.get_center())
	await seconds(0.5)
	check(lander().docked, "the ship should dock in the parking spot")


# Per-ship-type measurements, for whichever ship type is chosen. Each one puts
# the ship in free flight, so choose a ship first.

func dry_mass() -> float:
	return lander().total_mass() - lander().fuel


# Presses + until dry mass reaches the ship type's Maximum weight.
func raise_to_maximum_weight() -> void:
	var steps := ceili((lander().ship_type.maximum_weight - dry_mass()) / Lander.DRY_MASS_STEP)
	for i in steps + 1:
		await press(&"weight_up")


# Whether a second of full thrust above the pad leaves the ship climbing.
func climbs_under_full_thrust() -> bool:
	var ship := lander()
	place(Vector2(World.WORLD_WIDTH / 2.0, 0))
	hold(&"ui_up")
	await seconds(1.0)
	release(&"ui_up")
	return ship.velocity.y < 0.0 and ship.position.y < 0.0


# Holds full thrust from below the border band until the ship crosses into deep
# space or 10 s pass; returns the top climb speed reached.
func top_climb_speed_to_the_border() -> float:
	var ship := lander()
	place(Vector2(World.WORLD_WIDTH / 2.0, World.BORDER_Y + 600.0))
	var top_speed := 0.0
	hold(&"ui_up")
	for i in roundi(10.0 * PHYSICS_FPS):
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
# wait_for_power is false, until the Terminal has powered on.
func restart(wait_for_power := true) -> void:
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
