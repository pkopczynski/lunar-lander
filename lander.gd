class_name Lander
extends CharacterBody2D
# Flight physics, fuel, mass (`load_mass`, the Load) and the fuel cap (`fuel_cap()`), border
# crossing and its disturbance (with a seedable `rng`), steering, landing and docking judgement (the
# "on the pad" check reads the current location's pad through `pad_center_x()`; `touch_down()` judges
# the landing bands: Landed, a Hard landing that wears Condition and shows `HARD LANDING −12%`
# as the Landed title, or a crash), refuelling, result
# display (with a `status` line, set through `show_status()`, under Docked!/Landed!), touching a
# solid off the pad (`touch()`: damage by impact speed to the ship in service's Condition and a
# bounce, `damaged` for each loss; a crash above the crash speed or at 0%), resting on the ground
# (friction, tipped over, Stranded), the R key (`recovery_requested` after a crash or while
# Stranded, else the debug pad shortcut on the Surface; it never restarts),
# `landed_on_pad` (from a real landing and from the debug pad shortcut) and `lift_off_blocked`
# (keeps the ship resting and refuelling but grounded, for unloading), and
# `start_loading(load)`/`finish_loading()` (keeps the ship Docked, unable to turn or undock,
# refuelling up to the cap for the incoming Load, which joins the mass only when loading finishes).
# Attached to `Lander`. It flies the ship in service, an `OwnedShip` handed over by the Hangar's
# `fly(ship)` (hull, collision shape and flame from its Ship type), and reads only that ship's
# effective numbers, never its Ship type's. Its fuel is the ship's fuel in tank: the Lander burns
# and refuels it, wears the ship's Condition on hits and Hard landings, and changes nothing else on the ship. `start_docked()` puts it in the parking spot.
#
# The Lander's `state` (Flying, Landed, Docked, Crashed, Stranded) changes only through `enter()`, which
# starts every state fresh: not held, no lift-off burn, docking armed, leveling stopped, with the
# state's colour and message. `start_docked()`, `reset_to_pad()` and `fly_from()` also move the ship
# and clear any border bounce, steering or disturbance. `enter()` also clears the `status` line.
# `rest()` rewrites the message every frame (title, `status`, then Refueling…), so outside text such
# as the loading and unloading countdowns must go through `show_status()`, which also shows it right
# away (keeping the Refueling… line) for a held ship (held ships don't rest). `lift_off_blocked` is
# set from outside like `held`, but `enter()` doesn't clear it, so a ship that settles back onto the
# pad while unloading stays grounded; the Economy clears it when unloading finishes. `lift_off()` is
# the only transition that looks at the state it leaves (the lift-off burn from the pad, no
# re-docking from the spot). Crashed, Stranded and held make `_physics_process` return early;
# Landed and Docked skip gravity and judging. A ship resting on a solid off the pad stays Flying.
# R is handled in `_unhandled_input`. Entering Crashed emits `crashed` and entering Stranded
# `stranded`; the Lander still flies a Wreck like any ship, since only the Office keeps one docked.
#
# It has no ship until the Hangar's `_ready()` hands it SPARROW 1 and docks it behind the Office;
# a Ship swap hands it a new ship and docks it again. `start_docked()` never asks to enter the
# Office; only `dock()` does, by emitting `docked_at_station` from the end of its level tween, so
# the signal waits for the ship to be upright and lifting off first (`enter()` kills the tween)
# cancels it. The Office answers
# with the "ENTER THE OFFICE?" popup and calls `hold()`, which freezes `_physics_process`; the
# Lander doesn't know why it's held. No, and leaving the Office from the main screen, call
# `release()`; the refuel delay starts over because docking zeroed it and a held ship doesn't count
# it down. A Ship swap calls `start_docked()`, and entering Docked releases the hold.
# `start_loading()` releases it too: a loading ship isn't held but rests (so it refuels), with
# `loading` blocking lift-off and turning.

# Per-ship values (thrust, turn rate, masses, tank, burn rate) are the ship in service's
# effective numbers (OwnedShip), built from ShipType.
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

# Landing bands, judged at touchdown on the pad: safe up to the MAX_LANDING_* limits, a crash
# above the CRASH_LANDING_* ones, and a Hard landing in between, losing Condition in a straight
# line from 0% at the safe edge to MAX_HARD_LANDING_DAMAGE at the crash edge, the worst band counting.
const MAX_LANDING_VERTICAL_SPEED := 50.0
const MAX_LANDING_HORIZONTAL_SPEED := 25.0
const MAX_LANDING_ANGLE_DEG := 15.0
const CRASH_LANDING_VERTICAL_SPEED := 80.0
const CRASH_LANDING_HORIZONTAL_SPEED := 40.0
const CRASH_LANDING_ANGLE_DEG := 25.0
const MAX_HARD_LANDING_DAMAGE := 0.25
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

# Touching a solid (anything but the pad's ground, judged by the landing bands) damages the
# ship by its impact speed, the speed into the surface: none below NO_DAMAGE_SPEED, rising in a
# straight line to MAX_HIT_DAMAGE of Condition just under CRASH_SPEED, a crash above it. A hit
# leaves the surface at BOUNCE_SHARE of its impact speed, keeping SURFACE_SPEED_KEPT of its speed
# along it; below NO_DAMAGE_SPEED the ship just settles. A ship on the ground slides to a stop at
# GROUND_FRICTION.
const NO_DAMAGE_SPEED := 15.0
const CRASH_SPEED := 120.0
const MAX_HIT_DAMAGE := 0.5
const BOUNCE_SHARE := 0.35
const SURFACE_SPEED_KEPT := 0.8
const GROUND_FRICTION := 60.0
# Resting on the ground tilted past TIPPED_ANGLE_DEG for TIPPED_TIME is a crash.
const TIPPED_ANGLE_DEG := 90.0
const TIPPED_TIME := 2.0
# A ship on the ground slower than this is resting (Stranded, with an empty tank).
const REST_SPEED := 4.0

const SOFT_WALL_WIDTH := 150.0
const SOFT_WALL_DAMPING := 8.0
const SOFT_WALL_PUSH := 300.0

# Docked in the parking spot by flying in, once the ship has finished easing upright.
# Lifting off before then cancels it.
signal docked_at_station
# Landed on the pad, by a real landing or the debug pad shortcut.
signal landed_on_pad
# Entered Crashed: the Hangar makes the ship a Wreck and the Economy settles the crash.
signal crashed
# Entered Stranded: the Economy settles it like a crash, but the ship isn't wrecked.
signal stranded
# R while Crashed or Stranded: the Office performs Recovery. The Lander doesn't know who answers.
signal recovery_requested
# A hit or a Hard landing took this share of Condition (0.06 is 6%) from the ship in service;
# it didn't crash it.
signal damaged(loss: float)

enum State { FLYING, LANDED, DOCKED, CRASHED, STRANDED }

const LANDED_COLOR := Color(0.3, 1.0, 0.4)
const HARD_LANDING_TEXT := "HARD LANDING −%d%%"
const CRASHED_COLOR := Color(1.0, 0.3, 0.3)
const CRASHED_TEXT := "Crashed!\nPress R for recovery"
const STRANDED_COLOR := Color(1.0, 0.75, 0.3)
const STRANDED_TEXT := "Stranded!\nPress R for recovery"

# The ship in service it flies, set by fly(). Its numbers are the ship's effective numbers;
# ship_type, dry_mass and fuel only read through to it (fuel also writes: burning and refuelling).
var ship: OwnedShip
var ship_type: ShipType:
	get:
		return ship.ship_type
var dry_mass: float:
	get:
		return ship.dry_mass()
var fuel: float:
	get:
		return ship.fuel
	set(value):
		ship.fuel = value
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
# How long the ship has rested on the ground tipped over.
var tipped_time := 0.0
# A line the resting message adds under Docked!/Landed!, such as the loading countdown.
# Set it through show_status(): the message is rewritten every frame while resting.
var status := ""
# Whether the last rest refuelled, so a new status keeps the Refueling… line.
var refueling := false
# The Condition the last touchdown on the pad took, 0.0 for a safe one; the Landed title shows it.
var hard_landing_loss := 0.0

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


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("restart"):
		return
	# R never restarts anything. After a crash, or Stranded, it asks for Recovery, anywhere.
	if state == State.CRASHED or state == State.STRANDED:
		recovery_requested.emit()
	# A testing shortcut: in debug builds R on the Surface puts the ship back on the pad.
	elif OS.is_debug_build() and not in_deep_space:
		reset_to_pad()


# Takes the ship in service: its Ship type's hull, collision shape and flame, and from now on its
# effective numbers and fuel in tank. Called by the Hangar, which then calls start_docked().
func fly(owned: OwnedShip) -> void:
	ship = owned
	body.polygon = ship.ship_type.hull
	hull.polygon = ship.ship_type.hull
	flame.polygon = ship.ship_type.flame


# Puts the ship in service Docked in the station's parking spot, facing up and at rest, keeping
# its fuel. Every run and every Ship swap starts here. The type is only checked against the ship
# in service: it was the ship type to become before ships were owned, and tests still pass it.
func start_docked(type: ShipType = null) -> void:
	assert(type == null or type == ship_type, "start_docked() can only dock the ship in service")
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
	tipped_time = 0.0
	hard_landing_loss = 0.0
	if level_tween:
		level_tween.kill()
	match new_state:
		State.FLYING:
			modulate = Color.WHITE
			message.visible = false
		State.LANDED:
			show_state(landed_title(), LANDED_COLOR)
		State.DOCKED:
			show_state("Docked!", LANDED_COLOR)
		State.CRASHED:
			flame.visible = false
			show_state(CRASHED_TEXT, CRASHED_COLOR)
		State.STRANDED:
			flame.visible = false
			show_state(STRANDED_TEXT, STRANDED_COLOR)


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
	if held or state == State.CRASHED or state == State.STRANDED:
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
		rotation += Input.get_axis("ui_left", "ui_right") * ship.turn_rate() * delta

	var mass_factor := total_mass() / REFERENCE_MASS
	velocity.y += GRAVITY * (1.0 + GRAVITY_MASS_SCALE * (mass_factor - 1.0)) * gravity_share() * delta

	if thrusting:
		var thrust_dir := Vector2.UP.rotated(rotation)
		var burn_factor := (dry_mass + fuel + LOAD_BURN_SHARE * load_mass) / REFERENCE_MASS
		fuel = maxf(fuel - ship.burn_rate() * burn_factor * burn_multiplier(thrust_dir) * delta, 0.0)
		velocity += thrust_dir * ship.thrust() / mass_factor * delta
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
		if touched_only_ground() and is_on_pad():
			touch_down(impact_velocity)
			return
		var bounced := touch(impact_velocity)
		if state != State.FLYING:
			return
		if not bounced:
			on_ground(thrusting, delta)
			if state != State.FLYING:
				return
	elif is_on_floor():
		on_ground(thrusting, delta)
		if state != State.FLYING:
			return
	else:
		tipped_time = 0.0

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
	return clampf(ship.maximum_weight() - dry_mass - with_load, 0.0, ship.tank())


func tank_level() -> float:
	return fuel / ship.tank()


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


# The parking spot has no collider: docking checks that every hull vertex is inside its Rect2.
func is_inside_spot() -> bool:
	for point in hull.polygon:
		if not station.parking_spot.has_point(to_global(point)):
			return false
	return true


# Only touching the pad's ground goes to landing judgement.
func touched_only_ground() -> bool:
	for i in get_slide_collision_count():
		if get_slide_collision(i).get_collider() != ground:
			return false
	return true


func pad_center_x() -> float:
	return world.location.pad_center_x


# The pad has no collider: "on the pad" compares x positions with the current location's pad.
func is_on_pad() -> bool:
	return absf(position.x - pad_center_x()) <= PAD_WIDTH / 2.0


# Radians from upright; angle_difference() wraps to [-PI, PI], so e.g. 350° counts as 10°.
func tilt() -> float:
	return absf(angle_difference(0.0, rotation))


# How far into the landing bands a touchdown is: 0.0 inside every safe limit, 1.0 at a crash
# edge, above 1.0 past one. The worst band counts.
func landing_band_share(impact_velocity: Vector2) -> float:
	return maxf(maxf(maxf(
		band_share(impact_velocity.y, MAX_LANDING_VERTICAL_SPEED, CRASH_LANDING_VERTICAL_SPEED),
		band_share(absf(impact_velocity.x), MAX_LANDING_HORIZONTAL_SPEED, CRASH_LANDING_HORIZONTAL_SPEED)),
		band_share(rad_to_deg(tilt()), MAX_LANDING_ANGLE_DEG, CRASH_LANDING_ANGLE_DEG)), 0.0)


func band_share(value: float, safe: float, crash_edge: float) -> float:
	return inverse_lerp(safe, crash_edge, value)


# Takes a loss from the ship in service's Condition: to 0% crashes it, else it emits `damaged`.
# Returns whether the ship survived.
func wear(loss: float) -> bool:
	ship.condition = maxf(ship.condition - loss, 0.0)
	if ship.condition <= 0.0:
		crash()
		return false
	damaged.emit(loss)
	return true


# A touchdown on the pad: past a band it crashes; inside one it's a Hard landing, which costs the
# ship in service Condition (to 0% crashes it) but still lands; inside the safe limits it just lands.
func touch_down(impact_velocity: Vector2) -> void:
	var share := landing_band_share(impact_velocity)
	if share > 1.0:
		crash()
		return
	var loss := MAX_HARD_LANDING_DAMAGE * share
	if loss <= 0.0:
		land()
		return
	if wear(loss):
		land(loss)


# A touch of any solid off the pad: the hardest contact of the move sets the impact speed. It
# damages the ship in service (a hit to 0% Condition crashes it) and bounces it, or crashes it
# above CRASH_SPEED. It never disturbs the controls, and the ship keeps its attitude. Returns
# whether the ship bounced.
func touch(impact_velocity: Vector2) -> bool:
	var impact := 0.0
	var normal := Vector2.UP
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var into := -impact_velocity.dot(collision.get_normal())
		if into > impact:
			impact = into
			normal = collision.get_normal()
	if impact > CRASH_SPEED:
		crash()
		return false
	if impact < NO_DAMAGE_SPEED:
		return false
	if not wear(MAX_HIT_DAMAGE * inverse_lerp(NO_DAMAGE_SPEED, CRASH_SPEED, impact)):
		return false
	var along := impact_velocity + normal * impact
	velocity = along * SURFACE_SPEED_KEPT + normal * impact * BOUNCE_SHARE
	return true


# In contact with a solid off the pad without bouncing: on a floor, sliding slows by friction
# (not while thrusting, so lift-off isn't braked). At rest (slower than REST_SPEED, on a floor or
# wedged against a steep face), tipped over crashes after TIPPED_TIME, and an empty tank is Stranded.
func on_ground(thrusting: bool, delta: float) -> void:
	if is_on_floor() and not thrusting:
		velocity = velocity.move_toward(Vector2.ZERO, GROUND_FRICTION * delta)
	if velocity.length() >= REST_SPEED:
		tipped_time = 0.0
		return
	if tilt() > deg_to_rad(TIPPED_ANGLE_DEG):
		tipped_time += delta
		if tipped_time >= TIPPED_TIME:
			crash()
		return
	tipped_time = 0.0
	if fuel <= 0.0:
		enter(State.STRANDED)
		stranded.emit()


# Lands on the pad; a Hard landing passes the Condition it took, for the Landed title.
func land(loss := 0.0) -> void:
	enter(State.LANDED)
	hard_landing_loss = loss
	message.text = landed_title()
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
		rotation += Input.get_axis("ui_left", "ui_right") * ship.turn_rate() * delta
	rest_time += delta
	refueling = rest_time >= REFUEL_DELAY and fuel < fuel_cap()
	if refueling:
		fuel = minf(fuel + ship.tank() * REFUEL_TANK_SHARE * delta, fuel_cap())
	show_rest_message()


func show_status(text: String) -> void:
	status = text
	# A held ship doesn't rest, so show it now.
	show_rest_message()


func show_rest_message() -> void:
	if state != State.DOCKED and state != State.LANDED:
		return
	var lines := PackedStringArray(["Docked!" if state == State.DOCKED else landed_title()])
	if status != "":
		lines.append(status)
	if refueling:
		lines.append("Refueling…")
	message.text = "\n".join(lines)


# Landed!, or HARD LANDING −12% after a Hard landing; the loss reads as the HUD's flash does.
func landed_title() -> String:
	if hard_landing_loss <= 0.0:
		return "Landed!"
	return HARD_LANDING_TEXT % maxi(roundi(hard_landing_loss * 100.0), 1)


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
	crashed.emit()
