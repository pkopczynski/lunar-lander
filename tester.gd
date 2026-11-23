class_name Tester
extends CanvasLayer
# Tester mode and the Tester panel, a hidden tool that lets a tester skip the grind. Typing the
# letters T E S T E R within `CODE_TIME` seconds (anywhere: in flight, Docked, in the Office) turns
# Tester mode `on`, and typing them again turns it off, every switch with it. It lives in this scene
# node only (ADR 0008): it lasts for the page session and is never part of the Career.
#
# With Tester mode on, backquote (physical key) opens the Tester panel (`panel_open`), an overlay
# drawn on `Panel` above the Terminal (layer 20) in flight and over the Office alike. While it's open
# everything stops: it pauses the tree, and also disables the two nodes that run while paused (the
# Economy: delivery clock, offer expiry, loading and unloading; the Hangar: the fuel pump), so
# fiddling with options never makes a Contract overdue; closing it puts both back as they were. It
# sees every key first (`_input`) and swallows each one while open, so none reaches the Office or the
# flight: Up/Down move, Return runs or toggles the selected row, Escape (or backquote) closes it. A row
# that can't apply right now is dimmed and does nothing.
#
# The Tester options are registered in `_ready()` with `add_option()`: a name, a kind (a switch stays
# ON/OFF, an action runs once), when it's available and what it does, so a new option is one entry.
# The switches act from outside through the owners' public operations: Auto-refuel tops the ship in
# service's fuel up to its fuel cap every frame (`Hangar.top_up()`), Auto-repair repairs it after each
# `Lander.damaged` (`Hangar.repair()`), Immune sets `Lander.immune`. The money options are Tester
# adjustments (`Economy.make_tester_adjustment()`), and the teleports are `Lander.return_to_station()`
# and `Lander.reset_to_pad()`. `tag_text()` is the `TESTER: FUEL · REPAIR · IMMUNE` marker the HUD
# and the Terminal header show while Tester mode is on; `changed` tells them to redraw.
# Attached to `Tester`; process mode Always. Must stay below `Lander` in `main.tscn`, so Auto-refuel
# tops up after the Lander has burnt fuel in the same frame.

# Tester mode, a switch or the panel changed: the HUD and the Terminal redraw their tag.
signal changed

enum Kind { SWITCH, ACTION }

const CODE := "TESTER"
# The letters of the code must all be typed within this many seconds.
const CODE_TIME := 3.0
const TAG := "TESTER"
const TAG_SEPARATOR := " · "
const ADJUSTMENT := 500000

const FONT := preload("res://fonts/Silkscreen-Regular.ttf")
const TITLE := "TESTER PANEL"
const HINT := "UP DOWN MOVE   RETURN SELECT   ESC CLOSE"
const ON_TEXT := "ON"
const OFF_TEXT := "OFF"
const INK := Color(1.0, 0.45, 0.9)
const DIM_INK := Color(1.0, 0.45, 0.9, 0.3)
const BACKGROUND := Color(0.0, 0.0, 0.0, 0.92)
const TITLE_SIZE := 24
const TEXT_SIZE := 16
const ROW_HEIGHT := 32.0
const PADDING := 24.0
const BORDER_WIDTH := 3.0
const PANEL_WIDTH := 420.0


# One row of the Tester panel.
class Option:
	var name: String
	var kind: Kind
	# The switch's short name in the tag, as FUEL; "" for an action.
	var tag: String
	var available: Callable
	var run: Callable
	var is_on := false


var on := false
var panel_open := false
var options: Array[Option] = []
var selected := 0
# Seconds since the scene started, counted in frames so the --fixed-fps tests are deterministic.
var time := 0.0
# The last letters typed and when, oldest first, at most CODE's length.
var typed := ""
var typed_at: Array[float] = []
# While the panel is open: whether the tree was paused before, and the process modes it changed.
var was_paused := false
var stopped: Dictionary[Node, ProcessMode] = {}

@onready var lander: Lander = $"../Lander"
@onready var hangar: Hangar = $"../Hangar"
@onready var economy: Economy = $"../Economy"
@onready var office: Office = $"../Office"
@onready var panel: Control = $Panel


func _ready() -> void:
	add_option("AUTO-REFUEL", Kind.SWITCH, always, func() -> void: pass, "FUEL")
	add_option("AUTO-REPAIR", Kind.SWITCH, always, func() -> void: pass, "REPAIR")
	add_option("IMMUNE", Kind.SWITCH, always, func() -> void: lander.immune = is_on("IMMUNE"), "IMMUNE")
	add_option("+" + Economy.eur(ADJUSTMENT), Kind.ACTION, always, economy.make_tester_adjustment.bind(ADJUSTMENT))
	add_option(Economy.eur(-ADJUSTMENT), Kind.ACTION, always, economy.make_tester_adjustment.bind(-ADJUSTMENT))
	add_option("BACK TO STATION", Kind.ACTION, can_return_to_station, lander.return_to_station)
	add_option("BACK TO PAD", Kind.ACTION, can_teleport, lander.reset_to_pad)
	lander.damaged.connect(repair_after_loss)
	panel.draw.connect(draw_panel)
	panel.visible = false


# Registers a row: a switch flips is_on and then runs (reading is_on), an action just runs.
func add_option(name: String, kind: Kind, available: Callable, run: Callable, tag := "") -> void:
	var option := Option.new()
	option.name = name
	option.kind = kind
	option.tag = tag
	option.available = available
	option.run = run
	options.append(option)


static func always() -> bool:
	return true


# Back to station and Back to pad: from flight or Landed, never while Crashed, Stranded or Docked, nor
# while the Terminal shows (the Office, or a pad's Workshop).
func can_teleport() -> bool:
	return lander.state in [Lander.State.FLYING, Lander.State.LANDED] and not office.showing


# Back to station also waits for unloading to finish: the Load is coming off at the pad.
func can_return_to_station() -> bool:
	return can_teleport() and economy.phase != Economy.Phase.UNLOADING


func _process(delta: float) -> void:
	time += delta


# Auto-refuel, after the Lander has burnt this frame's fuel (Tester stays below it in the tree).
func _physics_process(_delta: float) -> void:
	if is_on("AUTO-REFUEL"):
		hangar.top_up()


# Sees every key before the Office or the flight does.
func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo:
		var letter := OS.get_keycode_string(key.keycode)
		if letter.length() == 1 and letter >= "A" and letter <= "Z" and type_letter(letter):
			get_viewport().set_input_as_handled()
			return
		if key.physical_keycode == KEY_QUOTELEFT:
			if panel_open:
				close_panel()
			elif on and not office.powering:
				open_panel()
			if panel_open or on:
				get_viewport().set_input_as_handled()
			return
	if panel_open:
		handle_panel_input(event)
		get_viewport().set_input_as_handled()


# Returns whether this letter completed the code (and so toggled Tester mode).
func type_letter(letter: String) -> bool:
	typed += letter
	typed_at.append(time)
	if typed.length() > CODE.length():
		typed = typed.right(CODE.length())
		typed_at.pop_front()
	if typed != CODE or time - typed_at[0] > CODE_TIME:
		return false
	typed = ""
	typed_at.clear()
	turn(not on)
	return true


# Turning Tester mode off closes the panel and turns every switch off.
func turn(to_on: bool) -> void:
	on = to_on
	if not on:
		close_panel()
		for option in options:
			if option.is_on:
				option.is_on = false
				option.run.call()
	changed.emit()


func handle_panel_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_up"):
		selected = maxi(selected - 1, 0)
	elif event.is_action_pressed("ui_down"):
		selected = mini(selected + 1, options.size() - 1)
	elif event.is_action_pressed("ui_accept"):
		choose(options[selected])
	elif event.is_action_pressed("ui_cancel"):
		close_panel()
	panel.queue_redraw()


func choose(option: Option) -> void:
	if not option.available.call():
		return
	if option.kind == Kind.SWITCH:
		option.is_on = not option.is_on
	option.run.call()
	changed.emit()


# Everything stops: the tree pauses, and the nodes that run while paused are disabled.
func open_panel() -> void:
	panel_open = true
	was_paused = get_tree().paused
	get_tree().paused = true
	for node: Node in [economy, hangar]:
		stopped[node] = node.process_mode
		node.process_mode = Node.PROCESS_MODE_DISABLED
	panel.visible = true
	panel.queue_redraw()
	changed.emit()


func close_panel() -> void:
	if not panel_open:
		return
	panel_open = false
	for node: Node in stopped:
		node.process_mode = stopped[node]
	stopped.clear()
	get_tree().paused = was_paused
	panel.visible = false
	changed.emit()


# Auto-repair: the loss has happened and flashed (the HUD heard `damaged` first), then the ship in
# service is back at 100%, free.
func repair_after_loss(_loss: float) -> void:
	if is_on("AUTO-REPAIR"):
		hangar.repair(hangar.in_service)


# Observable state

func is_on(name: String) -> bool:
	return option_named(name).is_on


func option_named(name: String) -> Option:
	for option in options:
		if option.name == name:
			return option
	return null


# AUTO-REFUEL  OFF, +€500 000: one per row, top to bottom.
func rows() -> PackedStringArray:
	var texts := PackedStringArray()
	for option in options:
		texts.append(row_text(option))
	return texts


func row_text(option: Option) -> String:
	if option.kind == Kind.ACTION:
		return option.name
	return "%s  %s" % [option.name, switch_text(option)]


# A switch's ON or OFF.
static func switch_text(option: Option) -> String:
	return ON_TEXT if option.is_on else OFF_TEXT


# Whether the named row can apply right now; a dimmed row does nothing.
func available(name: String) -> bool:
	return option_named(name).available.call()


# Whether each row can apply right now; a dimmed row does nothing.
func available_rows() -> Array[bool]:
	var available: Array[bool] = []
	for option in options:
		available.append(option.available.call())
	return available


# TESTER: FUEL · REPAIR · IMMUNE (the switches that are on), TESTER with none, "" with Tester mode off.
func tag_text() -> String:
	if not on:
		return ""
	var tags := PackedStringArray()
	for option in options:
		if option.is_on:
			tags.append(option.tag)
	return TAG if tags.is_empty() else "%s: %s" % [TAG, TAG_SEPARATOR.join(tags)]


# Drawing

func draw_panel() -> void:
	var height := PADDING * 3.0 + TITLE_SIZE + options.size() * ROW_HEIGHT + TEXT_SIZE + PADDING
	var box := Rect2(panel.size / 2.0 - Vector2(PANEL_WIDTH, height) / 2.0, Vector2(PANEL_WIDTH, height))
	panel.draw_rect(box, BACKGROUND)
	panel.draw_rect(box, INK, false, BORDER_WIDTH)
	var inner := box.grow(-PADDING)
	panel.draw_string(FONT, Vector2(inner.position.x, inner.position.y + TITLE_SIZE), TITLE,
		HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_SIZE, INK)
	var y := inner.position.y + TITLE_SIZE + PADDING
	var available := available_rows()
	for i in options.size():
		var row := Rect2(inner.position.x, y, inner.size.x, ROW_HEIGHT)
		var ink := INK if available[i] else DIM_INK
		if i == selected:
			panel.draw_rect(row, ink)
		var color := Color.BLACK if i == selected else ink
		var baseline := Vector2(row.position.x + TEXT_SIZE / 2.0, row.get_center().y + TEXT_SIZE / 2.0)
		var option := options[i]
		panel.draw_string(FONT, baseline, option.name, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE, color)
		if option.kind == Kind.SWITCH:
			panel.draw_string(FONT, baseline, switch_text(option), HORIZONTAL_ALIGNMENT_RIGHT,
				row.size.x - TEXT_SIZE, TEXT_SIZE, color)
		y += ROW_HEIGHT
	panel.draw_string(FONT, Vector2(inner.position.x, inner.end.y), HINT, HORIZONTAL_ALIGNMENT_CENTER,
		inner.size.x, TEXT_SIZE, DIM_INK)
