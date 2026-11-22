class_name FuelScreen
extends RefCounted
# The Terminal's FUEL screen for one owned ship, opened by FUEL on its Ship page: in the Office
# (`HANGAR // SPARROW 1 // FUEL`), buying fuel or selling it back at the station's price; in a pad's
# Workshop (`MINE PAD // WORKSHOP // FUEL`), buying only, at that pad's price (`Office.place`).
#
# One control runs from SELL BACK to BUY: `< BUY +1 000 L >`, stepped with Left/Right to the next
# round `STEP_LITRES` (so after FULL the steps are round again), never past selling the whole tank (0
# in a Workshop) or buying up to the fuel cap; FULL sets it to fill up to the cap.
# On the left: IN TANK (litres, then kg, as it is now, so it grows or shrinks while pumping), FUEL CAP,
# PRICE per litre and TOTAL (or YOU GET for a sell-back). Between them and the control, a vertical
# bar of the Tank: green up to the fuel in it, a dim pulsing green part for the fuel still to pump
# and the amount chosen (above the green when buying, the top of the tank when selling back), and a
# white line at the fuel cap when it's below the Tank. The button under the control reads BUY FUEL or SELL FUEL and asks first; buying may
# take the balance below €0, with the confirm's red debt warning. Yes pays (one Transaction) and the
# Hangar pumps the fuel (`Hangar.refuel()`). Fuel still to be pumped already counts toward the cap.
# Escape goes back to the Ship page. The Office creates it and calls it while the screen shows. It
# draws in the Office's palette, so a Workshop's is orange.

enum Row { AMOUNT, FULL, CONFIRM }

const STEP_LITRES := 1000.0
const BUY_TEXT := "< BUY +%s >"
const SELL_TEXT := "< SELL BACK -%s >"
const FULL_TEXT := "FULL"
const BUY_FUEL_TEXT := "BUY FUEL"
const SELL_FUEL_TEXT := "SELL FUEL"
const BUY_QUESTION := "BUY %s FOR %s?"
const SELL_QUESTION := "SELL %s FOR %s?"
const BOUGHT_NOTICE := "%s PUMPED INTO %s"
const SOLD_NOTICE := "%s SOLD BACK FROM %s"
const NOTHING_CHOSEN := "NO FUEL CHOSEN"
# Amounts this close to 0 litres count as none.
const NONE_LITRES := 0.5

const ACTION_SIZE := HangarScreen.ACTION_SIZE
const BAR_WIDTH := 36.0
const BAR_GAP := 24.0
# The pulsing part's alpha swings between these, PULSE_HZ times a second.
const PULSE_LOW := 0.15
const PULSE_HIGH := 0.5
const PULSE_HZ := 1.5
const ACTION_STEP := HangarScreen.ACTION_STEP
const STATUS_LABEL_WIDTH := HangarScreen.STATUS_LABEL_WIDTH

var office: Office
var hangar: Hangar
var economy: Economy
var ship: OwnedShip
# Where the fuel is bought: a pad's Workshop, or the station (null).
var place: Location = null
var row := Row.AMOUNT
# Litres to buy (above 0) or sell back (below 0).
var amount := 0.0


func _init(owner: Office, owner_hangar: Hangar, owner_economy: Economy) -> void:
	office = owner
	hangar = owner_hangar
	economy = owner_economy


func open(owned: OwnedShip) -> void:
	ship = owned
	place = office.place
	row = Row.AMOUNT
	amount = clampf(STEP_LITRES, lowest(), highest())


# Returns whether it used the event.
func handle_input(event: InputEvent) -> bool:
	if event.is_action_pressed("ui_up"):
		row = maxi(row - 1, 0) as Row
	elif event.is_action_pressed("ui_down"):
		row = mini(row + 1, Row.size() - 1) as Row
	elif event.is_action_pressed("ui_left"):
		amount = clampf(ceilf(amount / STEP_LITRES) * STEP_LITRES - STEP_LITRES, lowest(), highest())
	elif event.is_action_pressed("ui_right"):
		amount = clampf(floorf(amount / STEP_LITRES) * STEP_LITRES + STEP_LITRES, lowest(), highest())
	elif event.is_action_pressed("ui_accept"):
		if row == Row.FULL:
			amount = highest()
			row = Row.CONFIRM
		elif row == Row.CONFIRM:
			confirm()
	elif event.is_action_pressed("ui_cancel"):
		office.open_ship_page(ship, HangarScreen.Action.FUEL)
	else:
		return false
	return true


func confirm() -> void:
	if reason() != "":
		office.show_notice(reason(), true)
		return
	var owned := ship
	var at := place
	var kg := amount * OwnedShip.KG_PER_LITRE
	var litres := Office.litres(absf(kg))
	var cost := owned.fuel_cost(absf(kg), at)
	var on_yes := func() -> void:
		economy.pay_for_fuel(owned, kg, at)
		hangar.refuel(owned, kg)
		office.show_notice((BOUGHT_NOTICE if kg > 0.0 else SOLD_NOTICE) % [litres, owned.name])
		open(owned)
	if kg > 0.0:
		var after := economy.balance - cost
		office.ask(BUY_QUESTION % [litres, "%s"], Economy.eur(cost), on_yes,
			HangarScreen.DEBT_WARNING % Economy.eur(after) if after < 0 else "")
	else:
		office.ask(SELL_QUESTION % [litres, "%s"], Economy.eur(cost), on_yes)


# Litres in the tank once any pumping under way is done.
func in_tank() -> float:
	return Office.to_litres(hangar.fuel_after_pumping(ship))


func cap() -> float:
	return Office.to_litres(hangar.fuel_cap(ship))


# The control's ends: selling the whole tank back (nothing in a Workshop), and buying up to the fuel cap.
func lowest() -> float:
	return 0.0 if place else -in_tank()


func highest() -> float:
	return maxf(cap() - in_tank(), 0.0)


func buying() -> bool:
	return amount >= 0.0


# Observable state

# IN TANK 3 200 L (2 560 KG), FUEL CAP 6 000 L (4 800 KG), PRICE €0.60 / L, TOTAL €600 or YOU GET €600.
func lines() -> PackedStringArray:
	var texts := PackedStringArray()
	for pair: Array in status():
		texts.append("%s %s" % pair)
	return texts


func status() -> Array[Array]:
	var kg := OwnedShip.KG_PER_LITRE
	return [["IN TANK", Office.litres_and_kg(ship.fuel)], ["FUEL CAP", Office.litres_and_kg(cap() * kg)],
		["PRICE", Office.per_litre(ship.fuel_price(place))],
		["TOTAL" if buying() else "YOU GET", Economy.eur(ship.fuel_cost(absf(amount) * kg, place))]]


# The bar's levels as shares of the Tank: x the top of the green fill, y the top of the pulsing part
# above it (the tank after pumping and the chosen amount, or the fuel now when selling back below
# it), z the fuel cap.
func bar() -> Vector3:
	var tank := Office.to_litres(ship.tank())
	var now := Office.to_litres(ship.fuel)
	var after := in_tank() + amount
	return Vector3(minf(now, after), maxf(now, after), cap()) / tank


func amount_text() -> String:
	var litres := Office.litres(absf(amount) * OwnedShip.KG_PER_LITRE)
	return (BUY_TEXT if buying() else SELL_TEXT) % litres


func button_text() -> String:
	return BUY_FUEL_TEXT if buying() else SELL_FUEL_TEXT


# Why the button can't be taken, or "".
func reason() -> String:
	return NOTHING_CHOSEN if absf(amount) < NONE_LITRES else ""


# Drawing

# The ship's name and its fuel on the left, the control, FULL and the button on the right.
func draw(area: Rect2) -> void:
	var half := area.size.x / 2.0
	var y := area.position.y + Office.HEADER_SIZE
	office.draw_text(ship.name, Vector2(area.position.x, y), Office.HEADER_SIZE, half)
	y += Office.LINE_GAP + Office.TEXT_SIZE
	for pair: Array in status():
		y += Office.TEXT_SIZE + Office.LINE_GAP
		office.draw_text(pair[0], Vector2(area.position.x, y), Office.TEXT_SIZE, STATUS_LABEL_WIDTH)
		office.draw_text(pair[1], Vector2(area.position.x + STATUS_LABEL_WIDTH, y), Office.TEXT_SIZE,
			half - STATUS_LABEL_WIDTH, HORIZONTAL_ALIGNMENT_LEFT, office.palette.value)

	var buttons_x := area.position.x + half + BAR_WIDTH + BAR_GAP
	draw_bar(Rect2(area.position.x + half, area.position.y, BAR_WIDTH, 2.0 * ACTION_STEP + ACTION_SIZE.y))
	var button := Rect2(Vector2(buttons_x, area.position.y), Vector2(area.end.x - buttons_x, ACTION_SIZE.y))
	var no_popup := office.popup == Office.PopupKind.NONE
	for each: Row in Row.values():
		var label: String = [amount_text(), FULL_TEXT, button_text()][each]
		office.draw_action(button, label, "", each == row and no_popup, reason() if each == Row.CONFIRM else "")
		button.position.y += ACTION_STEP


# The Tank as a vertical bar filling upward: its frame, the green fill, the pulsing part and the cap.
func draw_bar(frame: Rect2) -> void:
	var levels := bar()
	var inner := frame.grow(-Office.LINE_WIDTH * 2.0)
	var level_y := func(share: float) -> float: return inner.end.y - inner.size.y * clampf(share, 0.0, 1.0)
	var fill_top: float = level_y.call(levels.x)
	var pulse_top: float = level_y.call(levels.y)
	var pulse := lerpf(PULSE_LOW, PULSE_HIGH, 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * TAU * PULSE_HZ))
	office.terminal.draw_rect(Rect2(inner.position.x, pulse_top, inner.size.x, fill_top - pulse_top),
		Color(office.palette.ink, pulse))
	office.terminal.draw_rect(Rect2(inner.position.x, fill_top, inner.size.x, inner.end.y - fill_top), office.palette.ink)
	office.terminal.draw_rect(frame, office.palette.ink, false, Office.LINE_WIDTH)
	if levels.z < 1.0:
		var cap_y: float = level_y.call(levels.z)
		office.terminal.draw_line(Vector2(frame.position.x, cap_y), Vector2(frame.end.x, cap_y), office.palette.value,
			Office.LINE_WIDTH)
