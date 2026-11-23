class_name Lander
extends CharacterBody2D
# Flight physics, fuel, mass (`load_mass`, the Load) and the fuel cap (`fuel_cap()`), border
# crossing and its disturbance (with a seedable `rng`), steering, landing and docking judgement (the
# "on the pad" check reads the current location's pad through `pad_center_x()`; `touch_down()` judges
# the landing bands as the ship comes down onto the pad: safe, a Hard landing that wears Condition
# and shows `HARD LANDING −12%` as the Landed title, or a crash), no refuelling of its own (fuel
# is bought at the station or a pad's Workshop and pumped in by the Hangar), result
# display (with a `status` line, set through `show_status()`, under Docked!/Landed!), ground
# contact as a rigid body (`move()`: contact points from `find_contacts()`, the push and friction
# at each from `push_off()`, the ship's `spin` about its `centre_of_mass`), touching a solid off
# the pad (`touch()`: damage by impact speed to the ship in service's Condition, `damaged` for each
# loss; a crash above the crash speed or at 0%), resting on the ground (`rest_on_ground()`: Landed
# once settled on the pad, tipped over, Stranded), the R key (only `recovery_requested`, after a crash or
# while Stranded; it does nothing else and never restarts), `immune` (set by the Tester panel's Immune:
# no hit, Hard landing, tip-over or crash counts), the Tester panel's teleports (`return_to_station()`,
# `reset_to_pad()`), `landed_on_pad` (from a real landing and from `reset_to_pad()`) and `lift_off_blocked`
# (keeps the ship resting but grounded, for unloading), `pump_time_left` (set by the
# Hangar's pump: the ship can't lift off or undock while fuel is pumped, and says `Pumping fuel… 6s`),
# and `start_loading(load)`/`finish_loading()` (keeps the ship Docked, unable to turn or undock, while
# the incoming Load goes aboard; it joins the mass only when loading finishes).
# Attached to `Lander`. It flies the ship in service, an `OwnedShip` handed over by the Hangar's
# `fly(ship)` (hull, collision shape and flame from its Ship type), and reads only that ship's
# effective numbers, never its Ship type's. Its fuel is the ship's fuel in tank: the Lander burns
# it, wears the ship's Condition on hits and Hard landings, and changes nothing else on the ship. `start_docked()` puts it in the parking spot.
#
# The Lander's `state` (Flying, Landed, Docked, Crashed, Stranded) changes only through `enter()`, which
# starts every state fresh: not held, no lift-off burn, docking armed, leveling stopped, with the
# state's colour and message. `start_docked()`, `return_to_station()`, `reset_to_pad()` and `fly_from()` also move the ship
# and clear any border bounce, steering or disturbance. `enter()` also clears the `status` line.
# `rest()` rewrites the message every frame (title, `status`, then Pumping fuel…), so
# outside text such as the loading and unloading countdowns must go through `show_status()`, which also
# shows it right away (keeping those lines) for a held ship (held ships don't rest). `lift_off_blocked`,
# `pump_time_left` and `immune` are set from outside like `held`, but `enter()` doesn't clear them: a ship that
# settles back onto the pad while unloading stays grounded until the Economy clears `lift_off_blocked`,
# and the Hangar's pump counts `pump_time_left` down to 0. `lift_off()` is
# the only transition that looks at the state it leaves (the lift-off burn from the pad, no
# re-docking from the spot). Crashed, Stranded and held make `_physics_process` return early;
# Landed and Docked skip gravity and judging. A ship touching the ground stays Flying: on the pad
# until it has settled (then Landed), off it for good. The spin lives only in Flying (`enter()` and
# `move_to()` stop it); docking still eases the ship upright with a tween, landing doesn't.
# `touching` is last frame's contact: the controls turn the ship by torque while it's set, and
# coming down onto the pad is judged when it wasn't.
# R is handled in `_unhandled_input`. Entering Crashed emits `crashed` and entering Stranded
# `stranded`; the Lander still flies a Wreck like any ship, since only the Office keeps one docked.
#
# It has no ship until the Hangar's `_ready()` hands it SPARROW 1 and docks it behind the Office;
# a Ship swap hands it a new ship and docks it again. `start_docked()` never asks to enter the
# Office; only `dock()` (flying in, or `return_to_station()`) does, by emitting `docked_at_station` from the end of its level tween, so
# the signal waits for the ship to be upright and lifting off first (`enter()` kills the tween)
# cancels it. The Office answers
# with the "ENTER THE OFFICE?" popup and calls `hold()`, which freezes `_physics_process`; the
# Lander doesn't know why it's held. No, and leaving the Office from the main screen, call
# `release()`; O then opens the Office again while the ship `is_free_in_dock()` (Docked, not held, not
# loading, not easing upright), which the Office reads, and the pad's Workshop while it
# `is_free_on_pad()`. A Ship swap calls `start_docked()`, and entering Docked releases the hold.
# `start_loading()` releases it too: a loading ship isn't held but rests, with `loading` blocking
# lift-off and turning.

# Per-ship values (thrust, turn rate, masses, tank, burn rate) are the ship in service's
# effective numbers (OwnedShip), built from ShipType.
const GRAVITY := 60.0

# Mass at which thrust, gravity and burn rate are unscaled: about a default Sparrow with a full
# tank (14 800 kg since its Tank became 6 000 l; kept at 15 000 so the Mule's and Halo's flight
# didn't change).
const REFERENCE_MASS := 15000.0
const GRAVITY_MASS_SCALE := 0.5
# Share of the Load's mass that counts toward fuel burn, so loaded ships burn more gently.
const LOAD_BURN_SHARE := 0.5

const LIFTOFF_BURN_MULTIPLIER := 2.0
const LIFTOFF_BURN_TIME := 1.0
const BRAKING_BURN_FACTOR := 1.0
const BRAKING_FULL_SPEED := 150.0

const LEVEL_TIME := 0.3

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
# ship by its impact speed, the speed into the surface of the hardest-hitting contact point: none
# below NO_DAMAGE_SPEED, rising in a straight line to MAX_HIT_DAMAGE of Condition just under
# CRASH_SPEED, a crash above it. A hit leaves the surface at the contact point at BOUNCE_SHARE of
# its impact speed, keeping SURFACE_SPEED_KEPT of its speed along it; below NO_DAMAGE_SPEED the
# point just stops going in. The pad never bounces: its legs take the touchdown.
const NO_DAMAGE_SPEED := 15.0
const CRASH_SPEED := 120.0
const MAX_HIT_DAMAGE := 0.5
const BOUNCE_SHARE := 0.35
const SURFACE_SPEED_KEPT := 0.8
# Ground contact is a rigid body: each contact point pushes (never pulls) and turns the ship about
# its centre of mass (the hull's area centroid, as a plate of even density). Coulomb friction at
# each point brakes sliding at GROUND_FRICTION (its coefficient is GROUND_FRICTION / GRAVITY). A
# spin on the ground fades at GROUND_SPIN_DAMPING per second; in the air it doesn't fade at all.
const GROUND_FRICTION := 60.0
const GROUND_SPIN_DAMPING := 0.5
# The controls spin a ship touching the ground at this torque (rad/s²) for a Sparrow's turn rate,
# scaled by the ship's own; in the air, turning against a spin brakes it at the same rate.
const GROUND_TURN := 6.0
# Hull points this close to a solid count as touching it; at most CONTACT_POINTS_PER_SHAPE points
# per hull shape, and points closer than CONTACT_MERGE_DISTANCE are one. Each point's surface
# normal comes from a ray CONTACT_RAY_REACH long either way through it, outward from the centre.
const CONTACT_MARGIN := 1.5
const CONTACT_POINTS_PER_SHAPE := 16
const CONTACT_MERGE_DISTANCE := 3.0
const CONTACT_RAY_REACH := 4.0
const CONTACT_ITERATIONS := 10
# A ship touching the ground is at rest below REST_SPEED and REST_SPIN. Resting at
# TIPPED_ANGLE_DEG or more for TIPPED_TIME is a crash; resting on the pad, inside the landing
# bands' tilt, for SETTLE_TIME is Landed; resting off it with an empty tank is Stranded.
const REST_SPEED := 4.0
const REST_SPIN := 0.15
const TIPPED_ANGLE_DEG := 90.0
const TIPPED_TIME := 2.0
const SETTLE_TIME := 0.3
# The worst touchdown on the pad counts until the ship has been off the ground this long.
const TOUCHDOWN_MEMORY := 1.0

const SOFT_WALL_WIDTH := 150.0
const SOFT_WALL_DAMPING := 8.0
const SOFT_WALL_PUSH := 300.0

# Docked in the parking spot by flying in, once the ship has finished easing upright.
# Lifting off before then cancels it.
signal docked_at_station
# Landed on the pad, by a real landing or reset_to_pad() (the Tester panel's Back to pad).
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
const PUMPING_TEXT := "Pumping fuel… %ds"

# The ship in service it flies, set by fly(). Its numbers are the ship's effective numbers;
# ship_type, dry_mass and fuel only read through to it (fuel also writes: burning).
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
# Set from outside: the ship rests where it is but can't lift off.
# Unlike held, entering a state doesn't clear it, so a ship that settles back keeps it.
var lift_off_blocked := false
# Set through start_loading() and finish_loading(): while a Load goes aboard the ship rests,
# but can't lift off or turn. It counts toward the mass
# only once loading finishes.
var loading := false
var incoming_load := 0.0
# Set from outside (the Hangar's pump): seconds of pumping fuel left. While above 0 the ship can't
# lift off or undock, and the resting message says Pumping fuel… Unlike held, enter() leaves it.
var pump_time_left := 0.0
# Set from outside (the Tester panel's Immune): no hit, Hard landing, tip-over or crash counts. Unlike
# held, enter() leaves it.
var immune := false
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
# The ship as a rigid body: its spin (rad/s, positive clockwise like rotation), its centre of
# mass in its own coordinates and its moment of inertia per unit mass (px²), both from the hull.
var spin := 0.0
var centre_of_mass := Vector2.ZERO
var inertia := 1.0
# Whether the hull touched a solid on the last physics frame, whether that was only the pad's
# ground, and for how long it hasn't touched anything.
var touching := false
var over_pad := false
var airborne_time := 0.0
# How long the ship has rested on the ground tipped over, and on the pad settled.
var tipped_time := 0.0
var settle_time := 0.0
# The Condition the worst touchdown on the pad has taken since the ship came down onto it.
var touchdown_loss := 0.0
# A line the resting message adds under Docked!/Landed!, such as the loading countdown.
# Set it through show_status(): the message is rewritten every frame while resting.
var status := ""
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
	# R never restarts anything. After a crash, or Stranded, it asks for Recovery, anywhere; otherwise
	# it does nothing.
	if state == State.CRASHED or state == State.STRANDED:
		recovery_requested.emit()


# Takes the ship in service: its Ship type's hull, collision shape and flame, and from now on its
# effective numbers and fuel in tank. Called by the Hangar, which then calls start_docked().
func fly(owned: OwnedShip) -> void:
	ship = owned
	body.polygon = ship.ship_type.hull
	hull.polygon = ship.ship_type.hull
	flame.polygon = ship.ship_type.flame
	weigh_hull()


# The hull's centre of mass and moment of inertia per unit mass, as a plate of even density.
func weigh_hull() -> void:
	var outline := hull.polygon
	var area := 0.0
	var moment := Vector2.ZERO
	var second_moment := 0.0
	for i in outline.size():
		var p := outline[i]
		var q := outline[(i + 1) % outline.size()]
		var cross := p.cross(q)
		area += cross / 2.0
		moment += (p + q) * cross
		second_moment += cross * (p.dot(p) + p.dot(q) + q.dot(q))
	centre_of_mass = moment / (6.0 * area)
	# About the origin, then moved to the centre of mass (parallel axis).
	inertia = second_moment / 12.0 / area - centre_of_mass.length_squared()


# Puts the ship in service Docked in the station's parking spot, facing up and at rest, keeping
# its fuel. Every run and every Ship swap starts here. The type is only checked against the ship
# in service: it was the ship type to become before ships were owned, and tests still pass it.
func start_docked(type: ShipType = null) -> void:
	assert(type == null or type == ship_type, "start_docked() can only dock the ship in service")
	enter(State.DOCKED)
	move_to(station.parking_spot.get_center())


# Puts the ship Landed on the current pad, upright and at rest, from anywhere, keeping its ship type,
# dry mass, fuel and Load, as a real landing does: `landed_on_pad` follows. The Tester panel's Back to pad.
func reset_to_pad() -> void:
	var hull_bottom := 0.0
	for point in hull.polygon:
		hull_bottom = maxf(hull_bottom, point.y)
	enter(State.LANDED)
	move_to(Vector2(pad_center_x(), ground_top() - hull_bottom))
	landed_on_pad.emit()


# Puts the ship Docked in the parking spot, upright and at rest, keeping its fuel and Load, as if it
# had flown in: `docked_at_station` follows once the leveling ends. The Tester panel's Back to station.
func return_to_station() -> void:
	move_to(station.parking_spot.get_center())
	dock()


# Puts the ship Flying at a position, upright, keeping its ship type, dry mass and fuel.
func fly_from(at: Vector2, at_velocity := Vector2.ZERO) -> void:
	enter(State.FLYING)
	move_to(at, at_velocity)


# The one way into a Ship state. Every state starts fresh: not held, no lift-off
# burn, docking armed, no leveling under way.
func enter(new_state: State) -> void:
	state = new_state
	held = false
	since_liftoff = INF
	can_dock = true
	status = ""
	tipped_time = 0.0
	settle_time = 0.0
	spin = 0.0
	touchdown_loss = 0.0
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
	spin = 0.0
	touching = false
	over_pad = false
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
		and not ((lift_off_blocked or loading or pump_time_left > 0.0) and state != State.FLYING)
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
		turn(delta)

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

	if not move(thrusting, delta):
		return

	keep_inside_world()
	cross_border()
	try_docking(thrusting)


func total_mass() -> float:
	return dry_mass + fuel + load_mass


# The most fuel the ship may hold: a full Tank, or less if the Load would push
# the ship past its Maximum weight.
func fuel_cap() -> float:
	return fuel_cap_for(load_mass + incoming_load)


func fuel_cap_for(with_load: float) -> float:
	return ship.fuel_cap(with_load)


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
	if immune:
		return true
	ship.condition = maxf(ship.condition - loss, 0.0)
	if ship.condition <= 0.0:
		crash()
		return false
	damaged.emit(loss)
	return true


# Turns the ship with the controls: in the air at its turn rate, braking any spin the turn opposes;
# touching the ground, as a torque on its spin.
func turn(delta: float) -> void:
	var input := Input.get_axis("ui_left", "ui_right")
	var torque := GROUND_TURN * ship.turn_rate() / ShipType.SPARROW.turn_rate
	if touching:
		spin += input * torque * delta
		return
	rotation += input * ship.turn_rate() * delta
	if input * spin < 0.0:
		spin = move_toward(spin, 0.0, absf(input) * torque * delta)


# One physics step of the ship's motion: contact with any solid it touches (damage, the pad's
# touchdown, the push and friction at each contact point), then its spin about its centre of mass
# and its move. Coming onto the pad, from the air or sliding onto it, is a touchdown; then the
# pad's rules (no bounce, Landed once settled) hold while the ship is tilted inside the landing
# bands. Tipping past them, it's touching the ground like anywhere else: its hull hitting the pad
# is a hit. Returns whether it's still Flying.
func move(thrusting: bool, delta: float) -> bool:
	var contacts := find_contacts()
	var came_onto_pad := not over_pad
	touching = not contacts.is_empty()
	over_pad = touching and is_on_pad_only(contacts)
	if not touching:
		airborne_time += delta
		if airborne_time > TOUCHDOWN_MEMORY:
			touchdown_loss = 0.0
		tipped_time = 0.0
		settle_time = 0.0
	else:
		airborne_time = 0.0
		spin *= exp(-GROUND_SPIN_DAMPING * delta)
	var centre := to_global(centre_of_mass)
	if over_pad and came_onto_pad and not touch_down(velocity):
		return false
	var on_pad := over_pad and rad_to_deg(tilt()) <= CRASH_LANDING_ANGLE_DEG
	if touching and not on_pad and not touch(contacts, centre):
		return false
	push_off(contacts, centre, on_pad)

	var turned := spin * delta
	global_position = centre + (global_position - centre).rotated(turned)
	rotation += turned
	var collision := move_and_collide(velocity * delta)
	if collision:
		# Slide the rest of the way; the push next frame deals with the velocity.
		move_and_collide(collision.get_remainder().slide(collision.get_normal()))
	if not touching:
		return true
	return rest_on_ground(on_pad, thrusting, delta)


# A point where the hull touches a solid: its surface normal there, and the impulses (per unit
# mass, px/s) pushing the ship off it and along it this frame.
class Contact:
	var point: Vector2
	var normal: Vector2
	var collider: Object
	var hit := false
	var target_speed := 0.0
	var target_along := 0.0
	var push := 0.0
	var friction := 0.0


# Every point where the hull is within CONTACT_MARGIN of a solid.
func find_contacts() -> Array[Contact]:
	var space := get_world_2d().direct_space_state
	var centre := to_global(centre_of_mass)
	var found: Array[Contact] = []
	for owner_id in get_shape_owners():
		var shape_transform := global_transform * shape_owner_get_transform(owner_id)
		for i in shape_owner_get_shape_count(owner_id):
			var query := PhysicsShapeQueryParameters2D.new()
			query.shape = shape_owner_get_shape(owner_id, i)
			query.transform = shape_transform
			query.margin = CONTACT_MARGIN
			query.collision_mask = collision_mask
			query.exclude = [get_rid()]
			var points := space.collide_shape(query, CONTACT_POINTS_PER_SHAPE)
			if points.is_empty():
				continue
			var nearest := space.get_rest_info(query)
			for j in range(0, points.size(), 2):
				var point: Vector2 = (points[j] + points[j + 1]) / 2.0
				if found.any(func(known: Contact) -> bool: return known.point.distance_to(point) < CONTACT_MERGE_DISTANCE):
					continue
				var contact := Contact.new()
				contact.point = point
				contact.normal = nearest.get("normal", Vector2.UP)
				contact.collider = instance_from_id(nearest.get("collider_id", 0))
				# The surface's own normal and solid at the point.
				var outward := (point - centre).normalized()
				var ray := PhysicsRayQueryParameters2D.create(point - outward * CONTACT_RAY_REACH,
					point + outward * CONTACT_RAY_REACH,
					collision_mask, [get_rid()])
				var surface := space.intersect_ray(ray)
				if surface and surface.normal != Vector2.ZERO:
					contact.normal = surface.normal
					contact.collider = surface.collider
				found.append(contact)
	return found


# Touching only the ground, with the ship over the pad: the pad's landing rules apply. The pad has
# no collider, so "over the pad" compares x positions with the current location's pad.
func is_on_pad_only(contacts: Array[Contact]) -> bool:
	if in_deep_space or not is_on_pad():
		return false
	return contacts.all(func(contact: Contact) -> bool: return contact.collider == ground)


func point_velocity(centre: Vector2, point: Vector2) -> Vector2:
	var arm := point - centre
	return velocity + Vector2(-spin * arm.y, spin * arm.x)


func apply_impulse_at(impulse: Vector2, arm: Vector2) -> void:
	velocity += impulse
	spin += arm.cross(impulse) / inertia


# Coming down onto the pad: past a landing band it crashes; inside one it's a Hard landing, which
# costs the ship in service Condition (to 0% crashes it). The worst touchdown counts: a later,
# gentler one costs nothing more. Returns whether the ship survived. It lands once it settles.
func touch_down(impact_velocity: Vector2) -> bool:
	if immune:
		return true
	var share := landing_band_share(impact_velocity)
	if share > 1.0:
		crash()
		return false
	var loss := MAX_HARD_LANDING_DAMAGE * share
	if loss <= touchdown_loss:
		return true
	var worse := loss - touchdown_loss
	touchdown_loss = loss
	return wear(worse)


# Touching any solid off the pad: the hardest-hitting contact point sets the impact speed. It
# damages the ship in service (a hit to 0% Condition crashes it), or crashes it above CRASH_SPEED.
# The bounce is the push's. Returns whether the ship survived.
func touch(contacts: Array[Contact], centre: Vector2) -> bool:
	var impact := 0.0
	for contact in contacts:
		impact = maxf(impact, -point_velocity(centre, contact.point).dot(contact.normal))
	if impact > CRASH_SPEED and not immune:
		crash()
		return false
	if impact < NO_DAMAGE_SPEED:
		return true
	return wear(MAX_HIT_DAMAGE * inverse_lerp(NO_DAMAGE_SPEED, CRASH_SPEED, impact))


# Pushes the ship off every contact point at once (sequential impulses): no point keeps going into
# a surface, and none is pulled. A point hitting off the pad bounces out and keeps
# SURFACE_SPEED_KEPT of its speed along the surface; any other is held by Coulomb friction.
func push_off(contacts: Array[Contact], centre: Vector2, on_pad: bool) -> void:
	var grip := GROUND_FRICTION / GRAVITY
	for contact in contacts:
		var point_speed := point_velocity(centre, contact.point)
		var into := -point_speed.dot(contact.normal)
		contact.hit = not on_pad and into >= NO_DAMAGE_SPEED
		contact.target_speed = into * BOUNCE_SHARE if contact.hit else 0.0
		contact.target_along = point_speed.dot(contact.normal.orthogonal()) * SURFACE_SPEED_KEPT
		contact.push = 0.0
		contact.friction = 0.0
	for _iteration in CONTACT_ITERATIONS:
		for contact in contacts:
			var arm := contact.point - centre
			var normal := contact.normal
			var arm_normal := arm.cross(normal)
			var push := (contact.target_speed - point_velocity(centre, contact.point).dot(normal)) \
				/ (1.0 + arm_normal * arm_normal / inertia)
			var total := maxf(contact.push + push, 0.0)
			apply_impulse_at(normal * (total - contact.push), arm)
			contact.push = total
			var along := normal.orthogonal()
			var arm_along := arm.cross(along)
			var speed_along := point_velocity(centre, contact.point).dot(along)
			var target := contact.target_along if contact.hit else 0.0
			total = contact.friction + (target - speed_along) / (1.0 + arm_along * arm_along / inertia)
			if not contact.hit:
				total = clampf(total, -grip * contact.push, grip * contact.push)
			apply_impulse_at(along * (total - contact.friction), arm)
			contact.friction = total


# Touching the ground: at rest (not thrusting, slower than REST_SPEED and REST_SPIN), tipped over
# crashes after TIPPED_TIME; under the pad's rules it lands after SETTLE_TIME (a Hard landing
# keeps its loss); otherwise an empty tank is Stranded. Returns whether it's still Flying.
func rest_on_ground(on_pad: bool, thrusting: bool, delta: float) -> bool:
	if thrusting or velocity.length() >= REST_SPEED or absf(spin) >= REST_SPIN:
		tipped_time = 0.0
		settle_time = 0.0
		return true
	# Rounded to the degree: a Mule that falls onto its side rests at about 89.7° (the contact
	# margin), and it must count as 90°.
	if roundf(rad_to_deg(tilt())) >= TIPPED_ANGLE_DEG and not immune:
		settle_time = 0.0
		tipped_time += delta
		if tipped_time < TIPPED_TIME:
			return true
		crash()
		return false
	tipped_time = 0.0
	if on_pad:
		settle_time += delta
		if settle_time < SETTLE_TIME:
			return true
		land(touchdown_loss)
		return false
	settle_time = 0.0
	if fuel <= 0.0:
		enter(State.STRANDED)
		stranded.emit()
		return false
	return true


# Lands on the pad where the ship settled; a Hard landing passes the Condition it took, for the
# Landed title.
func land(loss := 0.0) -> void:
	enter(State.LANDED)
	hard_landing_loss = loss
	message.text = landed_title()
	velocity = Vector2.ZERO
	landed_on_pad.emit()


func dock() -> void:
	enter(State.DOCKED)
	settle()
	level_tween.tween_callback(docked_at_station.emit)


# Freezes the ship in whatever state it's in until release() or the next state.
func hold() -> void:
	held = true


func release() -> void:
	held = false


# Docked and free: not held, not loading and not easing upright after docking. Only such a ship may
# turn in place, and the Office's O key opens the Office only then.
func is_free_in_dock() -> bool:
	return state == State.DOCKED and not held and not loading and not is_leveling()


# Landed on a pad and not held: the Office's O key opens the pad's Workshop only then.
func is_free_on_pad() -> bool:
	return state == State.LANDED and not held


func is_leveling() -> bool:
	return level_tween != null and level_tween.is_running()


# The Economy has the fuel above the cap for the incoming Load pumped out meanwhile.
func start_loading(with_load: float) -> void:
	held = false
	loading = true
	incoming_load = with_load


func finish_loading() -> void:
	loading = false
	load_mass += incoming_load
	incoming_load = 0.0


# Stops the ship where it docked and levels it.
func settle() -> void:
	velocity = Vector2.ZERO
	# Wrap first so leveling never unwinds the player's full spins.
	rotation = wrapf(rotation, -PI, PI)
	level_tween = create_tween()
	level_tween.tween_property(self, "rotation", 0.0, LEVEL_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func rest(delta: float) -> void:
	# A docked ship may turn in place to face the way out.
	if is_free_in_dock():
		rotation += Input.get_axis("ui_left", "ui_right") * ship.turn_rate() * delta
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
	if pump_time_left > 0.0:
		lines.append(PUMPING_TEXT % ceili(pump_time_left))
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
