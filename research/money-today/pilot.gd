extends Node
# A simple autopilot: follows waypoints by pressing the real input actions.

var lander: Lander
var waypoints: Array = []  # each: {pos: Vector2, vmax: float, tol: float, land: bool, dock: bool}
var active := false
var gentle := 0.6
var duty := 0.0

func _ready() -> void:
	process_physics_priority = -100

func set_action(a: StringName, on: bool) -> void:
	if on and not Input.is_action_pressed(a): Input.action_press(a)
	elif not on and Input.is_action_pressed(a): Input.action_release(a)

func stop() -> void:
	active = false
	for a in [&"ui_up", &"ui_left", &"ui_right"]: set_action(a, false)

func hull_bottom() -> float:
	var b := 0.0
	for p in lander.ship_type.hull: b = maxf(b, p.y)
	return b

func _physics_process(_delta: float) -> void:
	if not active or waypoints.is_empty():
		for a in [&"ui_up", &"ui_left", &"ui_right"]: set_action(a, false)
		return
	var wp: Dictionary = waypoints[0]
	var pos := lander.position
	var vel := lander.velocity
	var mf := lander.total_mass() / Lander.REFERENCE_MASS
	var g := Lander.GRAVITY * (1.0 + Lander.GRAVITY_MASS_SCALE * (mf - 1.0)) * lander.gravity_share()
	var amax := lander.ship_type.thrust / mf
	var v_des: Vector2
	var upright := false
	if wp.get("land", false):
		var h := lander.ground_top() - hull_bottom() - pos.y
		var dx: float = wp.pos.x - pos.x
		var ab := maxf(gentle * (amax - g), 3.0)
		var vx := clampf(dx * 1.0, -120.0, 120.0)
		var tf := 1.2 * PI / lander.ship_type.turn_rate
		var hh := maxf(h - 5.0, 0.0)
		var vy := minf(ab * (-tf + sqrt(tf * tf + 2.0 * hh / ab)) + 15.0, wp.vmax)
		if absf(dx) > 25.0 and h < 220.0:
			vy = 0.0
		v_des = Vector2(vx, vy)
		upright = h < 40.0
	else:
		var to: Vector2 = wp.pos - pos
		var dist := to.length()
		if dist < wp.tol and vel.length() < wp.get("arrive", 30.0):
			waypoints.pop_front()
			return
		var ab := maxf(gentle * (amax - g), 3.0) if to.y > 0.0 and g > 0.0 else gentle * amax
		var tf := 1.2 * PI / lander.ship_type.turn_rate
		var speed := minf(wp.vmax, ab * (-tf + sqrt(tf * tf + 2.0 * dist / ab)) + wp.get("min_speed", 0.0))
		v_des = to.normalized() * speed
		if wp.get("dock", false) and dist < 25.0:
			# Coast in: no thrust inside the spot so it can dock.
			for a in [&"ui_up", &"ui_left", &"ui_right"]: set_action(a, false)
			return
	var a_req := (v_des - vel) * 2.0
	var a_thrust := a_req - Vector2(0.0, g)
	var target_rot := atan2(a_thrust.x, -a_thrust.y)
	if upright: target_rot = clampf(target_rot, -0.15, 0.15)
	var err := angle_difference(lander.rotation, target_rot)
	set_action(&"ui_right", err > 0.04)
	set_action(&"ui_left", err < -0.04)
	var aligned := absf(err) < 0.35
	if aligned:
		duty += clampf(a_thrust.length() / amax, 0.0, 1.0)
	var fire := aligned and duty >= 1.0
	if fire: duty -= 1.0
	set_action(&"ui_up", fire)
