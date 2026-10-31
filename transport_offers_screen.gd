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
# The ACCEPT button with its padding above and below, at the bottom of open details.
const ACCEPT_SPAN := ACCEPT_SIZE.y + 4.0 * ROW_PADDING
const START_LOADING_SIZE := Vector2(200, 32)
# The room kept at a Contract's right end for its X.
const REMOVE_WIDTH := 24.0
const NOTICE_PADDING := Vector2(8, 4)

# Text
const ACCEPT_TEXT := "ACCEPT"
const CONTRACTS_TEXT := "CONTRACTS"
const FUEL_LIMITED_LABEL := "FUEL LIMITED:"
const FUEL_LIMITED_NOTE := "FUEL LIMITED"
const START_LOADING_TEXT := "START LOADING"
const REMOVE_TEXT := "X"
const KG_SUFFIX := " KG"
const OFFER_EXPIRED_TEXT := "OFFER EXPIRED"

# Seconds a notice such as OFFER EXPIRED shows.
const NOTICE_TIME := 2.0

var office: Office
var economy: Economy
var focus := Column.OFFERS
# The open offers and the cursor over their rows and ACCEPT buttons.
var list: ExpandableList
# The offer whose ARE YOU SURE? is showing, if any.
var accepting: TransportOffer
# The Contracts column's cursor: a Contract's index, or the Contracts' count for START LOADING.
var contract_index := 0
var notice_text := ""
var notice_left := 0.0


func _init(owner: Office, owner_economy: Economy) -> void:
	office = owner
	economy = owner_economy
	list = ExpandableList.new(func() -> Array: return owner_economy.offers, fits, measure, ACCEPT_SPAN)
	economy.offer_expired.connect(on_offer_expired)


func tick(delta: float) -> void:
	notice_left = maxf(notice_left - delta, 0.0)
	list.tick(delta)
	list.follow(list_area(office.body_area(Rect2(Vector2.ZERO, office.terminal.size))).size.y)


# An open offer that expires just closes; one whose ARE YOU SURE? is showing closes that too
# and says so.
func on_offer_expired(offer: TransportOffer) -> void:
	if offer == accepting and office.popup == Office.PopupKind.ACCEPT_OFFER:
		office.popup = Office.PopupKind.NONE
		accepting = null
		show_notice(OFFER_EXPIRED_TEXT)


func show_notice(text: String) -> void:
	notice_text = text
	notice_left = NOTICE_TIME


# Returns whether it used the event; Escape with no open offer under the cursor is left to
# the Office.
func handle_input(event: InputEvent) -> bool:
	if event.is_action_pressed("ui_right"):
		if focus != Column.CONTRACTS:
			contract_index = economy.contracts.size()
		focus = Column.CONTRACTS
	elif event.is_action_pressed("ui_left"):
		focus = Column.OFFERS
	elif focus == Column.CONTRACTS:
		return handle_contracts_input(event)
	elif event.is_action_pressed("ui_up"):
		list.move(-1)
	elif event.is_action_pressed("ui_down"):
		list.move(1)
	elif event.is_action_pressed("ui_accept"):
		if list.on_button():
			accepting = list.selected()
			office.show_popup(Office.PopupKind.ACCEPT_OFFER, Office.Choice.YES)
		else:
			list.toggle()
	elif not (event.is_action_pressed("ui_cancel") and list.close_selected()):
		return false
	return true


# Up/Down walk the Contracts, then START LOADING. Escape is left to the Office.
func handle_contracts_input(event: InputEvent) -> bool:
	if event.is_action_pressed("ui_up"):
		contract_index = maxi(contract_index - 1, 0)
	elif event.is_action_pressed("ui_down"):
		contract_index = mini(contract_index + 1, economy.contracts.size())
	elif event.is_action_pressed("ui_accept"):
		if selected_contract() != null:
			office.show_popup(Office.PopupKind.REMOVE_CONTRACT, Office.Choice.NO)
		elif start_loading_enabled():
			office.start_loading()
	else:
		return false
	return true


# Yes on ARE YOU SURE?: the Economy checks again that the offer is still there and still fits.
func confirm_accept() -> void:
	if not economy.accept(accepting) and not accepting in economy.offers:
		show_notice(OFFER_EXPIRED_TEXT)
	accepting = null


# Yes on REMOVE CONTRACT?: the cursor stays on a Contract while any are left.
func confirm_remove() -> void:
	economy.remove_contract(selected_contract())
	contract_index = maxi(mini(contract_index, economy.contracts.size() - 1), 0)


# The left column of the screen's area.
static func list_area(area: Rect2) -> Rect2:
	return Rect2(area.position, Vector2(area.size.x * LIST_SHARE, area.size.y))


# An offer's row (with its reason and note lines) and fully open details, as heights.
func measure(offer: TransportOffer) -> Vector2:
	var row_lines := 1 + int(economy.misfit_reason(offer) != "") + int(red_note(offer) != "")
	var detail_lines := ceili(float(detail_pairs(offer).size()) / DETAIL_COLUMNS)
	return Vector2(row_lines * ROW_HEIGHT, detail_lines * ROW_HEIGHT + ACCEPT_SPAN)


# An offer's ACCEPT can be selected only when the offer fits.
func fits(offer: TransportOffer) -> bool:
	return economy.misfit_reason(offer) == ""


# Observable state

# The Contract under the Contracts column's cursor, or null on START LOADING.
func selected_contract() -> TransportOffer:
	contract_index = mini(contract_index, economy.contracts.size())
	return economy.contracts[contract_index] if contract_index < economy.contracts.size() else null


# The notice showing, such as OFFER EXPIRED, or "".
func notice() -> String:
	return notice_text if notice_left > 0.0 else ""


func on_accept() -> bool:
	return list.on_button()


# The row's details, ending with the ACCEPT button; empty when the row isn't open.
func details(row: int) -> PackedStringArray:
	var lines := PackedStringArray()
	if not row in list.expanded_rows():
		return lines
	for detail: Array in detail_pairs(economy.offers[row]):
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
# passengers, FUEL LIMITED (the fuel cap over the Tank) once the Load leaves less room
# than a full Tank, which is exactly when the cargo passes the full-Tank cargo, then, with
# Contracts, DELIVER WITHIN (the shortest Deadline) and TOTAL VALUE (the sum of rewards).
func summary() -> PackedStringArray:
	var lines := PackedStringArray()
	for part in summary_parts():
		lines.append("%s %s" % [part[0], part[1]])
	return lines


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
	if not economy.contracts.is_empty():
		parts.append(["DELIVER WITHIN", TransportOffer.countdown(economy.deadline()), Office.GREEN, Office.WHITE])
		parts.append(["TOTAL VALUE", Economy.eur(total_value()), Office.GREEN, Office.WHITE])
	return parts


func total_value() -> int:
	var total := 0
	for contract in economy.contracts:
		total += contract.reward()
	return total


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
	var column := list_area(area)
	list.follow(column.size.y)
	var selected_index := list.selected_index()
	var on_button := list.on_button()
	# Drawing has no clipping, so tints are cut to the column and lines outside it are skipped.
	var y := column.position.y - list.scroll
	for i in economy.offers.size():
		var offer := economy.offers[i]
		var heights := measure(offer)
		ExpandableList.draw_clipped_rect(office.terminal, Rect2(column.position.x, y, column.size.x, heights.x), column,
			Office.row_tint(i))
		var row := Rect2(column.position.x, y, column.size.x, ROW_HEIGHT)
		# With focus on the Contracts, the list's row is outlined instead of inverted.
		var under_cursor := i == selected_index and not on_button
		var selected := under_cursor and focus == Column.OFFERS
		var reason := economy.misfit_reason(offer).to_upper()
		# Only an unavailable offer's text is dimmed; the cursor stays bright on it.
		if selected:
			ExpandableList.draw_clipped_rect(office.terminal, row, column, Office.GREEN)
		elif under_cursor and column.encloses(row):
			office.terminal.draw_rect(row, Office.GREEN, false, Office.LINE_WIDTH)
		var color := Office.BLACK if selected else Office.GREEN if reason == "" else Office.DIM_GREEN
		var baseline := Vector2(row.position.x + ROW_PADDING, row.get_center().y + Office.TEXT_SIZE / 2.0)
		var width := row.size.x - 2.0 * ROW_PADDING
		if ExpandableList.line_fits(baseline.y, Office.TEXT_SIZE, column):
			office.draw_text(offer.label(), baseline, Office.TEXT_SIZE, width,
				HORIZONTAL_ALIGNMENT_LEFT, color)
			office.draw_text("%s   %s" % [TransportOffer.KIND_LABELS[offer.kind()], TransportOffer.countdown(offer.time_left)],
				baseline, Office.TEXT_SIZE, width, HORIZONTAL_ALIGNMENT_RIGHT, color)
		y += ROW_HEIGHT
		var note := red_note(offer)
		for line: Array in [[reason, Office.DIM_GREEN], [note, Office.RED]]:
			if line[0] == "":
				continue
			if ExpandableList.line_fits(y + Office.TEXT_SIZE, Office.TEXT_SIZE, column):
				office.draw_text(line[0], Vector2(baseline.x, y + Office.TEXT_SIZE), Office.TEXT_SIZE, width,
					HORIZONTAL_ALIGNMENT_RIGHT, line[1])
			y += ROW_HEIGHT
		var open_height := heights.y * list.open_share(offer)
		if open_height > 0.0:
			# Open details grow from the row on a stronger tint, cut to their height so far.
			var clip := Rect2(column.position.x, y, column.size.x, open_height).intersection(column)
			ExpandableList.draw_clipped_rect(office.terminal, clip, column, Office.DETAILS_TINT)
			var accept_selected := i == selected_index and on_button and focus == Column.OFFERS
			draw_details(offer, Vector2(baseline.x, y), width, reason == "", accept_selected, clip)
			y += open_height
	list.draw_markers(office.terminal, column, Office.GREEN)
	if notice() != "":
		draw_notice(Vector2(column.position.x, column.end.y))
	var right_x := column.end.x + COLUMN_GAP
	draw_contracts(Rect2(right_x, area.position.y, area.end.x - right_x, area.size.y))


# The notice inverted at the bottom left of the list.
func draw_notice(bottom_left: Vector2) -> void:
	var box := Rect2(bottom_left - Vector2(0.0, Office.TEXT_SIZE + 2.0 * NOTICE_PADDING.y),
		Vector2(office.text_width(notice(), Office.TEXT_SIZE), Office.TEXT_SIZE) + 2.0 * NOTICE_PADDING)
	office.terminal.draw_rect(box, Office.GREEN)
	office.draw_text(notice(), box.position + NOTICE_PADDING + Vector2(0.0, Office.TEXT_SIZE), Office.TEXT_SIZE,
		-1, HORIZONTAL_ALIGNMENT_LEFT, Office.BLACK)


# CONTRACTS and its list (each with a plain X at its right end), the summary, then START LOADING
# (dimmed while there are no Contracts); the Contract row or button under the cursor is inverted.
func draw_contracts(area: Rect2) -> void:
	var y := area.position.y
	var lines := contract_lines()
	var focused := focus == Column.CONTRACTS
	for i in lines.size():
		y += ROW_HEIGHT
		var selected := i > 0 and focused and contract_index == i - 1
		var color := Office.BLACK if selected else Office.GREEN
		if selected:
			# The whole row inverted, like a selected offer, its text sharing the baseline.
			office.terminal.draw_rect(Rect2(area.position.x - ROW_PADDING, y - (ROW_HEIGHT + Office.TEXT_SIZE) / 2.0,
				area.size.x + 2.0 * ROW_PADDING, ROW_HEIGHT), Office.GREEN)
		office.draw_text(lines[i], Vector2(area.position.x, y), Office.TEXT_SIZE, area.size.x - REMOVE_WIDTH,
			HORIZONTAL_ALIGNMENT_LEFT, color)
		if i == 0:
			office.terminal.draw_line(Vector2(area.position.x, y + ROW_PADDING),
				Vector2(area.end.x, y + ROW_PADDING), Office.GREEN, Office.LINE_WIDTH)
		else:
			office.draw_text(REMOVE_TEXT, Vector2(area.end.x - REMOVE_WIDTH, y), Office.TEXT_SIZE, REMOVE_WIDTH,
				HORIZONTAL_ALIGNMENT_RIGHT, color)
	y += ROW_HEIGHT
	for part in summary_parts():
		y += ROW_HEIGHT
		office.draw_label_value(part[0], part[1], Vector2(area.position.x, y), Office.TEXT_SIZE, area.size.x, part[2],
			part[3])
	var button := Rect2(Vector2(area.position.x, y + ROW_HEIGHT), START_LOADING_SIZE)
	var lit := Office.GREEN if start_loading_enabled() else Office.DIM_GREEN
	focused = focused and selected_contract() == null
	if focused:
		office.terminal.draw_rect(button, lit)
	else:
		office.terminal.draw_rect(button, lit, false, Office.LINE_WIDTH)
	office.draw_text(START_LOADING_TEXT, Vector2(button.position.x, button.get_center().y + Office.TEXT_SIZE / 2.0),
		Office.TEXT_SIZE, button.size.x, HORIZONTAL_ALIGNMENT_CENTER, Office.BLACK if focused else lit)


# Draws the details in two columns under the row, labels green and values white (both dimmed
# when the offer doesn't fit), then ACCEPT at their bottom right (inverted when selected,
# dimmed when the offer doesn't fit). Only what lies wholly in clip is drawn.
func draw_details(offer: TransportOffer, top_left: Vector2, width: float, fits: bool, selected: bool,
		clip: Rect2) -> void:
	var y := top_left.y
	var pairs := detail_pairs(offer)
	var column_width := width / DETAIL_COLUMNS
	for i in pairs.size():
		var x := top_left.x + (i % DETAIL_COLUMNS) * column_width
		if i % DETAIL_COLUMNS == 0:
			y += ROW_HEIGHT
		if not ExpandableList.line_fits(y, Office.TEXT_SIZE, clip):
			continue
		office.draw_label_value(pairs[i][0], pairs[i][1], Vector2(x, y), Office.TEXT_SIZE, column_width,
			Office.GREEN if fits else Office.DIM_GREEN, Office.WHITE if fits else Office.DIM_WHITE)
	var button := Rect2(Vector2(top_left.x + width - ACCEPT_SIZE.x, y + ROW_PADDING * 2.0), ACCEPT_SIZE)
	if not clip.encloses(button):
		return
	var lit := Office.GREEN if fits else Office.DIM_GREEN
	if selected:
		office.terminal.draw_rect(button, lit)
	else:
		office.terminal.draw_rect(button, lit, false, Office.LINE_WIDTH)
	office.draw_text(ACCEPT_TEXT, Vector2(button.position.x, button.get_center().y + Office.TEXT_SIZE / 2.0),
		Office.TEXT_SIZE, button.size.x, HORIZONTAL_ALIGNMENT_CENTER, Office.BLACK if selected else lit)
