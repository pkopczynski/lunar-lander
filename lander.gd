class_name Lander
extends CharacterBody2D

# Per-ship values (thrust, turn rate, masses, tank, burn rate) live in ShipType.
const GRAVITY := 60.0

const MIN_DRY_MASS := 5000.0
const DRY_MASS_STEP := 1000.0
# Mass at which thrust, gravity and burn rate are unscaled: a default Sparrow with a full tank.
const REFERENCE_MASS := 15000.0
const GRAVITY_MASS_SCALE := 0.5

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

const PAD_CENTER_X := World.WORLD_WIDTH / 2.0
const PAD_WIDTH := 120.0
const PAD_HEIGHT := 6.0

# Gravity fades out over this strip just below the border.
const BORDER_BAND := 200.0
const CROSSING_SPEED := 150.0
const BOUNCE_STIFFNESS := 9.0

const STEER_DISTANCE := 150.0
const STEER_SPEED := 100.0
const STEER_BRAKING := 600.0
# Below this vertical speed, steering turns the nose up.
const STEER_STILL_SPEED := 20.0

const SOFT_WALL_WIDTH := 150.0
const SOFT_WALL_DAMPING := 8.0
const SOFT_WALL_PUSH := 300.0

const LANDED_COLOR := Color(0.3, 1.0, 0.4)
const CRASHED_COLOR := Color(1.0, 0.3, 0.3)

var ship_type: ShipType
var dry_mass: float
var fuel: float
var landed := false
var docked := false
var rest_time := 0.0
var since_liftoff := INF
var level_tween: Tween
var in_deep_space := false
var bouncing := false
var steering_after_crossing := false
var can_dock := true

@onready var body: Polygon2D = $Body
@onready var flame: Polygon2D = $Flame
@onready var hull: CollisionPolygon2D = $CollisionPolygon2D
@onready var camera: FollowCamera = $Camera
@onready var ground: StaticBody2D = $"../Ground"
@onready var pad: Polygon2D = $"../Ground/Pad"
@onready var station: Station = $"../Station"
@onready var message: Label = $"../UI/Message"


func _ready() -> void:
	become(ShipType.SPARROW)
	start_docked()
	var half := PAD_WIDTH / 2.0
	pad.position.x = PAD_CENTER_X - pad.get_parent().position.x
	pad.polygon = PackedVector2Array([
		Vector2(-half, -PAD_HEIGHT), Vector2(half, -PAD_HEIGHT),
		Vector2(half, 0), Vector2(-half, 0),
	])


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		get_tree().reload_current_scene()
	elif event.is_action_pressed("weight_up"):
		dry_mass = minf(dry_mass + DRY_MASS_STEP, ship_type.maximum_weight)
	elif event.is_action_pressed("weight_down"):
		dry_mass = maxf(dry_mass - DRY_MASS_STEP, MIN_DRY_MASS)


func become(type: ShipType) -> void:
	ship_type = type
	body.polygon = type.hull
	hull.polygon = type.hull
	flame.polygon = type.flame
	dry_mass = type.default_dry_mass
	fuel = type.tank


# Every run starts Docked in the station's parking spot, facing up, at rest.
func start_docked() -> void:
	position = station.parking_spot.get_center()
	rotation = 0.0
	velocity = Vector2.ZERO
	in_deep_space = true
	landed = false
	docked = true
	rest_time = 0.0
	modulate = LANDED_COLOR
	message.text = "Docked!"
	message.visible = true
	camera.reset_smoothing()


func _physics_process(delta: float) -> void:
	var thrusting := Input.is_action_pressed("ui_up") and fuel > 0.0
	flame.visible = thrusting
	if landed or docked:
		if not thrusting:
			rest(delta)
			return
		lift_off()

	if is_steered():
		rotation = rotate_toward(rotation, steer_rotation(), ship_type.turn_rate * delta)
	else:
		rotation += Input.get_axis("ui_left", "ui_right") * ship_type.turn_rate * delta

	var mass_factor := total_mass() / REFERENCE_MASS
	velocity.y += GRAVITY * (1.0 + GRAVITY_MASS_SCALE * (mass_factor - 1.0)) * gravity_share() * delta

	if thrusting:
		var thrust_dir := Vector2.UP.rotated(rotation)
		fuel = maxf(fuel - ship_type.burn_rate * mass_factor * burn_multiplier(thrust_dir) * delta, 0.0)
		velocity += thrust_dir * ship_type.thrust / mass_factor * delta
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
	return dry_mass + fuel


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


func is_steered() -> bool:
	return steering_after_crossing or soft_wall_depth() > 0.0


func steer_rotation() -> float:
	return PI if velocity.y > STEER_STILL_SPEED else 0.0


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
		camera.shake()
		camera.punch()
	else:
		bouncing = true


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


func is_safe_landing(impact_velocity: Vector2) -> bool:
	# angle_difference() wraps to [-PI, PI], so e.g. 350° counts as 10° from upright.
	var tilt := absf(angle_difference(0.0, rotation))
	var on_pad := absf(position.x - PAD_CENTER_X) <= PAD_WIDTH / 2.0
	return impact_velocity.y <= MAX_LANDING_VERTICAL_SPEED \
		and absf(impact_velocity.x) <= MAX_LANDING_HORIZONTAL_SPEED \
		and tilt <= deg_to_rad(MAX_LANDING_ANGLE_DEG) \
		and on_pad


func land() -> void:
	landed = true
	settle("Landed!")
	# Leveling lifts the corner that touched down, so drop back onto the ground.
	level_tween.tween_callback(move_and_collide.bind(Vector2.DOWN * PAD_HEIGHT * 4.0))


func dock() -> void:
	docked = true
	settle("Docked!")


func settle(title: String) -> void:
	rest_time = 0.0
	velocity = Vector2.ZERO
	# Wrap first so leveling never unwinds the player's full spins.
	rotation = wrapf(rotation, -PI, PI)
	level_tween = create_tween()
	level_tween.tween_property(self, "rotation", 0.0, LEVEL_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	modulate = LANDED_COLOR
	message.text = title
	message.visible = true


func rest(delta: float) -> void:
	# A docked ship may turn in place to face the way out.
	if docked and not (level_tween and level_tween.is_running()):
		rotation += Input.get_axis("ui_left", "ui_right") * ship_type.turn_rate * delta
	rest_time += delta
	var refueling := rest_time >= REFUEL_DELAY and fuel < ship_type.tank
	if refueling:
		fuel = minf(fuel + ship_type.tank * REFUEL_TANK_SHARE * delta, ship_type.tank)
	var title := "Docked!" if docked else "Landed!"
	message.text = title + "\nRefueling…" if refueling else title


func lift_off() -> void:
	# Only leaving the pad costs extra fuel; undocking burns at the default rate.
	if landed:
		since_liftoff = 0.0
	if docked:
		can_dock = false
	landed = false
	docked = false
	if level_tween:
		level_tween.kill()
	modulate = Color.WHITE
	message.visible = false


func crash() -> void:
	set_physics_process(false)
	flame.visible = false
	modulate = CRASHED_COLOR
	message.text = "Crashed!\nPress R to retry"
	message.visible = true
