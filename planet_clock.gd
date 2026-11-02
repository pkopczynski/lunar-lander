class_name PlanetClock
extends Node
# The planet's one clock: the local time and the current location. It knows nothing about
# the sky, the HUD or contracts. Pausable, so it stops while the Office shows; a scene node
# with no static state, so a restart wipes it.

const MINUTES_PER_DAY := 1440
# 120× real time: a whole day lasts 12 real minutes.
const MINUTES_PER_SECOND := 2.0

# The start periods: the parts of the day a mission can start in, each six hours long
# from midnight (Night 00:00-05:59, Morning 06:00-11:59, Day 12:00-17:59, Evening 18:00-23:59).
enum StartPeriod { NIGHT, MORNING, DAY, EVENING }
const PERIOD_MINUTES := 360

# The World follows it, moving the pad (and later the terrain).
signal location_changed(location: Location)

# The location below the station; change it only through move_to().
var location := Location.VALLEY
# The local time, in in-game minutes since midnight.
var minutes := 0.0
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


# The local time carries on unchanged.
func move_to(to: Location) -> void:
	location = to
	location_changed.emit(location)


func hhmm() -> String:
	var whole := floori(minutes)
	return "%02d:%02d" % [whole / 60, whole % 60]
