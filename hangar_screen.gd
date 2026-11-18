class_name HangarScreen
extends RefCounted
# The Office's HANGAR screen and each owned ship's Ship page (`HANGAR // SPARROW 1`).
#
# The Hangar is a table of berths headed `BERTHS n/4`: one row per owned ship (name and IN SERVICE,
# Condition, fuel in litres, parachute, number of upgrades), then a dim row per empty berth. Up/Down
# move, Return on a ship opens its Ship page, Return on an empty berth opens the Shipyard.
#
# The Ship page shows the ship's name, IN SERVICE tag, wireframe and fitted upgrades on the left,
# CONDITION, FUEL, DRY MASS, CARGO and VALUE in the middle, and its actions in a column on the
# right: PUT IN SERVICE (the Ship swap: free and instant, each ship keeps its own fuel; blocked with
# Contracts) and SELL €x (blocked for the ship in service; allowed in debt). Every action asks first;
# a blocked one is dimmed with a red reason, and Return on it only shows that reason. Escape goes
# back to the berths table. The Office creates it and calls it while either screen shows; it calls
# the Hangar's and the Economy's named operations and never edits a ship.

enum Action { PUT_IN_SERVICE, SELL }

const BERTHS_TEXT := "BERTHS %d/%d"
const EMPTY_BERTH_TEXT := "EMPTY BERTH: BUY A SHIP IN THE SHIPYARD"
const COLUMNS := ["SHIP", "CONDITION", "FUEL", "PARACHUTE", "UPGRADES"]
# Where each column starts, as a share of the table's width.
const COLUMN_SHARES := [0.0, 0.4, 0.55, 0.72, 0.87]
const NO_PARACHUTE := "–"
const NO_UPGRADES := "NO UPGRADES"
const ACTION_LABELS := {Action.PUT_IN_SERVICE: "PUT IN SERVICE", Action.SELL: "SELL "}
const SERVICE_QUESTION := "PUT %s IN SERVICE?"
const SELL_QUESTION := "SELL %s FOR %s?"
const ALREADY_IN_SERVICE := "ALREADY IN SERVICE"
const CONTRACTS_LOCK := "LOCKED: CONTRACTS ACCEPTED"
const IN_SERVICE_CANT_BE_SOLD := "THE SHIP IN SERVICE CAN'T BE SOLD"

const ROW_HEIGHT := TransportOffersScreen.ROW_HEIGHT
const ROW_PADDING := TransportOffersScreen.ROW_PADDING
const ACTION_SIZE := Vector2(300, 36)
# From the top of one action's button to the next, leaving a line for its reason.
const ACTION_STEP := 36.0 + 2.0 * Office.LINE_GAP + Office.TEXT_SIZE
const STATUS_LABEL_WIDTH := 140.0

var office: Office
var hangar: Hangar
var economy: Economy
# The berth row under the cursor in the table.
var row := 0
# The ship whose page is open, and the action under its cursor.
var ship: OwnedShip
var action := Action.PUT_IN_SERVICE


func _init(owner: Office, owner_hangar: Hangar, owner_economy: Economy) -> void:
	office = owner
	hangar = owner_hangar
	economy = owner_economy


func open_page(owned: OwnedShip) -> void:
	ship = owned
	action = Action.PUT_IN_SERVICE
	row = hangar.ships.find(owned)


# Returns whether it used the event; Escape on the berths table is left to the Office.
func handle_input(event: InputEvent) -> bool:
	if office.screen == Office.Screen.SHIP_PAGE:
		return handle_page_input(event)
	if event.is_action_pressed("ui_up"):
		row = maxi(row - 1, 0)
	elif event.is_action_pressed("ui_down"):
		row = mini(row + 1, Hangar.BERTHS - 1)
	elif event.is_action_pressed("ui_accept"):
		if row < hangar.ships.size():
			office.open_ship_page(hangar.ships[row])
		else:
			office.open_screen(Office.Screen.SHIPYARD)
	else:
		return false
	return true


func handle_page_input(event: InputEvent) -> bool:
	if event.is_action_pressed("ui_up"):
		action = maxi(action - 1, 0) as Action
	elif event.is_action_pressed("ui_down"):
		action = mini(action + 1, Action.size() - 1) as Action
	elif event.is_action_pressed("ui_accept"):
		take_action()
	elif event.is_action_pressed("ui_cancel"):
		office.open_screen(Office.Screen.HANGAR)
	else:
		return false
	return true


func take_action() -> void:
	var reason := action_reason(action)
	if reason != "":
		office.show_notice(reason, true)
		return
	var owned := ship
	match action:
		Action.PUT_IN_SERVICE:
			office.ask(SERVICE_QUESTION % owned.name, "", func() -> void: hangar.put_in_service(owned))
		Action.SELL:
			office.ask(SELL_QUESTION % [owned.name, "%s"], Economy.eur(owned.sale_price()), func() -> void:
				economy.get_paid_for_ship(owned)
				hangar.sell(owned)
				row = mini(row, hangar.ships.size() - 1)
				office.open_screen(Office.Screen.HANGAR))


# Observable state

func berths_text() -> String:
	return BERTHS_TEXT % [hangar.ships.size(), Hangar.BERTHS]


# One per berth, its columns split by two spaces: SPARROW 1 IN SERVICE  100%  6 250 L  –  0, then
# the empty berths.
func rows() -> PackedStringArray:
	var texts := PackedStringArray()
	for owned in hangar.ships:
		texts.append("  ".join(row_cells(owned)))
	for i in Hangar.BERTHS - hangar.ships.size():
		texts.append(EMPTY_BERTH_TEXT)
	return texts


func row_cells(owned: OwnedShip) -> PackedStringArray:
	var title := owned.name
	if owned == hangar.in_service:
		title += " " + Office.IN_SERVICE_TEXT
	return PackedStringArray([title, condition_text(owned), Office.litres(owned.fuel), NO_PARACHUTE, "0"])


# The Ship page's text, top to bottom and left to right, as label and value lines.
func page_lines() -> PackedStringArray:
	var texts := PackedStringArray([ship.name])
	if ship == hangar.in_service:
		texts.append(Office.IN_SERVICE_TEXT)
	texts.append(NO_UPGRADES)
	for pair: Array in status():
		texts.append("%s %s" % pair)
	return texts


func status() -> Array[Array]:
	return [["CONDITION", condition_text(ship)],
		["FUEL", "%s / %s" % [Office.litres(ship.fuel).trim_suffix(" L"), Office.litres(ship.tank())]],
		["DRY MASS", Office.kg(ship.dry_mass())], ["CARGO", Office.kg(ship.full_tank_cargo())],
		["VALUE", Economy.eur(ship.value())]]


# The action column's labels, top to bottom: PUT IN SERVICE, SELL €125 000.
func actions() -> PackedStringArray:
	var texts := PackedStringArray()
	for each: Action in Action.values():
		texts.append(ACTION_LABELS[each] + action_price(each))
	return texts


func selected_action() -> String:
	return actions()[action]


# Each action's red reason, "" for one the player can take.
func reasons() -> PackedStringArray:
	var texts := PackedStringArray()
	for each: Action in Action.values():
		texts.append(action_reason(each))
	return texts


func action_reason(which: Action) -> String:
	match which:
		Action.PUT_IN_SERVICE:
			if ship == hangar.in_service:
				return ALREADY_IN_SERVICE
			if not economy.contracts.is_empty():
				return CONTRACTS_LOCK
		Action.SELL:
			if ship == hangar.in_service:
				return IN_SERVICE_CANT_BE_SOLD
	return ""


func action_price(which: Action) -> String:
	return Economy.eur(ship.sale_price()) if which == Action.SELL else ""


static func condition_text(owned: OwnedShip) -> String:
	return "%d%%" % roundi(owned.condition * 100.0)


# Drawing

func draw(area: Rect2) -> void:
	if office.screen == Office.Screen.SHIP_PAGE:
		draw_page(area)
	else:
		draw_table(area)


# BERTHS n/4, the column headings, then one row per berth; the selected row is inverted.
func draw_table(area: Rect2) -> void:
	var y := area.position.y + Office.TEXT_SIZE
	office.draw_text(berths_text(), Vector2(area.position.x, y), Office.TEXT_SIZE, -1.0,
		HORIZONTAL_ALIGNMENT_LEFT, Office.WHITE)
	y += Office.LINE_GAP
	var width := area.size.x - 2.0 * ROW_PADDING
	var heading := Rect2(area.position.x, y, area.size.x, ROW_HEIGHT)
	draw_cells(PackedStringArray(COLUMNS), heading, width, Office.DIM_GREEN, Office.DIM_GREEN)
	y += ROW_HEIGHT
	for i in Hangar.BERTHS:
		var rect := Rect2(area.position.x, y, area.size.x, ROW_HEIGHT)
		var selected := i == row
		var owned: OwnedShip = hangar.ships[i] if i < hangar.ships.size() else null
		var lit := Office.GREEN if owned != null else Office.DIM_GREEN
		office.terminal.draw_rect(rect, lit if selected else Office.row_tint(i))
		if owned != null:
			draw_cells(row_cells(owned), rect, width, Office.BLACK if selected else Office.GREEN,
				Office.BLACK if selected else Office.WHITE)
		else:
			office.draw_text(EMPTY_BERTH_TEXT, cell_baseline(rect, 0.0), Office.TEXT_SIZE, width,
				HORIZONTAL_ALIGNMENT_LEFT, Office.BLACK if selected else Office.DIM_GREEN)
		y += ROW_HEIGHT


# The first cell in label colour, the others in value colour, each at its column.
func draw_cells(cells: PackedStringArray, rect: Rect2, width: float, label_color: Color, value_color: Color) -> void:
	for i in cells.size():
		var x: float = COLUMN_SHARES[i] * width
		office.draw_text(cells[i], cell_baseline(rect, x), Office.TEXT_SIZE, -1.0, HORIZONTAL_ALIGNMENT_LEFT,
			label_color if i == 0 else value_color)


static func cell_baseline(rect: Rect2, x: float) -> Vector2:
	return Vector2(rect.position.x + ROW_PADDING + x, rect.get_center().y + Office.TEXT_SIZE / 2.0)


# Three columns: the ship (name, IN SERVICE, wireframe, fitted upgrades), its status, its actions.
func draw_page(area: Rect2) -> void:
	var third := area.size.x / 3.0
	var y := area.position.y + Office.HEADER_SIZE
	office.draw_text(ship.name, Vector2(area.position.x, y), Office.HEADER_SIZE, third)
	if ship == hangar.in_service:
		office.draw_in_service_tag(Vector2(area.position.x, y + Office.LINE_GAP))
	var picture := Rect2(area.position.x, y + 2.0 * Office.LINE_GAP + Office.TEXT_SIZE, third, area.size.y * 0.55)
	office.draw_wireframe(ship.ship_type.hull, picture)
	office.draw_text(NO_UPGRADES, Vector2(area.position.x, picture.end.y + Office.LINE_GAP + Office.TEXT_SIZE),
		Office.TEXT_SIZE, third, HORIZONTAL_ALIGNMENT_LEFT, Office.DIM_GREEN)

	var x := area.position.x + third
	y = area.position.y + Office.TEXT_SIZE
	for pair: Array in status():
		office.draw_text(pair[0], Vector2(x, y), Office.TEXT_SIZE, STATUS_LABEL_WIDTH)
		office.draw_text(pair[1], Vector2(x + STATUS_LABEL_WIDTH, y), Office.TEXT_SIZE, third - STATUS_LABEL_WIDTH,
			HORIZONTAL_ALIGNMENT_LEFT, Office.WHITE)
		y += Office.TEXT_SIZE + Office.LINE_GAP

	var button := Rect2(Vector2(area.position.x + 2.0 * third, area.position.y), Vector2(third, ACTION_SIZE.y))
	for each: Action in Action.values():
		office.draw_action(button, ACTION_LABELS[each], action_price(each), each == action and office.popup == Office.PopupKind.NONE,
			action_reason(each))
		button.position.y += ACTION_STEP
