class_name Lander
extends CharacterBody2D

# Per-ship values (thrust, turn rate, masses, tank, burn rate) live in ShipType.
const GRAVITY := 60.0

# Mass at which thrust, gravity and burn rate are unscaled: a default Sparrow with a full tank.
const REFERENCE_MASS := 15000.0
const GRAVITY_MASS_SCALE := 0.5
# Share of the Load's mass that counts toward fuel burn, so loaded ships burn more gently.
const LOAD_BURN_SHARE := 0.5

const LIFTOFF_BURN_MULTIPLIER := 2.0
const LIFTOFF_BURN_TIME := 1.0
const BRAKING_BURN_FACTOR := 1.0
const BRAKING_FULL_SPEED := 150.0

const LEVEL_TIME := 0.3
const REFUEL_DELAY := 2.0
# Share of the tank refilled per second: half a tank per 6 s.
const REFUEL_TANK_SHARE := 0.5 / 6.0

const MAX_LANDING_VERTICAL_SPEED := 50.0
const MAX_LANDING_HORIZONTAL_SPEED := 25.0
const MAX_LANDING_ANGLE_DEG := 15.0
const MAX_DOCKING_SPEED := 40.0

const PAD_WIDTH := 120.0
const PAD_HEIGHT := 6.0

# Gravity fades out over this strip just below the border.
const BORDER_BAND := 200.0
const CROSSING_SPEED := 150.0
const BOUNCE_STIFFNESS := 9.0

# Crossing the border disturbs the ship: while the controls are ignored, its nose wobbles
# DISTURB_WOBBLES times and settles on a random lasting turn, its path turning with it. The
# largest turn and the time scale from a crossing at CROSSING_SPEED (slow) to one at
# DISTURB_FAST_SPEED or faster; a turn is never smaller than DISTURB_MIN_TURN_SHARE of the
# largest, and each wobble swings up to half the largest either way.
const DISTURB_FAST_SPEED := 400.0
const DISTURB_SLOW_TURN_DEG := 12.0
const DISTURB_FAST_TURN_DEG := 3.0
const DISTURB_MIN_TURN_SHARE := 1.0 / 3.0
const DISTURB_SLOW_TIME := 0.6
const DISTURB_FAST_TIME := 0.3
const DISTURB_WOBBLES := 4

const STEER_DISTANCE := 150.0
const STEER_SPEED := 100.0
const STEER_BRAKING := 600.0

const SOFT_WALL_WIDTH := 150.0
const SOFT_WALL_DAMPING := 8.0
const SOFT_WALL_PUSH := 300.0

# Docked in the parking spot by flying in, once the ship has finished easing upright.
# Lifting off before then cancels it.
signal docked_at_station
# Landed on the pad, by a real landing or the debug pad shortcut.
signal landed_on_pad

enum State { FLYING, LANDED, DOCKED, CRASHED }

const LANDED_COLOR := Color(0.3, 1.0, 0.4)
const CRASHED_COLOR := Color(1.0, 0.3, 0.3)

var ship_type: ShipType
var dry_mass: float
var fuel: float
# Passengers and cargo carried for the Contracts.
var load_mass := 0.0
# Change only through enter(), which resets what the old state left behind.
var state := State.FLYING
# Set from outside through hold() and release(): a held ship ignores the controls and stays put.
var held := false
# Set from outside: the ship rests where it is (refuelling included) but can't lift off.
# Unlike held, entering a state doesn't clear it, so a ship that settles back keeps it.
var lift_off_blocked := false
# Set through start_loading() and finish_loading(): while a Load goes aboard the ship rests
# and refuels up to the cap for it, but can't lift off or turn. It counts toward the mass
# only once loading finishes.
var loading := false
var incoming_load := 0.0
var rest_time := 0.0
var since_liftoff := INF
var level_tween: Tween
var in_deep_space := false
var bouncing := false
var steering_after_crossing := false
# The border disturbance under way: seconds left of disturb_time, the nose's offsets from its
# angle at the crossing that it passes through (the last is the lasting turn), and the offset
# reached so far.
var disturb_left := 0.0
var disturb_time := 0.0
var disturb_offsets := PackedFloat32Array()
var disturb_offset := 0.0
# Seedable, for tests.
var rng := RandomNumberGenerator.new()
var can_dock := true
# A line the resting message adds under Docked!/Landed!, such as the loading countdown.
# Set it through show_status(): the message is rewritten every frame while resting.
var status := ""
var proto: PrototypeUpgrades
# Whether the last rest refuelled, so a new status keeps the Refueling… line.
var refueling := false

@onready var body: Polygon2D = $Body
@onready var flame: Polygon2D = $Flame
@onready var hull: CollisionPolygon2D = $CollisionPolygon2D
@onready var camera: FollowCamera = $Camera
@onready var world: World = $".."
@onready var ground: StaticBody2D = $"../Ground"
@onready var station: Station = $"../Station"
@onready var message: Label = $"../UI/Message"


func _ready() -> void:
	rng.randomize()
	start_docked(ShipType.SPARROW)
	# PROTOTYPE (issue #94): candidate upgrades, toggled in flight.
	proto = PrototypeUpgrades.new()
	add_child(proto)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		# A testing shortcut: in debug builds R on the Surface only puts the ship back on the pad.
		if OS.is_debug_build() and not in_deep_space:
			reset_to_pad()
		else:
			get_tree().reload_current_scene()


func become(type: ShipType) -> void:
	ship_type = type
	body.polygon = type.hull
	hull.polygon = type.hull
	flame.polygon = type.flame
	dry_mass = type.default_dry_mass
	fuel = type.tank


# Every run, and every Ship swap, starts Docked in the station's parking spot as
# the given ship type, facing up, at rest, at its default dry mass with a full tank.
func start_docked(type: ShipType) -> void:
	become(type)
	enter(State.DOCKED)
	move_to(station.parking_spot.get_center())


# Puts the ship Landed on the pad, upright and at rest, keeping its ship type, dry mass and fuel.
func reset_to_pad() -> void:
	var hull_bottom := 0.0
	for point in hull.polygon:
		hull_bottom = maxf(hull_bottom, point.y)
	enter(State.LANDED)
	move_to(Vector2(pad_center_x(), ground_top() - hull_bottom))
	landed_on_pad.emit()


# Puts the ship Flying at a position, upright, keeping its ship type, dry mass and fuel.
func fly_from(at: Vector2, at_velocity := Vector2.ZERO) -> void:
	enter(State.FLYING)
	move_to(at, at_velocity)


# The one way into a Ship state. Every state starts fresh: not held, no lift-off
# burn, docking armed, no leveling under way.
func enter(new_state: State) -> void:
	state = new_state
	held = false
	rest_time = 0.0
	since_liftoff = INF
	can_dock = true
	status = ""
	refueling = false
	if level_tween:
		level_tween.kill()
	match new_state:
		State.FLYING:
			modulate = Color.WHITE
			message.visible = false
		State.LANDED:
			show_state("Landed!", LANDED_COLOR)
		State.DOCKED:
			show_state("Docked!", LANDED_COLOR)
		State.CRASHED:
			flame.visible = false
			show_state("Crashed!\nPress R to retry", CRASHED_COLOR)


func show_state(title: String, color: Color) -> void:
	modulate = color
	message.text = title
	message.visible = true


# Moves the ship upright to a position, leaving any border bounce or steering behind.
func move_to(at: Vector2, at_velocity := Vector2.ZERO) -> void:
	position = at
	rotation = 0.0
	velocity = at_velocity
	in_deep_space = at.y < World.BORDER_Y
	bouncing = false
	steering_after_crossing = false
	disturb_left = 0.0
	camera.reset_smoothing()


func ground_top() -> float:
	var shape: RectangleShape2D = ground.get_node("CollisionShape2D").shape
	return ground.position.y - shape.size.y / 2.0


func _physics_process(delta: float) -> void:
	var thrusting := Input.is_action_pressed("ui_up") and fuel > 0.0 and disturb_left <= 0.0 \
		and not ((lift_off_blocked or loading) and state != State.FLYING)
	if held or state == State.CRASHED:
		flame.visible = false
		return
	flame.visible = thrusting
	if state != State.FLYING:
		if not thrusting:
			rest(delta)
			return
		lift_off()

	if disturb_left > 0.0:
		disturb(delta)
	else:
		rotation += Input.get_axis("ui_left", "ui_right") * ship_type.turn_rate * delta

	var mass_factor := total_mass() / REFERENCE_MASS
	velocity.y += GRAVITY * (1.0 + GRAVITY_MASS_SCALE * (mass_factor - 1.0)) * gravity_share() * delta

	if thrusting:
		var thrust_dir := Vector2.UP.rotated(rotation)
		var burn_factor := (dry_mass + fuel + LOAD_BURN_SHARE * load_mass) / REFERENCE_MASS
		fuel = maxf(fuel - ship_type.burn_rate * burn_factor * burn_multiplier(thrust_dir) * delta, 0.0)
		velocity += thrust_dir * ship_type.thrust / mass_factor * delta
	if proto:
		proto.fly(delta)
	since_liftoff += delta

	if bouncing:
		# A spring back toward the border, so a ship too slow to cross bounces off it.
		velocity.y -= BOUNCE_STIFFNESS * (position.y - World.BORDER_Y) * delta
	if steering_after_crossing and velocity.length() > STEER_SPEED:
		velocity = velocity.limit_length(move_toward(velocity.length(), STEER_SPEED, STEER_BRAKING * delta))
	push_off_soft_walls(delta)

	# move_and_slide() cancels velocity into the ground, so keep the impact velocity.
	var impact_velocity := velocity
	move_and_slide()

	if get_slide_collision_count() > 0:
		if touched_only_ground() and is_safe_landing(impact_velocity):
			land()
		else:
			crash()
		return

	keep_inside_world()
	cross_border()
	try_docking(thrusting)


func total_mass() -> float:
	return dry_mass + fuel + load_mass


# The most fuel refuelling may fill: a full Tank, or less if the Load would push
# the ship past its Maximum weight.
func fuel_cap() -> float:
	return fuel_cap_for(load_mass + incoming_load)


func fuel_cap_for(with_load: float) -> float:
	return clampf(ship_type.maximum_weight - dry_mass - with_load, 0.0, ship_type.tank)


func tank_level() -> float:
	return fuel / ship_type.tank


func gravity_share() -> float:
	return smoothstep(World.BORDER_Y, World.BORDER_Y + BORDER_BAND, position.y)


func burn_multiplier(thrust_dir: Vector2) -> float:
	var multiplier := 1.0
	if since_liftoff < LIFTOFF_BURN_TIME:
		multiplier *= LIFTOFF_BURN_MULTIPLIER
	var opposing := maxf(0.0, -thrust_dir.dot(velocity.normalized()))
	var speed_share := clampf(velocity.length() / BRAKING_FULL_SPEED, 0.0, 1.0)
	return multiplier * (1.0 + BRAKING_BURN_FACTOR * opposing * speed_share)


func soft_wall_depth() -> float:
	# Below the mountain tops the mountains wall the sides instead.
	if position.y >= World.MOUNTAIN_TOP_Y:
		return 0.0
	var edge_distance := minf(position.x, World.WORLD_WIDTH - position.x)
	return maxf(SOFT_WALL_WIDTH - edge_distance, 0.0)


func push_off_soft_walls(delta: float) -> void:
	var depth := soft_wall_depth()
	if depth <= 0.0:
		return
	var inward := 1.0 if position.x < World.WORLD_WIDTH / 2.0 else -1.0
	if velocity.x * inward < 0.0:
		velocity.x *= exp(-SOFT_WALL_DAMPING * delta)
	velocity.x += inward * SOFT_WALL_PUSH * depth / SOFT_WALL_WIDTH * delta


func keep_inside_world() -> void:
	if position.y >= World.MOUNTAIN_TOP_Y:
		return
	var clamped_x := clampf(position.x, 0.0, World.WORLD_WIDTH)
	if clamped_x != position.x:
		position.x = clamped_x
		velocity.x = 0.0


func cross_border() -> void:
	if absf(position.y - World.BORDER_Y) > STEER_DISTANCE:
		steering_after_crossing = false
	var past_border := (position.y < World.BORDER_Y) != in_deep_space
	if not past_border:
		bouncing = false
		return
	if bouncing:
		return
	if absf(velocity.y) >= CROSSING_SPEED:
		in_deep_space = not in_deep_space
		steering_after_crossing = true
		start_disturbance(velocity.length())
		camera.shake()
		camera.punch()
	else:
		bouncing = true


# Picks the lasting turn and the wobbles on the way to it; slower crossings are disturbed
# more, and for longer.
func start_disturbance(speed: float) -> void:
	var fast := clampf(inverse_lerp(CROSSING_SPEED, DISTURB_FAST_SPEED, speed), 0.0, 1.0)
	var largest := deg_to_rad(lerpf(DISTURB_SLOW_TURN_DEG, DISTURB_FAST_TURN_DEG, fast))
	disturb_offsets.clear()
	for i in DISTURB_WOBBLES:
		disturb_offsets.append(rng.randf_range(-largest / 2.0, largest / 2.0))
	var turn := rng.randf_range(DISTURB_MIN_TURN_SHARE * largest, largest)
	disturb_offsets.append(turn if rng.randf() < 0.5 else -turn)
	disturb_time = lerpf(DISTURB_SLOW_TIME, DISTURB_FAST_TIME, fast)
	disturb_left = disturb_time
	disturb_offset = 0.0


# Moves the nose along the wobbles, in equal quick steps from one offset to the next, and turns
# the velocity by the same angle so the path bends with it.
func disturb(delta: float) -> void:
	disturb_left = maxf(disturb_left - delta, 0.0)
	var progress := (1.0 - disturb_left / disturb_time) * disturb_offsets.size()
	var step := mini(floori(progress), disturb_offsets.size() - 1)
	var from := disturb_offsets[step - 1] if step > 0 else 0.0
	var offset := lerpf(from, disturb_offsets[step], progress - step)
	rotation += offset - disturb_offset
	velocity = velocity.rotated(offset - disturb_offset)
	disturb_offset = offset


func try_docking(thrusting: bool) -> void:
	if not is_inside_spot():
		can_dock = true
	elif can_dock and not thrusting and velocity.length() <= MAX_DOCKING_SPEED:
		dock()


func is_inside_spot() -> bool:
	for point in hull.polygon:
		if not station.parking_spot.has_point(to_global(point)):
			return false
	return true


func touched_only_ground() -> bool:
	for i in get_slide_collision_count():
		if get_slide_collision(i).get_collider() != ground:
			return false
	return true


func pad_center_x() -> float:
	return world.location.pad_center_x


func is_safe_landing(impact_velocity: Vector2) -> bool:
	# angle_difference() wraps to [-PI, PI], so e.g. 350° counts as 10° from upright.
	var tilt := absf(angle_difference(0.0, rotation))
	var on_pad := absf(position.x - pad_center_x()) <= PAD_WIDTH / 2.0
	return impact_velocity.y <= MAX_LANDING_VERTICAL_SPEED \
		and absf(impact_velocity.x) <= MAX_LANDING_HORIZONTAL_SPEED \
		and tilt <= deg_to_rad(MAX_LANDING_ANGLE_DEG) \
		and on_pad


func land() -> void:
	enter(State.LANDED)
	settle()
	# Leveling lifts the corner that touched down, so drop back onto the ground.
	level_tween.tween_callback(move_and_collide.bind(Vector2.DOWN * PAD_HEIGHT * 4.0))
	landed_on_pad.emit()


func dock() -> void:
	enter(State.DOCKED)
	settle()
	level_tween.tween_callback(docked_at_station.emit)


# Freezes the ship in whatever state it's in until release() or the next state.
func hold() -> void:
	held = true


# A released ship rests afresh, so refuelling waits the usual delay again.
func release() -> void:
	held = false
	rest_time = 0.0


# Fuel above the cap for the incoming Load is pumped out, and refuelling runs from the first frame.
func start_loading(with_load: float) -> void:
	held = false
	loading = true
	incoming_load = with_load
	fuel = minf(fuel, fuel_cap())
	rest_time = maxf(rest_time, REFUEL_DELAY)


func finish_loading() -> void:
	loading = false
	load_mass += incoming_load
	incoming_load = 0.0


# Stops the ship where it touched down and levels it.
func settle() -> void:
	velocity = Vector2.ZERO
	# Wrap first so leveling never unwinds the player's full spins.
	rotation = wrapf(rotation, -PI, PI)
	level_tween = create_tween()
	level_tween.tween_property(self, "rotation", 0.0, LEVEL_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func rest(delta: float) -> void:
	# A docked ship may turn in place to face the way out.
	if state == State.DOCKED and not loading and not (level_tween and level_tween.is_running()):
		rotation += Input.get_axis("ui_left", "ui_right") * ship_type.turn_rate * delta
	rest_time += delta
	refueling = rest_time >= REFUEL_DELAY and fuel < fuel_cap()
	if refueling:
		fuel = minf(fuel + ship_type.tank * REFUEL_TANK_SHARE * delta, fuel_cap())
	show_rest_message()


func show_status(text: String) -> void:
	status = text
	# A held ship doesn't rest, so show it now.
	show_rest_message()


func show_rest_message() -> void:
	if state != State.DOCKED and state != State.LANDED:
		return
	var lines := PackedStringArray(["Docked!" if state == State.DOCKED else "Landed!"])
	if status != "":
		lines.append(status)
	if refueling:
		lines.append("Refueling…")
	message.text = "\n".join(lines)


func lift_off() -> void:
	var from := state
	enter(State.FLYING)
	# Only leaving the pad costs extra fuel; undocking burns at the default rate.
	if from == State.LANDED:
		since_liftoff = 0.0
	# Undocking mustn't dock again before the ship has left the spot.
	if from == State.DOCKED:
		can_dock = false


func crash() -> void:
	enter(State.CRASHED)
