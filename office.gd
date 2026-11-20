class_name Office
extends CanvasLayer
# The player's Office: a full-window Terminal with a main screen of tiles opening the Shipyard,
# the Hangar (and each owned ship's Ship page), Transport offers and the Bank account. It pauses
# the world while showing. R after a crash or while Stranded opens it by Recovery (`recover()`), and it can't be left
# while the ship in service is a Wreck (`leave_reason()`); the main screen then tags it WRECKED. Buying, selling and the Ship swap go through the Hangar's and the
# Economy's named operations; it never edits an owned ship itself.
#
# The Office: resetting the mission rows from the planet clock on every opening and starting the
# mission at the chosen destination in the chosen start period at START LOADING (or START, a free
# flight), the Terminal's colours (green, dim green and black, white and red for values, and faint
# green list tints, alternating by row), the header with the balance top right (red below €0), the
# Terminal's screens (the main screen's tiles; `ShipyardScreen`, `HangarScreen`,
# `TransportOffersScreen` and `BankAccountScreen` handle the others), the YES/NO popups ("ARE YOU
# SURE?" for a Transport offer, "REMOVE CONTRACT?", "CANCEL MISSION?", "ENTER THE OFFICE?", also
# while delivering, and `ask()`'s confirms naming a thing and its price in white, with an optional
# red warning line, `popup_warning()`), a short notice
# line (`show_notice()`: a purchase done, or a blocked item's red reason), the building blocks the
# screens draw with (`draw_action()` for a button that may be blocked, the wireframe, rating
# blocks, the IN SERVICE tag), pausing the world while showing, and drawing the Terminal.
# Attached to `Office`.

enum Screen { MAIN, SHIPYARD, HANGAR, SHIP_PAGE, TRANSPORT_OFFERS, BANK_ACCOUNT }
# CONFIRM is `ask()`'s: its question and price, and what Yes does.
enum PopupKind { NONE, CONFIRM, ENTER_OFFICE, ACCEPT_OFFER, REMOVE_CONTRACT, CANCEL_MISSION }
enum Choice { YES, NO }

const HEADER := "ORBITAL FREIGHT CO. // "
# A hint starting with ← → gets its arrows drawn: Silkscreen has no arrow glyphs.
const KEY_HINTS := {
	Screen.MAIN: "← → MOVE   RETURN OPEN   ESC LEAVE",
	Screen.SHIPYARD: "← → BROWSE   RETURN BUY   ESC BACK",
	Screen.HANGAR: "UP DOWN MOVE   RETURN OPEN   ESC BACK",
	Screen.SHIP_PAGE: "UP DOWN MOVE   RETURN SELECT   ESC BACK",
	Screen.TRANSPORT_OFFERS: "← → COLUMNS   UP DOWN MOVE   RETURN SELECT   ESC BACK",
	Screen.BANK_ACCOUNT: "UP DOWN MOVE   RETURN OPEN   ESC BACK",
}
const ARROWS := "← →"
const ARE_YOU_SURE_TEXT := "ARE YOU SURE?"
const ENTER_OFFICE_TEXT := "ENTER THE OFFICE?"
const REMOVE_CONTRACT_TEXT := "REMOVE CONTRACT?"
const CANCEL_MISSION_TEXT := "CANCEL MISSION?"
const IN_SERVICE_TEXT := "IN SERVICE"
const WRECKED_TEXT := "WRECKED"
# Why the Office can't be left: the ship in service can't fly.
const WRECK_IN_SERVICE := "WRECK IN SERVICE: REPAIR IT OR PUT ANOTHER SHIP IN SERVICE"
const VERSION_PREFIX := "V"
# The main screen's tiles, in order: each opens the screen it names.
const TILES: Array[Screen] = [Screen.SHIPYARD, Screen.HANGAR, Screen.TRANSPORT_OFFERS, Screen.BANK_ACCOUNT]
const SCREEN_TITLES := {
	Screen.MAIN: "OFFICE",
	Screen.SHIPYARD: "SHIPYARD",
	Screen.HANGAR: "HANGAR",
	Screen.TRANSPORT_OFFERS: "TRANSPORT OFFERS",
	Screen.BANK_ACCOUNT: "BANK ACCOUNT",
}
# Ratings are drawn as this many blocks.
const RATING_BLOCKS := 5
# Fuel is shown in litres: this many kg to the litre.
const KG_PER_LITRE := 0.8
# Seconds the notice line shows.
const NOTICE_TIME := 2.5

const FONT := preload("res://fonts/Silkscreen-Regular.ttf")
const Hud := preload("res://hud.gd")

const GREEN := Color(0.25, 1.0, 0.4)
const DIM_GREEN := Color(0.25, 1.0, 0.4, 0.25)
const BLACK := Color.BLACK
# Values next to green labels, and values over a limit.
const WHITE := Color(0.9, 1.0, 0.92)
const DIM_WHITE := Color(0.9, 1.0, 0.92, 0.25)
const RED := Color(1.0, 0.3, 0.25)
# Faint list tints: alternating rows, and open details a little stronger.
const ROW_TINT_LIGHT := Color(0.25, 1.0, 0.4, 0.08)
const ROW_TINT_DARK := Color(0.25, 1.0, 0.4, 0.04)
const DETAILS_TINT := Color(0.25, 1.0, 0.4, 0.14)
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
const HINT_ARROW_SIZE := 12.0
# Padding around the IN SERVICE tag's text.
const TAG_PADDING := Vector2(8, 4)
# Share of the picture box's width and height the wireframe may fill.
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

# The widest a tile gets; narrower when the row wouldn't fit. A label wider than its tile wraps
# at its space.
const TILE_SIZE := Vector2(300, 180)
const TILE_GAP := 40.0
const TILE_TEXT_INSET := 16.0

const POPUP_SIZE := Vector2(440, 200)
const POPUP_BUTTON_SIZE := Vector2(120, 44)
const POPUP_BUTTON_GAP := 48.0

var showing := false
var screen := Screen.MAIN
var tile_index := 0
var popup := PopupKind.NONE
var selected_button := Choice.YES
# A CONFIRM popup's question (with %s where its price goes, white), price, and what Yes does.
var question := ""
var question_price := ""
var on_yes := Callable()
# A CONFIRM popup's red line under the question, such as THIS LEAVES YOU AT -€700, or "".
var question_warning := ""
var notice_text := ""
var notice_red := false
var notice_left := 0.0
# Whether the Terminal is powering on or off. Office input is ignored meanwhile.
var powering := false
# How far the Terminal's picture is powered on: 0 is off, 1 fully on.
var power := 1.0
var shipyard: ShipyardScreen
var hangar_screen: HangarScreen
var transport_offers: TransportOffersScreen
var bank_account: BankAccountScreen

@onready var lander: Lander = $"../Lander"
@onready var hangar: Hangar = $"../Hangar"
@onready var economy: Economy = $"../Economy"
@onready var clock: PlanetClock = $"../PlanetClock"
@onready var terminal: Control = $Terminal


func _ready() -> void:
	shipyard = ShipyardScreen.new(self, hangar, economy)
	hangar_screen = HangarScreen.new(self, hangar, economy)
	transport_offers = TransportOffersScreen.new(self, economy)
	bank_account = BankAccountScreen.new(self, economy)
	terminal.draw.connect(draw_terminal)
	lander.docked_at_station.connect(ask_to_enter)
	lander.recovery_requested.connect(recover)
	open()


# The Transport offers' countdowns tick every second; open details grow open.
func _process(delta: float) -> void:
	transport_offers.tick(delta)
	bank_account.tick(delta)
	if notice_left > 0.0:
		notice_left = maxf(notice_left - delta, 0.0)
		terminal.queue_redraw()
	if showing and screen in [Screen.TRANSPORT_OFFERS, Screen.BANK_ACCOUNT]:
		terminal.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if powering:
		return
	if popup != PopupKind.NONE:
		handle_popup_input(event)
	elif not showing:
		return
	elif screen == Screen.MAIN:
		handle_main_input(event)
	elif screen == Screen.TRANSPORT_OFFERS and transport_offers.handle_input(event):
		handled()
	elif screen == Screen.BANK_ACCOUNT and bank_account.handle_input(event):
		handled()
	elif screen == Screen.SHIPYARD and shipyard.handle_input(event):
		handled()
	elif screen in [Screen.HANGAR, Screen.SHIP_PAGE] and hangar_screen.handle_input(event):
		handled()
	elif event.is_action_pressed("ui_cancel"):
		screen = Screen.MAIN
		notice_left = 0.0
		handled()


func handle_main_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_up"):
		tile_index = maxi(tile_index - 1, 0)
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("ui_down"):
		tile_index = mini(tile_index + 1, TILES.size() - 1)
	elif event.is_action_pressed("ui_accept"):
		open_screen(TILES[tile_index])
	elif event.is_action_pressed("ui_cancel"):
		# Leaves the ship Docked as it is; one held since docking refuels after the usual delay.
		if leave_reason() != "":
			show_notice(leave_reason(), true)
		else:
			power_off(lander.release)
	else:
		return
	handled()


func handled() -> void:
	get_viewport().set_input_as_handled()
	terminal.queue_redraw()


# The Shipyard opens on the ship type of the ship in service, Transport offers on the offer list.
func open_screen(which: Screen) -> void:
	screen = which
	notice_left = 0.0
	if which == Screen.SHIPYARD:
		shipyard.open()
	elif which == Screen.TRANSPORT_OFFERS:
		transport_offers.focus = TransportOffersScreen.Column.OFFERS


func open_ship_page(ship: OwnedShip) -> void:
	open_screen(Screen.SHIP_PAGE)
	hangar_screen.open_page(ship)


# Asks YES/NO (Yes selected) with this question, its %s replaced by the price in white (none when
# the price is ""), and any warning in red under it; Yes calls on_yes_call.
func ask(text: String, price: String, on_yes_call: Callable, warning := "") -> void:
	question = text
	question_price = price
	on_yes = on_yes_call
	question_warning = warning
	show_popup(PopupKind.CONFIRM, Choice.YES)


# Shows a short line under the screen for NOTICE_TIME: white, or red for a blocked item's reason.
func show_notice(text: String, red := false) -> void:
	notice_text = text
	notice_red = red
	notice_left = NOTICE_TIME


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
	handled()


func open() -> void:
	showing = true
	visible = true
	screen = Screen.MAIN
	popup = PopupKind.NONE
	notice_left = 0.0
	transport_offers.reset_mission_rows(clock)
	get_tree().paused = true
	power_to(1.0)


# Recovery, R after a crash or while Stranded: the ship (a Wreck after a crash) goes back Docked at
# the station, still in service, and the Office opens on its main screen. Nothing reloads: the
# clock, location and offers carry on, and the stop was already settled when it happened.
func recover() -> void:
	hangar.recover()
	open()


# Powers the Terminal off, closes the Office, then calls after_closing: the flight
# view shows only once the effect is over.
func power_off(after_closing: Callable) -> void:
	popup = PopupKind.NONE
	power_to(0.0, func() -> void:
		close()
		after_closing.call())


# Once the Terminal is off, the mission starts at the chosen destination in the chosen start
# period: the local time is re-rolled within it every time. With Contracts, loading starts over
# the flight view; without, it's a free flight: the ship is released, free to undock at once.
func start_mission() -> void:
	if leave_reason() != "":
		show_notice(leave_reason(), true)
		return
	var destination := transport_offers.destination
	var period := transport_offers.start_period
	var free_flight := economy.contracts.is_empty()
	power_off(func() -> void:
		clock.start_mission(destination, period)
		if free_flight:
			lander.release()
		else:
			economy.start_loading())


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
	visible = false
	popup = PopupKind.NONE
	get_tree().paused = false


# Docking asks whether to enter the Office, over the flight view, once the ship is upright. The ship is held
# until the ship is released: by No here, or by leaving the Office. A delivering ship is asked
# too, so the mission can be cancelled.
func ask_to_enter() -> void:
	if economy.phase != Economy.Phase.NONE and not economy.mission_under_way():
		return
	lander.hold()
	visible = true
	show_popup(PopupKind.ENTER_OFFICE, Choice.NO)
	terminal.queue_redraw()


func show_popup(kind: PopupKind, default_button: Choice) -> void:
	popup = kind
	selected_button = default_button


func answer(choice: Choice) -> void:
	match [popup, choice]:
		[PopupKind.ENTER_OFFICE, Choice.YES]:
			open()
		[PopupKind.ENTER_OFFICE, Choice.NO]:
			# Docked as before: the ship refuels after the usual delay.
			close()
			lander.release()
		[PopupKind.CONFIRM, Choice.YES]:
			popup = PopupKind.NONE
			on_yes.call()
		[PopupKind.CONFIRM, Choice.NO], [PopupKind.ACCEPT_OFFER, Choice.NO], \
				[PopupKind.REMOVE_CONTRACT, Choice.NO], [PopupKind.CANCEL_MISSION, Choice.NO]:
			popup = PopupKind.NONE
		[PopupKind.ACCEPT_OFFER, Choice.YES]:
			popup = PopupKind.NONE
			transport_offers.confirm_accept()
		[PopupKind.REMOVE_CONTRACT, Choice.YES]:
			popup = PopupKind.NONE
			transport_offers.confirm_remove()
		[PopupKind.CANCEL_MISSION, Choice.YES]:
			popup = PopupKind.NONE
			transport_offers.confirm_cancel()


# Observable state

func tile_labels() -> PackedStringArray:
	var labels := PackedStringArray()
	for tile: Screen in TILES:
		labels.append(SCREEN_TITLES[tile])
	return labels


# Why the player can't leave the Office (Escape on the main screen, START, START LOADING), or "":
# the ship in service is a Wreck.
func leave_reason() -> String:
	return WRECK_IN_SERVICE if hangar.in_service.is_wreck() else ""


# The main screen's line under the tiles: the ship in service's name and its WRECKED tag while
# it's a Wreck; nothing otherwise.
func main_lines() -> PackedStringArray:
	if not hangar.in_service.is_wreck():
		return PackedStringArray()
	return PackedStringArray([hangar.in_service.name, WRECKED_TEXT])


func selected_tile() -> String:
	return SCREEN_TITLES[TILES[tile_index]]


func screen_title() -> String:
	if screen == Screen.SHIP_PAGE:
		return "%s // %s" % [SCREEN_TITLES[Screen.HANGAR], hangar_screen.ship.name]
	return SCREEN_TITLES[screen]


func balance_text() -> String:
	return Economy.eur(economy.balance)


func balance_red() -> bool:
	return economy.balance < 0


# The notice line showing, or "".
func notice() -> String:
	return notice_text if notice_left > 0.0 else ""


# Alternating faint list row tints, lighter on even rows.
static func row_tint(index: int) -> Color:
	return ROW_TINT_LIGHT if index % 2 == 0 else ROW_TINT_DARK


static func kg(value: float) -> String:
	return Hud.format_kg(value).to_upper()


static func to_litres(kg_of_fuel: float) -> float:
	return kg_of_fuel / KG_PER_LITRE


# Fuel in kg written in litres, as 6 250 L.
static func litres(kg_of_fuel: float) -> String:
	return Hud.group_thousands(roundi(to_litres(kg_of_fuel))) + " L"


# Drawing

func draw_terminal() -> void:
	var view := Rect2(Vector2.ZERO, terminal.size)
	if not showing:
		# The Enter-the-Office popup sits over the flight view, without the Terminal behind it.
		if popup != PopupKind.NONE:
			draw_popup(view)
		return
	terminal.draw_rect(view, BLACK)
	if power <= LINE_SHARE:
		draw_power_line(view, power / LINE_SHARE)
		return
	# The picture grows from (or shrinks to) the bright line across the middle.
	var picture_scale := maxf(ease((power - LINE_SHARE) / (1.0 - LINE_SHARE), POWER_EASE), MIN_PICTURE_SCALE)
	var centre := view.get_center()
	var scale := Vector2(1.0, picture_scale)
	terminal.draw_set_transform(centre - centre * scale, 0.0, scale)
	draw_screen(view)
	if picture_scale < 1.0:
		terminal.draw_rect(view, Color(GLOW, GLOW_ALPHA * (1.0 - picture_scale)))
	terminal.draw_set_transform(Vector2.ZERO)
	draw_scanlines(view)


# The first or last moment of the effect: a dot that stretches into a line across
# the screen as `stretch` goes from 0 to 1.
func draw_power_line(view: Rect2, stretch: float) -> void:
	var centre := view.get_center()
	var half_width := view.size.x / 2.0 * ease(stretch, POWER_EASE)
	if half_width < DOT_RADIUS:
		terminal.draw_circle(centre, DOT_RADIUS, GLOW)
	else:
		terminal.draw_line(centre - Vector2(half_width, 0.0), centre + Vector2(half_width, 0.0), GLOW, GLOW_WIDTH)


# The Terminal's picture: frame, header, the current screen, key hint and any popup.
func draw_screen(view: Rect2) -> void:
	var frame := view.grow(-MARGIN)
	terminal.draw_rect(frame, GREEN, false, BORDER_WIDTH)
	var inner := frame.grow(-PADDING)

	var header_baseline := Vector2(inner.position.x, inner.position.y + HEADER_SIZE)
	draw_text(HEADER + screen_title(), header_baseline, HEADER_SIZE)
	draw_text(balance_text(), header_baseline, HEADER_SIZE, inner.size.x, HORIZONTAL_ALIGNMENT_RIGHT,
		RED if balance_red() else WHITE)
	var rule_y := inner.position.y + HEADER_SIZE + LINE_GAP
	terminal.draw_line(Vector2(frame.position.x, rule_y), Vector2(frame.end.x, rule_y), GREEN, LINE_WIDTH)

	var hint_y := inner.end.y
	var hint_rule_y := hint_y - HINT_SIZE - LINE_GAP
	terminal.draw_line(Vector2(frame.position.x, hint_rule_y), Vector2(frame.end.x, hint_rule_y), GREEN, LINE_WIDTH)
	draw_key_hint(Vector2(inner.position.x, hint_y))
	draw_text(version_text(), Vector2(inner.position.x, hint_y), HINT_SIZE, inner.size.x,
		HORIZONTAL_ALIGNMENT_RIGHT, DIM_GREEN)

	var body := body_area(view)
	match screen:
		Screen.MAIN:
			draw_tiles(body)
			draw_main_lines(body)
		Screen.SHIPYARD:
			shipyard.draw(body)
		Screen.HANGAR, Screen.SHIP_PAGE:
			hangar_screen.draw(body)
		Screen.TRANSPORT_OFFERS:
			transport_offers.draw(body)
		Screen.BANK_ACCOUNT:
			bank_account.draw(body)
	if notice() != "":
		draw_text(notice(), Vector2(body.position.x, body.end.y), TEXT_SIZE, body.size.x, HORIZONTAL_ALIGNMENT_LEFT,
			RED if notice_red else WHITE)
	if popup != PopupKind.NONE:
		draw_popup(view)


# The area between the header's and the key hint's rules, where the current screen draws.
func body_area(view: Rect2) -> Rect2:
	var inner := view.grow(-MARGIN - PADDING)
	var rule_y := inner.position.y + HEADER_SIZE + LINE_GAP
	var hint_rule_y := inner.end.y - HINT_SIZE - LINE_GAP
	return Rect2(inner.position.x, rule_y + LINE_GAP, inner.size.x, hint_rule_y - rule_y - 2.0 * LINE_GAP)


# The main screen's tiles in a row across the middle; the selected one is inverted.
func draw_tiles(area: Rect2) -> void:
	var tile_width := minf(TILE_SIZE.x, (area.size.x - (TILES.size() - 1) * TILE_GAP) / TILES.size())
	var row_width := TILES.size() * tile_width + (TILES.size() - 1) * TILE_GAP
	var x := area.get_center().x - row_width / 2.0
	var labels := tile_labels()
	for i in TILES.size():
		var tile := Rect2(Vector2(x, area.get_center().y - TILE_SIZE.y / 2.0), Vector2(tile_width, TILE_SIZE.y))
		var selected := i == tile_index
		if selected:
			terminal.draw_rect(tile, GREEN)
		else:
			terminal.draw_rect(tile, GREEN, false, BORDER_WIDTH)
		var lines := PackedStringArray([labels[i]])
		if text_width(labels[i], STAT_SIZE) > tile_width - 2.0 * TILE_TEXT_INSET:
			lines = labels[i].split(" ", false, 1)
		var y := tile.get_center().y + STAT_SIZE / 2.0 - (lines.size() - 1) * (STAT_SIZE + LINE_GAP) / 2.0
		for line in lines:
			draw_text(line, Vector2(tile.position.x, y), STAT_SIZE, tile.size.x, HORIZONTAL_ALIGNMENT_CENTER,
				BLACK if selected else GREEN)
			y += STAT_SIZE + LINE_GAP
		x += tile_width + TILE_GAP


# Under the tiles, centred: the ship in service's name in white and its red WRECKED tag.
func draw_main_lines(area: Rect2) -> void:
	var lines := main_lines()
	if lines.is_empty():
		return
	var name_text := lines[0] + " "
	var tag_size := FONT.get_string_size(lines[1], HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE) + 2.0 * TAG_PADDING
	var width := text_width(name_text, STAT_SIZE) + tag_size.x
	var baseline := Vector2(area.get_center().x - width / 2.0,
		area.get_center().y + TILE_SIZE.y / 2.0 + TILE_GAP + STAT_SIZE)
	draw_text(name_text, baseline, STAT_SIZE, -1.0, HORIZONTAL_ALIGNMENT_LEFT, WHITE)
	draw_tag(lines[1], baseline + Vector2(text_width(name_text, STAT_SIZE), -STAT_SIZE / 2.0 - tag_size.y / 2.0), RED)


# A button the player may not be able to take: its label and a price, inverted while selected.
# A blocked one is dimmed, with its red reason under it; an unaffordable price is red.
func draw_action(button: Rect2, label: String, price: String, selected: bool, reason := "", price_red := false) -> void:
	var blocked := reason != ""
	var lit := DIM_GREEN if blocked else GREEN
	if selected:
		terminal.draw_rect(button, lit)
	else:
		terminal.draw_rect(button, lit, false, LINE_WIDTH)
	var label_color := BLACK if selected else lit
	var price_color := RED if price_red else BLACK if selected else DIM_WHITE if blocked else WHITE
	var width := text_width(label, TEXT_SIZE) + text_width(price, TEXT_SIZE)
	var baseline := Vector2(button.get_center().x - width / 2.0, button.get_center().y + TEXT_SIZE / 2.0)
	draw_text(label, baseline, TEXT_SIZE, -1.0, HORIZONTAL_ALIGNMENT_LEFT, label_color)
	draw_text(price, baseline + Vector2(text_width(label, TEXT_SIZE), 0.0), TEXT_SIZE, -1.0,
		HORIZONTAL_ALIGNMENT_LEFT, price_color)
	if blocked:
		draw_text(reason, Vector2(button.position.x, button.end.y + LINE_GAP + TEXT_SIZE), TEXT_SIZE, -1.0,
			HORIZONTAL_ALIGNMENT_LEFT, RED)


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
	draw_tag(IN_SERVICE_TEXT, top_left, GREEN)


# A filled tag with black text, such as IN SERVICE (green) or WRECKED (red).
func draw_tag(text: String, top_left: Vector2, color: Color) -> void:
	var text_size := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE)
	terminal.draw_rect(Rect2(top_left, text_size + 2.0 * TAG_PADDING), color)
	draw_text(text, top_left + TAG_PADDING + Vector2(0, TEXT_SIZE), TEXT_SIZE, -1, HORIZONTAL_ALIGNMENT_LEFT, BLACK)


# Silkscreen has no arrow glyphs, so the hint's arrows are drawn as triangles.
func draw_key_hint(baseline_left: Vector2) -> void:
	var hint: String = KEY_HINTS[screen]
	var words := hint.trim_prefix(ARROWS).strip_edges()
	var has_arrows := hint.begins_with(ARROWS)
	var arrows_width := HINT_ARROW_SIZE * 3.0 + LINE_GAP if has_arrows else 0.0
	var x := baseline_left.x + (terminal.size.x - 2.0 * (MARGIN + PADDING) - arrows_width
		- text_width(words, HINT_SIZE)) / 2.0
	if not has_arrows:
		draw_text(words, Vector2(x, baseline_left.y), HINT_SIZE)
		return
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
	match popup:
		PopupKind.CONFIRM:
			return question % question_price if question_price != "" else question
		PopupKind.ENTER_OFFICE:
			return ENTER_OFFICE_TEXT
		PopupKind.REMOVE_CONTRACT:
			return REMOVE_CONTRACT_TEXT
		PopupKind.CANCEL_MISSION:
			return CANCEL_MISSION_TEXT
	return ARE_YOU_SURE_TEXT


# A CONFIRM popup's red warning, or "".
func popup_warning() -> String:
	return question_warning if popup == PopupKind.CONFIRM else ""


func draw_popup(view: Rect2) -> void:
	var text := popup_text()
	var warning := popup_warning()
	var size := Vector2(maxf(POPUP_SIZE.x, maxf(text_width(text, STAT_SIZE), text_width(warning, TEXT_SIZE))
		+ 2.0 * PADDING), POPUP_SIZE.y)
	var box := Rect2(view.get_center() - size / 2.0, size)
	terminal.draw_rect(box, BLACK)
	terminal.draw_rect(box, GREEN, false, BORDER_WIDTH)
	# The question green and its price white, centred together.
	var parts := PackedStringArray([text])
	if popup == PopupKind.CONFIRM and question_price != "":
		parts = question.split("%s")
		parts.insert(1, question_price)
	var text_x := box.get_center().x - text_width(text, STAT_SIZE) / 2.0
	for i in parts.size():
		draw_text(parts[i], Vector2(text_x, box.position.y + PADDING + STAT_SIZE), STAT_SIZE, -1.0,
			HORIZONTAL_ALIGNMENT_LEFT, WHITE if parts.size() > 1 and i == 1 else GREEN)
		text_x += text_width(parts[i], STAT_SIZE)
	if warning != "":
		draw_text(warning, Vector2(box.position.x, box.position.y + PADDING + STAT_SIZE + LINE_GAP + TEXT_SIZE),
			TEXT_SIZE, box.size.x, HORIZONTAL_ALIGNMENT_CENTER, RED)
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


func draw_scanlines(view: Rect2) -> void:
	var y := 0.0
	while y < view.size.y:
		terminal.draw_line(Vector2(0.0, y), Vector2(view.size.x, y), SCANLINE_COLOR, 1.0)
		y += SCANLINE_SPACING


func draw_text(text: String, baseline: Vector2, font_size: int, width := -1.0,
		alignment := HORIZONTAL_ALIGNMENT_LEFT, color := GREEN) -> void:
	terminal.draw_string(FONT, baseline, text, alignment, width, font_size, color)


# A label and its value after it on one line, green and white unless given.
func draw_label_value(label: String, value: String, baseline: Vector2, font_size: int, width := -1.0,
		label_color := GREEN, value_color := WHITE) -> void:
	var spaced := label + " "
	draw_text(spaced, baseline, font_size, width, HORIZONTAL_ALIGNMENT_LEFT, label_color)
	var label_width := text_width(spaced, font_size)
	draw_text(value, baseline + Vector2(label_width, 0.0), font_size, width - label_width if width >= 0.0 else -1.0,
		HORIZONTAL_ALIGNMENT_LEFT, value_color)


func text_width(text: String, font_size: int) -> float:
	return FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
