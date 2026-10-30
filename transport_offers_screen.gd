class_name TransportOffersScreen
extends RefCounted
# The Office's TRANSPORT OFFERS screen: input and drawing for the offer list in the left
# column. The Office owns the Terminal and calls this while the screen is showing.

# Share of the screen's width the offer list takes; the rest is left for the Contracts.
const LIST_SHARE := 0.6
const ROW_HEIGHT := 28.0
const ROW_PADDING := 6.0
const ACCEPT_TEXT := "ACCEPT"
const DETAIL_COLUMNS := 2
const ACCEPT_SIZE := Vector2(120, 32)

var office: Office
var economy: Economy
var selected_index := 0
# The offer whose details are open under its row, if any. Kept by offer, not row, so it
# stays with its offer while others above it expire.
var expanded: TransportOffer


func _init(owner: Office, owner_economy: Economy) -> void:
	office = owner
	economy = owner_economy


# Returns whether it used the event; Escape with no details open is left to the Office.
func handle_input(event: InputEvent) -> bool:
	follow_expanded()
	if event.is_action_pressed("ui_up"):
		move(-1)
	elif event.is_action_pressed("ui_down"):
		move(1)
	elif event.is_action_pressed("ui_accept"):
		# Return on the open details is ACCEPT, which comes with the Contracts.
		if expanded == null:
			expanded = economy.offers[selected_index]
	elif event.is_action_pressed("ui_cancel") and expanded != null:
		expanded = null
	else:
		return false
	return true


# Moving to another row closes the open details: only one offer's are open at a time.
func move(step: int) -> void:
	expanded = null
	selected_index = clampi(selected_index + step, 0, economy.offers.size() - 1)


# Keeps the selection on the expanded offer, and in range, as offers come and go.
func follow_expanded() -> void:
	if expanded != null and not expanded in economy.offers:
		expanded = null
	if expanded != null:
		selected_index = economy.offers.find(expanded)
	selected_index = clampi(selected_index, 0, economy.offers.size() - 1)


# Observable state

# The row whose details are open, or -1.
func expanded_row() -> int:
	follow_expanded()
	return economy.offers.find(expanded) if expanded != null else -1


# The open details' text, ending with the ACCEPT button; empty when none are open.
func details() -> PackedStringArray:
	follow_expanded()
	var lines := PackedStringArray()
	if expanded == null:
		return lines
	for detail: Array in detail_pairs(expanded):
		lines.append("%s %s" % detail)
	lines.append(ACCEPT_TEXT)
	return lines


# The offer's details as [label, text] pairs.
static func detail_pairs(offer: TransportOffer) -> Array[Array]:
	return [["PASSENGERS", str(offer.passengers)], ["CARGO", Office.kg(offer.cargo_mass)],
		["DEADLINE", countdown(offer.deadline)], ["TRADER", offer.trader.to_upper()],
		["VALUE", Economy.eur(offer.value())]]


func rows() -> PackedStringArray:
	var lines := PackedStringArray()
	for offer in economy.offers:
		lines.append(row_text(offer))
	return lines


# Per row, why the ship can't take that offer, or "" when it can.
func reasons() -> PackedStringArray:
	var lines := PackedStringArray()
	for offer in economy.offers:
		lines.append(economy.misfit_reason(offer).to_upper())
	return lines


static func row_text(offer: TransportOffer) -> String:
	return "#%03d %s %s %s" % [offer.number, offer.title.to_upper(), TransportOffer.KIND_LABELS[offer.kind()],
		countdown(offer.time_left)]


# Whole seconds as m:ss, counting a started second as a whole one.
static func countdown(seconds_left: float) -> String:
	var whole := maxi(ceili(seconds_left), 0)
	return "%d:%02d" % [whole / 60, whole % 60]


# Drawing

func draw(area: Rect2) -> void:
	follow_expanded()
	var list := Rect2(area.position, Vector2(area.size.x * LIST_SHARE, area.size.y))
	var y := list.position.y
	for i in economy.offers.size():
		var offer := economy.offers[i]
		var row := Rect2(list.position.x, y, list.size.x, ROW_HEIGHT)
		var selected := i == selected_index
		var reason := economy.misfit_reason(offer).to_upper()
		var lit := Office.GREEN if reason == "" else Office.DIM_GREEN
		if selected:
			office.terminal.draw_rect(row, lit)
		var color := Office.BLACK if selected else lit
		var baseline := Vector2(row.position.x + ROW_PADDING, row.get_center().y + Office.TEXT_SIZE / 2.0)
		var width := row.size.x - 2.0 * ROW_PADDING
		office.draw_text("#%03d %s" % [offer.number, offer.title.to_upper()], baseline, Office.TEXT_SIZE, width,
			HORIZONTAL_ALIGNMENT_LEFT, color)
		office.draw_text("%s   %s" % [TransportOffer.KIND_LABELS[offer.kind()], countdown(offer.time_left)],
			baseline, Office.TEXT_SIZE, width, HORIZONTAL_ALIGNMENT_RIGHT, color)
		y += ROW_HEIGHT
		if reason != "":
			office.draw_text(reason, Vector2(baseline.x, y + Office.TEXT_SIZE), Office.TEXT_SIZE, width,
				HORIZONTAL_ALIGNMENT_RIGHT, Office.DIM_GREEN)
			y += ROW_HEIGHT
		if offer == expanded:
			y = draw_details(offer, Vector2(baseline.x, y), width, reason == "")


# Draws the details in two columns under the row, then ACCEPT (dimmed when the offer doesn't
# fit); returns the y below them.
func draw_details(offer: TransportOffer, top_left: Vector2, width: float, fits: bool) -> float:
	var y := top_left.y
	var pairs := detail_pairs(offer)
	var column_width := width / DETAIL_COLUMNS
	for i in pairs.size():
		var x := top_left.x + (i % DETAIL_COLUMNS) * column_width
		if i % DETAIL_COLUMNS == 0:
			y += ROW_HEIGHT
		office.draw_text("%s %s" % pairs[i], Vector2(x, y), Office.TEXT_SIZE, column_width)
	var button := Rect2(Vector2(top_left.x, y + ROW_PADDING * 2.0), ACCEPT_SIZE)
	if fits:
		office.terminal.draw_rect(button, Office.GREEN)
	else:
		office.terminal.draw_rect(button, Office.DIM_GREEN, false, Office.LINE_WIDTH)
	office.draw_text(ACCEPT_TEXT, Vector2(button.position.x, button.get_center().y + Office.TEXT_SIZE / 2.0),
		Office.TEXT_SIZE, button.size.x, HORIZONTAL_ALIGNMENT_CENTER, Office.BLACK if fits else Office.DIM_GREEN)
	return button.end.y + ROW_PADDING * 2.0
