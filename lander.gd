extends CharacterBody2D

const GRAVITY := 60.0
const THRUST := 150.0
const ROTATION_SPEED := 3.0
const START_DRIFT := 60.0

const MAX_LANDING_VERTICAL_SPEED := 50.0
const MAX_LANDING_HORIZONTAL_SPEED := 25.0
const MAX_LANDING_ANGLE_DEG := 15.0

const PAD_CENTER_X := 720.0
const PAD_WIDTH := 120.0
const PAD_HEIGHT := 6.0

const LANDED_COLOR := Color(0.3, 1.0, 0.4)
const CRASHED_COLOR := Color(1.0, 0.3, 0.3)

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


func _physics_process(delta: float) -> void:
	rotation += Input.get_axis("ui_left", "ui_right") * ROTATION_SPEED * delta

	velocity.y += GRAVITY * delta

	var thrusting := Input.is_action_pressed("ui_up")
	if thrusting:
		velocity += Vector2.UP.rotated(rotation) * THRUST * delta
	flame.visible = thrusting

	# move_and_slide() cancels velocity into the ground, so keep the impact velocity.
	var impact_velocity := velocity
	move_and_slide()

	if get_slide_collision_count() > 0:
		finish(is_safe_landing(impact_velocity))
		return

	var screen := get_viewport_rect()
	if position.x < screen.position.x or position.x > screen.end.x or position.y > screen.end.y:
		finish(false)


func is_safe_landing(impact_velocity: Vector2) -> bool:
	# angle_difference() wraps to [-PI, PI], so e.g. 350° counts as 10° from upright.
	var tilt := absf(angle_difference(0.0, rotation))
	var on_pad := absf(position.x - PAD_CENTER_X) <= PAD_WIDTH / 2.0
	return impact_velocity.y <= MAX_LANDING_VERTICAL_SPEED \
		and absf(impact_velocity.x) <= MAX_LANDING_HORIZONTAL_SPEED \
		and tilt <= deg_to_rad(MAX_LANDING_ANGLE_DEG) \
		and on_pad


func finish(landed: bool) -> void:
	set_physics_process(false)
	flame.visible = false
	modulate = LANDED_COLOR if landed else CRASHED_COLOR
	message.text = ("Landed!" if landed else "Crashed!") + "\nPress R to retry"
	message.visible = true
