class_name BankAccountScreen
extends RefCounted
# The Office's BANK ACCOUNT screen: the pilot, the balance and the transactions, newest first.
# Each transaction opens to show how its payout was worked out, several at once, as in the
# Transport offers list. The Office owns the Terminal and calls this while the screen is showing.
#
# The pilot, the balance and the transactions, each opening to show how its payout was worked out:
# input, observable text and drawing. The Office creates it and calls it while that screen shows.
# A row's amount is white for a gain (or €0) and red for a loss; the rest of the row stays green,
# and the selected row is all black on its green bar.

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


static func no_button(_transaction: Transaction) -> bool:
	return false


# Under the pilot's name and the balance, a row's height below it, leaving room right of it
# for the ▲/▼ markers.
static func list_area(area: Rect2) -> Rect2:
	var top := area.position.y + 3.0 * Office.LINE_GAP + Office.NAME_SIZE + Office.STAT_SIZE + ROW_HEIGHT
	var marker_room := 2.0 * (ExpandableList.MARKER_GAP + ExpandableList.MARKER_SIZE.x)
	return Rect2(area.position.x, top, area.size.x - marker_room, area.end.y - top)


# A transaction's row and fully open details, as heights.
func measure(transaction: Transaction) -> Vector2:
	return Vector2(ROW_HEIGHT, transaction.detail_pairs().size() * ROW_HEIGHT + 2.0 * ROW_PADDING)


# Observable state

func lines() -> PackedStringArray:
	return PackedStringArray([Economy.PILOT, "%s %s" % [BALANCE_LABEL, Economy.eur(economy.balance)]])


# Newest first, e.g. #004 INDUSTRIAL SUPPLIES  CARGO  €54 400 or SHIP PURCHASE — MULE 1  SHIP  -€400 000.
func rows() -> PackedStringArray:
	var texts := PackedStringArray()
	for transaction in economy.transactions:
		texts.append("%s  %s" % [transaction.label(), row_value(transaction)])
	return texts


# The row's details; empty when the row isn't open.
func details(row: int) -> PackedStringArray:
	var texts := PackedStringArray()
	if not row in list.expanded_rows():
		return texts
	for detail: Array in economy.transactions[row].detail_pairs():
		texts.append(("%s %s" % detail).strip_edges())
	return texts


# The row's right-hand part: the kind and the payout.
static func row_value(transaction: Transaction) -> String:
	return kind_text(transaction) + Economy.eur(transaction.payout)


static func kind_text(transaction: Transaction) -> String:
	var kind := transaction.kind_label()
	return kind + "  " if kind != "" else ""


# The colour the row's amount is drawn in.
func amount_color(row: int) -> Color:
	if row == list.selected_index():
		return Office.BLACK
	return Office.RED if economy.transactions[row].payout < 0 else Office.WHITE


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
			office.draw_text(transaction.label(), baseline, Office.TEXT_SIZE, width,
				HORIZONTAL_ALIGNMENT_LEFT, color)
			var amount := Economy.eur(transaction.payout)
			office.draw_text(amount, baseline, Office.TEXT_SIZE, width, HORIZONTAL_ALIGNMENT_RIGHT, amount_color(i))
			office.draw_text(kind_text(transaction), baseline, Office.TEXT_SIZE,
				width - office.text_width(amount, Office.TEXT_SIZE), HORIZONTAL_ALIGNMENT_RIGHT, color)
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
func draw_details(transaction: Transaction, top_left: Vector2, width: float, clip: Rect2) -> void:
	var y := top_left.y
	for pair: Array in transaction.detail_pairs():
		y += ROW_HEIGHT
		if not ExpandableList.line_fits(y, Office.TEXT_SIZE, clip):
			continue
		office.draw_label_value(pair[0], pair[1], Vector2(top_left.x, y), Office.TEXT_SIZE, width)
