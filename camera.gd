class_name FollowCamera
extends Camera2D

const SURFACE_ZOOM := 1.3
const DEEP_SPACE_ZOOM := 0.6
const STATION_ZOOM := 1.3
# Below the station, the zoom blends from deep space to station over this distance.
const STATION_BLEND := 600.0

const SLOW_SPEED := 50.0
const FAST_SPEED := 400.0
# Multiplies the region zoom at full speed.
const FAST_ZOOM_FACTOR := 0.65
const ZOOM_EASE_SPEED := 2.0

const PUNCH_ZOOM := 3.0
const PUNCH_IN_TIME := 0.35
const PUNCH_HOLD_TIME := 0.25
const PUNCH_OUT_TIME := 1.4

const SHAKE_TIME := 2.0
const SHAKE_STRENGTH := 10.0

var shake_left := 0.0
var eased_zoom := SURFACE_ZOOM
var punch_factor := 1.0
var punch_tween: Tween

@onready var lander: Lander = get_parent()


func _ready() -> void:
	limit_top = int(Station.TOP_Y)


func _process(delta: float) -> void:
	var fast_share := clampf(inverse_lerp(SLOW_SPEED, FAST_SPEED, lander.velocity.length()), 0.0, 1.0)
	var target := region_zoom() * lerpf(1.0, FAST_ZOOM_FACTOR, fast_share)
	eased_zoom = lerpf(eased_zoom, target, 1.0 - exp(-ZOOM_EASE_SPEED * delta))
	zoom = Vector2.ONE * eased_zoom * punch_factor
	fit_side_limits()
	limit_bottom = int(lander.world.ground_bottom())

	shake_left = maxf(shake_left - delta, 0.0)
	offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * SHAKE_STRENGTH * shake_left / SHAKE_TIME


func region_zoom() -> float:
	if not lander.in_deep_space:
		return SURFACE_ZOOM
	var station_share := smoothstep(World.SPACE_TOP_Y + STATION_BLEND, World.SPACE_TOP_Y, lander.position.y)
	return lerpf(DEEP_SPACE_ZOOM, STATION_ZOOM, station_share)


# The sides clamp to the world edges, but a view wider than the world is
# centred on it instead of pinned to the right edge.
func fit_side_limits() -> void:
	var view_width := get_viewport_rect().size.x / zoom.x
	var extra := maxf(view_width - World.WORLD_WIDTH, 0.0) / 2.0
	limit_left = int(-extra)
	limit_right = int(World.WORLD_WIDTH + extra)


func shake() -> void:
	shake_left = SHAKE_TIME


func punch() -> void:
	if punch_tween:
		punch_tween.kill()
	punch_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	punch_tween.tween_property(self, "punch_factor", PUNCH_ZOOM, PUNCH_IN_TIME)
	punch_tween.tween_interval(PUNCH_HOLD_TIME)
	punch_tween.tween_property(self, "punch_factor", 1.0, PUNCH_OUT_TIME)
