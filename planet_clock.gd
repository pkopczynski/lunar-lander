class_name PlanetClock
extends Node
# The planet's one clock: the local time and the current location. It knows nothing about
# the sky, the HUD or contracts. Pausable, so it stops while the Office shows; a scene node
# with no static state, so a restart wipes it.
#
# The planet clock: the local time (`minutes`, in-game minutes since midnight, a float), ticked in
# physics at 2 in-game minutes per real second (120×, a day lasts 12 real minutes) and wrapping at
# midnight, and the current location (`location`, changed only through `move_to()`, which emits
# `location_changed`, starts the drift count over and leaves the time alone). Location drift:
# `drift` counts in-game minutes while the ship is above the Border (`count_drift()`, called by the
# World), back to 0 below it, and at `DRIFT_MINUTES` (48 h) moves to the next entry in
# `Location.ALL` once the surface is out of view. `start_mission(destination, start_period)` moves
# to the destination and sets the time to a random whole minute within the start period
# (`PlanetClock.StartPeriod`: Night 00:00–05:59, Morning 06:00–11:59, Day 12:00–17:59, Evening
# 18:00–23:59); a run starts with the Valley and the Evening. `start_period()` is the start period
# holding the local time, and `hhmm()` gives the time as `14:07`. Shared formatters:
# `PlanetClock.local_time(at)` writes a local time (in-game minutes since a midnight, not wrapped)
# as `14:30`, or `01:10 +1` once it's at or past `MINUTES_PER_DAY` (the next day; the Bank account
# uses it); `PlanetClock.time_of_day(at)` writes it as `14:30` whichever day it falls on (the HUD
# and the loaded message); `PlanetClock.duration(real_seconds)` writes real seconds as an in-game
# duration, `3H 00M` (whole in-game minutes); and `PlanetClock.countdown(real_seconds)` writes real
# seconds left as in-game hours, `20H`, while more than an hour is left, then in-game minutes, `60M`
# (a started hour or minute counting as a whole one; an offer's time to accept), with
# `PlanetClock.in_last_hour(real_seconds)` telling when it's counting minutes. A seedable `rng`. It
# knows nothing about the sky, the HUD or contracts. Attached to `PlanetClock`.

const MINUTES_PER_DAY := 1440
# 120× real time: a whole day lasts 12 real minutes.
const MINUTES_PER_SECOND := 2.0

# The start periods: the parts of the day a mission can start in, each six hours long
# from midnight (Night 00:00-05:59, Morning 06:00-11:59, Day 12:00-17:59, Evening 18:00-23:59).
enum StartPeriod { NIGHT, MORNING, DAY, EVENING }
const PERIOD_MINUTES := 360
# Two whole days above the Border, then the location moves on to the next one.
const DRIFT_MINUTES := 2880.0

# The World follows it, moving the pad and rebuilding the terrain.
signal location_changed(location: Location)

# The location below the station; change it only through move_to().
var location := Location.VALLEY
# The local time, in in-game minutes since midnight.
var minutes := 0.0
# In-game minutes counted toward drift: the time above the Border since the ship last went
# below it or the location last changed.
var drift := 0.0
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
	start_run()


# Ticked in physics so the --fixed-fps tests stay deterministic.
func _physics_process(delta: float) -> void:
	minutes = fposmod(minutes + delta * MINUTES_PER_SECOND, MINUTES_PER_DAY)


# Seeds the rng and starts the run over from it, for tests.
func reseed(value: int) -> void:
	rng.seed = value
	start_run()


# A run starts at the Valley, at a random Evening minute.
func start_run() -> void:
	start_mission(Location.VALLEY, StartPeriod.EVENING)


# Moves to the destination and sets the local time to a random whole minute within the start
# period, re-rolled every time.
func start_mission(destination: Location, period: StartPeriod) -> void:
	move_to(destination)
	minutes = period * PERIOD_MINUTES + rng.randi_range(0, PERIOD_MINUTES - 1)


# Called every physics frame by the World. Counts while the ship is above the Border, and
# moves the location on once the count reaches DRIFT_MINUTES, but only while the surface isn't
# in view, so the change never pops into sight.
func count_drift(delta: float, above_border: bool, surface_in_view: bool) -> void:
	if not above_border:
		drift = 0.0
		return
	drift += delta * MINUTES_PER_SECOND
	if drift >= DRIFT_MINUTES and not surface_in_view:
		move_to(location.next())


# The local time carries on unchanged; the drift count starts over.
func move_to(to: Location) -> void:
	location = to
	drift = 0.0
	location_changed.emit(location)


func start_period() -> StartPeriod:
	return floori(minutes) / PERIOD_MINUTES as StartPeriod


func hhmm() -> String:
	return local_time(minutes)


# A local time in in-game minutes since midnight as 14:30, counting on past midnight: a time
# on the next day (at or past MINUTES_PER_DAY) reads 01:10 +1.
static func local_time(at: float) -> String:
	var day := floori(at) / MINUTES_PER_DAY
	return time_of_day(at) + (" +%d" % day if day > 0 else "")


# A local time as 14:30, whichever day it falls on.
static func time_of_day(at: float) -> String:
	var whole := floori(at)
	return "%02d:%02d" % [whole % MINUTES_PER_DAY / 60, whole % 60]


# Real seconds as an in-game duration, 3H 00M, in whole in-game minutes.
static func duration(real_seconds: float) -> String:
	var whole := floori(real_seconds * MINUTES_PER_SECOND)
	return "%dH %02dM" % [whole / 60, whole % 60]


# Real seconds left as an in-game countdown, a started hour or minute counting as a whole one:
# hours (20H … 2H) while more than an hour is left, then minutes (60M … 1M).
static func countdown(real_seconds: float) -> String:
	var minutes_left := maxi(ceili(real_seconds * MINUTES_PER_SECOND), 0)
	if minutes_left > 60:
		return "%dH" % ceili(minutes_left / 60.0)
	return "%dM" % minutes_left


# Whether a countdown of real seconds left is in its last in-game hour, counting minutes.
static func in_last_hour(real_seconds: float) -> bool:
	return real_seconds * MINUTES_PER_SECOND <= 60.0
