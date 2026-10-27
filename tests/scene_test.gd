extends RefCounted
# Base for scene tests: loads the main scene, drives it with input actions and
# checks what a player could observe. Extend it with `extends "res://tests/scene_test.gd"`.

const MAIN_SCENE := "res://main.tscn"
const PHYSICS_FPS := 60.0
const RESTART_TIMEOUT_FRAMES := 600

var tree: SceneTree
var failures: Array[String] = []
var checks := 0


func start(scene_tree: SceneTree) -> void:
	tree = scene_tree
	tree.change_scene_to_file(MAIN_SCENE)
	# The new scene is added on the next frame and becomes ready on the one after.
	await tree.process_frame
	await tree.process_frame


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
func choose_ship(type_name := "Sparrow") -> void:
	for i in ShipType.ALL.size():
		if office().selected_offer().name == type_name:
			break
		await press(&"ui_right")
	check(office().selected_offer().name == type_name, "the Office should offer the %s" % type_name)
	await press(&"ui_accept")
	await press(&"ui_accept")
	check(not office().showing, "choosing the %s should close the Office" % type_name)


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


# Ship type measurements: the same for every ship type, so their numbers compare.

const DEEP_SPACE_SPOT := Vector2(World.WORLD_WIDTH / 2.0, (World.BORDER_Y + World.SPACE_TOP_Y) / 2.0)
const MEASURE_TIMEOUT := 120.0
# The Sparrow's numbers from the helpers below, measured once. Other ship types'
# tuning targets are relative to these.
const SPARROW_CLIMB_OFF_PAD := 45.3
const SPARROW_FULL_TANK_THRUST_TIME := 24.35


func raise_to_maximum_weight() -> void:
	var ship := lander()
	var steps := ceili((ship.ship_type.maximum_weight - ship.dry_mass) / Lander.DRY_MASS_STEP) + 1
	for i in steps:
		await press(&"weight_up")
	check_near(ship.total_mass() - ship.fuel, ship.ship_type.maximum_weight, 0.01, "dry mass at Maximum weight")


# Drops the ship gently onto the pad and waits until it has Landed.
func land_on_pad() -> void:
	var ship := lander()
	var hull_bottom := 0.0
	for point in ship.ship_type.hull:
		hull_bottom = maxf(hull_bottom, point.y)
	place(Vector2(Lander.PAD_CENTER_X, 600.0 - hull_bottom), Vector2(0, 20))
	await seconds(3.0)
	check(ship.landed, "the %s should have Landed on the pad, at %s, says %s" % [ship.ship_type.name, ship.position, message()])


# Height in px gained in the first second of full thrust off the pad.
func climb_off_pad() -> float:
	await land_on_pad()
	var ship := lander()
	var start_y := ship.position.y
	hold(&"ui_up")
	await seconds(1.0)
	release(&"ui_up")
	return start_y - ship.position.y


# Seconds of continuous full thrust a full Tank lasts, held still in deep space.
func full_tank_thrust_time() -> float:
	var ship := lander()
	check_near(ship.tank_level(), 1.0, 0.0001, "tank level before the thrust run")
	place(DEEP_SPACE_SPOT)
	hold(&"ui_up")
	var count := 0
	while ship.fuel > 0.0 and count < MEASURE_TIMEOUT * PHYSICS_FPS:
		await frames(1)
		count += 1
		ship.position = DEEP_SPACE_SPOT
		ship.velocity = Vector2.ZERO
	release(&"ui_up")
	return count / PHYSICS_FPS


# Rad/s turned while holding Right in deep space.
func measured_turn_rate() -> float:
	var ship := lander()
	place(DEEP_SPACE_SPOT)
	hold(&"ui_right")
	await seconds(1.0)
	release(&"ui_right")
	return ship.rotation / 1.0


func check_hovers_at_maximum_weight() -> void:
	var ship := lander()
	await raise_to_maximum_weight()
	place(Vector2(World.WORLD_WIDTH / 2.0, 0))
	hold(&"ui_up")
	await seconds(1.0)
	release(&"ui_up")
	check(ship.velocity.y < 0.0, "should be climbing under full thrust, velocity.y is %s" % ship.velocity.y)
	check(ship.position.y < 0.0, "should have climbed, y is %s" % ship.position.y)


func check_crosses_the_border_at_maximum_weight() -> void:
	var ship := lander()
	await raise_to_maximum_weight()
	place(Vector2(World.WORLD_WIDTH / 2.0, World.BORDER_Y + 600.0))
	var top_climb_speed := 0.0
	hold(&"ui_up")
	for i in roundi(15.0 * PHYSICS_FPS):
		await frames(1)
		top_climb_speed = maxf(top_climb_speed, -ship.velocity.y)
		if ship.in_deep_space:
			break
	release(&"ui_up")
	check(ship.in_deep_space, "should have crossed into deep space")
	check(top_climb_speed >= Lander.CROSSING_SPEED, "should reach the crossing speed, top speed %s" % top_climb_speed)


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


# Presses R and waits until the reloaded main scene is ready.
func restart() -> void:
	var old_scene := main()
	await press(&"restart")
	for i in RESTART_TIMEOUT_FRAMES:
		if main() != old_scene and main() != null and main().is_node_ready():
			return
		await tree.process_frame
	check(false, "R should have reloaded the scene")


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
