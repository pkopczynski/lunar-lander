class_name TransportOffersScreen
extends RefCounted
# The Office's TRANSPORT OFFERS screen: input and drawing for the offer list in the left
# column and the Contracts in the right one. The Office owns the Terminal and calls this
# while the screen is showing.

enum Column { OFFERS, CONTRACTS }

# Layout. LIST_SHARE is the share of the screen's width the offer list takes; the rest is
# left for the Contracts.
const LIST_SHARE := 0.6
const COLUMN_GAP := 32.0
const ROW_HEIGHT := 28.0
const ROW_PADDING := 6.0
const DETAIL_COLUMNS := 2
const ACCEPT_SIZE := Vector2(120, 32)
const START_LOADING_SIZE := Vector2(200, 32)
const NOTICE_PADDING := Vector2(8, 4)

# Text
const ACCEPT_TEXT := "ACCEPT"
const CONTRACTS_TEXT := "CONTRACTS"
const FUEL_LIMITED_LABEL := "FUEL LIMITED:"
const FUEL_LIMITED_NOTE := "FUEL LIMITED"
const START_LOADING_TEXT := "START LOADING"
const KG_SUFFIX := " KG"
const OFFER_EXPIRED_TEXT := "OFFER EXPIRED"

# Seconds a notice such as OFFER EXPIRED shows.
const NOTICE_TIME := 2.0

var office: Office
var economy: Economy
var focus := Column.OFFERS
var selected_index := 0
# The offer whose details are open under its row, if any. Kept by offer, not row, so it
# stays with its offer while others above it expire.
var expanded: TransportOffer
var notice_text := ""
var notice_left := 0.0


func _init(owner: Office, owner_economy: Economy) -> void:
	office = owner
	economy = owner_economy
	economy.offer_expired.connect(on_offer_expired)


func tick(delta: float) -> void:
	notice_left = maxf(notice_left - delta, 0.0)


# An offer expiring while its details or its ARE YOU SURE? are open closes them and says so.
func on_offer_expired(offer: TransportOffer) -> void:
	if offer != expanded:
		return
	expanded = null
	if office.popup == Office.PopupKind.ACCEPT_OFFER:
		office.popup = Office.PopupKind.NONE
	show_notice(OFFER_EXPIRED_TEXT)


func show_notice(text: String) -> void:
	notice_text = text
	notice_left = NOTICE_TIME


# Returns whether it used the event; Escape with no details open is left to the Office.
func handle_input(event: InputEvent) -> bool:
	follow_expanded()
	if event.is_action_pressed("ui_right"):
		# Only one thing is open at a time: leaving the list closes the details.
		expanded = null
		focus = Column.CONTRACTS
	elif event.is_action_pressed("ui_left"):
		focus = Column.OFFERS
	elif focus == Column.CONTRACTS:
		# START LOADING is the only button here. Escape is left to the Office.
		if event.is_action_pressed("ui_accept") and start_loading_enabled():
			office.start_loading()
		return event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_up") \
			or event.is_action_pressed("ui_down")
	elif event.is_action_pressed("ui_up"):
		move(-1)
	elif event.is_action_pressed("ui_down"):
		move(1)
	elif event.is_action_pressed("ui_accept"):
		if expanded == null:
			if not economy.offers.is_empty():
				expanded = economy.offers[selected_index]
		elif economy.misfit_reason(expanded) == "":
			office.show_popup(Office.PopupKind.ACCEPT_OFFER, Office.Choice.YES)
	elif event.is_action_pressed("ui_cancel") and expanded != null:
		expanded = null
	else:
		return false
	return true


# Yes on ARE YOU SURE?: the Economy checks again that the offer is still there and still fits.
func confirm_accept() -> void:
	if not economy.accept(expanded) and not expanded in economy.offers:
		show_notice(OFFER_EXPIRED_TEXT)
	expanded = null


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

# The notice showing, such as OFFER EXPIRED, or "".
func notice() -> String:
	return notice_text if notice_left > 0.0 else ""


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
		["DEADLINE", TransportOffer.countdown(offer.deadline)], ["TRADER", offer.trader.to_upper()],
		["VALUE", Economy.eur(offer.reward())]]


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


# The right column: CONTRACTS, then one line per Contract.
func contract_lines() -> PackedStringArray:
	var lines := PackedStringArray([CONTRACTS_TEXT])
	for contract in economy.contracts:
		lines.append(contract.label())
	return lines


# Under the Contracts: seats taken, cargo against the full-Tank cargo for the accepted
# passengers, and FUEL LIMITED (the fuel cap over the Tank) once the Load leaves less room
# than a full Tank, which is exactly when the cargo passes the full-Tank cargo.
func summary() -> PackedStringArray:
	var lines := PackedStringArray()
	for part in summary_parts():
		lines.append("%s %s" % [part[0], part[1]])
	return lines


# The summary lines whose value is red.
func red_summary_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	for part in summary_parts():
		if part[3] == Office.RED:
			lines.append("%s %s" % [part[0], part[1]])
	return lines


# Per row, the red note under a fitting offer that would leave less room than a full Tank
# on top of the Contracts, or "".
func red_notes() -> PackedStringArray:
	var lines := PackedStringArray()
	for offer in economy.offers:
		lines.append(red_note(offer))
	return lines


func red_note(offer: TransportOffer) -> String:
	if economy.misfit_reason(offer) != "" or not limits_fuel(economy.contract_load_mass() + offer.load_mass()):
		return ""
	return FUEL_LIMITED_NOTE


# The summary as [label, value, label colour, value colour].
func summary_parts() -> Array[Array]:
	var ship := economy.lander
	var passengers := economy.contract_passengers()
	var load_mass := economy.contract_load_mass()
	var fuel_limited := limits_fuel(load_mass)
	var parts: Array[Array] = [
		["PASSENGERS", "%d/%d" % [passengers, ship.ship_type.passenger_seats], Office.GREEN, Office.WHITE],
		["CARGO", kg_of(economy.contract_cargo(), ship.ship_type.full_tank_cargo(passengers)), Office.GREEN,
			Office.RED if fuel_limited else Office.WHITE]]
	if fuel_limited:
		parts.append([FUEL_LIMITED_LABEL, kg_of(ship.fuel_cap_for(load_mass), ship.ship_type.tank),
			Office.RED, Office.RED])
	return parts


func limits_fuel(load_mass: float) -> bool:
	var ship := economy.lander
	return ship.fuel_cap_for(load_mass) < ship.ship_type.tank


func start_loading_enabled() -> bool:
	return not economy.contracts.is_empty()


# Two masses as 2 500/8 000 KG.
static func kg_of(part: float, whole: float) -> String:
	return "%s/%s" % [Office.kg(part).trim_suffix(KG_SUFFIX), Office.kg(whole)]


static func row_text(offer: TransportOffer) -> String:
	return "%s %s %s" % [offer.label(), TransportOffer.KIND_LABELS[offer.kind()],
		TransportOffer.countdown(offer.time_left)]


# Drawing

func draw(area: Rect2) -> void:
	follow_expanded()
	var list := Rect2(area.position, Vector2(area.size.x * LIST_SHARE, area.size.y))
	var y := list.position.y
	for i in economy.offers.size():
		var offer := economy.offers[i]
		var row := Rect2(list.position.x, y, list.size.x, ROW_HEIGHT)
		# With focus on the Contracts, the list's row is outlined instead of inverted.
		var selected := i == selected_index and focus == Column.OFFERS
		var reason := economy.misfit_reason(offer).to_upper()
		var lit := Office.GREEN if reason == "" else Office.DIM_GREEN
		if selected:
			office.terminal.draw_rect(row, lit)
		elif i == selected_index:
			office.terminal.draw_rect(row, lit, false, Office.LINE_WIDTH)
		var color := Office.BLACK if selected else lit
		var baseline := Vector2(row.position.x + ROW_PADDING, row.get_center().y + Office.TEXT_SIZE / 2.0)
		var width := row.size.x - 2.0 * ROW_PADDING
		office.draw_text(offer.label(), baseline, Office.TEXT_SIZE, width,
			HORIZONTAL_ALIGNMENT_LEFT, color)
		office.draw_text("%s   %s" % [TransportOffer.KIND_LABELS[offer.kind()], TransportOffer.countdown(offer.time_left)],
			baseline, Office.TEXT_SIZE, width, HORIZONTAL_ALIGNMENT_RIGHT, color)
		y += ROW_HEIGHT
		if reason != "":
			office.draw_text(reason, Vector2(baseline.x, y + Office.TEXT_SIZE), Office.TEXT_SIZE, width,
				HORIZONTAL_ALIGNMENT_RIGHT, Office.DIM_GREEN)
			y += ROW_HEIGHT
		var note := red_note(offer)
		if note != "":
			office.draw_text(note, Vector2(baseline.x, y + Office.TEXT_SIZE), Office.TEXT_SIZE, width,
				HORIZONTAL_ALIGNMENT_RIGHT, Office.RED)
			y += ROW_HEIGHT
		if offer == expanded:
			y = draw_details(offer, Vector2(baseline.x, y), width, reason == "")
	if notice() != "":
		draw_notice(Vector2(list.position.x, list.end.y))
	var right_x := list.end.x + COLUMN_GAP
	draw_contracts(Rect2(right_x, area.position.y, area.end.x - right_x, area.size.y))


# The notice inverted at the bottom left of the list.
func draw_notice(bottom_left: Vector2) -> void:
	var box := Rect2(bottom_left - Vector2(0.0, Office.TEXT_SIZE + 2.0 * NOTICE_PADDING.y),
		Vector2(office.text_width(notice(), Office.TEXT_SIZE), Office.TEXT_SIZE) + 2.0 * NOTICE_PADDING)
	office.terminal.draw_rect(box, Office.GREEN)
	office.draw_text(notice(), box.position + NOTICE_PADDING + Vector2(0.0, Office.TEXT_SIZE), Office.TEXT_SIZE,
		-1, HORIZONTAL_ALIGNMENT_LEFT, Office.BLACK)


# CONTRACTS and its list, the summary, then START LOADING (dimmed while there are no Contracts).
func draw_contracts(area: Rect2) -> void:
	var y := area.position.y
	var lines := contract_lines()
	for i in lines.size():
		y += ROW_HEIGHT
		office.draw_text(lines[i], Vector2(area.position.x, y), Office.TEXT_SIZE, area.size.x)
		if i == 0:
			office.terminal.draw_line(Vector2(area.position.x, y + ROW_PADDING),
				Vector2(area.end.x, y + ROW_PADDING), Office.GREEN, Office.LINE_WIDTH)
	y += ROW_HEIGHT
	for part in summary_parts():
		y += ROW_HEIGHT
		var label: String = part[0] + " "
		office.draw_text(label, Vector2(area.position.x, y), Office.TEXT_SIZE, area.size.x,
			HORIZONTAL_ALIGNMENT_LEFT, part[2])
		var label_width := office.text_width(label, Office.TEXT_SIZE)
		office.draw_text(part[1], Vector2(area.position.x + label_width, y), Office.TEXT_SIZE,
			area.size.x - label_width, HORIZONTAL_ALIGNMENT_LEFT, part[3])
	var button := Rect2(Vector2(area.position.x, y + ROW_HEIGHT), START_LOADING_SIZE)
	var lit := Office.GREEN if start_loading_enabled() else Office.DIM_GREEN
	var focused := focus == Column.CONTRACTS
	if focused:
		office.terminal.draw_rect(button, lit)
	else:
		office.terminal.draw_rect(button, lit, false, Office.LINE_WIDTH)
	office.draw_text(START_LOADING_TEXT, Vector2(button.position.x, button.get_center().y + Office.TEXT_SIZE / 2.0),
		Office.TEXT_SIZE, button.size.x, HORIZONTAL_ALIGNMENT_CENTER, Office.BLACK if focused else lit)


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
