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
