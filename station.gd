class_name Station
extends StaticBody2D

const PASSAGE_WIDTH := 100.0
const ENTRY_LENGTH := 300.0
const ARM_LENGTH := 400.0
const ARM_COUNT := 3
const ARM_GAP := 120.0
const ROOF_THICKNESS := 200.0
const TOP_Y := World.SPACE_TOP_Y - ENTRY_LENGTH - ARM_COUNT * PASSAGE_WIDTH \
	- (ARM_COUNT - 1) * ARM_GAP - ROOF_THICKNESS

const SPOT_SIZE := Vector2(120, 136)
const CHAMBER_MARGIN := 25.0

const WALL_COLOR := Color(0.3, 0.33, 0.4)
const SPOT_COLOR := Color(0.3, 0.8, 1.0)
const SPOT_LINE_WIDTH := 3.0

var parking_spot: Rect2


func _ready() -> void:
	var center_x := World.WORLD_WIDTH / 2.0
	var half := PASSAGE_WIDTH / 2.0
	var shaft_top := TOP_Y + ROOF_THICKNESS
	var shaft_bottom := World.SPACE_TOP_Y - ENTRY_LENGTH
	# The entry corridor and the shaft above it are one straight cut. It reaches
	# below the station so the cut opens the bottom face.
	var passages: Array[Rect2] = [
		Rect2(center_x - half, shaft_top, PASSAGE_WIDTH, World.SPACE_TOP_Y + half - shaft_top),
	]
	# Arms of two E letters, back to back: three to the left, three to the right.
	var ending_centers: Array[Vector2] = []
	var chamber_size := SPOT_SIZE + Vector2.ONE * CHAMBER_MARGIN * 2.0
	for i in ARM_COUNT:
		var arm_y := shaft_bottom - PASSAGE_WIDTH - i * (PASSAGE_WIDTH + ARM_GAP)
		for side: float in [-1.0, 1.0]:
			passages.append(Rect2(center_x, arm_y, side * (half + ARM_LENGTH), PASSAGE_WIDTH).abs())
			var tip_x := center_x + side * (half + ARM_LENGTH)
			ending_centers.append(Vector2(tip_x - side * chamber_size.x / 2.0, arm_y + half))

	var spot_center: Vector2 = ending_centers.pick_random()
	parking_spot = Rect2(spot_center - SPOT_SIZE / 2.0, SPOT_SIZE)
	passages.append(Rect2(spot_center - chamber_size / 2.0, chamber_size))

	var open := rect_polygon(passages[0])
	for passage in passages.slice(1):
		open = Geometry2D.merge_polygons(open, rect_polygon(passage))[0]
	var block := rect_polygon(Rect2(-World.SIDE_OVERHANG, TOP_Y,
		World.WORLD_WIDTH + 2.0 * World.SIDE_OVERHANG, World.SPACE_TOP_Y - TOP_Y))
	for wall in Geometry2D.clip_polygons(block, open):
		var shape := CollisionPolygon2D.new()
		shape.polygon = wall
		add_child(shape)
		var visual := Polygon2D.new()
		visual.polygon = wall
		visual.color = WALL_COLOR
		add_child(visual)


func _draw() -> void:
	draw_rect(parking_spot, SPOT_COLOR, false, SPOT_LINE_WIDTH)


static func rect_polygon(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
