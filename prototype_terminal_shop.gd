extends Control
# PROTOTYPE: throwaway, never merge. Wayfinder ticket "The shop and Hangar screens on the
# Terminal" (#98). Run: Godot --path . prototype_terminal_shop.tscn
#
# Three variants of where the Hangar, upgrades, fuel, repair and the parachute repack sit on the
# Terminal, switchable with TAB. The Shipyard and the Workshop are one design shared by all three.
#   A  SHIP PAGE     4 tiles. Hangar is a list of berths; RETURN on a ship opens its own page with
#                    an action menu (PUT IN SERVICE, UPGRADES, FUEL, REPAIR, REPACK, SELL).
#   B  SERVICE TILES 6 tiles. Hangar only chooses the ship in service and sells; UPGRADES and
#                    SERVICE (fuel, repair, repack) are their own tiles with a < SHIP > picker.
#   C  TWO COLUMNS   4 tiles. Hangar is two columns like Transport offers: berths on the left, the
#                    chosen ship's tabs (STATUS / UPGRADES / FUEL) on the right.
# F1 cycles the balance (rich / tight / in debt), F2 toggles Contracts, F3 opens the Workshop.
# All state is in memory; every price is a placeholder for the "Prices" ticket.

enum Screen { MAIN, SHIPYARD, HANGAR, SHIP, UPGRADES, FUEL, SERVICE, OFFERS, BANK, WORKSHOP }

const FONT := preload("res://fonts/Silkscreen-Regular.ttf")
const VARIANTS := ["A", "B", "C"]
const VARIANT_NAMES := {"A": "SHIP PAGE", "B": "SERVICE TILES", "C": "TWO COLUMNS"}
const GREEN := Color(0.25, 1.0, 0.4)
const ORANGE := Color(1.0, 0.62, 0.15)
const WHITE := Color(0.92, 0.97, 0.94)
const RED := Color(1.0, 0.3, 0.25)
const BLACK := Color.BLACK
const MARGIN := 24.0
const PADDING := 32.0
const BORDER := 3.0
const ROW_H := 26.0
const TEXT := 16
const SMALL := 14
const BIG := 24
const NAME := 40
const BERTHS := 4
const KG_PER_L := 0.8
const FUEL_STEP := 500
const STATION_FUEL := 1.0
const PAD_FUEL := 1.6
const REPAIR_RATE := 0.6
const SELL_SHARE := 0.5
var BALANCES := [40000, 2100, -800]

var TYPES := {
	"SPARROW": {"flavour": "SMALL, LIGHT AND QUICK. BUILT FOR SHORT HOPS.", "price": 8000, "tank": 6000,
		"dry": 10000, "maxw": 22000, "seats": 4, "capacity": 8000, "thrust": 5, "handling": 5, "mult": 1.0},
	"MULE": {"flavour": "LONG, HEAVY AND SLOW. HAULS THE BIG LOADS.", "price": 24000, "tank": 15000,
		"dry": 20000, "maxw": 41000, "seats": 4, "capacity": 16000, "thrust": 2, "handling": 2, "mult": 2.0},
	"HALO": {"flavour": "A BALANCED RING FOR MIXED RUNS. OPEN AT THE NOSE.", "price": 40000, "tank": 10000,
		"dry": 14000, "maxw": 32000, "seats": 10, "capacity": 11000, "thrust": 4, "handling": 4, "mult": 1.5},
}
# Category, sub-heading, name, Sparrow price, dry mass share, effect, control, replaces.
var UPGRADES := [
	["FLIGHT AIDS", "", "LANDING PARACHUTE", 2000, 0.02, "HOLDS THE FALL TO ~70 PX/S. ONE OPENING PER REPACK", "SPACE", ""],
	["FLIGHT AIDS", "", "SIDE THRUSTERS", 3000, 0.03, "PUSH SIDEWAYS AT 30% THRUST, NOSE STAYS PUT", "A / D", ""],
	["FLIGHT AIDS", "", "REVERSE THRUST", 2500, 0.02, "THRUST OUT OF THE NOSE AT 50%", "DOWN", ""],
	["FLIGHT AIDS", "", "STRONGER ENGINE", 5000, 0.04, "THRUST X1.25   BURN X1.25", "", ""],
	["CAPACITY", "", "LARGER TANK", 3500, 0.03, "TANK X1.5", "", ""],
	["CAPACITY", "FUEL SYSTEM", "FUEL-EFFICIENT ENGINE", 3000, 0.02, "BURN X0.8", "", ""],
	["CAPACITY", "FUEL SYSTEM", "MODERN FUEL SYSTEM", 6000, 0.03, "BURN X0.6", "", "FUEL-EFFICIENT ENGINE"],
	["PAINT", "", "PAINT: RED STRIPE", 400, 0.0, "A RED STRIPE ON THE HULL", "", "PAINT: ALL WHITE"],
]

var variant := "A"
var balance_index := 1
var contracts := false
var screen := Screen.MAIN
var back_stack: Array = []
var cursor := 0
var ships: Array = []
var counters := {"SPARROW": 1, "MULE": 1, "HALO": 0}
var in_service := 0
var ship_index := 0
var shipyard_index := 0
var tab := 0
var fuel_amount := 0
var popup := {}
var popup_yes := true
var notice := ""
var notice_red := false
var notice_left := 0.0
var stops: Array = []


func _ready() -> void:
	ships = [
		{"name": "SPARROW 1", "type": "SPARROW", "cond": 92, "fuel": 3200, "chute": "USED",
			"upgrades": ["LANDING PARACHUTE", "SIDE THRUSTERS", "PAINT: ALL WHITE"]},
		{"name": "MULE 1", "type": "MULE", "cond": 0, "fuel": 1400, "chute": "", "upgrades": ["STRONGER ENGINE"]},
	]
	set_anchors_preset(Control.PRESET_FULL_RECT)
	set_process(true)
	dump()


func _process(delta: float) -> void:
	if notice_left > 0.0:
		notice_left -= delta
		queue_redraw()


# Model

func balance() -> int:
	return BALANCES[balance_index]


func ship() -> Dictionary:
	return ships[ship_index]


func type_of(s: Dictionary) -> Dictionary:
	return TYPES[s.type]


func upgrade(name: String) -> Array:
	for u: Array in UPGRADES:
		if u[2] == name:
			return u
	return []


func upgrade_price(u: Array, s: Dictionary) -> int:
	return int(u[3] * type_of(s).mult)


func upgrade_mass(u: Array, s: Dictionary) -> int:
	return int(u[4] * type_of(s).dry)


func value(s: Dictionary) -> int:
	var v: int = type_of(s).price
	for name: String in s.upgrades:
		if not upgrade(name).is_empty():
			v += upgrade_price(upgrade(name), s)
	return v


func repair_cost(s: Dictionary) -> int:
	return int((100 - s.cond) / 100.0 * REPAIR_RATE * value(s))


func sale_price(s: Dictionary) -> int:
	return maxi(int(value(s) * SELL_SHARE) - repair_cost(s), 0)


func repack_cost(s: Dictionary) -> int:
	return int(300 * type_of(s).mult)


func dry_mass(s: Dictionary) -> int:
	var m: int = type_of(s).dry
	for name: String in s.upgrades:
		if not upgrade(name).is_empty():
			m += upgrade_mass(upgrade(name), s)
	return m


func tank_l(s: Dictionary) -> int:
	return int(type_of(s).tank * (1.5 if "LARGER TANK" in s.upgrades else 1.0))


func fuel_cap(s: Dictionary) -> int:
	return mini(tank_l(s), int((type_of(s).maxw - dry_mass(s)) / KG_PER_L))


func cargo(s: Dictionary) -> int:
	return clampi(type_of(s).maxw - dry_mass(s) - int(tank_l(s) * KG_PER_L), 0, type_of(s).capacity)


func locked(s: Dictionary) -> bool:
	return contracts and ships.find(s) == in_service


func wreck(s: Dictionary) -> bool:
	return s.cond <= 0


func short(price: int) -> String:
	return "NOT ENOUGH MONEY: %s SHORT" % eur(price - balance())


# Each check returns "" when allowed, otherwise the reason shown in red.
func why_not_upgrade(u: Array, s: Dictionary) -> String:
	if u[2] in s.upgrades:
		return "FITTED"
	if wreck(s):
		return "WRECK: REPAIR IT FIRST"
	if locked(s):
		return "LOCKED: CONTRACTS ACCEPTED"
	if balance() - upgrade_price(u, s) < 0:
		return short(upgrade_price(u, s))
	return ""


func why_not_service(s: Dictionary) -> String:
	if ships.find(s) == in_service:
		return "ALREADY IN SERVICE"
	if contracts:
		return "LOCKED: CONTRACTS ACCEPTED"
	if wreck(s):
		return "WRECK: REPAIR IT FIRST"
	return ""


func why_not_sell(s: Dictionary) -> String:
	return "THE SHIP IN SERVICE CAN'T BE SOLD" if ships.find(s) == in_service else ""


func why_not_repair(s: Dictionary) -> String:
	return "NO DAMAGE" if s.cond >= 100 else ""


func why_not_repack(s: Dictionary) -> String:
	if s.chute == "PACKED":
		return "ALREADY PACKED"
	if wreck(s):
		return "WRECK: REPAIR IT FIRST"
	return ""


func why_not_buy_ship(type: String) -> String:
	if ships.size() >= BERTHS:
		return "HANGAR FULL %d/%d: SELL A SHIP FIRST" % [ships.size(), BERTHS]
	if balance() - TYPES[type].price < 0:
		return short(TYPES[type].price)
	return ""


func why_not_fuel(s: Dictionary) -> String:
	if wreck(s):
		return "WRECK: REPAIR IT FIRST"
	if fuel_amount == 0:
		return "CHOOSE AN AMOUNT"
	return ""


func fuel_price() -> float:
	return PAD_FUEL if screen == Screen.WORKSHOP else STATION_FUEL


func fuel_range(s: Dictionary) -> Vector2i:
	var low := 0 if screen == Screen.WORKSHOP else -int(s.fuel)
	return Vector2i(low, fuel_cap(s) - int(s.fuel))


func adjust_fuel(step: int) -> void:
	var r := fuel_range(ship())
	fuel_amount = clampi(fuel_amount + step * FUEL_STEP, r.x, r.y)


# Actions: each asks first, then reports what happened.

func ask(text: String, on_yes: Callable) -> void:
	popup = {"text": text, "yes": on_yes}
	popup_yes = true


func say(text: String, red := false) -> void:
	notice = text
	notice_red = red
	notice_left = 3.0


func pay(amount: int) -> void:
	BALANCES[balance_index] -= amount


func try(reason: String, text: String, on_yes: Callable) -> void:
	if reason != "":
		say(reason, true)
	else:
		ask(text, on_yes)


func buy_upgrade(u: Array) -> void:
	var s := ship()
	var text := "BUY %s FOR %s?" % [u[2], eur(upgrade_price(u, s))]
	if u[7] != "" and u[7] in s.upgrades:
		text = "BUY %s FOR %s? IT REPLACES %s" % [u[2], eur(upgrade_price(u, s)), u[7]]
	try(why_not_upgrade(u, s), text, func() -> void:
		pay(upgrade_price(u, s))
		s.upgrades.erase(u[7])
		s.upgrades.append(u[2])
		if u[2] == "LANDING PARACHUTE":
			s.chute = "PACKED"
		say("%s FITTED TO %s" % [u[2], s.name]))


func put_in_service(s: Dictionary) -> void:
	try(why_not_service(s), "PUT %s IN SERVICE?" % s.name, func() -> void:
		in_service = ships.find(s)
		say("%s IS IN SERVICE" % s.name))


func sell(s: Dictionary) -> void:
	try(why_not_sell(s), "SELL %s FOR %s?" % [s.name, eur(sale_price(s))], func() -> void:
		pay(-sale_price(s))
		var serving: Dictionary = ships[in_service]
		ships.erase(s)
		in_service = ships.find(serving)
		ship_index = in_service
		say("%s SOLD FOR %s" % [s.name, eur(sale_price(s))]))


func repair(s: Dictionary) -> void:
	try(why_not_repair(s), "REPAIR %s FOR %s?" % [s.name, eur(repair_cost(s) * (1.5 if screen == Screen.WORKSHOP else 1.0))],
		func() -> void:
			pay(int(repair_cost(s) * (1.5 if screen == Screen.WORKSHOP else 1.0)))
			s.cond = 100
			say("%s REPAIRED" % s.name))


func repack(s: Dictionary) -> void:
	try(why_not_repack(s), "REPACK THE PARACHUTE OF %s FOR %s?" % [s.name, eur(repack_cost(s))], func() -> void:
		pay(repack_cost(s))
		s.chute = "PACKED"
		say("PARACHUTE PACKED"))


func confirm_fuel(s: Dictionary) -> void:
	var total := int(fuel_amount * fuel_price())
	var text := "BUY %s FOR %s?" % [litres(fuel_amount), eur(total)]
	if fuel_amount < 0:
		text = "SELL %s FOR %s?" % [litres(-fuel_amount), eur(-total)]
	try(why_not_fuel(s), text, func() -> void:
		pay(total)
		s.fuel += fuel_amount
		say(("%s BOUGHT" if fuel_amount > 0 else "%s SOLD BACK") % litres(absi(fuel_amount)))
		fuel_amount = 0)


func buy_ship(type: String) -> void:
	try(why_not_buy_ship(type), "BUY A %s FOR %s?" % [type, eur(TYPES[type].price)], func() -> void:
		pay(TYPES[type].price)
		counters[type] += 1
		var name := "%s %d" % [type, counters[type]]
		ships.append({"name": name, "type": type, "cond": 100, "fuel": TYPES[type].tank, "chute": "", "upgrades": []})
		say("%s IS IN THE HANGAR (%d/%d)" % [name, ships.size(), BERTHS]))


# Navigation

func go(to: Screen) -> void:
	back_stack.append([screen, cursor])
	notice_left = 0.0
	screen = to
	cursor = 0
	fuel_amount = 0
	tab = 0
	if to in [Screen.UPGRADES, Screen.SERVICE] and variant == "B":
		ship_index = in_service
	if to == Screen.WORKSHOP:
		ship_index = in_service


func back() -> void:
	if back_stack.is_empty():
		return
	var last: Array = back_stack.pop_back()
	screen = last[0]
	cursor = last[1]
	fuel_amount = 0


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	var key: int = event.keycode
	if key == KEY_TAB:
		variant = VARIANTS[(VARIANTS.find(variant) + 1) % VARIANTS.size()]
		screen = Screen.MAIN
		back_stack.clear()
		cursor = 0
	elif key == KEY_F1:
		balance_index = (balance_index + 1) % BALANCES.size()
	elif key == KEY_F2:
		contracts = not contracts
	elif key == KEY_F3:
		if screen == Screen.WORKSHOP:
			back()
		else:
			go(Screen.WORKSHOP)
	elif not popup.is_empty():
		popup_input(key)
	elif key == KEY_UP:
		move(-1)
	elif key == KEY_DOWN:
		move(1)
	elif key in [KEY_LEFT, KEY_RIGHT]:
		var step := -1 if key == KEY_LEFT else 1
		var stop: Dictionary = stops[cursor] if cursor < stops.size() else {}
		if stop.has("adjust"):
			stop.adjust.call(step)
		else:
			move(step)
	elif key in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		if cursor < stops.size():
			stops[cursor].action.call()
	elif key == KEY_ESCAPE:
		back()
	else:
		return
	get_viewport().set_input_as_handled()
	queue_redraw()
	dump()


func popup_input(key: int) -> void:
	if key in [KEY_LEFT, KEY_RIGHT]:
		popup_yes = key == KEY_LEFT
	elif key in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		var on_yes: Callable = popup.yes
		popup = {}
		if popup_yes:
			on_yes.call()
	elif key == KEY_ESCAPE:
		popup = {}


func move(step: int) -> void:
	if stops.is_empty():
		return
	cursor = clampi(cursor + step, 0, stops.size() - 1)
	var stop: Dictionary = stops[cursor]
	if stop.has("hover"):
		stop.hover.call()


func dump() -> void:
	var names := []
	for s: Dictionary in ships:
		names.append("%s%s %d%% %dl %s" % [s.name, "*" if ships.find(s) == in_service else "", s.cond, s.fuel, s.upgrades])
	print("[proto] variant=%s screen=%s balance=%d contracts=%s ships=%s" % [variant, Screen.keys()[screen], balance(), contracts, names])


# Drawing helpers

func fg() -> Color:
	return ORANGE if screen == Screen.WORKSHOP else GREEN


func dim() -> Color:
	return Color(fg(), 0.3)


func text(t: String, pos: Vector2, size := TEXT, color := Color.TRANSPARENT, width := -1.0,
		align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	draw_string(FONT, pos, t, align, width, size, fg() if color == Color.TRANSPARENT else color)


func text_w(t: String, size := TEXT) -> float:
	return FONT.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


func label_value(label: String, val: String, pos: Vector2, label_w := 200.0, color := WHITE, size := TEXT) -> void:
	text(label, pos, size)
	text(val, pos + Vector2(label_w, 0), size, color)


# A selectable stop: drawn inverted when the cursor is on it. `disabled` draws it dim.
func stop(rect: Rect2, label: String, action: Callable, extra := {}) -> void:
	var index := stops.size()
	var entry := {"action": action}
	entry.merge(extra)
	stops.append(entry)
	var on := index == cursor and popup.is_empty()
	var disabled: bool = extra.get("disabled", false)
	var c := dim() if disabled else fg()
	if on:
		draw_rect(rect, c)
	elif extra.get("boxed", true):
		draw_rect(rect, c, false, 2.0)
	var right: String = extra.get("right", "")
	var y := rect.position.y + rect.size.y / 2.0 + SMALL / 2.0
	text(label, Vector2(rect.position.x + 8, y), SMALL, BLACK if on else c, rect.size.x - 16,
		extra.get("align", HORIZONTAL_ALIGNMENT_LEFT))
	if right != "":
		text(right, Vector2(rect.position.x + 8, y), SMALL, BLACK if on else (dim() if disabled else extra.get("right_color", WHITE)),
			rect.size.x - 16, HORIZONTAL_ALIGNMENT_RIGHT)


func button(pos: Vector2, label: String, reason: String, action: Callable, width := 260.0) -> float:
	stop(Rect2(pos, Vector2(width, 30)), label, action, {"disabled": reason != "", "align": HORIZONTAL_ALIGNMENT_CENTER,
		"reason": reason})
	if reason != "" and pos.x + width + 14 + text_w(reason, SMALL) < size.x - MARGIN - PADDING:
		text(reason, pos + Vector2(width + 14, 21), SMALL, RED)
	return pos.y + 40


func eur(amount: float) -> String:
	var a := int(round(amount))
	return ("-€" if a < 0 else "€") + grouped(absi(a))


func grouped(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = " " + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out


func litres(l: int) -> String:
	return "%s L (%s KG)" % [grouped(l), grouped(int(l * KG_PER_L))]


func condition_text(s: Dictionary) -> String:
	return "WRECKED" if wreck(s) else "%d%%" % s.cond


# Frame

func _draw() -> void:
	stops.clear()
	var view := Rect2(Vector2.ZERO, size)
	draw_rect(view, BLACK)
	var frame := view.grow(-MARGIN)
	draw_rect(frame, fg(), false, BORDER)
	var inner := frame.grow(-PADDING)
	var header := "ORBITAL FREIGHT CO. // " + title()
	if screen == Screen.WORKSHOP:
		header = "MINE PAD // WORKSHOP"
	text(header, Vector2(inner.position.x, inner.position.y + BIG), BIG)
	text(eur(balance()), Vector2(inner.position.x, inner.position.y + BIG), BIG,
		RED if balance() < 0 else WHITE, inner.size.x, HORIZONTAL_ALIGNMENT_RIGHT)
	var rule_y := inner.position.y + BIG + 14
	draw_line(Vector2(frame.position.x, rule_y), Vector2(frame.end.x, rule_y), fg(), 2.0)
	var hint_rule := inner.end.y - TEXT - 14
	draw_line(Vector2(frame.position.x, hint_rule), Vector2(frame.end.x, hint_rule), fg(), 2.0)
	text(hint(), Vector2(inner.position.x, inner.end.y), SMALL, Color.TRANSPARENT, inner.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	var body := Rect2(inner.position.x, rule_y + 14, inner.size.x, hint_rule - rule_y - 28)
	match screen:
		Screen.MAIN: draw_main(body)
		Screen.SHIPYARD: draw_shipyard(body)
		Screen.HANGAR:
			match variant:
				"A": draw_hangar_a(body)
				"B": draw_hangar_b(body)
				"C": draw_hangar_c(body)
		Screen.SHIP: draw_ship_page(body)
		Screen.UPGRADES: draw_upgrades(body, variant == "B")
		Screen.FUEL: draw_fuel_page(body)
		Screen.SERVICE: draw_service(body)
		Screen.WORKSHOP: draw_workshop(body)
		Screen.OFFERS, Screen.BANK:
			text("UNCHANGED: SEE THE GAME", body.get_center() - Vector2(150, 0), TEXT, Color(fg(), 0.5))
	cursor = clampi(cursor, 0, maxi(stops.size() - 1, 0))
	if notice_left > 0.0:
		text(notice, Vector2(body.position.x, body.end.y + 4), SMALL, RED if notice_red else WHITE, body.size.x,
			HORIZONTAL_ALIGNMENT_RIGHT)
	if not popup.is_empty():
		draw_popup(view)
	var y := 0.0
	while y < size.y:
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(0, 0, 0, 0.35), 1.0)
		y += 4.0
	draw_switcher(view)


func title() -> String:
	match screen:
		Screen.MAIN: return "OFFICE"
		Screen.SHIPYARD: return "SHIPYARD"
		Screen.HANGAR: return "HANGAR"
		Screen.SHIP: return "HANGAR // " + ship().name
		Screen.UPGRADES: return "UPGRADES" if variant == "B" else "HANGAR // %s // UPGRADES" % ship().name
		Screen.FUEL: return "HANGAR // %s // FUEL" % ship().name
		Screen.SERVICE: return "SERVICE"
		Screen.OFFERS: return "TRANSPORT OFFERS"
		Screen.BANK: return "BANK ACCOUNT"
	return ""


func hint() -> String:
	if not popup.is_empty():
		return "LEFT RIGHT CHOOSE   RETURN CONFIRM   ESC NO"
	if screen == Screen.MAIN:
		return "ARROWS MOVE   RETURN OPEN   ESC LEAVE"
	if screen == Screen.SHIPYARD:
		return "LEFT RIGHT BROWSE   RETURN BUY   ESC BACK"
	return "UP DOWN MOVE   LEFT RIGHT CHANGE   RETURN SELECT   ESC BACK"


func draw_switcher(view: Rect2) -> void:
	var t := "PROTOTYPE   TAB  %s: %s    F1  %s    F2  %s    F3  WORKSHOP" % [variant, VARIANT_NAMES[variant],
		["RICH", "TIGHT", "IN DEBT"][balance_index], "CONTRACTS" if contracts else "NO CONTRACTS"]
	var w := text_w(t, 12) + 24
	var r := Rect2(Vector2(view.get_center().x - w / 2.0, view.end.y - 21), Vector2(w, 20))
	draw_rect(r, Color(1, 1, 1, 0.92))
	draw_string(FONT, Vector2(r.position.x + 12, r.end.y - 5), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, BLACK)


func draw_popup(view: Rect2) -> void:
	var t: String = popup.text
	var w := maxf(440.0, text_w(t, 18) + 64)
	var box := Rect2(view.get_center() - Vector2(w, 180) / 2.0, Vector2(w, 180))
	draw_rect(box, BLACK)
	draw_rect(box, fg(), false, BORDER)
	text(t, Vector2(box.position.x, box.position.y + 56), 18, Color.TRANSPARENT, box.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	var x := box.get_center().x - 144
	for yes: bool in [true, false]:
		var b := Rect2(Vector2(x, box.end.y - 70), Vector2(120, 40))
		var on := yes == popup_yes
		if on:
			draw_rect(b, fg())
		else:
			draw_rect(b, fg(), false, 2.0)
		text("YES" if yes else "NO", Vector2(b.position.x, b.get_center().y + 8), TEXT, BLACK if on else fg(),
			b.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		x += 168


func blocks(n: int, pos: Vector2) -> void:
	for i in 5:
		var r := Rect2(pos + Vector2(i * 20, 0), Vector2(14, 14))
		if i < n:
			draw_rect(r, fg())
		else:
			draw_rect(r, dim(), false, 1.0)


func draw_wireframe(type: String, box: Rect2) -> void:
	var outlines := {"SPARROW": ShipType.SPARROW.hull, "MULE": ShipType.MULE.hull, "HALO": ShipType.HALO.hull}
	var outline: PackedVector2Array = outlines[type]
	var bounds := Rect2(outline[0], Vector2.ZERO)
	for p: Vector2 in outline:
		bounds = bounds.expand(p)
	var scale := minf(box.size.x * 0.8 / bounds.size.x, box.size.y * 0.8 / bounds.size.y)
	var points := PackedVector2Array()
	for p: Vector2 in outline:
		points.append(box.get_center() + (p - bounds.get_center()) * scale)
	points.append(points[0])
	draw_polyline(points, fg(), BORDER)


# Main screen

func tiles() -> Array:
	if variant == "B":
		return [["SHIPYARD", Screen.SHIPYARD], ["HANGAR", Screen.HANGAR], ["UPGRADES", Screen.UPGRADES],
			["SERVICE", Screen.SERVICE], ["TRANSPORT OFFERS", Screen.OFFERS], ["BANK ACCOUNT", Screen.BANK]]
	return [["SHIPYARD", Screen.SHIPYARD], ["HANGAR", Screen.HANGAR], ["TRANSPORT OFFERS", Screen.OFFERS],
		["BANK ACCOUNT", Screen.BANK]]


func draw_main(body: Rect2) -> void:
	var all := tiles()
	var per_row := 3 if all.size() == 6 else 4
	var tile := Vector2(300, 140) if per_row == 3 else Vector2(225, 160)
	var gap := 32.0
	var rows := ceili(all.size() / float(per_row))
	var top := body.get_center().y - (rows * tile.y + (rows - 1) * gap) / 2.0
	for i in all.size():
		var col := i % per_row
		var row := i / per_row
		var x := body.get_center().x - (per_row * tile.x + (per_row - 1) * gap) / 2.0 + col * (tile.x + gap)
		var to: Screen = all[i][1]
		var sub := ""
		if to == Screen.HANGAR:
			sub = "%d/%d BERTHS" % [ships.size(), BERTHS]
		var rect := Rect2(Vector2(x, top + row * (tile.y + gap)), tile)
		stop(rect, "", func() -> void: go(to), {"right": ""})
		var on := stops.size() - 1 == cursor
		text(all[i][0], Vector2(rect.position.x, rect.get_center().y + 8), 20, BLACK if on else fg(), rect.size.x,
			HORIZONTAL_ALIGNMENT_CENTER)
		if sub != "":
			text(sub, Vector2(rect.position.x, rect.get_center().y + 36), SMALL, BLACK if on else WHITE, rect.size.x,
				HORIZONTAL_ALIGNMENT_CENTER)


# Shipyard: one design for every variant

func draw_shipyard(body: Rect2) -> void:
	var names := TYPES.keys()
	var type: String = names[shipyard_index]
	var t: Dictionary = TYPES[type]
	text("< %d/%d >" % [shipyard_index + 1, names.size()], Vector2(body.position.x, body.position.y + TEXT), TEXT,
		Color.TRANSPARENT, body.size.x, HORIZONTAL_ALIGNMENT_RIGHT)
	text("HANGAR %d/%d" % [ships.size(), BERTHS], Vector2(body.position.x, body.position.y + TEXT), TEXT, WHITE)
	var half := body.size.x / 2.0
	draw_wireframe(type, Rect2(body.position + Vector2(0, 30), Vector2(half, body.size.y - 30)))
	var x := body.position.x + half
	var y := body.position.y + 70
	text(type, Vector2(x, y), NAME)
	var owned := 0
	for s: Dictionary in ships:
		if s.type == type:
			owned += 1
	if owned > 0:
		text("OWNED: %d" % owned, Vector2(x + text_w(type, NAME) + 16, y - 12), SMALL, WHITE)
	y += 26
	text(t.flavour, Vector2(x, y), SMALL)
	y += 40
	label_value("PRICE", eur(t.price), Vector2(x, y), 200, WHITE, 20)
	y += 32
	label_value("TANK", "%s L  FULL" % grouped(t.tank), Vector2(x, y), 200)
	y += 26
	label_value("SEATS", str(t.seats), Vector2(x, y), 200)
	y += 26
	label_value("CARGO", "%s KG" % grouped(t.maxw - t.dry - int(t.tank * KG_PER_L)), Vector2(x, y), 200)
	y += 26
	label_value("MAX CAPACITY", "%s KG" % grouped(t.capacity), Vector2(x, y), 200)
	y += 26
	text("THRUST", Vector2(x, y))
	blocks(t.thrust, Vector2(x + 200, y - 14))
	y += 26
	text("HANDLING", Vector2(x, y))
	blocks(t.handling, Vector2(x + 200, y - 14))
	y += 22
	var reason := why_not_buy_ship(type)
	stop(Rect2(Vector2(x, y), Vector2(200, 30)), "BUY  " + eur(t.price), func() -> void: buy_ship(type),
		{"disabled": reason != "", "align": HORIZONTAL_ALIGNMENT_CENTER,
		"adjust": func(step: int) -> void: shipyard_index = posmod(shipyard_index + step, names.size())})
	if reason != "":
		text(reason, Vector2(x, y + 52), SMALL, RED)


# Shared panels

func draw_status(s: Dictionary, pos: Vector2, label_w := 170.0) -> float:
	var y := pos.y
	label_value("CONDITION", condition_text(s), Vector2(pos.x, y), label_w, RED if wreck(s) else WHITE)
	y += 24
	label_value("FUEL", "%s / %s L" % [grouped(s.fuel), grouped(tank_l(s))], Vector2(pos.x, y), label_w)
	y += 24
	label_value("DRY MASS", "%s KG" % grouped(dry_mass(s)), Vector2(pos.x, y), label_w)
	y += 24
	label_value("CARGO", "%s KG" % grouped(cargo(s)), Vector2(pos.x, y), label_w)
	y += 24
	if "LANDING PARACHUTE" in s.upgrades:
		label_value("PARACHUTE", s.chute, Vector2(pos.x, y), label_w, RED if s.chute == "USED" else WHITE)
		y += 24
	label_value("VALUE", eur(value(s)), Vector2(pos.x, y), label_w)
	y += 24
	return y


func draw_fitted(s: Dictionary, pos: Vector2) -> float:
	var y := pos.y
	text("FITTED", pos, SMALL)
	y += 22
	if s.upgrades.is_empty():
		text("NONE", Vector2(pos.x, y), SMALL, WHITE)
		return y + 22
	for name: String in s.upgrades:
		text(name, Vector2(pos.x, y), SMALL, WHITE)
		y += 20
	return y


func draw_upgrade_list(area: Rect2, s: Dictionary) -> Array:
	var hovered := []
	var y := area.position.y
	var last_cat := ""
	var last_sub := ""
	for u: Array in UPGRADES:
		if u[0] != last_cat:
			text(u[0], Vector2(area.position.x, y + 16), SMALL, WHITE)
			draw_line(Vector2(area.position.x, y + 22), Vector2(area.end.x, y + 22), dim(), 1.0)
			y += 30
			last_cat = u[0]
			last_sub = ""
		if u[1] != last_sub:
			text(u[1], Vector2(area.position.x + 12, y + 14), 12, Color(fg(), 0.6))
			y += 20
			last_sub = u[1]
		var reason := why_not_upgrade(u, s)
		var right := "FITTED" if u[2] in s.upgrades else eur(upgrade_price(u, s))
		var on := stops.size() == cursor
		if on:
			hovered = u
		stop(Rect2(Vector2(area.position.x, y), Vector2(area.size.x, ROW_H - 2)), u[2], func() -> void: buy_upgrade(u),
			{"disabled": reason == "FITTED", "boxed": false, "right": right,
			"right_color": RED if reason.begins_with("NOT ENOUGH") else WHITE})
		y += ROW_H
	return hovered


# The chosen upgrade's offer: effect, mass, REPLACES, and why it can't be bought.
func draw_upgrade_detail(u: Array, s: Dictionary, pos: Vector2, width: float) -> void:
	if u.is_empty():
		text("CHOOSE AN UPGRADE", pos, SMALL, Color(fg(), 0.5))
		return
	var y := pos.y
	text(u[2], Vector2(pos.x, y), 20)
	y += 30
	text(u[5], Vector2(pos.x, y), SMALL, WHITE, width)
	y += 26
	if u[6] != "":
		label_value("CONTROL", u[6], Vector2(pos.x, y), 150, WHITE, SMALL)
		y += 22
	var m := upgrade_mass(u, s)
	label_value("DRY MASS", "+%s KG" % grouped(m), Vector2(pos.x, y), 150, WHITE, SMALL)
	y += 22
	label_value("CARGO", "%s -> %s KG" % [grouped(cargo(s)), grouped(maxi(cargo(s) - m, 0))], Vector2(pos.x, y), 150,
		WHITE, SMALL)
	y += 22
	if u[7] != "":
		label_value("REPLACES", u[7], Vector2(pos.x, y), 150, WHITE, SMALL)
		y += 22
	label_value("PRICE", eur(upgrade_price(u, s)), Vector2(pos.x, y), 150, WHITE, SMALL)
	y += 30
	var reason := why_not_upgrade(u, s)
	if reason != "" and reason != "FITTED":
		text(reason, Vector2(pos.x, y), SMALL, RED, width)
	elif reason == "":
		text("RETURN TO BUY", Vector2(pos.x, y), SMALL, Color(fg(), 0.6))


func draw_fuel_panel(s: Dictionary, pos: Vector2, width := 420.0) -> float:
	var y := pos.y
	label_value("IN TANK", litres(s.fuel), Vector2(pos.x, y), 170)
	y += 24
	label_value("FUEL CAP", "%s L" % grouped(fuel_cap(s)), Vector2(pos.x, y), 170)
	y += 24
	label_value("PRICE", "€%.2f / L" % fuel_price(), Vector2(pos.x, y), 170)
	y += 18
	var amount := ("BUY +%s L" if fuel_amount >= 0 else "SELL BACK %s L") % grouped(absi(fuel_amount))
	stop(Rect2(Vector2(pos.x, y), Vector2(width, 30)), "<  %s  >" % amount, func() -> void: confirm_fuel(s),
		{"adjust": func(step: int) -> void: adjust_fuel(step), "align": HORIZONTAL_ALIGNMENT_CENTER})
	y += 38
	stop(Rect2(Vector2(pos.x, y), Vector2(width, 30)), "FULL", func() -> void:
		fuel_amount = fuel_cap(s) - int(s.fuel)
		queue_redraw(), {"align": HORIZONTAL_ALIGNMENT_CENTER})
	y += 58
	var total := int(fuel_amount * fuel_price())
	label_value("YOU GET" if total < 0 else "TOTAL", eur(absi(total)), Vector2(pos.x, y), 170)
	y += 18
	y = button(Vector2(pos.x, y), "BUY FUEL" if fuel_amount >= 0 else "SELL FUEL", why_not_fuel(s),
		func() -> void: confirm_fuel(s), width)
	return y


# Variant A: berth list, then a page per ship

func draw_hangar_a(body: Rect2) -> void:
	text("BERTHS %d/%d" % [ships.size(), BERTHS], Vector2(body.position.x, body.position.y + 16), TEXT, WHITE)
	var cols := [0.0, 260.0, 420.0, 600.0, 760.0]
	var y := body.position.y + 40
	for h: Array in [["SHIP", 0], ["CONDITION", 1], ["FUEL", 2], ["PARACHUTE", 3], ["UPGRADES", 4]]:
		text(h[0], Vector2(body.position.x + 8 + cols[h[1]], y + 14), 12, Color(fg(), 0.6))
	y += 24
	for s: Dictionary in ships:
		var i := ships.find(s)
		stop(Rect2(Vector2(body.position.x, y), Vector2(body.size.x, 32)), "", func() -> void:
			ship_index = i
			go(Screen.SHIP), {"boxed": false})
		var on := stops.size() - 1 == cursor
		var c := BLACK if on else fg()
		var w := BLACK if on else WHITE
		var ty := y + 22
		text(s.name + ("  IN SERVICE" if i == in_service else ""), Vector2(body.position.x + 8, ty), TEXT, c)
		text(condition_text(s), Vector2(body.position.x + 8 + cols[1], ty), TEXT, BLACK if on else (RED if wreck(s) else WHITE))
		text("%s L" % grouped(s.fuel), Vector2(body.position.x + 8 + cols[2], ty), TEXT, w)
		text(s.chute if s.chute != "" else "-", Vector2(body.position.x + 8 + cols[3], ty), TEXT, w)
		text(str(s.upgrades.size()), Vector2(body.position.x + 8 + cols[4], ty), TEXT, w)
		y += 36
	for i in BERTHS - ships.size():
		stop(Rect2(Vector2(body.position.x, y), Vector2(body.size.x, 32)), "EMPTY BERTH: OPEN THE SHIPYARD",
			func() -> void: go(Screen.SHIPYARD), {"boxed": false, "disabled": true})
		y += 36


func draw_ship_page(body: Rect2) -> void:
	var s := ship()
	var third := body.size.x / 3.0
	draw_wireframe(s.type, Rect2(body.position, Vector2(third, body.size.y * 0.7)))
	var y := body.position.y + 28
	text(s.name, Vector2(body.position.x, y), BIG)
	if ships.find(s) == in_service:
		text("IN SERVICE", Vector2(body.position.x, y + 22), SMALL, WHITE)
	draw_fitted(s, Vector2(body.position.x, body.position.y + body.size.y * 0.72))
	var x := body.position.x + third
	draw_status(s, Vector2(x, body.position.y + 24))
	var bx := body.position.x + 2.0 * third
	var by := body.position.y + 4
	var w := third
	by = button(Vector2(bx, by), "PUT IN SERVICE", why_not_service(s), func() -> void: put_in_service(s), w)
	by = button(Vector2(bx, by), "UPGRADES", "", func() -> void: go(Screen.UPGRADES), w)
	by = button(Vector2(bx, by), "FUEL", "WRECK: REPAIR IT FIRST" if wreck(s) else "", func() -> void: go(Screen.FUEL), w)
	by = button(Vector2(bx, by), "REPAIR  " + eur(repair_cost(s)), why_not_repair(s), func() -> void: repair(s), w)
	if "LANDING PARACHUTE" in s.upgrades:
		by = button(Vector2(bx, by), "REPACK PARACHUTE  " + eur(repack_cost(s)), why_not_repack(s),
			func() -> void: repack(s), w)
	by = button(Vector2(bx, by), "SELL  " + eur(sale_price(s)), why_not_sell(s), func() -> void: sell(s), w)
	# Reasons would run off the right edge: the cursor's reason shows below the column instead.
	if cursor < stops.size() and stops[cursor].get("reason", "") != "":
		text(stops[cursor].reason, Vector2(bx, by + 10), SMALL, RED, w)


func draw_fuel_page(body: Rect2) -> void:
	var s := ship()
	draw_wireframe(s.type, Rect2(body.position, Vector2(body.size.x / 3.0, body.size.y)))
	draw_fuel_panel(s, Vector2(body.position.x + body.size.x / 3.0 + 40, body.position.y + 24))


# The upgrade list on the left, the chosen offer on the right. Variant B adds a ship picker.
func draw_upgrades(body: Rect2, picker: bool) -> void:
	var top := body.position.y
	if picker:
		top = draw_picker(body)
	var s := ship()
	var list_w := body.size.x * 0.55
	var hovered := draw_upgrade_list(Rect2(Vector2(body.position.x, top), Vector2(list_w, body.size.y)), s)
	draw_upgrade_detail(hovered, s, Vector2(body.position.x + list_w + 40, top + 24), body.size.x - list_w - 40)


func draw_picker(body: Rect2) -> float:
	var s := ship()
	var label := "<  %s%s  >" % [s.name, "  (IN SERVICE)" if ships.find(s) == in_service else ""]
	stop(Rect2(body.position, Vector2(420, 30)), label, func() -> void: pass,
		{"adjust": func(step: int) -> void:
			ship_index = posmod(ship_index + step, ships.size())
			fuel_amount = 0, "align": HORIZONTAL_ALIGNMENT_CENTER})
	text("CONDITION %s   FUEL %s L" % [condition_text(s), grouped(s.fuel)], body.position + Vector2(440, 21), SMALL,
		RED if wreck(s) else WHITE)
	return body.position.y + 44


# Variant B: Hangar chooses the ship in service and sells; UPGRADES and SERVICE are tiles

func draw_hangar_b(body: Rect2) -> void:
	text("BERTHS %d/%d" % [ships.size(), BERTHS], Vector2(body.position.x, body.position.y + 16), TEXT, WHITE)
	var y := body.position.y + 34
	for s: Dictionary in ships:
		var i := ships.find(s)
		var info := "%s   %s L   %d UPGRADES" % [condition_text(s), grouped(s.fuel), s.upgrades.size()]
		stop(Rect2(Vector2(body.position.x, y), Vector2(body.size.x, 30)),
			s.name + ("   IN SERVICE" if i == in_service else ""), func() -> void: pass,
			{"boxed": false, "right": info, "hover": func() -> void: ship_index = i})
		y += 34
		if i == ship_index:
			var x := body.position.x + 24
			for b: Array in [["PUT IN SERVICE", why_not_service(s), func() -> void: put_in_service(s)],
					["SELL  " + eur(sale_price(s)), why_not_sell(s), func() -> void: sell(s)]]:
				stop(Rect2(Vector2(x, y), Vector2(240, 28)), b[0], b[2],
					{"disabled": b[1] != "", "align": HORIZONTAL_ALIGNMENT_CENTER})
				x += 256
			var reason := why_not_service(s) if why_not_service(s) != "ALREADY IN SERVICE" else why_not_sell(s)
			if reason != "":
				text(reason, Vector2(x + 8, y + 19), SMALL, RED)
			y += 40
	for i in BERTHS - ships.size():
		text("EMPTY BERTH", Vector2(body.position.x + 8, y + 20), SMALL, dim())
		y += 34


func draw_service(body: Rect2) -> void:
	var top := draw_picker(body)
	var s := ship()
	text("FUEL", Vector2(body.position.x, top + 18), TEXT, WHITE)
	draw_fuel_panel(s, Vector2(body.position.x, top + 46), 380)
	var x := body.position.x + body.size.x * 0.55
	text("REPAIR", Vector2(x, top + 18), TEXT, WHITE)
	label_value("CONDITION", condition_text(s), Vector2(x, top + 46), 170, RED if wreck(s) else WHITE)
	var y := button(Vector2(x, top + 60), "REPAIR  " + eur(repair_cost(s)), why_not_repair(s),
		func() -> void: repair(s), 300) + 20
	if "LANDING PARACHUTE" in s.upgrades:
		text("PARACHUTE", Vector2(x, y + 10), TEXT, WHITE)
		label_value("STATE", s.chute, Vector2(x, y + 38), 170, RED if s.chute == "USED" else WHITE)
		button(Vector2(x, y + 52), "REPACK  " + eur(repack_cost(s)), why_not_repack(s), func() -> void: repack(s), 300)


# Variant C: berths on the left, the chosen ship's tabs on the right

func draw_hangar_c(body: Rect2) -> void:
	var left_w := body.size.x * 0.34
	text("BERTHS %d/%d" % [ships.size(), BERTHS], Vector2(body.position.x, body.position.y + 16), TEXT, WHITE)
	var y := body.position.y + 30
	for s: Dictionary in ships:
		var i := ships.find(s)
		var r := Rect2(Vector2(body.position.x, y), Vector2(left_w, 52))
		stop(r, "", func() -> void: ship_index = i, {"boxed": false, "hover": func() -> void:
			ship_index = i
			fuel_amount = 0})
		var on := stops.size() - 1 == cursor
		if i == ship_index and not on:
			draw_rect(r, Color(fg(), 0.15))
		text(s.name, r.position + Vector2(8, 22), TEXT, BLACK if on else fg())
		if i == in_service:
			text("IN SERVICE", r.position + Vector2(8, 22), 12, BLACK if on else WHITE, r.size.x - 16, HORIZONTAL_ALIGNMENT_RIGHT)
		text("%s   %s L%s" % [condition_text(s), grouped(s.fuel), ("   CHUTE " + s.chute) if s.chute != "" else ""],
			r.position + Vector2(8, 42), 12, BLACK if on else (RED if wreck(s) else WHITE))
		y += 58
	for i in BERTHS - ships.size():
		stop(Rect2(Vector2(body.position.x, y), Vector2(left_w, 52)), "EMPTY BERTH   BUY >",
			func() -> void: go(Screen.SHIPYARD), {"boxed": false, "disabled": true})
		y += 58
	var x := body.position.x + left_w + 32
	var right_w := body.size.x - left_w - 32
	draw_line(Vector2(x - 16, body.position.y), Vector2(x - 16, body.end.y), dim(), 1.0)
	var s := ship()
	var tabs := ["STATUS", "UPGRADES", "FUEL"]
	var tab_label := ""
	for i in tabs.size():
		tab_label += ("[ %s ]" if i == tab else "  %s  ") % tabs[i] + "   "
	stop(Rect2(Vector2(x, body.position.y), Vector2(right_w, 30)), "<  " + tab_label + " >", func() -> void: pass,
		{"adjust": func(step: int) -> void: tab = posmod(tab + step, tabs.size()), "boxed": true})
	var top := body.position.y + 44
	match tab:
		0:
			text(s.name, Vector2(x, top + 20), 20)
			var sy := draw_status(s, Vector2(x, top + 50))
			draw_fitted(s, Vector2(x, sy + 6))
			var bx := x + right_w * 0.5
			var by := top
			for b: Array in [["PUT IN SERVICE", why_not_service(s), func() -> void: put_in_service(s)],
					["REPAIR  " + eur(repair_cost(s)), why_not_repair(s), func() -> void: repair(s)],
					["REPACK PARACHUTE  " + eur(repack_cost(s)), why_not_repack(s), func() -> void: repack(s)],
					["SELL  " + eur(sale_price(s)), why_not_sell(s), func() -> void: sell(s)]]:
				if b[0].begins_with("REPACK") and not "LANDING PARACHUTE" in s.upgrades:
					continue
				stop(Rect2(Vector2(bx, by), Vector2(right_w * 0.5, 30)), b[0], b[2],
					{"disabled": b[1] != "", "align": HORIZONTAL_ALIGNMENT_CENTER})
				if b[1] != "" and stops.size() - 1 == cursor:
					text(b[1], Vector2(bx, by + 50), SMALL, RED, right_w * 0.5)
				by += 38
		1:
			var list_w := right_w * 0.55
			var hovered := draw_upgrade_list(Rect2(Vector2(x, top), Vector2(list_w, body.end.y - top)), s)
			draw_upgrade_detail(hovered, s, Vector2(x + list_w + 24, top + 24), right_w - list_w - 24)
		2:
			draw_fuel_panel(s, Vector2(x, top + 24), 400)


# Workshop: the Landed ship's fuel and full REPAIR on a pad, orange on black

func draw_workshop(body: Rect2) -> void:
	var s := ship()
	text(s.name + "  LANDED AT THE MINE", Vector2(body.position.x, body.position.y + 20), 20)
	draw_status(s, Vector2(body.position.x, body.position.y + 60))
	var x := body.position.x + body.size.x * 0.45
	text("FUEL", Vector2(x, body.position.y + 20), TEXT, WHITE)
	var y := draw_fuel_panel(s, Vector2(x, body.position.y + 48), 380)
	text("REPAIR", Vector2(x, y + 14), TEXT, WHITE)
	button(Vector2(x, y + 26), "REPAIR  " + eur(repair_cost(s) * 1.5), why_not_repair(s), func() -> void: repair(s), 380)
