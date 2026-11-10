class_name PrototypeUpgrades
extends Node2D
# PROTOTYPE, throwaway: lives only on the prototype/first-upgrades branch, never merged.
# Answers "The first set of upgrades and how each changes flight" (issue #94): toggles candidate
# upgrades on the ship so they can be felt in flight. All numbers are rough first guesses.
#
# Keys (flight view): 1-9 toggle upgrades, T cycles ship type, [ / ] change the Load by 1 t,
# F drops the ship just under the Border above the pad (as after a crossing), R puts it on the pad.
# Abilities: SPACE opens/cuts the parachute, A/D side thrusters, DOWN reverse thrust.

# id: [name, dry-mass change as a share of the type's dry mass, effect text]
const UPGRADES := {
	"chute": ["LANDING PARACHUTE", 0.04, "SPACE opens it in the air; cut with SPACE; one per descent"],
	"side": ["SIDE THRUSTERS", 0.05, "A/D push sideways, nose stays put"],
	"reverse": ["REVERSE THRUST", 0.06, "DOWN thrusts out of the nose, half power"],
	"tank": ["LARGER TANK", 0.08, "Tank x1.5"],
	"efficient": ["FUEL-EFFICIENT ENGINE", 0.03, "Burn x0.8"],
	"modern": ["MODERN FUEL SYSTEM", 0.06, "Burn x0.6, REPLACES FUEL-EFFICIENT ENGINE"],
	"seats": ["EXTRA SEATS", 0.05, "+2 seats (mass only in flight)"],
	"cargo": ["CARGO FRAME", 0.10, "+3 t cargo and Maximum weight"],
	"engine": ["STRONGER ENGINE (extra)", 0.08, "Thrust x1.25, burn x1.25"],
}
const ORDER := ["chute", "side", "reverse", "tank", "efficient", "modern", "seats", "cargo", "engine"]
const REPLACES := {"modern": "efficient", "efficient": "modern"}

# The open parachute's terminal speed for a ship at the reference mass, in full gravity.
const CHUTE_TERMINAL_SPEED := 70.0
const CHUTE_DRAG := Lander.GRAVITY / (CHUTE_TERMINAL_SPEED * CHUTE_TERMINAL_SPEED)
# Opening faster than this tears it: useless for the rest of the descent.
const CHUTE_MAX_OPEN_SPEED := 300.0
# Below this share of gravity there's too little air to open or hold it.
const CHUTE_MIN_AIR := 0.5
const SIDE_THRUST_SHARE := 0.3
const REVERSE_THRUST_SHARE := 0.5

const LOAD_STEP := 1000.0
const DROP_HEIGHT_BELOW_BORDER := 60.0
const DROP_SPEED := 160.0

enum Chute { READY, OPEN, USED, TORN }

var fitted := {}
var base_type: ShipType
var chute := Chute.READY
var side_firing := 0.0
var reverse_firing := false
# The descent under way since the last F, and the last one's result.
var tracking := false
var track_fuel := 0.0
var track_time := 0.0
var last_result := "none yet: press F"

var lander: Lander
var panel := Label.new()


func _ready() -> void:
	lander = get_parent()
	base_type = lander.ship_type
	var layer := CanvasLayer.new()
	add_child(layer)
	panel.position = Vector2(12, 8)
	panel.add_theme_font_size_override("font_size", 14)
	panel.add_theme_color_override("font_shadow_color", Color.BLACK)
	layer.add_child(panel)
	lander.landed_on_pad.connect(on_landed)
	lander.docked_at_station.connect(func() -> void: chute = Chute.READY)
	var office: Office = lander.get_node("../Office")
	office.close.call_deferred()
	lander.release.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused or not event is InputEventKey or not event.pressed or event.echo:
		return
	var key: Key = event.physical_keycode
	if key >= KEY_1 and key <= KEY_9:
		toggle(ORDER[key - KEY_1])
	elif key == KEY_T:
		base_type = ShipType.ALL[(ShipType.ALL.find(base_type) + 1) % ShipType.ALL.size()]
		lander.become(base_type)
		apply()
		lander.fuel = lander.fuel_cap()
	elif key == KEY_BRACKETRIGHT or key == KEY_BRACKETLEFT:
		var step := LOAD_STEP if key == KEY_BRACKETRIGHT else -LOAD_STEP
		lander.load_mass = clampf(lander.load_mass + step, 0.0, lander.ship_type.cargo_capacity)
		lander.fuel = minf(lander.fuel, lander.fuel_cap())
	elif key == KEY_F:
		drop()
	elif key == KEY_SPACE and fitted.get("chute", false):
		use_chute()
	else:
		return
	get_viewport().set_input_as_handled()


func toggle(id: String) -> void:
	fitted[id] = not fitted.get(id, false)
	if fitted[id] and REPLACES.has(id):
		fitted[REPLACES[id]] = false
	var full := lander.fuel >= lander.ship_type.tank - 1.0
	apply()
	lander.fuel = lander.fuel_cap() if full else minf(lander.fuel, lander.fuel_cap())


# The ship flies with its type's numbers plus all its fitted upgrades.
func apply() -> void:
	var type := ShipType.new()
	for property in ["name", "flavour", "hull", "flame", "default_dry_mass", "maximum_weight", "tank",
			"passenger_seats", "cargo_capacity", "thrust", "burn_rate", "turn_rate"]:
		type.set(property, base_type.get(property))
	var mass_share := 0.0
	for id in ORDER:
		if fitted.get(id, false):
			mass_share += UPGRADES[id][1]
	if fitted.get("tank", false):
		type.tank *= 1.5
	if fitted.get("efficient", false):
		type.burn_rate *= 0.8
	if fitted.get("modern", false):
		type.burn_rate *= 0.6
	if fitted.get("seats", false):
		type.passenger_seats += 2
	if fitted.get("cargo", false):
		type.cargo_capacity += 3000.0
		type.maximum_weight += 3000.0
	if fitted.get("engine", false):
		type.thrust *= 1.25
		type.burn_rate *= 1.25
	type.default_dry_mass = base_type.default_dry_mass * (1.0 + mass_share)
	lander.ship_type = type
	lander.dry_mass = type.default_dry_mass


func drop() -> void:
	lander.load_mass = minf(lander.load_mass, lander.ship_type.cargo_capacity)
	lander.fuel = lander.fuel_cap()
	lander.fly_from(Vector2(lander.pad_center_x(), World.BORDER_Y + DROP_HEIGHT_BELOW_BORDER),
		Vector2(0.0, DROP_SPEED))
	chute = Chute.READY
	tracking = true
	track_fuel = lander.fuel
	track_time = 0.0


func use_chute() -> void:
	if lander.state != Lander.State.FLYING:
		return
	match chute:
		Chute.OPEN:
			chute = Chute.USED
		Chute.READY:
			if lander.gravity_share() < CHUTE_MIN_AIR:
				return
			chute = Chute.TORN if lander.velocity.length() > CHUTE_MAX_OPEN_SPEED else Chute.OPEN


func on_landed() -> void:
	chute = Chute.READY
	finish_tracking("LANDED")


func finish_tracking(how: String) -> void:
	if not tracking:
		return
	tracking = false
	last_result = "%s, %.0f kg fuel, %.1f s, %.1f t Load" % [how, track_fuel - lander.fuel, track_time,
		lander.load_mass / 1000.0]


# Called by the lander every flying physics frame, after the main engine.
func fly(delta: float) -> void:
	var mass_factor := lander.total_mass() / Lander.REFERENCE_MASS
	var burn_factor := (lander.dry_mass + lander.fuel + Lander.LOAD_BURN_SHARE * lander.load_mass) \
		/ Lander.REFERENCE_MASS
	var free := lander.disturb_left <= 0.0 and lander.fuel > 0.0
	var type := lander.ship_type

	side_firing = 0.0
	if fitted.get("side", false) and free:
		side_firing = float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A))
	if side_firing != 0.0:
		lander.velocity += Vector2.RIGHT.rotated(lander.rotation) * side_firing \
			* SIDE_THRUST_SHARE * type.thrust / mass_factor * delta
		burn(SIDE_THRUST_SHARE * type.burn_rate * burn_factor * delta)

	reverse_firing = fitted.get("reverse", false) and free and Input.is_action_pressed("ui_down")
	if reverse_firing:
		lander.velocity += Vector2.DOWN.rotated(lander.rotation) \
			* REVERSE_THRUST_SHARE * type.thrust / mass_factor * delta
		burn(REVERSE_THRUST_SHARE * type.burn_rate * burn_factor * delta)

	if chute == Chute.OPEN:
		var air := lander.gravity_share()
		if air < CHUTE_MIN_AIR:
			chute = Chute.USED
		else:
			var speed := lander.velocity.length()
			var slowing := minf(CHUTE_DRAG * speed * speed * air / mass_factor * delta, speed)
			lander.velocity -= lander.velocity.normalized() * slowing


func burn(kg: float) -> void:
	lander.fuel = maxf(lander.fuel - kg, 0.0)


func _process(delta: float) -> void:
	if tracking:
		if lander.state == Lander.State.CRASHED:
			finish_tracking("CRASHED")
		elif lander.state == Lander.State.FLYING:
			track_time += delta
	if lander.state != Lander.State.FLYING:
		side_firing = 0.0
		reverse_firing = false
	queue_redraw()
	panel.text = panel_text()


func panel_text() -> String:
	var type := lander.ship_type
	var lines := PackedStringArray([
		"PROTOTYPE: first upgrades (throwaway, issue #94)",
		"SHIP %s [T]   LOAD %.1f t [ / ]   seats %d, cargo %.0f t" % [base_type.name.to_upper(),
			lander.load_mass / 1000.0, type.passenger_seats, type.cargo_capacity / 1000.0],
		"dry %.1f t   fuel %.1f / %.1f t   total %.1f / max %.1f t   burn %.0f kg/s   thrust %.0f" % [
			lander.dry_mass / 1000.0, lander.fuel / 1000.0, type.tank / 1000.0, lander.total_mass() / 1000.0,
			type.maximum_weight / 1000.0, type.burn_rate, type.thrust],
		"speed: down %.0f  side %.0f px/s   (safe landing: down <= 50, side <= 25)" % [
			lander.velocity.y, absf(lander.velocity.x)],
		"",
	])
	for i in ORDER.size():
		var id: String = ORDER[i]
		var info: Array = UPGRADES[id]
		var extra := ""
		if id == "chute" and fitted.get(id, false):
			extra = "   [%s]" % Chute.keys()[chute]
		lines.append("[%d] %s %s  +%d%% dry  %s%s" % [i + 1, "X" if fitted.get(id, false) else "-",
			info[0], roundi(info[1] * 100.0), info[2], extra])
	lines.append("")
	lines.append("F drop from under the Border (160 px/s down)   R back on pad")
	lines.append("LAST DESCENT: " + last_result)
	return "\n".join(lines)


func _draw() -> void:
	var ink := Color(0.95, 0.95, 1.0)
	var jet := Color(1.0, 0.7, 0.3)
	if chute == Chute.OPEN:
		# The canopy stays upright whatever the ship's turn.
		draw_set_transform(Vector2.ZERO, -lander.rotation)
		var top := -90.0
		var canopy := PackedVector2Array()
		for i in 13:
			var angle := PI + PI * i / 12.0
			canopy.append(Vector2(cos(angle) * 40.0, top + sin(angle) * 22.0))
		canopy.append(Vector2(40.0, top))
		draw_colored_polygon(canopy, Color(0.9, 0.35, 0.25))
		var anchor := Vector2.UP.rotated(lander.rotation) * 14.0
		for x in [-40.0, -14.0, 14.0, 40.0]:
			draw_line(anchor, Vector2(x, top), ink, 1.0)
		draw_set_transform(Vector2.ZERO, 0.0)
	if side_firing != 0.0:
		var side := -side_firing * 16.0
		draw_colored_polygon(PackedVector2Array([Vector2(side, -4), Vector2(side, 4),
			Vector2(side * 1.8, 0)]), jet)
	if reverse_firing:
		draw_colored_polygon(PackedVector2Array([Vector2(-6, -18), Vector2(6, -18), Vector2(0, -34)]), jet)
