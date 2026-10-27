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

const SURFACE_COLOR := Color(0.9, 0.4, 0.1)

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

const STAR_SEED := 7
# Area of deep space per star, in px².
const STAR_SPACING := 6000.0
const STAR_RADIUS_MIN := 1.0
const STAR_RADIUS_MAX := 2.0
const SURFACE_STAR_DEPTH := 300.0
const SURFACE_STAR_SHARE := 0.4

var star_positions := PackedVector2Array()
var star_radii := PackedFloat32Array()
var star_alphas := PackedFloat32Array()

@onready var mountains: StaticBody2D = $Mountains


func _ready() -> void:
	var outline := PackedVector2Array(MOUNTAIN_OUTLINE)
	var mirrored := PackedVector2Array()
	for point in outline:
		mirrored.append(Vector2(WORLD_WIDTH - point.x, point.y))
	build_mountain(outline)
	build_mountain(mirrored)

	var rng := RandomNumberGenerator.new()
	rng.seed = STAR_SEED
	var width := WORLD_WIDTH + 2.0 * SIDE_OVERHANG
	var deep := Rect2(-SIDE_OVERHANG, SPACE_TOP_Y, width, BORDER_Y - SPACE_TOP_Y)
	add_stars(rng, deep, roundi(deep.get_area() / STAR_SPACING))
	var surface := Rect2(-SIDE_OVERHANG, BORDER_Y, width, SURFACE_STAR_DEPTH)
	add_stars(rng, surface, roundi(surface.get_area() / STAR_SPACING * SURFACE_STAR_SHARE))


func build_mountain(outline: PackedVector2Array) -> void:
	var shape := CollisionPolygon2D.new()
	shape.polygon = outline
	mountains.add_child(shape)
	var visual := Polygon2D.new()
	visual.polygon = outline
	visual.color = MOUNTAIN_COLOR
	mountains.add_child(visual)


func add_stars(rng: RandomNumberGenerator, area: Rect2, count: int) -> void:
	for i in count:
		var star := Vector2(rng.randf_range(area.position.x, area.end.x), rng.randf_range(area.position.y, area.end.y))
		star_positions.append(star)
		star_radii.append(rng.randf_range(STAR_RADIUS_MIN, STAR_RADIUS_MAX))
		# Stars below the border fade out toward the bright surface.
		star_alphas.append(1.0 - clampf((star.y - BORDER_Y) / SURFACE_STAR_DEPTH, 0.0, 1.0))


func _draw() -> void:
	var left := -SIDE_OVERHANG
	var right := WORLD_WIDTH + SIDE_OVERHANG
	draw_polygon(PackedVector2Array([
		Vector2(left, BORDER_Y), Vector2(right, BORDER_Y),
		Vector2(right, GROUND_BOTTOM_Y), Vector2(left, GROUND_BOTTOM_Y),
	]), PackedColorArray([Color.BLACK, Color.BLACK, SURFACE_COLOR, SURFACE_COLOR]))
	draw_ridge(FAR_RIDGE, FAR_RIDGE_DARKENING)
	draw_ridge(NEAR_RIDGE, NEAR_RIDGE_DARKENING)
	for i in star_positions.size():
		draw_circle(star_positions[i], star_radii[i], Color(1, 1, 1, star_alphas[i]))


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
	return Color.BLACK.lerp(SURFACE_COLOR, inverse_lerp(BORDER_Y, GROUND_BOTTOM_Y, y))
