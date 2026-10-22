extends CharacterBody2D

const GRAVITY := 60.0
const THRUST := 150.0
const ROTATION_SPEED := 3.0
const GROUND_FRICTION := 200.0

@onready var flame: Polygon2D = $Flame


func _physics_process(delta: float) -> void:
	rotation += Input.get_axis("ui_left", "ui_right") * ROTATION_SPEED * delta

	velocity.y += GRAVITY * delta

	var thrusting := Input.is_action_pressed("ui_up")
	if thrusting:
		velocity += Vector2.UP.rotated(rotation) * THRUST * delta
	flame.visible = thrusting

	if is_on_floor():
		velocity.x = move_toward(velocity.x, 0.0, GROUND_FRICTION * delta)

	move_and_slide()
