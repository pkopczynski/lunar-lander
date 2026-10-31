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
var list := ExpandableList.new()
# The row under the cursor.
var selected_index: int:
	get:
		sync()
		return list.row


func _init(owner: Office, owner_economy: Economy) -> void:
	office = owner
	economy = owner_economy


func tick(delta: float) -> void:
	list.tick(delta)
	follow()


# Returns whether it used the event; Escape with no open transaction under the cursor is left
# to the Office.
func handle_input(event: InputEvent) -> bool:
	sync()
	if event.is_action_pressed("ui_up"):
		list.move(economy.transactions, -1, no_button)
	elif event.is_action_pressed("ui_down"):
		list.move(economy.transactions, 1, no_button)
	elif event.is_action_pressed("ui_accept"):
		list.toggle()
	elif not (event.is_action_pressed("ui_cancel") and list.close_selected()):
		return false
	return true


func sync() -> void:
	list.sync(economy.transactions, no_button)


# Scrolls the list to keep the cursor in view.
func follow() -> void:
	sync()
	list.follow(economy.transactions, measure,
		list_area(office.body_area(Rect2(Vector2.ZERO, office.terminal.size))).size.y, 0.0)


static func no_button(_transaction: TransportOffer.Transaction) -> bool:
	return false


# Under the pilot's name and the balance, leaving room right of it for the ▲/▼ markers.
static func list_area(area: Rect2) -> Rect2:
	var top := area.position.y + 3.0 * Office.LINE_GAP + Office.NAME_SIZE + Office.STAT_SIZE
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


# The transactions whose details are open, top to bottom.
func expanded_rows() -> Array:
	sync()
	var open := []
	for i in economy.transactions.size():
		if economy.transactions[i] in list.expanded:
			open.append(i)
	return open


# The row's details; empty when the row isn't open.
func details(row: int) -> PackedStringArray:
	var texts := PackedStringArray()
	if not row in expanded_rows():
		return texts
	for detail: Array in detail_pairs(economy.transactions[row]):
		texts.append("%s %s" % detail)
	return texts


# Pixels the list is scrolled down to keep the cursor in view.
func scroll() -> float:
	follow()
	return list.scroll


# Whether the list has content above or below its area, shown by the ▲/▼ markers.
func more_above() -> bool:
	follow()
	return list.more_above()


func more_below() -> bool:
	follow()
	return list.more_below()


# Whether the row under the cursor lies wholly in the list's area.
func cursor_in_view() -> bool:
	follow()
	return list.cursor_in_view()


# How the payout was worked out, as [label, text] pairs. The deadline is the flight's, which
# the penalty was counted against.
static func detail_pairs(transaction: TransportOffer.Transaction) -> Array[Array]:
	var overdue := transaction.overdue_seconds()
	var penalty := Economy.eur(0)
	if overdue > 0:
		penalty = "%s (%d S OVERDUE)" % [Economy.eur(-transaction.penalty), overdue]
	return [["BASE VALUE", Economy.eur(transaction.reward)], ["PENALTY", penalty],
		["PAYOUT", Economy.eur(transaction.payout)], ["DEADLINE", TransportOffer.countdown(transaction.deadline)],
		["DELIVERED IN", TransportOffer.countdown(floorf(transaction.delivery_time))]]


# The row's right-hand part: the kind and the payout.
static func row_value(transaction: TransportOffer.Transaction) -> String:
	return "%s  %s" % [TransportOffer.KIND_LABELS[transaction.contract.kind()], Economy.eur(transaction.payout)]


# Drawing

func draw(area: Rect2) -> void:
	var y := area.position.y + Office.LINE_GAP + Office.NAME_SIZE
	office.draw_text(Economy.PILOT, Vector2(area.position.x, y), Office.NAME_SIZE)
	y += 2.0 * Office.LINE_GAP + Office.STAT_SIZE
	var label := BALANCE_LABEL + " "
	office.draw_text(label, Vector2(area.position.x, y), Office.STAT_SIZE)
	office.draw_text(Economy.eur(economy.balance), Vector2(area.position.x + office.text_width(label, Office.STAT_SIZE), y),
		Office.STAT_SIZE, -1, HORIZONTAL_ALIGNMENT_LEFT, Office.WHITE)

	sync()
	var column := list_area(area)
	list.follow(economy.transactions, measure, column.size.y, 0.0)
	# Drawing has no clipping, so tints are cut to the column and lines outside it are skipped.
	y = column.position.y - list.scroll
	for i in economy.transactions.size():
		var transaction := economy.transactions[i]
		var row := Rect2(column.position.x, y, column.size.x, ROW_HEIGHT)
		var selected := i == list.row
		ExpandableList.draw_clipped_rect(office.terminal, row, column,
			Office.GREEN if selected else ExpandableList.row_tint(i))
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
		var label: String = pair[0] + " "
		office.draw_text(label, Vector2(top_left.x, y), Office.TEXT_SIZE, width)
		var label_width := office.text_width(label, Office.TEXT_SIZE)
		office.draw_text(pair[1], Vector2(top_left.x + label_width, y), Office.TEXT_SIZE, width - label_width,
			HORIZONTAL_ALIGNMENT_LEFT, Office.WHITE)
