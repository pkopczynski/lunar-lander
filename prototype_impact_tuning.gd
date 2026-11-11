# PROTOTYPE, throwaway: live tuning for "How hitting terrain feels" (issue #101) and
# "How a ship on the ground tips and rolls" (#102). Never merged. Tab shows the sliders,
# F3 repairs, F4 clears the tally, F6 drops the ship in an awkward pose.
class_name ImpactTuning
extends CanvasLayer

# Static, so a scene reload (R in deep space, or after a crash) keeps them.
static var values := {
	"restitution": 0.35,        # share of impact speed kept as bounce
	"tangent_keep": 0.8,        # share of speed along the surface kept on a hit
	"rest_speed": 15.0,         # below this impact speed: no bounce, just rest
	"ground_friction": 60.0,    # px/s² braking while resting/sliding on the floor
	"no_damage": 15.0,          # px/s
	"crash_speed": 120.0,       # px/s
	"max_hit": 50.0,            # % condition lost just under crash speed
	"hard_max": 25.0,           # % condition lost at the far end of a landing band
	"v_safe": 50.0, "v_crash": 80.0,
	"h_safe": 25.0, "h_crash": 40.0,
	"tilt_safe": 15.0, "tilt_crash": 25.0,
	"tip_angle": 90.0, "tip_time": 2.0,
	# #102
	"tip_physics": 1.0,         # 0 = #101 (ship keeps its angle on contact), 1 = rigid body
	"pad_settle": 1.0,          # 0 = touching the pad lands at once, 1 = lands once settled on it
	"pad_restitution": 0.0,     # bounce off the pad (legs absorb it) when pad_settle is on
	"ground_turn": 6.0,         # rad/s² the controls spin a grounded Sparrow (0 = no control)
	"ground_spin_damping": 0.5, # 1/s rolling resistance
	"air_spin_damping": 3.0,    # 1/s: how fast a spin picked up on the ground fades in flight
	"inertia_scale": 1.0,       # × the hull's own moment of inertia
}
const RANGES := {
	"restitution": [0.0, 1.0, 0.05], "tangent_keep": [0.0, 1.0, 0.05],
	"rest_speed": [0.0, 60.0, 1.0], "ground_friction": [0.0, 400.0, 10.0],
	"no_damage": [0.0, 60.0, 1.0], "crash_speed": [40.0, 300.0, 5.0],
	"max_hit": [0.0, 100.0, 5.0], "hard_max": [0.0, 100.0, 5.0],
	"v_safe": [10.0, 150.0, 5.0], "v_crash": [10.0, 200.0, 5.0],
	"h_safe": [5.0, 100.0, 5.0], "h_crash": [5.0, 150.0, 5.0],
	"tilt_safe": [0.0, 45.0, 1.0], "tilt_crash": [0.0, 90.0, 1.0],
	"tip_angle": [30.0, 180.0, 5.0], "tip_time": [0.0, 5.0, 0.25],
	"tip_physics": [0.0, 1.0, 1.0], "pad_settle": [0.0, 1.0, 1.0],
	"pad_restitution": [0.0, 1.0, 0.05], "ground_turn": [0.0, 30.0, 0.5],
	"ground_spin_damping": [0.0, 5.0, 0.1], "air_spin_damping": [0.0, 10.0, 0.25],
	"inertia_scale": [0.25, 4.0, 0.25],
}

# The tally: one entry per leg (lift-off to the next landing/dock/crash).
static var legs: Array[Dictionary] = []
static var leg_hits := 0
static var leg_damage := 0.0

static func v(key: String) -> float:
	return values[key]

var panel: VBoxContainer
var readout: Label
var lander: Lander
var dots_node: Node2D


func _ready() -> void:
	layer = 50
	readout = Label.new()
	readout.position = Vector2(16, 16)
	readout.add_theme_font_size_override("font_size", 16)
	readout.add_theme_color_override("font_outline_color", Color.BLACK)
	readout.add_theme_constant_override("outline_size", 4)
	add_child(readout)
	var bg := PanelContainer.new()
	bg.position = Vector2(16, 230)
	add_child(bg)
	panel = VBoxContainer.new()
	bg.add_child(panel)
	for key in values:
		var row := HBoxContainer.new()
		var name_label := Label.new()
		name_label.custom_minimum_size.x = 130
		name_label.text = key
		var value_label := Label.new()
		value_label.custom_minimum_size.x = 50
		value_label.text = str(values[key])
		var slider := HSlider.new()
		slider.custom_minimum_size.x = 200
		slider.focus_mode = Control.FOCUS_NONE
		slider.min_value = RANGES[key][0]
		slider.max_value = RANGES[key][1]
		slider.step = RANGES[key][2]
		slider.value = values[key]
		slider.value_changed.connect(func(x: float) -> void:
			values[key] = x
			value_label.text = str(x))
		row.add_child(name_label)
		row.add_child(slider)
		row.add_child(value_label)
		panel.add_child(row)
	bg.visible = false
	var dots := Node2D.new()
	dots.draw.connect(func() -> void:
		var xf := lander.get_viewport().get_canvas_transform()
		for k in lander.contacts_debug:
			dots.draw_circle(xf * k.p, 3.0, Color.YELLOW)
			dots.draw_line(xf * k.p, xf * (k.p + k.n * 12.0), Color.YELLOW, 1.0)
		dots.draw_circle(xf * lander.to_global(lander.com_local), 2.5, Color.CYAN))
	add_child(dots)
	dots_node = dots


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_TAB:
				panel.get_parent().visible = not panel.get_parent().visible
			KEY_F3:
				lander.condition = 100.0
			KEY_F4:
				legs.clear()
				leg_hits = 0
				leg_damage = 0.0
			KEY_F5:
				print("TUNING ", values)


static func record_hit(damage: float) -> void:
	leg_hits += 1
	leg_damage += damage


static func end_leg(how: String) -> void:
	legs.append({"how": how, "hits": leg_hits, "damage": leg_damage})
	print("LEG %s: %d hits, %.1f%% damage" % [how, leg_hits, leg_damage])
	leg_hits = 0
	leg_damage = 0.0


func _process(_delta: float) -> void:
	var lines := PackedStringArray()
	lines.append("CONDITION %d%%" % roundi(lander.condition))
	lines.append(lander.last_hit_text)
	var hit_legs := 0
	var total := 0.0
	var landings := 0
	for leg in legs:
		total += leg.damage
		if leg.hits > 0:
			hit_legs += 1
		if leg.how != "crash":
			landings += 1
	lines.append("legs %d (crashes %d) | legs with damage %d | avg damage/leg %.1f%%" % [
		legs.size(), legs.size() - landings, hit_legs, total / maxf(legs.size(), 1)])
	lines.append("this leg: %d hits, %.1f%%" % [leg_hits, leg_damage])
	lines.append("tilt %d° · spin %d°/s · contacts %d · tipped %.1f s · pad severity %.2f · impact %d" % [
		roundi(rad_to_deg(angle_difference(0.0, lander.rotation))), roundi(rad_to_deg(lander.angular)),
		lander.contacts_debug.size() if lander.touching else 0, lander.tipped_time, lander.pad_severity, roundi(lander.last_impact)])
	lines.append("Tab tuning · F3 repair · F4 clear tally · F5 print values · F6 drop in an awkward pose")
	dots_node.queue_redraw()
	readout.text = "\n".join(lines)
