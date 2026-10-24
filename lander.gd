class_name Lander
extends CharacterBody2D

const GRAVITY := 60.0
const THRUST := 150.0
const ROTATION_SPEED := 3.0
const START_DRIFT := 60.0

const DEFAULT_DRY_MASS := 10000.0
const MIN_DRY_MASS := 5000.0
const MAX_DRY_MASS := 17000.0
const DRY_MASS_STEP := 1000.0
const FUEL_CAPACITY := 5000.0
# Mass at which thrust, gravity and burn rate are unscaled: default ship with a full tank.
const REFERENCE_MASS := 15000.0
const GRAVITY_MASS_SCALE := 0.5

const BURN_RATE := FUEL_CAPACITY / 20.0
const LIFTOFF_BURN_MULTIPLIER := 2.0
const LIFTOFF_BURN_TIME := 1.0
const BRAKING_BURN_FACTOR := 1.0
const BRAKING_FULL_SPEED := 150.0

const LEVEL_TIME := 0.3
const REFUEL_DELAY := 2.0
const REFUEL_RATE := FUEL_CAPACITY * 0.5 / 6.0

const MAX_LANDING_VERTICAL_SPEED := 50.0
const MAX_LANDING_HORIZONTAL_SPEED := 25.0
const MAX_LANDING_ANGLE_DEG := 15.0

const PAD_CENTER_X := 720.0
const PAD_WIDTH := 120.0
const PAD_HEIGHT := 6.0

const LANDED_COLOR := Color(0.3, 1.0, 0.4)
const CRASHED_COLOR := Color(1.0, 0.3, 0.3)

var dry_mass := DEFAULT_DRY_MASS
var fuel := FUEL_CAPACITY
var landed := false
var landed_time := 0.0
var since_liftoff := INF
var level_tween: Tween

@onready var flame: Polygon2D = $Flame
@onready var pad: Polygon2D = $"../Ground/Pad"
@onready var message: Label = $"../UI/Message"


func _ready() -> void:
	velocity.x = START_DRIFT
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
		dry_mass = minf(dry_mass + DRY_MASS_STEP, MAX_DRY_MASS)
	elif event.is_action_pressed("weight_down"):
		dry_mass = maxf(dry_mass - DRY_MASS_STEP, MIN_DRY_MASS)


func _physics_process(delta: float) -> void:
	var thrusting := Input.is_action_pressed("ui_up") and fuel > 0.0
	flame.visible = thrusting
	if landed:
		if not thrusting:
			rest(delta)
			return
		lift_off()

	rotation += Input.get_axis("ui_left", "ui_right") * ROTATION_SPEED * delta

	var mass_factor := total_mass() / REFERENCE_MASS
	velocity.y += GRAVITY * (1.0 + GRAVITY_MASS_SCALE * (mass_factor - 1.0)) * delta

	if thrusting:
		var thrust_dir := Vector2.UP.rotated(rotation)
		fuel = maxf(fuel - BURN_RATE * mass_factor * burn_multiplier(thrust_dir) * delta, 0.0)
		velocity += thrust_dir * THRUST / mass_factor * delta
	since_liftoff += delta

	# move_and_slide() cancels velocity into the ground, so keep the impact velocity.
	var impact_velocity := velocity
	move_and_slide()

	if get_slide_collision_count() > 0:
		if is_safe_landing(impact_velocity):
			land()
		else:
			crash()
		return

	var screen := get_viewport_rect()
	if position.x < screen.position.x or position.x > screen.end.x or position.y > screen.end.y:
		crash()


func total_mass() -> float:
	return dry_mass + fuel


func burn_multiplier(thrust_dir: Vector2) -> float:
	var multiplier := 1.0
	if since_liftoff < LIFTOFF_BURN_TIME:
		multiplier *= LIFTOFF_BURN_MULTIPLIER
	var opposing := maxf(0.0, -thrust_dir.dot(velocity.normalized()))
	var speed_share := clampf(velocity.length() / BRAKING_FULL_SPEED, 0.0, 1.0)
	return multiplier * (1.0 + BRAKING_BURN_FACTOR * opposing * speed_share)


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
	landed_time = 0.0
	velocity = Vector2.ZERO
	# Wrap first so leveling never unwinds the player's full spins.
	rotation = wrapf(rotation, -PI, PI)
	level_tween = create_tween()
	level_tween.tween_property(self, "rotation", 0.0, LEVEL_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# Leveling lifts the corner that touched down, so drop back onto the ground.
	level_tween.tween_callback(move_and_collide.bind(Vector2.DOWN * PAD_HEIGHT * 4.0))
	modulate = LANDED_COLOR
	message.text = "Landed!"
	message.visible = true


func rest(delta: float) -> void:
	landed_time += delta
	var refueling := landed_time >= REFUEL_DELAY and fuel < FUEL_CAPACITY
	if refueling:
		fuel = minf(fuel + REFUEL_RATE * delta, FUEL_CAPACITY)
	message.text = "Landed!\nRefueling…" if refueling else "Landed!"


func lift_off() -> void:
	landed = false
	since_liftoff = 0.0
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
