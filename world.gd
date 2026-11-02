class_name World
extends Node2D

const WORLD_WIDTH := 2000.0
# Background drawn past the side edges, for windows wider than the world.
const SIDE_OVERHANG := 1200.0
const GROUND_BOTTOM_Y := 648.0
# About 7 s of full thrust straight up from the pad.
const BORDER_Y := -1660.0
const SPACE_TOP_Y := -4260.0

const MOUNTAIN_TOP_Y := 208.0
# Left mountain outline; the right one is its mirror image.
const MOUNTAIN_OUTLINE := [
	Vector2(-SIDE_OVERHANG, 640), Vector2(-SIDE_OVERHANG, MOUNTAIN_TOP_Y), Vector2(30, MOUNTAIN_TOP_Y),
	Vector2(70, 260), Vector2(110, 240), Vector2(150, 320), Vector2(130, 370), Vector2(190, 410),
	Vector2(170, 460), Vector2(230, 500), Vector2(210, 550), Vector2(250, 600), Vector2(250, 640),
]
const MOUNTAIN_COLOR := Color(0.35, 0.33, 0.33)
# A location's terrain, such as the Mine's benches: warmer than the ground, like cut rock.
const TERRAIN_COLOR := Color(0.52, 0.45, 0.38)

# The Backdrop: two Tatra-like ridges behind the surface, no collision. Only the
# top edge is listed; each ridge closes down to the ground bottom. Most of it
# sits between the mountains, which cover its ends.
# The farther ridge: jagged granite High Tatra peaks, tallest near Rysy.
const FAR_RIDGE := [
	Vector2(-SIDE_OVERHANG, 300), Vector2(150, 300), Vector2(230, 260), Vector2(270, 285),
	Vector2(320, 225), Vector2(350, 250), Vector2(390, 208), Vector2(420, 240),
	Vector2(455, 222), Vector2(490, 270), Vector2(530, 245), Vector2(570, 290),
	Vector2(610, 255), Vector2(650, 300), Vector2(700, 275), Vector2(750, 320),
	Vector2(800, 300), Vector2(860, 340), Vector2(930, 320), Vector2(1000, 350),
	Vector2(1080, 330), Vector2(1160, 345), Vector2(1250, 320), Vector2(1330, 335),
	Vector2(1420, 300), Vector2(1500, 320), Vector2(1580, 285), Vector2(1650, 310),
	Vector2(1720, 290), Vector2(1800, 320), Vector2(1880, 300), Vector2(WORLD_WIDTH + SIDE_OVERHANG, 300),
]
# The nearer ridge: low rounded ridges and Giewont's sleeping knight (the steep
# Wielki Giewont, the long Długi Giewont, then the small bump of Mały Giewont).
const NEAR_RIDGE := [
	Vector2(-SIDE_OVERHANG, 420), Vector2(200, 420), Vector2(280, 400), Vector2(360, 380),
	Vector2(440, 395), Vector2(520, 370), Vector2(600, 385), Vector2(680, 360),
	Vector2(760, 375), Vector2(840, 395), Vector2(920, 410), Vector2(1000, 415),
	Vector2(1080, 400), Vector2(1140, 370), Vector2(1180, 330), Vector2(1210, 290),
	Vector2(1235, 255), Vector2(1250, 248), Vector2(1270, 252), Vector2(1300, 268),
	Vector2(1360, 280), Vector2(1420, 292), Vector2(1470, 300), Vector2(1500, 315),
	Vector2(1530, 305), Vector2(1555, 300), Vector2(1590, 320), Vector2(1650, 345),
	Vector2(1720, 330), Vector2(1800, 350), Vector2(1880, 370), Vector2(WORLD_WIDTH + SIDE_OVERHANG, 380),
]
# How much darker than the background behind it each ridge is.
const FAR_RIDGE_DARKENING := 0.08
const NEAR_RIDGE_DARKENING := 0.16

# The solid scenery the sky's darkness dims (the ground, the mountains, a location's terrain);
# the pad isn't in it, so it stays easy to find at night.
const SCENERY_GROUP := &"scenery"

const STAR_SEED := 7
# Area of deep space per star, in px².
const STAR_SPACING := 6000.0
const STAR_RADIUS_MIN := 1.0
const STAR_RADIUS_MAX := 2.0
const SURFACE_STAR_DEPTH := 300.0
const SURFACE_STAR_SHARE := 0.4
# The surface's night stars cover the whole surface sky, sparser than deep space, drawn at the
# sky's star brightness behind the Backdrop.
const NIGHT_STAR_SPACING := 12000.0

# The location below the station, whose pad and terrain the surface shows. The planet
# clock owns it; the World follows.
var location: Location:
	get:
		return clock.location
# The sky look at the current local time; the World draws from it.
var sky := SkyLook.at(0.0)
# The whole local minute the sky was last taken for; it's taken again once a minute.
var sky_minute := -1
var star_positions := PackedVector2Array()
var star_radii := PackedFloat32Array()
var star_alphas := PackedFloat32Array()
var night_star_positions := PackedVector2Array()
var night_star_radii := PackedFloat32Array()

@onready var mountains: StaticBody2D = $Mountains
@onready var terrain: StaticBody2D = $Terrain
@onready var pad: Polygon2D = $Ground/Pad
@onready var clock: PlanetClock = $PlanetClock


func _ready() -> void:
	var outline := PackedVector2Array(MOUNTAIN_OUTLINE)
	var mirrored := PackedVector2Array()
	for point in outline:
		mirrored.append(Vector2(WORLD_WIDTH - point.x, point.y))
	build_mountain(outline)
	build_mountain(mirrored)
	var half := Lander.PAD_WIDTH / 2.0
	pad.polygon = PackedVector2Array([
		Vector2(-half, -Lander.PAD_HEIGHT), Vector2(half, -Lander.PAD_HEIGHT),
		Vector2(half, 0), Vector2(-half, 0),
	])
	clock.location_changed.connect(show_location)
	show_location(location)
	add_scenery($Ground/Polygon2D)
	show_sky()

	var rng := RandomNumberGenerator.new()
	rng.seed = STAR_SEED
	var width := WORLD_WIDTH + 2.0 * SIDE_OVERHANG
	var deep := Rect2(-SIDE_OVERHANG, SPACE_TOP_Y, width, BORDER_Y - SPACE_TOP_Y)
	add_stars(rng, deep, roundi(deep.get_area() / STAR_SPACING))
	var surface := Rect2(-SIDE_OVERHANG, BORDER_Y, width, SURFACE_STAR_DEPTH)
	add_stars(rng, surface, roundi(surface.get_area() / STAR_SPACING * SURFACE_STAR_SHARE))
	var surface_sky := Rect2(-SIDE_OVERHANG, BORDER_Y, width, GROUND_BOTTOM_Y - BORDER_Y)
	for i in roundi(surface_sky.get_area() / NIGHT_STAR_SPACING):
		night_star_positions.append(Vector2(rng.randf_range(surface_sky.position.x, surface_sky.end.x),
			rng.randf_range(surface_sky.position.y, surface_sky.end.y)))
		night_star_radii.append(rng.randf_range(STAR_RADIUS_MIN, STAR_RADIUS_MAX))


# The world redraws as the local time passes.
func _physics_process(_delta: float) -> void:
	if floori(clock.minutes) != sky_minute:
		show_sky()


# Takes the sky look for the current local time: redraws the gradient and Backdrop from it and
# dims the scenery.
func show_sky() -> void:
	sky = SkyLook.at(clock.minutes)
	sky_minute = floori(clock.minutes)
	for visual in get_tree().get_nodes_in_group(SCENERY_GROUP):
		dim(visual)
	queue_redraw()


# Makes a solid visual part of the scenery, dimmed by the sky's darkness from now on; a
# location's terrain goes through here too.
func add_scenery(visual: CanvasItem) -> void:
	visual.add_to_group(SCENERY_GROUP)
	dim(visual)


func dim(visual: CanvasItem) -> void:
	visual.self_modulate = Color.WHITE.darkened(sky.darkness)


# Moves the surface to the clock's new location: its pad, and its terrain built afresh.
func show_location(to: Location) -> void:
	pad.position.x = to.pad_center_x - pad.get_parent().position.x
	for child in terrain.get_children():
		terrain.remove_child(child)
		child.queue_free()
	for outline in to.terrain:
		var shape := CollisionPolygon2D.new()
		shape.polygon = outline
		terrain.add_child(shape)
		var visual := Polygon2D.new()
		visual.polygon = outline
		visual.color = TERRAIN_COLOR
		terrain.add_child(visual)
		add_scenery(visual)


func build_mountain(outline: PackedVector2Array) -> void:
	var shape := CollisionPolygon2D.new()
	shape.polygon = outline
	mountains.add_child(shape)
	var visual := Polygon2D.new()
	visual.polygon = outline
	visual.color = MOUNTAIN_COLOR
	mountains.add_child(visual)
	add_scenery(visual)


func add_stars(rng: RandomNumberGenerator, area: Rect2, count: int) -> void:
	for i in count:
		var star := Vector2(rng.randf_range(area.position.x, area.end.x), rng.randf_range(area.position.y, area.end.y))
		star_positions.append(star)
		star_radii.append(rng.randf_range(STAR_RADIUS_MIN, STAR_RADIUS_MAX))
		# Stars below the border fade out toward the bright surface.
		star_alphas.append(1.0 - clampf((star.y - BORDER_Y) / SURFACE_STAR_DEPTH, 0.0, 1.0))


# Every star the World draws, as {position, radius, color}: the surface's night stars (none by
# day), then the deep-space stars. Fully transparent ones are left out.
func shown_stars() -> Array[Dictionary]:
	var stars: Array[Dictionary] = []
	if sky.star_brightness > 0.0:
		for i in night_star_positions.size():
			stars.append({position = night_star_positions[i], radius = night_star_radii[i],
				color = Color(1, 1, 1, sky.star_brightness)})
	for i in star_positions.size():
		if star_alphas[i] > 0.0:
			stars.append({position = star_positions[i], radius = star_radii[i], color = Color(1, 1, 1, star_alphas[i])})
	return stars


func _draw() -> void:
	var left := -SIDE_OVERHANG
	var right := WORLD_WIDTH + SIDE_OVERHANG
	draw_polygon(PackedVector2Array([
		Vector2(left, BORDER_Y), Vector2(right, BORDER_Y),
		Vector2(right, GROUND_BOTTOM_Y), Vector2(left, GROUND_BOTTOM_Y),
	]), PackedColorArray([Color.BLACK, Color.BLACK, sky.ground_color, sky.ground_color]))
	# Stars go behind the Backdrop; the ground and mountains, child nodes, cover them too.
	for star in shown_stars():
		draw_circle(star.position, star.radius, star.color)
	draw_ridge(FAR_RIDGE, FAR_RIDGE_DARKENING)
	draw_ridge(NEAR_RIDGE, NEAR_RIDGE_DARKENING)


# Fills a Backdrop ridge with the background gradient, darkened, so it reads as
# a shadow of the sky behind it.
func draw_ridge(top_edge: Array, darkening: float) -> void:
	var outline := PackedVector2Array(top_edge)
	outline.append(Vector2(outline[-1].x, GROUND_BOTTOM_Y))
	outline.append(Vector2(outline[0].x, GROUND_BOTTOM_Y))
	var colors := PackedColorArray()
	for point in outline:
		colors.append(background_color(point.y).darkened(darkening))
	draw_polygon(outline, colors)


func background_color(y: float) -> Color:
	return Color.BLACK.lerp(sky.ground_color, inverse_lerp(BORDER_Y, GROUND_BOTTOM_Y, y))
