class_name Location
extends RefCounted
# The location table: every place on the planet the station can be above, with its pad and
# terrain and its ground's height. The mountain side walls, backdrop, deep space and station
# are shared.

# The open-pit mine's benches step down from the Valley's ground level, three steps a side, the
# last one onto the pit floor.
const BENCH_STEP := 60.0
const PIT_DEPTH := 3.0 * BENCH_STEP

# Shown in the HUD.
var name: String
var pad_center_x: float
# The top of the ground here, where the pad sits and ships land, in world y.
var ground_y := World.GROUND_TOP_Y
# How wide the ground (the landing surface) is, centred on the pad; by default it spans the whole
# world. Narrowed, ships beside it fall past its height onto whatever terrain lies below.
var ground_width := INF
# The lowest the surface reaches here, in world y: the camera's bottom limit, and how far down
# the sky fills. By default the ground's bottom.
var lowest_y := NAN:
	get:
		return ground_y + World.GROUND_DEPTH if is_nan(lowest_y) else lowest_y
# Solid polygons added to the shared ground and mountains; touching them crashes the ship.
var terrain: Array[PackedVector2Array] = []

# Named like constants: GDScript can't build objects in a const, so never reassign these.
static var VALLEY := valley()
static var MINE := mine()
# In drift order: the location after the last one is the first.
static var ALL: Array[Location] = [VALLEY, MINE]


# The location after this one in drift order, wrapping to the first.
func next() -> Location:
	return ALL[(ALL.find(self) + 1) % ALL.size()]


static func valley() -> Location:
	var location := Location.new()
	location.name = "VALLEY"
	location.pad_center_x = World.WORLD_WIDTH / 2.0
	return location


# An open-pit mine: stepped benches cut down into the ground on both sides to a pit floor below
# the Valley's ground, wider steps on the left, with the pad off-centre on the pit floor toward
# the right. Each side reaches under its mountain and down to the ground's bottom, so no sky
# shows below the Valley's ground outside the open-pit mine.
static func mine() -> Location:
	var location := Location.new()
	location.name = "MINE"
	location.pad_center_x = 1300.0
	location.ground_y = World.GROUND_TOP_Y + PIT_DEPTH
	var top := World.GROUND_TOP_Y
	var bottom := location.ground_y + World.GROUND_DEPTH
	var left := -World.SIDE_OVERHANG
	var right := World.WORLD_WIDTH + World.SIDE_OVERHANG
	location.terrain = [
		PackedVector2Array([
			Vector2(left, top), Vector2(450, top), Vector2(450, top + BENCH_STEP),
			Vector2(650, top + BENCH_STEP), Vector2(650, top + 2.0 * BENCH_STEP),
			Vector2(850, top + 2.0 * BENCH_STEP), Vector2(850, bottom), Vector2(left, bottom),
		]),
		PackedVector2Array([
			Vector2(1450, bottom), Vector2(1450, top + 2.0 * BENCH_STEP),
			Vector2(1550, top + 2.0 * BENCH_STEP), Vector2(1550, top + BENCH_STEP),
			Vector2(1650, top + BENCH_STEP), Vector2(1650, top), Vector2(right, top), Vector2(right, bottom),
		]),
	]
	return location
