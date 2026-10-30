class_name Office
extends CanvasLayer
# The player's Office: a full-window Terminal showing one Ship offer per ship type.
# It pauses the world while showing, and puts the chosen ship type in the parking spot.

enum PopupKind { NONE, ARE_YOU_SURE, SWAP }
enum Choice { YES, NO }

const HEADER := "ORBITAL FREIGHT CO. // FLEET OFFERS"
const KEY_HINT := "← → BROWSE   RETURN SELECT"
const ARE_YOU_SURE_TEXT := "ARE YOU SURE?"
const SWAP_TEXT := "WOULD YOU LIKE TO CHOOSE A DIFFERENT SHIP?"
const IN_SERVICE_TEXT := "IN SERVICE"
const VERSION_PREFIX := "V"
const RATING_BLOCKS := 5
const FULL_BLOCK := "■"
const EMPTY_BLOCK := "□"

const FONT := preload("res://fonts/Silkscreen-Regular.ttf")
const Hud := preload("res://hud.gd")

const GREEN := Color(0.25, 1.0, 0.4)
const DIM_GREEN := Color(0.25, 1.0, 0.4, 0.25)
const BLACK := Color.BLACK
const SCANLINE_COLOR := Color(0.0, 0.0, 0.0, 0.35)
const SCANLINE_SPACING := 4.0

const MARGIN := 24.0
const PADDING := 32.0
const BORDER_WIDTH := 3.0
const LINE_WIDTH := 2.0
const HEADER_SIZE := 24
const NAME_SIZE := 48
const TEXT_SIZE := 16
const STAT_SIZE := 24
const HINT_SIZE := 16
const LINE_GAP := 14.0
const BLOCK_SIZE := Vector2(22, 22)
const BLOCK_GAP := 6.0
const RATING_LABEL_WIDTH := 200.0
const HINT_ARROW_SIZE := 12.0
# The Ship offer's text block (name, flavour, stats, ratings) is centred on the picture by
# starting this far above the Ship offer area's middle.
const SHIP_OFFER_TEXT_LIFT := 5.0 * STAT_SIZE + 3.0 * LINE_GAP
# Padding around the IN SERVICE tag's text, and how far the tag sits above the name's middle.
const TAG_PADDING := Vector2(8, 4)
const TAG_RAISE := 4.0
# Share of the Ship offer area's width and height the wireframe picture may fill.
const PICTURE_SHARE := 0.4

# The CRT power-on/off effect: the picture collapses to a bright line, then a dot
# (power-off), or grows back from them (power-on). LINE_SHARE is the part of the
# effect spent on the line and dot.
const POWER_TIME := 0.3
const LINE_SHARE := 0.35
const MIN_PICTURE_SCALE := 0.01
const GLOW := Color(0.8, 1.0, 0.85)
const GLOW_WIDTH := 3.0
const DOT_RADIUS := 4.0
# How bright the glow over the squashed picture starts, fading as the picture opens.
const GLOW_ALPHA := 0.8
# ease() curve for the line's stretch and the picture's opening: slow start, fast finish.
const POWER_EASE := 2.0

const POPUP_SIZE := Vector2(440, 200)
const POPUP_BUTTON_SIZE := Vector2(120, 44)
const POPUP_BUTTON_GAP := 48.0

var showing := false
var popup := PopupKind.NONE
var selected_button := Choice.YES
var ship_offer_index := 0
# The ship type the player is flying, tagged IN SERVICE on its Ship offer. None at run start.
var in_service: ShipType = null
# Whether the Office opened for a Ship swap (rather than at run start), which lets
# Escape and picking the IN SERVICE Ship offer cancel it.
var swapping := false
# Whether the Terminal is powering on or off. Office input is ignored meanwhile.
var powering := false
# How far the Terminal's picture is powered on: 0 is off, 1 fully on.
var power := 1.0

@onready var lander: Lander = $"../Lander"
@onready var terminal: Control = $Terminal


func _ready() -> void:
	terminal.draw.connect(draw_terminal)
	lander.docked_at_station.connect(offer_swap)
	open()


func _unhandled_input(event: InputEvent) -> void:
	if powering:
		return
	if popup != PopupKind.NONE:
		handle_popup_input(event)
	elif showing:
		handle_ship_offer_input(event)


func handle_ship_offer_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left"):
		browse(-1)
	elif event.is_action_pressed("ui_right"):
		browse(1)
	elif event.is_action_pressed("ui_accept"):
		if in_service_shown():
			# Picking the ship already in service declines the swap.
			decline_swap()
		else:
			show_popup(PopupKind.ARE_YOU_SURE, Choice.YES)
	elif event.is_action_pressed("ui_cancel") and swapping:
		decline_swap()
	else:
		# Escape on the Ship offer screen at run start does nothing: a run needs a ship.
		return
	get_viewport().set_input_as_handled()
	terminal.queue_redraw()


func handle_popup_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left"):
		selected_button = Choice.YES
	elif event.is_action_pressed("ui_right"):
		selected_button = Choice.NO
	elif event.is_action_pressed("ui_accept"):
		answer(selected_button)
	elif event.is_action_pressed("ui_cancel"):
		answer(Choice.NO)
	else:
		return
	get_viewport().set_input_as_handled()
	terminal.queue_redraw()


# Browsing wraps around at both ends.
func browse(step: int) -> void:
	ship_offer_index = posmod(ship_offer_index + step, ShipType.ALL.size())


func open() -> void:
	showing = true
	visible = true
	popup = PopupKind.NONE
	get_tree().paused = true
	power_to(1.0)


# Powers the Terminal off, closes the Office, then calls after_closing: the flight
# view shows only once the effect is over.
func power_off(after_closing: Callable) -> void:
	popup = PopupKind.NONE
	power_to(0.0, func() -> void:
		close()
		after_closing.call())


func power_to(target: float, done := Callable()) -> void:
	powering = true
	var tween := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_method(set_power, 1.0 - target, target, POWER_TIME)
	tween.tween_callback(func() -> void:
		powering = false
		if done.is_valid():
			done.call())


func set_power(value: float) -> void:
	power = value
	terminal.queue_redraw()


func close() -> void:
	showing = false
	swapping = false
	in_service = null
	visible = false
	popup = PopupKind.NONE
	get_tree().paused = false


# Docking asks whether to swap ships, over the flight view. The ship is held until
# the answer: No releases it, a new ship type replaces it.
func offer_swap() -> void:
	lander.hold()
	visible = true
	show_popup(PopupKind.SWAP, Choice.NO)
	terminal.queue_redraw()


func show_popup(kind: PopupKind, default_button: Choice) -> void:
	popup = kind
	selected_button = default_button


func answer(choice: Choice) -> void:
	match [popup, choice]:
		[PopupKind.SWAP, Choice.YES]:
			open_for_swap()
		[PopupKind.SWAP, Choice.NO]:
			decline_swap()
		[PopupKind.ARE_YOU_SURE, Choice.YES]:
			var type := selected_ship_offer()
			power_off(lander.start_docked.bind(type))
		[PopupKind.ARE_YOU_SURE, Choice.NO]:
			popup = PopupKind.NONE


# The Terminal powers on with the ship type being flown selected and tagged IN SERVICE.
func open_for_swap() -> void:
	swapping = true
	in_service = lander.ship_type
	ship_offer_index = ShipType.ALL.find(in_service)
	open()


# Back to the parking spot, Docked as before: the ship stays as it is and refuels after the usual delay.
# From the Ship offer screen the Terminal powers off first; the swap popup just closes.
func decline_swap() -> void:
	if showing:
		power_off(lander.release)
	else:
		close()
		lander.release()


# Observable state

func selected_ship_offer() -> ShipType:
	return ShipType.ALL[ship_offer_index]


func in_service_shown() -> bool:
	return showing and selected_ship_offer() == in_service


func ship_offer_indicator() -> String:
	return "< %d/%d >" % [ship_offer_index + 1, ShipType.ALL.size()]


# The text the selected Ship offer shows, with ratings written as blocks.
func ship_offer_lines() -> PackedStringArray:
	var type := selected_ship_offer()
	var lines := PackedStringArray([type.name.to_upper(), type.flavour.to_upper()])
	for stat: Array in ship_offer_stats():
		lines.append("%s %s" % stat)
	for rating: Array in ship_offer_ratings():
		lines.append("%s %s" % [rating[0], blocks(rating[1])])
	lines.append(ship_offer_indicator())
	if in_service_shown():
		lines.append(IN_SERVICE_TEXT)
	return lines


# The selected Ship offer's numbers as [label, text] pairs.
func ship_offer_stats() -> Array[Array]:
	var type := selected_ship_offer()
	return [["TANK", kg(type.tank)], ["DRY MASS", kg(type.default_dry_mass)],
		["MAX WEIGHT", kg(type.maximum_weight)], ["SEATS", str(type.passenger_seats)],
		["CARGO", kg(type.cargo_capacity)]]


# The selected Ship offer's ratings as [label, blocks out of RATING_BLOCKS] pairs.
func ship_offer_ratings() -> Array[Array]:
	var type := selected_ship_offer()
	return [["THRUST", type.thrust_rating], ["HANDLING", type.handling_rating]]


# The wireframe picture's outline: the ship type's hull.
func ship_offer_picture() -> PackedVector2Array:
	return selected_ship_offer().hull


static func kg(value: float) -> String:
	return Hud.format_kg(value).to_upper()


static func blocks(rating: int) -> String:
	return FULL_BLOCK.repeat(rating) + EMPTY_BLOCK.repeat(RATING_BLOCKS - rating)


# Drawing

func draw_terminal() -> void:
	var screen := Rect2(Vector2.ZERO, terminal.size)
	if not showing:
		# The swap popup sits over the flight view, without the Terminal behind it.
		if popup != PopupKind.NONE:
			draw_popup(screen)
		return
	terminal.draw_rect(screen, BLACK)
	if power <= LINE_SHARE:
		draw_power_line(screen, power / LINE_SHARE)
		return
	# The picture grows from (or shrinks to) the bright line across the middle.
	var picture_scale := maxf(ease((power - LINE_SHARE) / (1.0 - LINE_SHARE), POWER_EASE), MIN_PICTURE_SCALE)
	var centre := screen.get_center()
	var scale := Vector2(1.0, picture_scale)
	terminal.draw_set_transform(centre - centre * scale, 0.0, scale)
	draw_screen(screen)
	if picture_scale < 1.0:
		terminal.draw_rect(screen, Color(GLOW, GLOW_ALPHA * (1.0 - picture_scale)))
	terminal.draw_set_transform(Vector2.ZERO)
	draw_scanlines(screen)


# The first or last moment of the effect: a dot that stretches into a line across
# the screen as `stretch` goes from 0 to 1.
func draw_power_line(screen: Rect2, stretch: float) -> void:
	var centre := screen.get_center()
	var half_width := screen.size.x / 2.0 * ease(stretch, POWER_EASE)
	if half_width < DOT_RADIUS:
		terminal.draw_circle(centre, DOT_RADIUS, GLOW)
	else:
		terminal.draw_line(centre - Vector2(half_width, 0.0), centre + Vector2(half_width, 0.0), GLOW, GLOW_WIDTH)


# The Terminal's picture: frame, header, Ship offer, key hint and any popup.
func draw_screen(screen: Rect2) -> void:
	var frame := screen.grow(-MARGIN)
	terminal.draw_rect(frame, GREEN, false, BORDER_WIDTH)
	var inner := frame.grow(-PADDING)

	draw_text(HEADER, Vector2(inner.position.x, inner.position.y + HEADER_SIZE), HEADER_SIZE)
	var rule_y := inner.position.y + HEADER_SIZE + LINE_GAP
	terminal.draw_line(Vector2(frame.position.x, rule_y), Vector2(frame.end.x, rule_y), GREEN, LINE_WIDTH)
	draw_text(ship_offer_indicator(), Vector2(inner.position.x, rule_y + LINE_GAP + TEXT_SIZE), TEXT_SIZE,
		inner.size.x, HORIZONTAL_ALIGNMENT_RIGHT)

	var hint_y := inner.end.y
	var hint_rule_y := hint_y - HINT_SIZE - LINE_GAP
	terminal.draw_line(Vector2(frame.position.x, hint_rule_y), Vector2(frame.end.x, hint_rule_y), GREEN, LINE_WIDTH)
	draw_key_hint(Vector2(inner.position.x, hint_y))
	draw_text(version_text(), Vector2(inner.position.x, hint_y), HINT_SIZE, inner.size.x,
		HORIZONTAL_ALIGNMENT_RIGHT, DIM_GREEN)

	var ship_offer_area := Rect2(inner.position.x, rule_y + LINE_GAP, inner.size.x, hint_rule_y - rule_y - 2.0 * LINE_GAP)
	draw_ship_offer(ship_offer_area)
	if popup != PopupKind.NONE:
		draw_popup(screen)


func draw_ship_offer(area: Rect2) -> void:
	var type := selected_ship_offer()
	var half := area.size.x / 2.0
	var picture_box := Rect2(area.position, Vector2(half, area.size.y))
	draw_wireframe(ship_offer_picture(), picture_box)

	var x := area.position.x + half
	var width := half
	var y := area.get_center().y - SHIP_OFFER_TEXT_LIFT + NAME_SIZE
	var title := type.name.to_upper()
	draw_text(title, Vector2(x, y), NAME_SIZE, width)
	if in_service_shown():
		draw_in_service_tag(Vector2(x + text_width(title, NAME_SIZE) + LINE_GAP,
			y - NAME_SIZE / 2.0 - TEXT_SIZE / 2.0 - TAG_RAISE))
	y += LINE_GAP + TEXT_SIZE
	draw_text(type.flavour.to_upper(), Vector2(x, y), TEXT_SIZE, width)
	y += 2.0 * LINE_GAP
	for stat: Array in ship_offer_stats():
		y += STAT_SIZE + LINE_GAP
		draw_text(stat[0], Vector2(x, y), STAT_SIZE, RATING_LABEL_WIDTH)
		draw_text(stat[1], Vector2(x + RATING_LABEL_WIDTH, y), STAT_SIZE, width - RATING_LABEL_WIDTH)
	y += LINE_GAP
	for rating: Array in ship_offer_ratings():
		y += STAT_SIZE + LINE_GAP
		draw_text(rating[0], Vector2(x, y), STAT_SIZE, RATING_LABEL_WIDTH)
		draw_rating(rating[1], Vector2(x + RATING_LABEL_WIDTH, y - BLOCK_SIZE.y))


func draw_wireframe(outline: PackedVector2Array, box: Rect2) -> void:
	var bounds := outline_bounds(outline)
	var fit := box.size * PICTURE_SHARE * 2.0 / bounds.size
	var scale := minf(fit.x, fit.y)
	var points := PackedVector2Array()
	for point: Vector2 in outline:
		points.append(box.get_center() + (point - bounds.get_center()) * scale)
	points.append(points[0])
	terminal.draw_polyline(points, GREEN, BORDER_WIDTH)


# The smallest box around an outline (a hull or flame).
static func outline_bounds(outline: PackedVector2Array) -> Rect2:
	var bounds := Rect2(outline[0], Vector2.ZERO)
	for point: Vector2 in outline:
		bounds = bounds.expand(point)
	return bounds


func draw_rating(rating: int, top_left: Vector2) -> void:
	for i in RATING_BLOCKS:
		var block := Rect2(top_left + Vector2(i * (BLOCK_SIZE.x + BLOCK_GAP), 0.0), BLOCK_SIZE)
		if i < rating:
			terminal.draw_rect(block, GREEN)
		else:
			terminal.draw_rect(block, DIM_GREEN, false, LINE_WIDTH)


func draw_in_service_tag(top_left: Vector2) -> void:
	var text_size := FONT.get_string_size(IN_SERVICE_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE)
	var tag := Rect2(top_left, text_size + 2.0 * TAG_PADDING)
	terminal.draw_rect(tag, GREEN)
	draw_text(IN_SERVICE_TEXT, top_left + TAG_PADDING + Vector2(0, TEXT_SIZE), TEXT_SIZE, -1,
		HORIZONTAL_ALIGNMENT_LEFT, BLACK)


# Silkscreen has no arrow glyphs, so the hint's arrows are drawn as triangles.
func draw_key_hint(baseline_left: Vector2) -> void:
	var words := KEY_HINT.replace("←", "").replace("→", "").strip_edges()
	var arrows_width := HINT_ARROW_SIZE * 3.0 + LINE_GAP
	var x := baseline_left.x + (terminal.size.x - 2.0 * (MARGIN + PADDING) - arrows_width
		- text_width(words, HINT_SIZE)) / 2.0
	var mid_y := baseline_left.y - HINT_SIZE / 2.0
	var h := HINT_ARROW_SIZE / 2.0
	terminal.draw_colored_polygon(PackedVector2Array([
		Vector2(x, mid_y), Vector2(x + HINT_ARROW_SIZE, mid_y - h), Vector2(x + HINT_ARROW_SIZE, mid_y + h)]), GREEN)
	x += HINT_ARROW_SIZE * 1.5
	terminal.draw_colored_polygon(PackedVector2Array([
		Vector2(x + HINT_ARROW_SIZE, mid_y), Vector2(x, mid_y - h), Vector2(x, mid_y + h)]), GREEN)
	x += HINT_ARROW_SIZE * 1.5 + LINE_GAP
	draw_text(words, Vector2(x, baseline_left.y), HINT_SIZE)


func version_text() -> String:
	return VERSION_PREFIX + GameVersion.VERSION


func popup_text() -> String:
	return SWAP_TEXT if popup == PopupKind.SWAP else ARE_YOU_SURE_TEXT


func draw_popup(screen: Rect2) -> void:
	var text := popup_text()
	var size := Vector2(maxf(POPUP_SIZE.x, text_width(text, STAT_SIZE) + 2.0 * PADDING), POPUP_SIZE.y)
	var box := Rect2(screen.get_center() - size / 2.0, size)
	terminal.draw_rect(box, BLACK)
	terminal.draw_rect(box, GREEN, false, BORDER_WIDTH)
	draw_text(text, Vector2(box.position.x, box.position.y + PADDING + STAT_SIZE), STAT_SIZE,
		box.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	var buttons_width := POPUP_BUTTON_SIZE.x * 2.0 + POPUP_BUTTON_GAP
	var button_y := box.end.y - PADDING - POPUP_BUTTON_SIZE.y
	var x := box.get_center().x - buttons_width / 2.0
	for choice: Choice in [Choice.YES, Choice.NO]:
		var button := Rect2(Vector2(x, button_y), POPUP_BUTTON_SIZE)
		var selected := choice == selected_button
		if selected:
			terminal.draw_rect(button, GREEN)
		else:
			terminal.draw_rect(button, GREEN, false, LINE_WIDTH)
		var label := "YES" if choice == Choice.YES else "NO"
		draw_text(label, Vector2(button.position.x, button.get_center().y + TEXT_SIZE / 2.0), TEXT_SIZE,
			button.size.x, HORIZONTAL_ALIGNMENT_CENTER, BLACK if selected else GREEN)
		x += POPUP_BUTTON_SIZE.x + POPUP_BUTTON_GAP


func draw_scanlines(screen: Rect2) -> void:
	var y := 0.0
	while y < screen.size.y:
		terminal.draw_line(Vector2(0.0, y), Vector2(screen.size.x, y), SCANLINE_COLOR, 1.0)
		y += SCANLINE_SPACING


func draw_text(text: String, baseline: Vector2, font_size: int, width := -1.0,
		alignment := HORIZONTAL_ALIGNMENT_LEFT, color := GREEN) -> void:
	terminal.draw_string(FONT, baseline, text, alignment, width, font_size, color)


func text_width(text: String, font_size: int) -> float:
	return FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
