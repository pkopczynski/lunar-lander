class_name SkyLook
extends RefCounted
# The sky look: one pure step from the local time (later also the weather) to how the
# surface's sky looks. It knows nothing about the clock or the World; the World draws from it.

const MINUTES_PER_DAY := 1440.0

# The ground-level sky colour at each keyframe, blended in between, wrapping around midnight.
const NAVY := Color(0.04, 0.06, 0.18)
const PALE_YELLOW := Color(0.95, 0.9, 0.62)
const BLUE := Color(0.35, 0.6, 0.95)
# Today's evening orange, exactly.
const ORANGE := Color(0.9, 0.4, 0.1)
# How much the scenery is darkened at full night (the night keyframes).
const NIGHT_DARKNESS := 0.6
# Named like a constant: GDScript can't build objects in a const, so never reassign it.
static var KEYFRAMES: Array[Keyframe] = [
	Keyframe.new(3 * 60.0, NAVY, NIGHT_DARKNESS),
	Keyframe.new(7 * 60.0 + 30.0, PALE_YELLOW, 0.1),
	Keyframe.new(13 * 60.0, BLUE, 0.0),
	Keyframe.new(19 * 60.0, ORANGE, 0.0),
	Keyframe.new(23 * 60.0, NAVY, NIGHT_DARKNESS),
]

# Surface stars fade in through the late evening and out at dawn, capped faint.
const STARS_IN_START := 20 * 60.0 + 30.0
const STARS_IN_END := 22 * 60.0 + 30.0
const STARS_OUT_START := 5 * 60.0
const STARS_OUT_END := 7 * 60.0
const STAR_BRIGHTNESS_MAX := 0.5
# Before noon the stars are fading out, after it fading in.
const NOON := 12 * 60.0

# A point in the day the sky is set at, in order through the day: the minute of the day, the
# ground-level colour and the scenery darkness.
class Keyframe:
	var minute: float
	var color: Color
	var darkness: float

	func _init(at_minute: float, at_color: Color, at_darkness: float) -> void:
		minute = at_minute
		color = at_color
		darkness = at_darkness


# The colour at the bottom of the surface gradient; it still fades to black at the Border.
var ground_color: Color
# How much the solid scenery (ground, mountains, terrain) is darkened, 0-1; the pad never is.
var darkness: float
# How bright the surface's night stars are, 0-1 (0 by day).
var star_brightness: float


# How far into the night the sky is, for the lights and looks that fade in with it: 0 by day (no
# darkness), 1 from full night's darkness on.
func night() -> float:
	return clampf(darkness / NIGHT_DARKNESS, 0.0, 1.0)


# The sky at a local time, in in-game minutes since midnight.
static func at(local_minutes: float) -> SkyLook:
	var minute := fposmod(local_minutes, MINUTES_PER_DAY)
	# The keyframes before and after this minute, the last one wrapping to the first.
	var count := KEYFRAMES.size()
	var next := 0
	while next < count and KEYFRAMES[next].minute <= minute:
		next += 1
	var before := KEYFRAMES[(next - 1 + count) % count]
	var after := KEYFRAMES[next % count]
	var span := fposmod(after.minute - before.minute, MINUTES_PER_DAY)
	var weight := smoothstep(0.0, 1.0, fposmod(minute - before.minute, MINUTES_PER_DAY) / span)

	var sky := SkyLook.new()
	sky.ground_color = before.color.lerp(after.color, weight)
	sky.darkness = lerpf(before.darkness, after.darkness, weight)
	var fading_in := clampf(inverse_lerp(STARS_IN_START, STARS_IN_END, minute), 0.0, 1.0)
	var fading_out := 1.0 - clampf(inverse_lerp(STARS_OUT_START, STARS_OUT_END, minute), 0.0, 1.0)
	sky.star_brightness = STAR_BRIGHTNESS_MAX * (fading_in if minute >= NOON else fading_out)
	return sky
