class_name Office
extends CanvasLayer
# The player's Office: a full-window Terminal showing one Offer per ship type.
# It pauses the world while showing, and puts the chosen ship type in the parking spot.

enum PopupKind { NONE, ARE_YOU_SURE }
enum Choice { YES, NO }

const HEADER := "ORBITAL FREIGHT CO. // FLEET OFFERS"
const KEY_HINT := "← → BROWSE   RETURN SELECT"
const ARE_YOU_SURE_TEXT := "ARE YOU SURE?"
const IN_SERVICE_TEXT := "IN SERVICE"
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
# Share of the Offer area's width and height the wireframe picture may fill.
const PICTURE_SHARE := 0.4

const POPUP_SIZE := Vector2(440, 200)
const POPUP_BUTTON_SIZE := Vector2(120, 44)
const POPUP_BUTTON_GAP := 48.0

var showing := false
var popup := PopupKind.NONE
var selected_button := Choice.YES
var offer_index := 0
# The ship type the player is flying, tagged IN SERVICE on its Offer. None at run start.
var in_service: ShipType = null

@onready var lander: Lander = $"../Lander"
@onready var terminal: Control = $Terminal


func _ready() -> void:
	terminal.draw.connect(draw_terminal)
	open()


func _unhandled_input(event: InputEvent) -> void:
	if not showing:
		return
	if popup == PopupKind.NONE:
		handle_offer_input(event)
	else:
		handle_popup_input(event)


func handle_offer_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left"):
		browse(-1)
	elif event.is_action_pressed("ui_right"):
		browse(1)
	elif event.is_action_pressed("ui_accept"):
		show_popup(PopupKind.ARE_YOU_SURE, Choice.YES)
	else:
		# Escape on the Offer screen at run start does nothing: a run needs a ship.
		return
	get_viewport().set_input_as_handled()
	terminal.queue_redraw()


func handle_popup_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left"):
		selected_button = Choice.YES
	elif event.is_action_pressed("ui_right"):
		selected_button = Choice.NO
	elif event.is_action_pressed("ui_accept"):
		answer(selected_button == Choice.YES)
	elif event.is_action_pressed("ui_cancel"):
		answer(false)
	else:
		return
	get_viewport().set_input_as_handled()
	terminal.queue_redraw()


# Browsing wraps around at both ends.
func browse(step: int) -> void:
	offer_index = posmod(offer_index + step, ShipType.ALL.size())


func open() -> void:
	showing = true
	visible = true
	popup = PopupKind.NONE
	get_tree().paused = true
	terminal.queue_redraw()


func close() -> void:
	showing = false
	visible = false
	popup = PopupKind.NONE
	get_tree().paused = false


func show_popup(kind: PopupKind, default_button: Choice) -> void:
	popup = kind
	selected_button = default_button


func answer(yes: bool) -> void:
	if yes:
		close()
		lander.become(selected_offer())
		lander.start_docked()
	else:
		popup = PopupKind.NONE


# Observable state

func selected_offer() -> ShipType:
	return ShipType.ALL[offer_index]


func in_service_shown() -> bool:
	return showing and selected_offer() == in_service


func offer_indicator() -> String:
	return "< %d/%d >" % [offer_index + 1, ShipType.ALL.size()]


# The text the selected Offer shows, with ratings written as blocks.
func offer_lines() -> PackedStringArray:
	var type := selected_offer()
	var lines := PackedStringArray([
		type.name.to_upper(), type.flavour.to_upper(),
		"TANK " + kg(type.tank), "DRY MASS " + kg(type.default_dry_mass),
		"MAX WEIGHT " + kg(type.maximum_weight),
		"THRUST " + blocks(type.thrust_rating), "HANDLING " + blocks(type.handling_rating),
		offer_indicator(),
	])
	if in_service_shown():
		lines.append(IN_SERVICE_TEXT)
	return lines


# The wireframe picture's outline: the ship type's hull.
func offer_picture() -> PackedVector2Array:
	return selected_offer().hull


static func kg(value: float) -> String:
	return Hud.format_kg(value).to_upper()


static func blocks(rating: int) -> String:
	return FULL_BLOCK.repeat(rating) + EMPTY_BLOCK.repeat(RATING_BLOCKS - rating)


# Drawing

func draw_terminal() -> void:
	var screen := Rect2(Vector2.ZERO, terminal.size)
	terminal.draw_rect(screen, BLACK)
	var frame := screen.grow(-MARGIN)
	terminal.draw_rect(frame, GREEN, false, BORDER_WIDTH)
	var inner := frame.grow(-PADDING)

	draw_text(HEADER, Vector2(inner.position.x, inner.position.y + HEADER_SIZE), HEADER_SIZE)
	var rule_y := inner.position.y + HEADER_SIZE + LINE_GAP
	terminal.draw_line(Vector2(frame.position.x, rule_y), Vector2(frame.end.x, rule_y), GREEN, LINE_WIDTH)
	draw_text(offer_indicator(), Vector2(inner.position.x, rule_y + LINE_GAP + TEXT_SIZE), TEXT_SIZE,
		inner.size.x, HORIZONTAL_ALIGNMENT_RIGHT)

	var hint_y := inner.end.y
	var hint_rule_y := hint_y - HINT_SIZE - LINE_GAP
	terminal.draw_line(Vector2(frame.position.x, hint_rule_y), Vector2(frame.end.x, hint_rule_y), GREEN, LINE_WIDTH)
	draw_key_hint(Vector2(inner.position.x, hint_y))

	var offer_area := Rect2(inner.position.x, rule_y + LINE_GAP, inner.size.x, hint_rule_y - rule_y - 2.0 * LINE_GAP)
	draw_offer(offer_area)
	if popup != PopupKind.NONE:
		draw_popup(screen)
	draw_scanlines(screen)


func draw_offer(area: Rect2) -> void:
	var type := selected_offer()
	var half := area.size.x / 2.0
	var picture_box := Rect2(area.position, Vector2(half, area.size.y))
	draw_wireframe(offer_picture(), picture_box)

	var x := area.position.x + half
	var width := half
	var y := area.get_center().y - 4.0 * STAT_SIZE - 2.0 * LINE_GAP
	y += NAME_SIZE
	draw_text(type.name.to_upper(), Vector2(x, y), NAME_SIZE, width)
	if in_service_shown():
		var name_width := FONT.get_string_size(type.name.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_SIZE).x
		draw_in_service_tag(Vector2(x + name_width + LINE_GAP, y - NAME_SIZE / 2.0 - TEXT_SIZE / 2.0 - 4.0))
	y += LINE_GAP + TEXT_SIZE
	draw_text(type.flavour.to_upper(), Vector2(x, y), TEXT_SIZE, width)
	y += 2.0 * LINE_GAP
	for stat: Array in [["TANK", type.tank], ["DRY MASS", type.default_dry_mass], ["MAX WEIGHT", type.maximum_weight]]:
		y += STAT_SIZE + LINE_GAP
		draw_text(stat[0], Vector2(x, y), STAT_SIZE, RATING_LABEL_WIDTH)
		draw_text(kg(stat[1]), Vector2(x + RATING_LABEL_WIDTH, y), STAT_SIZE, width - RATING_LABEL_WIDTH)
	y += LINE_GAP
	for rating: Array in [["THRUST", type.thrust_rating], ["HANDLING", type.handling_rating]]:
		y += STAT_SIZE + LINE_GAP
		draw_text(rating[0], Vector2(x, y), STAT_SIZE, RATING_LABEL_WIDTH)
		draw_rating(rating[1], Vector2(x + RATING_LABEL_WIDTH, y - BLOCK_SIZE.y))


func draw_wireframe(outline: PackedVector2Array, box: Rect2) -> void:
	var bounds := Rect2(outline[0], Vector2.ZERO)
	for point in outline:
		bounds = bounds.expand(point)
	var fit := box.size * PICTURE_SHARE * 2.0 / bounds.size
	var scale := minf(fit.x, fit.y)
	var points := PackedVector2Array()
	for point in outline:
		points.append(box.get_center() + (point - bounds.get_center()) * scale)
	points.append(points[0])
	terminal.draw_polyline(points, GREEN, BORDER_WIDTH)


func draw_rating(rating: int, top_left: Vector2) -> void:
	for i in RATING_BLOCKS:
		var block := Rect2(top_left + Vector2(i * (BLOCK_SIZE.x + BLOCK_GAP), 0.0), BLOCK_SIZE)
		if i < rating:
			terminal.draw_rect(block, GREEN)
		else:
			terminal.draw_rect(block, DIM_GREEN, false, LINE_WIDTH)


func draw_in_service_tag(top_left: Vector2) -> void:
	var text_size := FONT.get_string_size(IN_SERVICE_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE)
	var tag := Rect2(top_left, text_size + Vector2(16, 8))
	terminal.draw_rect(tag, GREEN)
	draw_text(IN_SERVICE_TEXT, top_left + Vector2(8, 4 + TEXT_SIZE), TEXT_SIZE, -1, HORIZONTAL_ALIGNMENT_LEFT, BLACK)


# Silkscreen has no arrow glyphs, so the hint's arrows are drawn as triangles.
func draw_key_hint(baseline_left: Vector2) -> void:
	var words := KEY_HINT.replace("←", "").replace("→", "").strip_edges()
	var arrows_width := HINT_ARROW_SIZE * 3.0 + LINE_GAP
	var words_width := FONT.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, HINT_SIZE).x
	var x := baseline_left.x + (terminal.size.x - 2.0 * (MARGIN + PADDING) - arrows_width - words_width) / 2.0
	var mid_y := baseline_left.y - HINT_SIZE / 2.0
	var h := HINT_ARROW_SIZE / 2.0
	terminal.draw_colored_polygon(PackedVector2Array([
		Vector2(x, mid_y), Vector2(x + HINT_ARROW_SIZE, mid_y - h), Vector2(x + HINT_ARROW_SIZE, mid_y + h)]), GREEN)
	x += HINT_ARROW_SIZE * 1.5
	terminal.draw_colored_polygon(PackedVector2Array([
		Vector2(x + HINT_ARROW_SIZE, mid_y), Vector2(x, mid_y - h), Vector2(x, mid_y + h)]), GREEN)
	x += HINT_ARROW_SIZE * 1.5 + LINE_GAP
	draw_text(words, Vector2(x, baseline_left.y), HINT_SIZE)


func draw_popup(screen: Rect2) -> void:
	var box := Rect2(screen.get_center() - POPUP_SIZE / 2.0, POPUP_SIZE)
	terminal.draw_rect(box, BLACK)
	terminal.draw_rect(box, GREEN, false, BORDER_WIDTH)
	draw_text(ARE_YOU_SURE_TEXT, Vector2(box.position.x, box.position.y + PADDING + STAT_SIZE), STAT_SIZE,
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
