class_name BankAccountScreen
extends RefCounted
# The Office's BANK ACCOUNT screen: the pilot, the balance and the transactions, newest first.
# Each transaction opens to show how its payout was worked out, several at once, as in the
# Transport offers list. The Office owns the Terminal and calls this while the screen is showing.

# The rows and details share the Transport offers list's layout.
const ROW_HEIGHT := TransportOffersScreen.ROW_HEIGHT
const ROW_PADDING := TransportOffersScreen.ROW_PADDING
const BALANCE_LABEL := "BALANCE"

var office: Office
var economy: Economy
# The open transactions and the cursor over their rows; transactions have no buttons.
var list: ExpandableList


func _init(owner: Office, owner_economy: Economy) -> void:
	office = owner
	economy = owner_economy
	list = ExpandableList.new(func() -> Array: return owner_economy.transactions, no_button, measure, 0.0)


func tick(delta: float) -> void:
	list.tick(delta)
	list.follow(list_area(office.body_area(Rect2(Vector2.ZERO, office.terminal.size))).size.y)


# Returns whether it used the event; Escape with no open transaction under the cursor is left
# to the Office.
func handle_input(event: InputEvent) -> bool:
	if event.is_action_pressed("ui_up"):
		list.move(-1)
	elif event.is_action_pressed("ui_down"):
		list.move(1)
	elif event.is_action_pressed("ui_accept"):
		list.toggle()
	elif not (event.is_action_pressed("ui_cancel") and list.close_selected()):
		return false
	return true


static func no_button(_transaction: TransportOffer.Transaction) -> bool:
	return false


# Under the pilot's name and the balance, a row's height below it, leaving room right of it
# for the ▲/▼ markers.
static func list_area(area: Rect2) -> Rect2:
	var top := area.position.y + 3.0 * Office.LINE_GAP + Office.NAME_SIZE + Office.STAT_SIZE + ROW_HEIGHT
	var marker_room := 2.0 * (ExpandableList.MARKER_GAP + ExpandableList.MARKER_SIZE.x)
	return Rect2(area.position.x, top, area.size.x - marker_room, area.end.y - top)


# A transaction's row and fully open details, as heights.
func measure(transaction: TransportOffer.Transaction) -> Vector2:
	return Vector2(ROW_HEIGHT, detail_pairs(transaction).size() * ROW_HEIGHT + 2.0 * ROW_PADDING)


# Observable state

func lines() -> PackedStringArray:
	return PackedStringArray([Economy.PILOT, "%s %s" % [BALANCE_LABEL, Economy.eur(economy.balance)]])


# Newest first, e.g. #004 MINING SUPPLIES  CARGO  €544.
func rows() -> PackedStringArray:
	var texts := PackedStringArray()
	for transaction in economy.transactions:
		texts.append("%s  %s" % [transaction.contract.label(), row_value(transaction)])
	return texts


# The row's details; empty when the row isn't open.
func details(row: int) -> PackedStringArray:
	var texts := PackedStringArray()
	if not row in list.expanded_rows():
		return texts
	for detail: Array in detail_pairs(economy.transactions[row]):
		texts.append("%s %s" % detail)
	return texts


# How the payout was worked out, as [label, text] pairs, times local. The deadline is the
# flight's, which the penalty was counted against.
static func detail_pairs(transaction: TransportOffer.Transaction) -> Array[Array]:
	var penalty := Economy.eur(0)
	if transaction.overdue_seconds() > 0:
		penalty = "%s (%d MIN OVERDUE)" % [Economy.eur(-transaction.penalty), transaction.overdue_minutes()]
	return [["BASE VALUE", Economy.eur(transaction.reward)], ["PENALTY", penalty],
		["PAYOUT", Economy.eur(transaction.payout)], ["DEADLINE", PlanetClock.local_time(transaction.deadline_at)],
		["LANDED", PlanetClock.local_time(transaction.landed_at)], ["DELIVERED TO", transaction.delivered_to],
		["SHIP", transaction.ship.to_upper()]]


# The row's right-hand part: the kind and the payout.
static func row_value(transaction: TransportOffer.Transaction) -> String:
	return "%s  %s" % [TransportOffer.KIND_LABELS[transaction.contract.kind()], Economy.eur(transaction.payout)]


# Drawing

func draw(area: Rect2) -> void:
	var y := area.position.y + Office.LINE_GAP + Office.NAME_SIZE
	office.draw_text(Economy.PILOT, Vector2(area.position.x, y), Office.NAME_SIZE)
	y += 2.0 * Office.LINE_GAP + Office.STAT_SIZE
	office.draw_label_value(BALANCE_LABEL, Economy.eur(economy.balance), Vector2(area.position.x, y), Office.STAT_SIZE)

	var column := list_area(area)
	list.follow(column.size.y)
	var selected_index := list.selected_index()
	# Drawing has no clipping, so tints are cut to the column and lines outside it are skipped.
	y = column.position.y - list.scroll
	for i in economy.transactions.size():
		var transaction := economy.transactions[i]
		var row := Rect2(column.position.x, y, column.size.x, ROW_HEIGHT)
		var selected := i == selected_index
		ExpandableList.draw_clipped_rect(office.terminal, row, column, Office.GREEN if selected else Office.row_tint(i))
		var color := Office.BLACK if selected else Office.GREEN
		var baseline := Vector2(row.position.x + ROW_PADDING, row.get_center().y + Office.TEXT_SIZE / 2.0)
		var width := row.size.x - 2.0 * ROW_PADDING
		if ExpandableList.line_fits(baseline.y, Office.TEXT_SIZE, column):
			office.draw_text(transaction.contract.label(), baseline, Office.TEXT_SIZE, width,
				HORIZONTAL_ALIGNMENT_LEFT, color)
			office.draw_text(row_value(transaction), baseline, Office.TEXT_SIZE, width, HORIZONTAL_ALIGNMENT_RIGHT, color)
		y += ROW_HEIGHT
		var open_height := measure(transaction).y * list.open_share(transaction)
		if open_height > 0.0:
			# Open details grow from the row on a stronger tint, cut to their height so far.
			var clip := Rect2(column.position.x, y, column.size.x, open_height).intersection(column)
			ExpandableList.draw_clipped_rect(office.terminal, clip, column, Office.DETAILS_TINT)
			draw_details(transaction, Vector2(baseline.x, y), width, clip)
			y += open_height
	list.draw_markers(office.terminal, column, Office.GREEN)


# The details one per line, labels green and values white; only what lies wholly in clip is drawn.
func draw_details(transaction: TransportOffer.Transaction, top_left: Vector2, width: float, clip: Rect2) -> void:
	var y := top_left.y
	for pair: Array in detail_pairs(transaction):
		y += ROW_HEIGHT
		if not ExpandableList.line_fits(y, Office.TEXT_SIZE, clip):
			continue
		office.draw_label_value(pair[0], pair[1], Vector2(top_left.x, y), Office.TEXT_SIZE, width)
