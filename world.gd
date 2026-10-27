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
	for i in star_positions.size():
		draw_circle(star_positions[i], star_radii[i], Color(1, 1, 1, star_alphas[i]))
