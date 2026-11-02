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
# [minute of the day, ground-level colour, scenery darkness], in order through the day.
const KEYFRAMES := [
	[3 * 60.0, NAVY, 0.6],
	[7 * 60.0 + 30.0, PALE_YELLOW, 0.1],
	[13 * 60.0, BLUE, 0.0],
	[19 * 60.0, ORANGE, 0.0],
	[23 * 60.0, NAVY, 0.6],
]

# Surface stars fade in through the late evening and out at dawn, capped faint.
const STARS_IN_START := 20 * 60.0 + 30.0
const STARS_IN_END := 22 * 60.0 + 30.0
const STARS_OUT_START := 5 * 60.0
const STARS_OUT_END := 7 * 60.0
const STAR_BRIGHTNESS_MAX := 0.5
# Before noon the stars are fading out, after it fading in.
const NOON := 12 * 60.0

# The colour at the bottom of the surface gradient; it still fades to black at the Border.
var ground_color: Color
# How much the solid scenery (ground, mountains, terrain) is darkened, 0-1; the pad never is.
var darkness: float
# How bright the surface's night stars are, 0-1 (0 by day).
var star_brightness: float


# The sky at a local time, in in-game minutes since midnight.
static func at(local_minutes: float) -> SkyLook:
	var minute := fposmod(local_minutes, MINUTES_PER_DAY)
	# The keyframes before and after this minute, the last one wrapping to the first.
	var count := KEYFRAMES.size()
	var next := 0
	while next < count and KEYFRAMES[next][0] <= minute:
		next += 1
	var before: Array = KEYFRAMES[(next - 1 + count) % count]
	var after: Array = KEYFRAMES[next % count]
	var span := fposmod(after[0] - before[0], MINUTES_PER_DAY)
	var weight := fposmod(minute - before[0], MINUTES_PER_DAY) / span
	weight = smoothstep(0.0, 1.0, weight)

	var sky := SkyLook.new()
	sky.ground_color = (before[1] as Color).lerp(after[1], weight)
	sky.darkness = lerpf(before[2], after[2], weight)
	var fading_in := clampf(inverse_lerp(STARS_IN_START, STARS_IN_END, minute), 0.0, 1.0)
	var fading_out := 1.0 - clampf(inverse_lerp(STARS_OUT_START, STARS_OUT_END, minute), 0.0, 1.0)
	sky.star_brightness = STAR_BRIGHTNESS_MAX * (fading_in if minute >= NOON else fading_out)
	return sky
