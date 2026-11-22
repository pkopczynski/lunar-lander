extends Control
# Draws the fuel bar and weight readout from the lander's state, the clock line (`VALLEY  14:07`)
# from the planet clock's, the destination and flight deadline under it (`MINE BY 14:30`) from the
# Economy's, the green `+€X` payout that rises above the ship and fades, and the ship in service's
# Condition under the weight (`CONDITION 87%`) with a brief red flash of each loss under it (`−6%`), and the bottom-left `O  ENTER THE OFFICE` (or `O  ENTER THE WORKSHOP` when Landed) hint while the Office's `can_open_by_key()` holds. Attached to `UI/Hud`.
# Its static `format_kg()`, `format_litres()` (fuel, `2 000 l (1 600 kg)`) and `group_thousands()` (`1 234 567`) also write the Office's masses and
# `Economy.eur()`'s euros.

const BAR_SIZE := Vector2(24, 200)
const RIGHT_MARGIN := 48.0
const BORDER_WIDTH := 2
const CORNER_RADIUS := 6
const FILL_INSET := 4.0
const FONT_SIZE := 16
const TEXT_GAP := 8.0

const FRAME_BG_COLOR := Color(0.1, 0.1, 0.12, 0.6)
const FRAME_COLOR := Color(0.8, 0.8, 0.85)
const EMPTY_FLASH_COLOR := Color(1.0, 0.3, 0.3)
const EMPTY_FLASH_HZ := 2.0
const FUEL_SURFACE_COLOR := Color(0.64, 0.42, 0.2)
const FUEL_BOTTOM_COLOR := Color("7a4a1e")
const TEXT_COLOR := Color(0.9, 0.9, 0.95)
const OVERDUE_COLOR := Color(1.0, 0.3, 0.3)

# The clock line in the upper right, with the delivery timer under it.
const TIMER_FONT_SIZE := 24
const TIMER_MARGIN := Vector2(24, 40)
const TIMER_LINE_HEIGHT := 32.0
# The O key's hint in the bottom-left corner, shown exactly while O would open the Office (Docked)
# or the pad's Workshop (Landed).
const OFFICE_HINT_TEXT := "O  ENTER THE OFFICE"
const WORKSHOP_HINT_TEXT := "O  ENTER THE WORKSHOP"
const OFFICE_HINT_MARGIN := Vector2(24, 24)
const DELIVERY_TEXT := "%s BY %s"
const OVERDUE_TEXT := "%s OVERDUE SINCE %s"

# The payout that rises above the ship and fades.
const PAYOUT_COLOR := Color(0.3, 1.0, 0.4)
const PAYOUT_FONT_SIZE := 20
const PAYOUT_WIDTH := 200.0
const PAYOUT_START_HEIGHT := 40.0
const PAYOUT_RISE := 60.0
const PAYOUT_TIME := 2.0

# The flash of a Condition loss under the Condition line, fading out.
const LOSS_COLOR := Color(1.0, 0.3, 0.3)
const LOSS_TIME := 1.5

const LEVEL_EASE_SPEED := 6.0
const WAVE_HEIGHT := 2.0
const WAVE_LENGTH := 14.0
const WAVE_SPEED := 3.0
const WAVE_SEGMENTS := 12

var shown_level := 1.0
var time := 0.0
var frame_style := StyleBoxFlat.new()
# The floating +€X, "" when none; payout_progress goes 0 → 1 as it rises and fades.
var payout := ""
var payout_progress := 0.0
var payout_tween: Tween
# The flashing −6%, "" when none; loss_left counts down from LOSS_TIME.
var loss := ""
var loss_left := 0.0

@onready var lander: Lander = $"../../Lander"
@onready var economy: Economy = $"../../Economy"
@onready var clock: PlanetClock = $"../../PlanetClock"
@onready var office: Office = $"../../Office"


func _ready() -> void:
	frame_style.bg_color = FRAME_BG_COLOR
	frame_style.set_border_width_all(BORDER_WIDTH)
	frame_style.set_corner_radius_all(CORNER_RADIUS)
	economy.paid_out.connect(show_payout)
	lander.damaged.connect(show_loss)


func _process(delta: float) -> void:
	time += delta
	loss_left = maxf(loss_left - delta, 0.0)
	if loss_left <= 0.0:
		loss = ""
	var level := lander.tank_level()
	shown_level = lerpf(shown_level, level, 1.0 - exp(-LEVEL_EASE_SPEED * delta))
	queue_redraw()


func _draw() -> void:
	var bar := Rect2(Vector2(size.x - RIGHT_MARGIN - BAR_SIZE.x, (size.y - BAR_SIZE.y) / 2.0), BAR_SIZE)
	var flashing := lander.fuel <= 0.0 and sin(time * TAU * EMPTY_FLASH_HZ) > 0.0
	frame_style.border_color = EMPTY_FLASH_COLOR if flashing else FRAME_COLOR
	draw_style_box(frame_style, bar)
	draw_fuel(bar.grow(-FILL_INSET))

	var font := get_theme_default_font()
	var text_width := RIGHT_MARGIN * 2.0 + BAR_SIZE.x
	var text_x := bar.get_center().x - text_width / 2.0
	draw_string(font, Vector2(text_x, bar.position.y - TEXT_GAP), "FUEL",
		HORIZONTAL_ALIGNMENT_CENTER, text_width, FONT_SIZE, TEXT_COLOR)
	draw_string(font, Vector2(text_x, bar.end.y + TEXT_GAP + FONT_SIZE), format_kg(lander.total_mass()),
		HORIZONTAL_ALIGNMENT_CENTER, text_width, FONT_SIZE, TEXT_COLOR)
	var condition_y := bar.end.y + 2.0 * (TEXT_GAP + FONT_SIZE)
	draw_string(font, Vector2(0.0, condition_y), condition_text(), HORIZONTAL_ALIGNMENT_RIGHT,
		size.x - TEXT_GAP, FONT_SIZE, TEXT_COLOR)
	if loss != "":
		draw_string(font, Vector2(0.0, condition_y + TEXT_GAP + FONT_SIZE), loss, HORIZONTAL_ALIGNMENT_RIGHT,
			size.x - TEXT_GAP, FONT_SIZE, Color(LOSS_COLOR, loss_left / LOSS_TIME))

	draw_string(font, Vector2(0.0, TIMER_MARGIN.y), clock_text(), HORIZONTAL_ALIGNMENT_RIGHT,
		size.x - TIMER_MARGIN.x, TIMER_FONT_SIZE, TEXT_COLOR)
	var timer := delivery_text()
	if timer != "":
		draw_string(font, Vector2(0.0, TIMER_MARGIN.y + TIMER_LINE_HEIGHT), timer, HORIZONTAL_ALIGNMENT_RIGHT,
			size.x - TIMER_MARGIN.x, TIMER_FONT_SIZE, OVERDUE_COLOR if delivery_overdue() else TEXT_COLOR)

	var hint := office_hint_text()
	if hint != "":
		draw_string(font, Vector2(OFFICE_HINT_MARGIN.x, size.y - OFFICE_HINT_MARGIN.y), hint,
			HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, TEXT_COLOR)

	if payout != "":
		var above := lander.get_global_transform_with_canvas().origin \
			- Vector2(PAYOUT_WIDTH / 2.0, PAYOUT_START_HEIGHT + PAYOUT_RISE * payout_progress)
		draw_string(font, above, payout, HORIZONTAL_ALIGNMENT_CENTER, PAYOUT_WIDTH, PAYOUT_FONT_SIZE,
			Color(PAYOUT_COLOR, 1.0 - payout_progress))


func show_payout(total: int) -> void:
	payout = "+" + Economy.eur(total)
	payout_progress = 0.0
	if payout_tween:
		payout_tween.kill()
	payout_tween = create_tween()
	payout_tween.tween_property(self, "payout_progress", 1.0, PAYOUT_TIME)
	payout_tween.tween_callback(func() -> void: payout = "")


func show_loss(share: float) -> void:
	loss = "−%d%%" % maxi(roundi(share * 100.0), 1)
	loss_left = LOSS_TIME


# The ship in service's Condition: CONDITION 87%.
func condition_text() -> String:
	return "CONDITION %d%%" % roundi(lander.ship.condition * 100.0)


# The flash of the last Condition loss while it shows (−6%), else "".
func loss_text() -> String:
	return loss


# O  ENTER THE OFFICE (Docked) or O  ENTER THE WORKSHOP (Landed) while O would open it
# (`Office.can_open_by_key()`), else "".
func office_hint_text() -> String:
	if not office.can_open_by_key():
		return ""
	return WORKSHOP_HINT_TEXT if lander.state == Lander.State.LANDED else OFFICE_HINT_TEXT


# The current location's name and the local time: VALLEY  14:07.
func clock_text() -> String:
	return "%s  %s" % [clock.location.name, clock.hhmm()]


# The destination and the flight deadline as a local time while delivering: MINE BY 14:30,
# MINE OVERDUE SINCE 14:30 once late, "" otherwise. The time alone is clear enough, so a
# next-day one has no +1.
func delivery_text() -> String:
	if not economy.mission_under_way():
		return ""
	var text := OVERDUE_TEXT if delivery_overdue() else DELIVERY_TEXT
	return text % [economy.destination().name, PlanetClock.time_of_day(economy.deadline_at())]


func delivery_overdue() -> bool:
	return economy.mission_under_way() and economy.delivery_left() < 0.0


func draw_fuel(inner: Rect2) -> void:
	var fill_height := inner.size.y * shown_level
	if fill_height < 0.5:
		return
	var surface_y := inner.end.y - fill_height
	# Shrink the wave near empty and full so it never leaves the bar.
	var amplitude := minf(WAVE_HEIGHT, minf(fill_height, inner.size.y - fill_height) / 2.0)
	var colors := PackedColorArray([FUEL_SURFACE_COLOR, FUEL_SURFACE_COLOR, FUEL_BOTTOM_COLOR, FUEL_BOTTOM_COLOR])
	# One quad per segment: quads always triangulate, a flat wave polygon may not.
	for i in WAVE_SEGMENTS:
		var x0 := inner.position.x + inner.size.x * i / WAVE_SEGMENTS
		var x1 := inner.position.x + inner.size.x * (i + 1) / WAVE_SEGMENTS
		draw_polygon(PackedVector2Array([
			Vector2(x0, surface_y + wave(x0) * amplitude), Vector2(x1, surface_y + wave(x1) * amplitude),
			Vector2(x1, inner.end.y), Vector2(x0, inner.end.y),
		]), colors)


func wave(x: float) -> float:
	return sin(x / WAVE_LENGTH * TAU + time * WAVE_SPEED)


static func format_kg(kg: float) -> String:
	return group_thousands(roundi(kg)) + " kg"


# Fuel (kg) in litres with its mass second, as 2 000 l (1 600 kg).
static func format_litres(kg: float) -> String:
	return "%s l (%s)" % [group_thousands(roundi(kg / OwnedShip.KG_PER_LITRE)), format_kg(kg)]


# A whole number of zero or more with its thousands split by spaces, as 1 234 567.
static func group_thousands(value: int) -> String:
	var digits := str(value)
	var grouped := ""
	for i in digits.length():
		if i > 0 and (digits.length() - i) % 3 == 0:
			grouped += " "
		grouped += digits[i]
	return grouped
