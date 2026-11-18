class_name ShipyardScreen
extends RefCounted
# The Office's SHIPYARD screen: one Ship offer at a time for every Ship type, with its price, and
# BUY €x. Buying asks first, then the Hangar adds a new owned ship (full tank, not in service), the
# Economy charges its price, and the Terminal opens the new ship's Ship page with a short notice.
# Buying works with Contracts (it doesn't change the ship in service), but is blocked when the
# Hangar is full or the balance would go below €0: BUY is then dimmed with a red reason, and Return
# on it only shows that reason. The Office creates it and calls it while that screen shows.

const FULL_BLOCK := "■"
const EMPTY_BLOCK := "□"
const OWNED_TEXT := "OWNED: %d"
const HANGAR_TEXT := "HANGAR %d/%d"
const BUY_TEXT := "BUY %s"
const BUY_QUESTION := "BUY A %s FOR %s?"
const BOUGHT_NOTICE := "%s IS IN THE HANGAR"
const HANGAR_FULL := "HANGAR FULL %d/%d: SELL A SHIP FIRST"
const NOT_ENOUGH_MONEY := "NOT ENOUGH MONEY: %s SHORT"
const TANK_FULL := "%s FULL"

# The stats' and ratings' rows: text size, and the step from one baseline to the next.
const ROW_SIZE := 20
const ROW_STEP := 30.0
const RATING_LABEL_WIDTH := 230.0
const BUY_BUTTON_SIZE := Vector2(260, 36)

var office: Office
var hangar: Hangar
var economy: Economy
var index := 0


func _init(owner: Office, owner_hangar: Hangar, owner_economy: Economy) -> void:
	office = owner
	hangar = owner_hangar
	economy = owner_economy


# Opens on the ship in service's type.
func open() -> void:
	index = maxi(ShipType.ALL.find(hangar.in_service.ship_type), 0)


# Returns whether it used the event; Escape is left to the Office.
func handle_input(event: InputEvent) -> bool:
	if event.is_action_pressed("ui_left"):
		browse(-1)
	elif event.is_action_pressed("ui_right"):
		browse(1)
	elif event.is_action_pressed("ui_accept"):
		buy()
	else:
		return false
	return true


# Browsing wraps around at both ends.
func browse(step: int) -> void:
	index = posmod(index + step, ShipType.ALL.size())


func buy() -> void:
	var type := selected()
	if reason() != "":
		office.show_notice(reason(), true)
		return
	office.ask(BUY_QUESTION % [type.name.to_upper(), "%s"], Economy.eur(type.price), func() -> void:
		var ship := hangar.buy(type)
		economy.pay_for_ship(ship)
		office.open_ship_page(ship)
		office.show_notice(BOUGHT_NOTICE % ship.name))


# Observable state

func selected() -> ShipType:
	return ShipType.ALL[index]


# Why the selected Ship offer can't be bought, or "" when it can.
func reason() -> String:
	if hangar.full():
		return HANGAR_FULL % [hangar.ships.size(), Hangar.BERTHS]
	var short := economy.shortfall(selected().price)
	if short > 0:
		return NOT_ENOUGH_MONEY % Economy.eur(short)
	return ""


func indicator() -> String:
	return "< %d/%d >" % [index + 1, ShipType.ALL.size()]


func hangar_text() -> String:
	return HANGAR_TEXT % [hangar.ships.size(), Hangar.BERTHS]


func owned_text() -> String:
	return OWNED_TEXT % hangar.count_of(selected())


func buy_text() -> String:
	return BUY_TEXT % Economy.eur(selected().price)


# The text the selected Ship offer shows, with ratings written as blocks.
func lines() -> PackedStringArray:
	var type := selected()
	var texts := PackedStringArray([hangar_text(), type.name.to_upper(), owned_text(), type.flavour.to_upper()])
	for stat: Array in stats():
		texts.append("%s %s" % stat)
	for rating: Array in ratings():
		texts.append("%s %s" % [rating[0], blocks(rating[1])])
	texts.append(indicator())
	texts.append(buy_text())
	if reason() != "":
		texts.append(reason())
	return texts


# The selected Ship offer's numbers as [label, text] pairs: the price, then the ship.
func stats() -> Array[Array]:
	var type := selected()
	return [["PRICE", Economy.eur(type.price)], ["TANK", TANK_FULL % Office.litres(type.tank)],
		["SEATS", str(type.passenger_seats)], ["CARGO", Office.kg(type.full_tank_cargo())],
		["MAX CAPACITY", Office.kg(type.cargo_capacity)]]


# The selected Ship offer's ratings as [label, blocks out of Office.RATING_BLOCKS] pairs.
func ratings() -> Array[Array]:
	var type := selected()
	return [["THRUST", type.thrust_rating], ["HANDLING", type.handling_rating]]


# The wireframe picture's outline: the ship type's hull.
func picture() -> PackedVector2Array:
	return selected().hull


static func blocks(rating: int) -> String:
	return FULL_BLOCK.repeat(rating) + EMPTY_BLOCK.repeat(Office.RATING_BLOCKS - rating)


# Drawing

# Wireframe left; name, flavour, numbers, ratings and BUY right; HANGAR n/4 top left and
# < n/N > top right.
func draw(area: Rect2) -> void:
	var type := selected()
	var top := area.position.y + Office.TEXT_SIZE
	office.draw_text(hangar_text(), Vector2(area.position.x, top), Office.TEXT_SIZE, -1.0,
		HORIZONTAL_ALIGNMENT_LEFT, Office.WHITE)
	office.draw_text(indicator(), Vector2(area.position.x, top), Office.TEXT_SIZE, area.size.x,
		HORIZONTAL_ALIGNMENT_RIGHT)
	var half := area.size.x / 2.0
	office.draw_wireframe(picture(), Rect2(area.position, Vector2(half, area.size.y)))

	var x := area.position.x + half
	var width := half
	var price_red := economy.shortfall(type.price) > 0
	var rows := stats().size() + ratings().size()
	var height := Office.NAME_SIZE + Office.LINE_GAP + Office.TEXT_SIZE + Office.LINE_GAP \
		+ rows * ROW_STEP + Office.LINE_GAP + BUY_BUTTON_SIZE.y + Office.LINE_GAP + Office.TEXT_SIZE
	var y := area.get_center().y - height / 2.0 + Office.NAME_SIZE
	var title := type.name.to_upper()
	office.draw_text(title, Vector2(x, y), Office.NAME_SIZE, width)
	office.draw_text(owned_text(), Vector2(x + office.text_width(title, Office.NAME_SIZE) + Office.LINE_GAP, y),
		Office.TEXT_SIZE, -1.0, HORIZONTAL_ALIGNMENT_LEFT, Office.WHITE)
	y += Office.LINE_GAP + Office.TEXT_SIZE
	office.draw_text(type.flavour.to_upper(), Vector2(x, y), Office.TEXT_SIZE, width)
	y += Office.LINE_GAP
	var all_stats := stats()
	for i in all_stats.size():
		y += ROW_STEP
		office.draw_text(all_stats[i][0], Vector2(x, y), ROW_SIZE, RATING_LABEL_WIDTH)
		# The price is the first stat.
		office.draw_text(all_stats[i][1], Vector2(x + RATING_LABEL_WIDTH, y), ROW_SIZE, width - RATING_LABEL_WIDTH,
			HORIZONTAL_ALIGNMENT_LEFT, Office.RED if i == 0 and price_red else Office.WHITE)
	for rating: Array in ratings():
		y += ROW_STEP
		office.draw_text(rating[0], Vector2(x, y), ROW_SIZE, RATING_LABEL_WIDTH)
		office.draw_rating(rating[1], Vector2(x + RATING_LABEL_WIDTH, y - Office.BLOCK_SIZE.y))
	y += Office.LINE_GAP
	var button := Rect2(Vector2(x, y), BUY_BUTTON_SIZE)
	office.draw_action(button, BUY_TEXT % "", Economy.eur(type.price), true, reason(), price_red)
