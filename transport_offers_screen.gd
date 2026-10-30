class_name TransportOffersScreen
extends RefCounted
# The Office's TRANSPORT OFFERS screen: input and drawing for the offer list in the left
# column and the Contracts in the right one. The Office owns the Terminal and calls this
# while the screen is showing.

enum Column { OFFERS, CONTRACTS }

# Share of the screen's width the offer list takes; the rest is left for the Contracts.
const LIST_SHARE := 0.6
const ROW_HEIGHT := 28.0
const ROW_PADDING := 6.0
const ACCEPT_TEXT := "ACCEPT"
const DETAIL_COLUMNS := 2
const ACCEPT_SIZE := Vector2(120, 32)
const CONTRACTS_TEXT := "CONTRACTS"
const FUEL_LIMITED_PREFIX := "FUEL LIMITED: "
const START_LOADING_TEXT := "START LOADING"
const KG_SUFFIX := " KG"
const OFFER_EXPIRED_TEXT := "OFFER EXPIRED"
# Seconds a notice such as OFFER EXPIRED shows.
const NOTICE_TIME := 2.0
const COLUMN_GAP := 32.0
const START_LOADING_SIZE := Vector2(200, 32)
const NOTICE_PADDING := Vector2(8, 4)

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
	economy.offer_withdrawn.connect(on_offer_withdrawn)


func tick(delta: float) -> void:
	notice_left = maxf(notice_left - delta, 0.0)


# An offer going while its details or its ARE YOU SURE? are open closes them; only one
# that expired says so.
func on_offer_withdrawn(offer: TransportOffer, expired: bool) -> void:
	if offer != expanded:
		return
	expanded = null
	if office.popup == Office.PopupKind.ACCEPT_OFFER:
		office.popup = Office.PopupKind.NONE
	if expired:
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


# Under the Contracts: seats and cargo taken, and FUEL LIMITED when the Load leaves less
# room than a full Tank.
func summary() -> PackedStringArray:
	var ship := economy.lander
	var lines := PackedStringArray([
		"PASSENGERS %d/%d" % [economy.contract_passengers(), ship.ship_type.passenger_seats],
		"CARGO " + kg_of(economy.contract_cargo(), ship.ship_type.cargo_capacity)])
	var fuel_cap := ship.fuel_cap_for(economy.contract_load_mass())
	if fuel_cap < ship.ship_type.tank:
		lines.append(FUEL_LIMITED_PREFIX + kg_of(fuel_cap, ship.ship_type.tank))
	return lines


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
	for line in summary():
		y += ROW_HEIGHT
		office.draw_text(line, Vector2(area.position.x, y), Office.TEXT_SIZE, area.size.x)
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
